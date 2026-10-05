import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Envoltura fina sobre flutter_local_notifications.
///
/// Programa cuatro avisos diarios (11:30, 15:00, 20:30 y 23:00) con un tono
/// que escala según se acerca el cierre del día. Si el usuario ya entrenó, los
/// avisos del día se cancelan.
///
/// Limitación conocida: el texto se fija al PROGRAMAR, así que la racha que
/// aparece en el aviso es la del momento en que se programó. Por eso se
/// resincroniza en cada arranque y en cada sesión completada.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Zona horaria usada para "las 11:30 en hora local".
  /// TODO: está fija en Madrid. Cuando haya usuarios fuera de España hay que
  /// detectar la zona del dispositivo (p. ej. con `flutter_timezone`) en vez de
  /// dejarla hardcodeada.
  static const timeZoneName = 'Europe/Madrid';

  /// Android 8+ obliga a declarar un canal; el mismo sirve para los avisos.
  static const channelId = 'kinea_diario';
  static const channelName = 'Recordatorios';
  static const channelDescription =
      'Recordatorios del entrenamiento diario y de la racha.';

  /// Los cuatro avisos del día, en orden. El id es fijo (0-3) para poder
  /// cancelarlos sin tocar nada más que se programe en el futuro.
  static const reminders = [
    _Reminder(hour: 11, minute: 30),
    _Reminder(hour: 15, minute: 0),
    _Reminder(hour: 20, minute: 30),
    _Reminder(hour: 23, minute: 0),
  ];

  /// Tono del aviso según el número de aviso (0 = el más tranquilo).
  static ({String title, String body}) message(int index, int streak) {
    final r = reminders[index];
    return switch (r.hour) {
      11 => (
          title: 'Kinea',
          body: 'Recuerda hacer tu ejercicio diario. Ya llevas una racha de '
              '$streak ${streak == 1 ? 'día' : 'días'}.',
        ),
      15 => (
          title: 'Kinea',
          body: 'El ejercicio te facilita el movimiento y te ayuda. '
              'No lo dejes pasar.',
        ),
      20 => (
          title: 'Kinea',
          body: 'Aún no has entrenado hoy. A estas horas ya debería estar hecho, '
              'y tu cuerpo te lo va a agradecer.',
        ),
      _ => (
          title: 'Se acaba el día',
          body: 'Última hora para entrenar. Si terminas el día sin hacerlo, '
              'pierdes la racha de $streak ${streak == 1 ? 'día' : 'días'}.',
        ),
    };
  }

  Future<void>? _init;

  /// Firma de lo último aplicado, para no reprogramar en bucle.
  String? _lastSignature;

  static bool get _supportedPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static bool get _canSchedule =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Prepara el plugin. Idempotente: se puede llamar desde varios sitios.
  Future<void> ensureReady() => _init ??= _doInit();

  Future<void> _doInit() async {
    if (kIsWeb || !_supportedPlatform) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // El permiso NO se pide aquí a propósito: se pide al pulsar el botón, para
    // poder explicarle al usuario qué está pasando.
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );
  }

  /// Pide el permiso de notificaciones. Devuelve si queda concedido.
  Future<bool> requestPermission() async {
    await ensureReady();
    if (kIsWeb || !_supportedPlatform) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      case TargetPlatform.macOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                    MacOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      default:
        return false;
    }
  }

  /// Lanza una notificación local inmediata.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await ensureReady();
    if (kIsWeb || !_supportedPlatform) return;

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  /// Atajo de prueba: pide permiso y emite los CUATRO avisos de golpe, para ver
  /// los textos y el tono sin esperar a las horas reales.
  Future<String> sendAllTest({required int streak}) async {
    if (kIsWeb) return 'Las notificaciones no están disponibles en web.';

    try {
      final granted = await requestPermission();
      if (!granted) {
        return 'Permiso denegado. Actívalo en los ajustes del sistema.';
      }
      for (var i = 0; i < reminders.length; i++) {
        final m = message(i, streak);
        await show(id: i, title: m.title, body: m.body);
      }
      return 'Enviados los ${reminders.length} avisos ($streak días de racha). '
          'Revisa la bandeja del sistema.';
    } catch (e) {
      return 'No se pudieron emitir los avisos: $e';
    }
  }

  /// Deja los cuatro avisos diarios listos, o los cancela si hoy ya se entrenó.
  ///
  /// Es idempotente por diseño: se llama en cada arranque y tras cada sesión,
  /// así que rehacerlo siempre parte del mismo sitio (primero cancela).
  Future<void> syncDailyReminders({
    required bool alreadyDoneToday,
    required int currentStreak,
  }) async {
    if (!_canSchedule) return;

    // ensureReady() ANTES de tocar tz.local: es ahí dentro donde se fija la
    // zona horaria. Si se lee antes, tz.local sigue siendo UTC y todas las
    // horas se calculan desplazadas.
    await ensureReady();

    // Firma para no reprogramar en bucle: solo cambia si cambia el día, el
    // estado de "hoy ya entrenó" o la racha mostrada.
    final now = tz.TZDateTime.now(tz.local);
    final dayStamp = '${now.year}-${now.month}-${now.day}';
    final signature = '$dayStamp|$alreadyDoneToday|$currentStreak';
    if (_lastSignature == signature) return;

    try {
      // Siempre primero: si hoy ya entrenó, esto es todo lo que hay que hacer.
      for (var i = 0; i < reminders.length; i++) {
        await _plugin.cancel(id: i);
      }
      if (alreadyDoneToday) {
        _lastSignature = signature;
        return;
      }

      for (var i = 0; i < reminders.length; i++) {
        final r = reminders[i];
        final m = message(i, currentStreak);
        await _plugin.zonedSchedule(
          id: i,
          title: m.title,
          body: m.body,
          scheduledDate: _nextOccurrence(now, r),
          notificationDetails: _details,
          // inexact: no exige SCHEDULE_EXACT_ALARM y basta de sobra para un
          // recordatorio diario.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: null,
        );
      }
      _lastSignature = signature;
    } catch (_) {
      // Si falla, no se marca la firma: se reintentará en la próxima llamada.
      _lastSignature = null;
    }
  }

  /// Próxima vez que suena [r]: hoy si aún no ha pasado, si no mañana.
  /// Se reconstruye con día+1 (no `add(Duration(days: 1))`) para que un cambio
  /// de hora de verano no desplace el aviso.
  static tz.TZDateTime _nextOccurrence(tz.TZDateTime now, _Reminder r) {
    final today =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, r.hour, r.minute);
    if (today.isAfter(now)) return today;
    return tz.TZDateTime(
        tz.local, now.year, now.month, now.day + 1, r.hour, r.minute);
  }

  /// Número de avisos que quedan programados. Útil para depurar.
  Future<int> pendingReminderCount() async {
    if (!_canSchedule) return 0;
    await ensureReady();
    final pending = await _plugin.pendingNotificationRequests();
    return pending.where((p) => p.id < reminders.length).length;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );
}

class _Reminder {
  const _Reminder({required this.hour, required this.minute});
  final int hour, minute;
}
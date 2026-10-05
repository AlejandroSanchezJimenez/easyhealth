import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/streak/streak_providers.dart';
import '../providers.dart';
import '../utils/date_key.dart';

/// Mantiene los avisos diarios alineados con el estado real del usuario.
///
/// Se reevalúa cuando cambia el historial, así que:
///
/// - Si hoy ya se completó el entrenamiento, cancela los avisos del día.
/// - Si no, (re)programa los cuatro con la racha actual.
///
/// Se "activa" desde [App] con un `ref.watch`.
final dailyRemindersProvider = Provider<void>((ref) {
  final sessions = ref.watch(sessionsProvider).valueOrNull;
  final stats = ref.watch(streakStatsProvider).valueOrNull;

  // Hasta que el historial esté disponible no se toca nada: si se programara
  // ahora, se haría con la racha a 0 y no se volvería a corregir hasta el
  // siguiente cambio.
  if (sessions == null) return;

  final today = dateKey(DateTime.now());
  final alreadyDoneToday = sessions.any((s) => s.dateKey == today);

  unawaited(ref.read(notificationServiceProvider).syncDailyReminders(
        alreadyDoneToday: alreadyDoneToday,
        currentStreak: stats?.currentStreak ?? 0,
      ));
});
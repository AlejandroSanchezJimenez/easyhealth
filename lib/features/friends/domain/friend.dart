import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/date_key.dart';

/// Estado de un vínculo de amistad.
///
/// La amistad es MUTUA y con aceptación: al añadir, se escriben los dos
/// documentos espejo en estado [pending]; quien recibió la solicitud la acepta
/// y ambos pasan a [accepted].
enum FriendStatus {
  pending,
  accepted;

  static FriendStatus parse(String? v) => v == 'accepted'
      ? FriendStatus.accepted
      : FriendStatus.pending;
}

/// Un vínculo de amistad visto desde MI lista.
///
/// `displayName` y `photoUrl` van desnormalizados: las reglas no permiten leer
/// el documento de otro usuario, así que se copiaron al crear el vínculo
/// (el nombre se resuelve a través del código de invitación).
@immutable
class Friend {
  const Friend({
    required this.uid,
    required this.status,
    required this.requestedBy,
    this.displayName = '',
    this.photoUrl,
    this.createdAt,
  });

  final String uid;
  final FriendStatus status;

  /// uid de quien envió la solicitud. Si no soy yo, espera mi aceptación.
  final String requestedBy;

  final String displayName;
  final String? photoUrl;
  final DateTime? createdAt;

  factory Friend.fromMap(String uid, Map<String, dynamic> m) => Friend(
        uid: uid,
        status: FriendStatus.parse(m['status'] as String?),
        requestedBy: m['requestedBy'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        photoUrl: m['photoUrl'] as String?,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'requestedBy': requestedBy,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

  bool isPendingFrom(String myUid) =>
      status == FriendStatus.pending && requestedBy != myUid;
}

/// Racha pública de un usuario, tal como la deja la Cloud Function.
///
/// OJO: [currentStreak] se calculó en el momento de la última sesión, así que
/// hay que volver a aplicar la regla de "vive si el último día fue hoy o ayer"
/// con [lastExerciseDate]. Ver [resolveFriendStreak].
@immutable
class FriendStreak {
  const FriendStreak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalExerciseDays = 0,
    this.lastExerciseDate,
  });

  final int currentStreak, longestStreak, totalExerciseDays;
  final String? lastExerciseDate;

  factory FriendStreak.fromMap(Map<String, dynamic> m) => FriendStreak(
        currentStreak: (m['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (m['longestStreak'] as num?)?.toInt() ?? 0,
        totalExerciseDays: (m['totalExerciseDays'] as num?)?.toInt() ?? 0,
        lastExerciseDate: m['lastExerciseDate'] as String?,
      );
}

/// Cómo mostrar la racha de un amigo.
@immutable
class ResolvedStreak {
  const ResolvedStreak({
    required this.streak,
    required this.inactiveDays,
    required this.hasData,
  });

  /// Días de racha VIVOS. 0 si lleva más de un día sin entrenar.
  final int streak;

  /// Días desde su última sesión. null si nunca ha entrenado.
  final int? inactiveDays;

  /// false cuando la Cloud Function aún no ha escrito el resumen.
  final bool hasData;

  bool get isActive => streak > 0;
  bool get neverTrained => hasData && inactiveDays == null && streak == 0;
}

/// Aplica la regla de racha viva sobre el resumen almacenado.
///
/// Sin esto, el número guardado se quedaría congelado: alguien con racha 5
/// que no entrena desde el martes seguiría apareciendo con 5 días para siempre.
ResolvedStreak resolveFriendStreak(FriendStreak s, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final last = s.lastExerciseDate;

  if (last == null) {
    return const ResolvedStreak(streak: 0, inactiveDays: null, hasData: true);
  }

  // Restar sobre dos medianoche locales evita que el cambio horario
  // descuadre el conteo de días.
  final gap = _asDateKey(dateKey(ref)).difference(_asDateKey(last)).inDays;
  final alive = gap <= 1;

  return ResolvedStreak(
    streak: alive ? s.currentStreak : 0,
    // Un `lastExerciseDate` en el futuro (skew del servidor) no debe dar
    // días negativos.
    inactiveDays: gap < 0 ? 0 : gap,
    hasData: true,
  );
}

/// 'yyyy-MM-dd' -> medianoche local.
DateTime _asDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Perfil público mínimo de un usuario: lo único que un amigo puede ver.
///
/// Sale de `userProfiles/{uid}`. Es FRESCO, a diferencia de los campos
/// desnormalizados del vínculo, que se copiaron al añadir y se quedan viejos
/// si la persona cambia luego su foto.
@immutable
class PublicProfile {
  const PublicProfile({this.displayName, this.photoUrl});

  final String? displayName;
  final String? photoUrl;

  factory PublicProfile.fromMap(Map<String, dynamic>? m) {
    final n = (m?['displayName'] as String?)?.trim();
    final p = (m?['photoUrl'] as String?)?.trim();
    return PublicProfile(
      displayName: (n == null || n.isEmpty) ? null : n,
      photoUrl: (p == null || p.isEmpty) ? null : p,
    );
  }
}
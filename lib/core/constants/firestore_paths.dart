class FirestorePaths {
  static const users = 'users';
  static const diseases = 'diseases';
  static const exercises = 'exercises';
  static const workouts = 'workouts';
  static const videos = 'videos';

  /// Resuelve un código de invitación -> {uid, displayName, photoUrl}.
  /// Legible por cualquier autenticado, pero NO listable.
  static const inviteCodes = 'inviteCodes';

  /// Resumen público de racha por usuario. Lo calcula y escribe una Cloud
  /// Function; el cliente solo lee.
  static const userStreaks = 'userStreaks';

  static String history(String uid) => '$users/$uid/history';
  static String progress(String uid) => '$users/$uid/progress';
  static String friends(String uid) => '$users/$uid/friends';
}

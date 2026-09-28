class FirestorePaths {
  static const users = 'users';
  static const diseases = 'diseases';
  static const exercises = 'exercises';
  static const workouts = 'workouts';
  static const videos = 'videos';

  static String history(String uid) => '$users/$uid/history';
  static String progress(String uid) => '$users/$uid/progress';
}

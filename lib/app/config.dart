class AppConfig {
  static const maxSyncRetries = 5;
  static const syncTimeout = Duration(seconds: 20);
  static const dailyWorkoutSize = 4;
  static const recentDaysToAvoid = 3;
  static const minFreeSpaceMarginBytes = 200 * 1024 * 1024;
}

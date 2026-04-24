import 'package:shared_preferences/shared_preferences.dart';

// タイミング種別の定数
class Timing {
  static const String wakeUp = 'wake_up';
  static const String afterBreakfast = 'after_breakfast';
  static const String afterLunch = 'after_lunch';
  static const String afterDinner = 'after_dinner';
  static const String betweenMeals = 'between_meals';
  static const String beforeSleep = 'before_sleep';

  // 表示用ラベル
  static String label(String timing) {
    switch (timing) {
      case wakeUp:
        return '起床時';
      case afterBreakfast:
        return '朝食後';
      case afterLunch:
        return '昼食後';
      case afterDinner:
        return '夕食後';
      case betweenMeals:
        return '食間';
      case beforeSleep:
        return '就寝前';
      default:
        return timing;
    }
  }

  // 全タイミング一覧（選択UI用）
  static const List<String> all = [
    wakeUp,
    afterBreakfast,
    afterLunch,
    betweenMeals,
    afterDinner,
    beforeSleep,
  ];
}

// SharedPreferences のキー定数
class PrefKeys {
  static const String wakeTime = 'wake_time';
  static const String breakfastTime = 'breakfast_time';
  static const String lunchTime = 'lunch_time';
  static const String dinnerTime = 'dinner_time';
  static const String sleepTime = 'sleep_time';
  static const String isSetupDone = 'is_setup_done';
}

// 生活時刻の読み書きヘルパー
class LifeTimePrefs {
  // 保存
  static Future<void> save({
    required String wakeTime,
    required String breakfastTime,
    required String lunchTime,
    required String dinnerTime,
    required String sleepTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.wakeTime, wakeTime);
    await prefs.setString(PrefKeys.breakfastTime, breakfastTime);
    await prefs.setString(PrefKeys.lunchTime, lunchTime);
    await prefs.setString(PrefKeys.dinnerTime, dinnerTime);
    await prefs.setString(PrefKeys.sleepTime, sleepTime);
    await prefs.setBool(PrefKeys.isSetupDone, true);
  }

  // 読み込み（Map で返す）
  static Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      PrefKeys.wakeTime: prefs.getString(PrefKeys.wakeTime) ?? '06:30',
      PrefKeys.breakfastTime:
          prefs.getString(PrefKeys.breakfastTime) ?? '07:30',
      PrefKeys.lunchTime: prefs.getString(PrefKeys.lunchTime) ?? '12:00',
      PrefKeys.dinnerTime: prefs.getString(PrefKeys.dinnerTime) ?? '18:30',
      PrefKeys.sleepTime: prefs.getString(PrefKeys.sleepTime) ?? '22:30',
    };
  }

  // 初回設定済みか
  static Future<bool> isSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.isSetupDone) ?? false;
  }
}

// "HH:mm" 文字列を DateTime に変換（基準日は today）
DateTime timeStringToDateTime(String timeStr, {DateTime? baseDate}) {
  final base = baseDate ?? DateTime.now();
  final parts = timeStr.split(':');
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return DateTime(base.year, base.month, base.day, hour, minute);
}

// DateTime を "HH:mm" 文字列に変換
String dateTimeToTimeString(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// タイミング種別 → 通知時刻（HH:mm）を計算
// lifeTimes は LifeTimePrefs.load() の結果を渡す
String calcNotifyTime(String timing, Map<String, String> lifeTimes) {
  switch (timing) {
    case Timing.wakeUp:
      return lifeTimes[PrefKeys.wakeTime] ?? '06:30';

    case Timing.afterBreakfast:
      final base =
          timeStringToDateTime(lifeTimes[PrefKeys.breakfastTime] ?? '07:30');
      return dateTimeToTimeString(
          base.add(const Duration(minutes: 30)));

    case Timing.afterLunch:
      final base =
          timeStringToDateTime(lifeTimes[PrefKeys.lunchTime] ?? '12:00');
      return dateTimeToTimeString(
          base.add(const Duration(minutes: 30)));

    case Timing.afterDinner:
      final base =
          timeStringToDateTime(lifeTimes[PrefKeys.dinnerTime] ?? '18:30');
      return dateTimeToTimeString(
          base.add(const Duration(minutes: 30)));

    case Timing.betweenMeals:
      // 食間 = 昼食時刻 + 2時間
      final base =
          timeStringToDateTime(lifeTimes[PrefKeys.lunchTime] ?? '12:00');
      return dateTimeToTimeString(
          base.add(const Duration(hours: 2)));

    case Timing.beforeSleep:
      final base =
          timeStringToDateTime(lifeTimes[PrefKeys.sleepTime] ?? '22:30');
      return dateTimeToTimeString(
          base.subtract(const Duration(minutes: 30)));

    default:
      return '08:00';
  }
}

// 終了日を計算する（開始日 + 服用日数 - 1）
// durationDays が 0 なら null を返す（無期限）
String? calcEndDate(String startDate, int durationDays) {
  if (durationDays <= 0) return null;
  final start = DateTime.parse(startDate);
  final end = start.add(Duration(days: durationDays - 1));
  return '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
}

// 今日の日付文字列 YYYY-MM-DD
String todayString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

// 残り日数を計算（終了日 - 今日）
int remainingDays(String endDate) {
  final end = DateTime.parse(endDate);
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  return end.difference(todayDate).inDays;
}
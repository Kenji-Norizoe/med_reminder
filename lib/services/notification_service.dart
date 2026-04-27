import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

Future<void> init() async {
  tz.initializeTimeZones();

  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

  const androidSettings = AndroidInitializationSettings('ic_stat_notify');

  const settings = InitializationSettings(
    android: androidSettings,
  );

  await _plugin.initialize(settings);
}

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'テスト通知',
      channelDescription: '通知テスト用',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_notify',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      0,
      'テスト通知',
      '通知が動いています',
      details,
    );
  }

  Future<void> scheduleSnooze({
    required int medicineId,
    required String medicineName,
    required String timing,
    required int minutes,
  }) async {
    final id =
        medicineId * 100 + DateTime.now().millisecondsSinceEpoch.remainder(10000);

    final scheduled = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    const androidDetails = AndroidNotificationDetails(
      'snooze_channel',
      'あとで通知',
      channelDescription: '服薬の再通知',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_stat_notify',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      '服薬リマインダー',
      '$medicineName（$timing）を飲む時間です',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

Future<void> scheduleDailyNotification({
  required int id,
  required String title,
  required String body,
  required int hour,
  required int minute,
}) async {
  final scheduled =
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 3));

  const androidDetails = AndroidNotificationDetails(
    'daily_channel',
    '毎日の服薬通知',
    channelDescription: '毎日の服薬リマインダー',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'ic_stat_notify',
  );

  const details = NotificationDetails(android: androidDetails);

  await _plugin.zonedSchedule(
    id,
    title,
    body,
    scheduled,
    details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );

  print('daily notification scheduled: $scheduled');
}

}
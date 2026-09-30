import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Two daily reminders max, motivating rather than nagging. Times are user-chosen
/// in Me > reminders (morning "Daily 10 ready" + evening "streak" nudge, both optional).
class RailParikshaNotifications {
  RailParikshaNotifications._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  static Future<bool> requestPermission() async {
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'railpariksha_daily',
      'Daily reminders',
      channelDescription: 'Daily practice and streak reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  /// [id] 1 = morning Daily 10 nudge, 2 = evening streak nudge. [title]/[body]
  /// are already resolved to the user's chosen language by the caller.
  static Future<void> scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: when,
      notificationDetails: _details,
      title: title,
      body: body,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }

  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}

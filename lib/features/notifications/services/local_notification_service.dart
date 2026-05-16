import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  static const String pendingFollowUpKey =
      'pending_open_followups';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(pendingFollowUpKey, true);
      },
    );

    final launchDetails =
        await _plugin.getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(pendingFollowUpKey, true);
    }

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<bool> consumePendingFollowUpOpen() async {
    final prefs = await SharedPreferences.getInstance();

    final value =
        prefs.getBool(pendingFollowUpKey) ?? false;

    if (value) {
      await prefs.remove(pendingFollowUpKey);
    }

    return value;
  }

  static Future<void> scheduleFollowUpNotification({
    required int id,
    required String patientName,
    required String reason,
    required DateTime date,
  }) async {
    // TEST MODE: after 1 minute
    final scheduledDate = DateTime.now().add(
      const Duration(minutes: 1),
    );

    /*
    // PRODUCTION MODE: 8:00 AM on follow-up date
    final scheduledDate = DateTime(
      date.year,
      date.month,
      date.day,
      8,
      0,
    );
    */

    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    await _plugin.zonedSchedule(
      id,
      'Follow-Up Reminder',
      '$patientName${reason.isNotEmpty ? ' - $reason' : ''}',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'follow_up_channel',
          'Follow-Up Reminders',
          channelDescription:
              'Doctor follow-up reminders',
          importance: Importance.max,
          priority: Priority.high,
          category:
              AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
        ),
      ),
      payload: id.toString(),
      androidScheduleMode:
          AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}
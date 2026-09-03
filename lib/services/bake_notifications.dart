/// Alarms for the long waits.
///
/// Two mechanisms, deliberately. Scheduled notifications are automatic and
/// cancel themselves when you finish a step early, but an aggressive battery
/// optimiser can still delay or drop one across an eight-hour bulk ferment.
/// Handing off to the phone's own clock app is manual, but it always rings.
///
/// Every method here swallows its own failures: missing permissions or an
/// unsupported platform must never take the app down mid-bake.

library;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'bake_schedule.dart';

/// What the OS is actually willing to let us do, so the UI can be honest
/// rather than promising an alarm that will not arrive.
class AlarmCapability {
  final bool notificationsAllowed;
  final bool exactAllowed;

  const AlarmCapability({
    required this.notificationsAllowed,
    required this.exactAllowed,
  });

  static const none = AlarmCapability(
    notificationsAllowed: false,
    exactAllowed: false,
  );
}

class BakeNotifications {
  BakeNotifications._();
  static final BakeNotifications instance = BakeNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'bake_steps';
  static const _channelName = 'Bake steps';

  /// Notification ids are derived from the step's position so that
  /// rescheduling replaces rather than duplicates.
  static const _idBase = 4200;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (_ready || !isSupported) return;
    try {
      tzdata.initializeTimeZones();
      // Scheduling by instant rather than by wall-clock zone: converting the
      // local DateTime through UTC preserves the exact moment, which is all we
      // need for one-shot alarms. No repeating notifications, so no DST edge.
      tz.setLocalLocation(tz.UTC);

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Ask for what we need, at the point the baker actually starts, not on
  /// first launch, where the request has no context.
  Future<AlarmCapability> requestPermissions() async {
    if (!isSupported) return AlarmCapability.none;
    await init();
    try {
      final notifications =
          await _android?.requestNotificationsPermission() ?? false;
      // Only *check* whether exact alarms are allowed. Requesting them on
      // Android 14+ throws the user out into system settings, which is a poor
      // thing to do the moment they tap Start now. Inexact scheduling is a
      // fine fallback, and the phone-alarm hand-off covers the cases where
      // timing really cannot slip.
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      return AlarmCapability(
        notificationsAllowed: notifications,
        exactAllowed: exact,
      );
    } catch (e) {
      debugPrint('Permission request failed: $e');
      return AlarmCapability.none;
    }
  }

  /// Replace all pending step alarms with ones matching [schedule].
  ///
  /// Called after every change, so finishing early genuinely cancels the old
  /// alarm instead of leaving a stale one to fire at the original time.
  Future<void> syncForSchedule(
    BakeSchedule schedule, {
    required bool exactAllowed,
  }) async {
    if (!isSupported) return;
    await init();
    if (!_ready) return;

    await cancelAll();

    final now = DateTime.now();
    for (var i = 0; i < schedule.steps.length; i++) {
      final step = schedule.steps[i];
      if (step.isDone) continue;
      // Fire when the step is due to end, that is when the baker is needed.
      if (!step.end.isAfter(now)) continue;

      final next = i + 1 < schedule.steps.length
          ? schedule.steps[i + 1].spec
          : null;
      await _schedule(
        id: _idBase + i,
        at: step.end,
        title: next == null
            ? 'Pizza time'
            : 'Next: ${next.title}',
        body: '${step.spec.title} is done.',
        exactAllowed: exactAllowed,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool exactAllowed,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        androidScheduleMode: exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders for each stage of your dough',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not schedule notification $id: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not cancel notifications: $e');
    }
  }

  /// Hand off to the phone's clock app. Rings through silent and Do Not
  /// Disturb, which a notification will not, so it is the right tool for the
  /// step you genuinely cannot sleep through.
  Future<bool> setPhoneAlarm(DateTime at, String label) async {
    if (!isSupported) return false;
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': at.hour,
          'android.intent.extra.alarm.MINUTES': at.minute,
          'android.intent.extra.alarm.MESSAGE': label,
          // Show the clock app so the baker can see and confirm the alarm.
          'android.intent.extra.alarm.SKIP_UI': false,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('Could not set phone alarm: $e');
      return false;
    }
  }
}

/// Notification id for a step, exposed for tests.
int notificationIdFor(int stepIndex) => BakeNotifications._idBase + stepIndex;

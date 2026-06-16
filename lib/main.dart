import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app.dart';

void main() {
  // MarionetteBinding (a WidgetsFlutterBinding subclass) is debug-only test
  // instrumentation; it must be the first binding constructed, otherwise the
  // base binding gets locked in first and its constructor asserts. In release
  // builds use the plain binding so the tool isn't shipped to users.
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'remux_sessions',
      channelName: 'Active SSH Sessions',
      channelDescription: 'Keeps SSH sessions alive in the background.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  runApp(
    const ProviderScope(
      child: RemuxApp(),
    ),
  );
}

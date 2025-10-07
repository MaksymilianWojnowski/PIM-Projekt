import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'screens/login_screen.dart';
import 'services/application_state.dart';

/// 🔔 Handler dla wiadomości w tle (musi być top-level / static).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // prosty log — możesz tu dodać własną logikę
  print(
    "📩 [BG] onBackgroundMessage: ${message.notification?.title} | ${message.notification?.body}",
  );
}

/// 🔔 Local notifications — plugin i kanał (Android)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel', // id kanału
  'Wysokie priorytety', // nazwa kanału w ustawieniach
  description: 'Banery w foregroundzie',
  importance: Importance.high,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _initLocalNotifications();
  await _initPush();

  print("✅ APP START");
  runApp(MyApp());
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // lub własna ikona

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  if (Platform.isAndroid) {
    final androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_channel);
  }
}

/// pokazuje lokalne powiadomienie (baner) gdy apka jest w foregroundzie
Future<void> _showLocal(RemoteMessage m) async {
  final title = m.notification?.title ?? 'Powiadomienie';
  final body = m.notification?.body ?? '';

  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'Wysokie priorytety',
    channelDescription: 'Banery w foregroundzie',
    importance: Importance.high,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // unikalne id
    title,
    body,
    details,
  );
}

Future<void> _initPush() async {
  final messaging = FirebaseMessaging.instance;

  // zgody (Android 13+ / iOS)
  final settings = await messaging.requestPermission();
  print("🔐 Notification permission: ${settings.authorizationStatus}");

  // iOS: pokaż w foregroundzie systemowe alerty
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // sub na topic 'all' — backend wysyła na ten temat
  await messaging.subscribeToTopic('all');
  print("🧷 Subscribed to topic 'all'");

  // token do diagnostyki
  final fcmToken = await messaging.getToken();
  print("📱 FCM token = $fcmToken");

  // 👇 Twój listener (foreground): loguje i pokazuje lokalny baner
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print(
      "📩 onMessage: ${message.notification?.title} | ${message.notification?.body}",
    );
    _showLocal(message);
  });

  // kliknięcie w powiadomienie, które otworzyło apkę
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print(
      "🚪 onMessageOpenedApp: ${message.notification?.title} | ${message.notification?.body}",
    );
  });
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final ApplicationState applicationState = ApplicationState();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ApplicationState>.value(
      value: applicationState,
      child: Consumer<ApplicationState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'FCM + Google Auth App',
            theme: appState.isDarkMode ? ThemeData.dark() : ThemeData.light(),
            home: LoginScreen(),
          );
        },
      ),
    );
  }
}

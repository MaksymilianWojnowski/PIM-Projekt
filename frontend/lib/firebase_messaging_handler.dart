import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 🔔 Funkcja globalna dla powiadomień w tle (wymagana przez AOT)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseMessagingHandler._showNotification(message);
}

class FirebaseMessagingHandler {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // 🔐 Prośba o zgodę na iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 🪪 Pobranie tokena
    String? token = await _firebaseMessaging.getToken();
    print("📲 FCM Token: $token");

    // 📡 Subskrypcja tematu (opcjonalna)
    await _firebaseMessaging.subscribeToTopic('all');
    print("📡 Subskrybowano temat: all");

    // Obsługa wiadomości w trakcie działania aplikacji
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Obsługa wiadomości w tle
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print(
      "📥 Otrzymano wiadomość w foreground: ${message.notification?.title}",
    );
    await _showNotification(message);
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0,
      message.notification?.title ?? '📨 Nowa wiadomość',
      message.notification?.body ?? 'Masz nowe powiadomienie',
      platformDetails,
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/notification_item.dart';

Future<List<NotificationItem>> fetchNotifications() async {
  final apiUrl = dotenv.env['API_URL'];
  final response = await http.get(Uri.parse("$apiUrl/notifications"));

  if (response.statusCode == 200) {
    // 🔠 Wymuszamy dekodowanie z UTF-8
    final decoded = utf8.decode(response.bodyBytes);
    final List<dynamic> data = json.decode(decoded);
    return data.map((json) => NotificationItem.fromJson(json)).toList();
  } else {
    throw Exception("Nie udało się pobrać postów");
  }
}

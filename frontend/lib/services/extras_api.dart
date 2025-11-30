import 'dart:convert';
import 'package:http/http.dart' as http;

class ExtrasApi {
  ExtrasApi(this.baseUrl);
  final String baseUrl;

  Future<Map<String, dynamic>?> getPollResults(int notificationId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/notifications/$notificationId/poll/results'),
    );
    if (r.statusCode == 200) {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    }
    return null;
  }

  Future<bool> voteInPoll({
    required int notificationId,
    required int optionId,
    required String voterEmail,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/poll/vote'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'option_id': optionId, 'voter_email': voterEmail}),
    );
    return r.statusCode == 200;
  }

  Future<int?> addComment({
    required int notificationId,
    required String authorName,
    String? authorEmail,
    required String content,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/comments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'author_name': authorName,
        'author_email': authorEmail,
        'content': content,
      }),
    );
    if (r.statusCode == 200) {
      final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return m['id'] as int?;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> listComments(int notificationId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/notifications/$notificationId/comments'),
    );
    if (r.statusCode == 200) {
      final m = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(m['items'] as List);
    }
    return [];
  }

  Future<bool> voteComment({
    required int commentId,
    required String voterEmail,
    required int value,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/notifications/comments/$commentId/vote'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'voter_email': voterEmail, 'value': value}),
    );
    return r.statusCode == 200;
  }
}

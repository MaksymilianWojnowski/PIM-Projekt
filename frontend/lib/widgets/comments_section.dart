import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/services/extras_api.dart';

class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.notificationId,
    required this.userEmail,
    required this.userName,
  });

  final int notificationId;
  final String userEmail;
  final String userName;

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final ctrl = TextEditingController();
  late final ExtrasApi api;
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = ExtrasApi(dotenv.env['API_URL']!);
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final list = await api.listComments(widget.notificationId);
    setState(() {
      items = list;
      loading = false;
    });
  }

  Future<void> _add() async {
    final content = ctrl.text.trim();
    if (content.isEmpty) return;
    final id = await api.addComment(
      notificationId: widget.notificationId,
      authorName:
          widget.userName.isNotEmpty
              ? widget.userName
              : widget.userEmail.split('@').first,
      authorEmail: widget.userEmail,
      content: content,
    );
    if (id != null) {
      ctrl.clear();
      await _load();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się dodać komentarza')),
      );
    }
  }

  Future<void> _vote(int commentId, int value) async {
    final ok = await api.voteComment(
      commentId: commentId,
      voterEmail: widget.userEmail,
      value: value,
    );
    if (ok) await _load();
  }

  String _shortDate(dynamic iso) {
    final s = (iso ?? '').toString();
    if (s.isEmpty) return '';
    // prosty, bez zależności od intl tutaj
    return s.replaceFirst('T', ' ').substring(0, min(16, s.length));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Komentarze', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Dodaj komentarz…',
            border: OutlineInputBorder(),
          ),
          minLines: 1,
          maxLines: 4,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(onPressed: _add, child: const Text('Wyślij')),
        ),
        const SizedBox(height: 12),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading)
          for (final c in items)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(c['author_name'] ?? 'Użytkownik'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['content'] ?? ''),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _vote(c['id'] as int, 1),
                          icon: const Icon(Icons.thumb_up),
                        ),
                        Text('${c['upvotes'] ?? 0}'),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _vote(c['id'] as int, -1),
                          icon: const Icon(Icons.thumb_down),
                        ),
                        Text('${c['downvotes'] ?? 0}'),
                        const Spacer(),
                        Text(
                          _shortDate(c['created_at']),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

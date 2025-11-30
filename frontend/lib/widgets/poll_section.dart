import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/services/extras_api.dart';

class PollSection extends StatefulWidget {
  const PollSection({
    super.key,
    required this.notificationId,
    required this.userEmail,
  });

  final int notificationId;
  final String userEmail;

  @override
  State<PollSection> createState() => _PollSectionState();
}

class _PollSectionState extends State<PollSection> {
  late final ExtrasApi api;
  Map<String, dynamic>?
  poll; // {id, question, total, options:[{id,text,votes}]}
  int? selectedOptionId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = ExtrasApi(dotenv.env['API_URL']!);
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => loading = true);
    final data = await api.getPollResults(widget.notificationId);
    setState(() {
      poll = data?['poll'] as Map<String, dynamic>?;
      loading = false;
    });
  }

  Future<void> _vote() async {
    if (selectedOptionId == null) return;
    final ok = await api.voteInPoll(
      notificationId: widget.notificationId,
      optionId: selectedOptionId!,
      voterEmail: widget.userEmail,
    );
    if (!mounted) return;
    if (ok) {
      await _loadResults();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dzięki za głos!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się oddać głosu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    if (poll == null) return const SizedBox.shrink();

    final total = (poll!['total'] as num).toInt();
    final options = List<Map<String, dynamic>>.from(poll!['options'] as List);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          poll!['question'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        for (final o in options)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  RadioListTile<int>(
                    value: o['id'] as int,
                    groupValue: selectedOptionId,
                    onChanged: (v) => setState(() => selectedOptionId = v),
                    title: Text(o['text'] as String),
                  ),
                  LinearProgressIndicator(
                    value:
                        total == 0
                            ? 0.0
                            : (o['votes'] as num).toDouble() / total.toDouble(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      total == 0
                          ? '0% (0)'
                          : '${(((o['votes'] as num).toDouble() / total) * 100).toStringAsFixed(0)}%  (${o['votes']})',
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _vote,
            child: const Text('Zagłosuj'),
          ),
        ),
      ],
    );
  }
}

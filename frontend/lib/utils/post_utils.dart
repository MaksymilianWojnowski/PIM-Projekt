import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

Widget buildImage(String url) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: 16 / 9, 
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 100),
      ),
    ),
  );
}
Widget buildFormattedTextWithLinks(BuildContext context, String content) {
  final urlRegex = RegExp(
    r'(https?:\/\/[^\s]+)',
    caseSensitive: false,
  );

  List<InlineSpan> spans = [];
  final matches = urlRegex.allMatches(content);

  int start = 0;

  for (final match in matches) {
    if (match.start > start) {
      spans.add(TextSpan(
        text: content.substring(start, match.start),
      ));
    }

    final url = match.group(0)!;
    spans.add(
      TextSpan(
        text: url,
        style: TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              throw 'Could not launch $url';
            }
          },
      ),
    );
    start = match.end;
  }

  if (start < content.length) {
    spans.add(TextSpan(text: content.substring(start)));
  }

  return RichText(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
      children: spans,
    ),
  );
}

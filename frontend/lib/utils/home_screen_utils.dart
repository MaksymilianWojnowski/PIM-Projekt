// lib/utils/home_screen_utils.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/utils/post_utils.dart';

class HomeScreenUtils {
  static void filterSearchResults(
    String query,
    List<NotificationItem> allNotifications,
    Function(List<NotificationItem>) onUpdateFilteredList,
  ) {
    final filtered = allNotifications
        .where((item) =>
            item.title.toLowerCase().contains(query.toLowerCase()) ||
            item.excerpt.toLowerCase().contains(query.toLowerCase()))
        .toList();
    onUpdateFilteredList(filtered);
  }

  static void signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  static Future<void> refreshNotifications(
    Function(List<NotificationItem>) onRefreshDone,
    Future<List<NotificationItem>> Function() fetchNotifications,
  ) async {
    final refreshed = await fetchNotifications();
    onRefreshDone(refreshed);
  }

  static void showPostDialog(BuildContext context, NotificationItem post) {
    final formattedDate =
        DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(post.scheduledTime));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.6,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: buildImage(post.leadingImage)),
                SizedBox(height: 10),
                Center(
                  child: Text(
                    formattedDate,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(height: 16),
                Text(post.title, style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 10),
                buildFormattedTextWithLinks(context, post.content),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 0) {
      final futureDiff = dateTime.difference(now);
      if (futureDiff.inDays > 1) return 'za ${futureDiff.inDays} dni';
      if (futureDiff.inHours > 1) return 'za ${futureDiff.inHours} godzin';
      if (futureDiff.inMinutes > 1) return 'za ${futureDiff.inMinutes} minut';
      return 'za chwilę';
    } else {
      if (difference.inDays > 1) return '${difference.inDays} dni temu';
      if (difference.inHours > 1) return '${difference.inHours} godzin temu';
      if (difference.inMinutes > 1) return '${difference.inMinutes} minut temu';
      return 'przed chwilą';
    }
  }
}

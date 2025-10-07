class NotificationItem {
  final String title;
  final String content;
  final String excerpt;
  final String leadingImage;
  final String scheduledTime;

  NotificationItem({
    required this.title,
    required this.content,
    required this.excerpt,
    required this.leadingImage,
    required this.scheduledTime,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      title: json['title'] ?? "Brak tytułu",
      content: json['content'] ?? "Brak treści",
      excerpt: json['excerpt'] ?? "Brak skrótu",
      leadingImage: json['leadingImage'] ?? "https://via.placeholder.com/150",
      scheduledTime: json['scheduled_time'] ?? "",
    );
  }
}

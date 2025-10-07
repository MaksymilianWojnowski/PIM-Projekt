import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/models/notification_item.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/application_state.dart';
import '../theme/colors.dart';
import 'package:frontend/utils/post_utils.dart';
import 'package:frontend/utils/home_screen_utils.dart'; 

class HomeScreen extends StatefulWidget {
  final String email;

  const HomeScreen({required this.email});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<NotificationItem>> futureNotifications;
  List<NotificationItem> _allNotifications = [];
  List<NotificationItem> _filteredNotifications = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    futureNotifications = fetchNotifications();
    futureNotifications.then((notifications) {
      setState(() {
        _allNotifications = notifications;
        _filteredNotifications = notifications;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : Color(0xFF0071B8),
      appBar: AppBar(
        backgroundColor: Color(0xFF0071B8),
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (query) {
                  HomeScreenUtils.filterSearchResults(
                    query,
                    _allNotifications,
                    (filtered) => setState(() => _filteredNotifications = filtered),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Szukaj...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
              )
            : Image.asset(
                'assets/logoinsert.png',
                height: 116,
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            iconSize: 36,
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _filteredNotifications = _allNotifications;
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            iconSize: 36,
            onPressed: () => HomeScreenUtils.signOut(context),
          ),
          IconButton(
            icon: Icon(Icons.brightness_6),
            iconSize: 36,
            onPressed: () {
              Provider.of<ApplicationState>(context, listen: false).toggleDarkMode();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationItem>>(
        future: futureNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Błąd: ${snapshot.error}"));
          }

          return RefreshIndicator(
            onRefresh: () async {
              await HomeScreenUtils.refreshNotifications(
                (refreshed) => setState(() {
                  _allNotifications = refreshed;
                  _filteredNotifications = refreshed;
                }),
                fetchNotifications,
              );
            },
            child: ListView.builder(
              itemCount: _filteredNotifications.length,
              itemBuilder: (context, index) {
                final post = _filteredNotifications[index];
                return GestureDetector(
                  onLongPress: () => HomeScreenUtils.showPostDialog(context, post),
                  child: Card(
                    margin: EdgeInsets.all(10),
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: ExpansionTile(
                      backgroundColor: Theme.of(context).cardColor,
                      collapsedBackgroundColor: Theme.of(context).cardColor,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post.leadingImage,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image),
                        ),
                      ),
                      title: Text(
                        post.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Theme.of(context).textTheme.bodyLarge!.color : AppColors.primaryDark,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.excerpt,
                            style: TextStyle(
                              color: isDarkMode ? Theme.of(context).textTheme.bodyMedium!.color : Colors.black,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            HomeScreenUtils.timeAgo(DateTime.parse(post.scheduledTime)),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: 
                            buildFormattedTextWithLinks(context, post.content)
                        ),
                        
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

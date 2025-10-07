import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  String loginStatus = '';

  final double logoHeight = 300; 

  Future<void> handleSignIn() async {
    final email = await _authService.signInWithGoogle();

    if (email != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(email: email)),
      );
    } else {
      setState(() {
        loginStatus = 'Brak dostępu – email nie znajduje się w bazie';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0071B8), // kolor z logo InsERT
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logoinsert.png', height: logoHeight),
              SizedBox(height: 60),
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  onPressed: handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // estetyczne zaokrąglenia
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Zaloguj się przez Google',
                    style: TextStyle(
                      color: Color(0xFF007ACC),
                      fontSize: 18, // większy rozmiar czcionki
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                loginStatus,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    final clientId =
        Platform.isIOS
            ? dotenv.env['GOOGLE_CLIENT_ID_IOS']
            : dotenv.env['GOOGLE_CLIENT_ID_ANDROID'];

    // 🔎 DIAGNOSTYKA: pokaż, co przyszło z .env i jaka platforma
    print("🔧 [AuthService] Platform.isIOS=${Platform.isIOS}");
    print("🔧 [AuthService] GOOGLE_CLIENT_ID = $clientId");

    _googleSignIn = GoogleSignIn(
      serverClientId: clientId,
      scopes: const ['email'],
    );
  }

  Future<String?> signInWithGoogle() async {
    try {
      // 🔎 DIAGNOSTYKA: czy mamy w ogóle clientId i API_URL?
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null || apiUrl.isEmpty) {
        print("❌ [AuthService] Brak API_URL w .env");
      } else {
        print("🔧 [AuthService] API_URL = $apiUrl");
      }

      // 🔎 DIAGNOSTYKA: stan przed logowaniem
      final preSignedIn = await _googleSignIn.isSignedIn();
      print("🔧 [AuthService] isSignedIn (before) = $preSignedIn");

      // Czasem pomaga twardy reset stanu:
      try {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
        print("🔧 [AuthService] Wykonano signOut + disconnect");
      } catch (_) {}

      // 🔎 DIAGNOSTYKA: spróbuj silentSignIn (może już mamy konto)
      try {
        final silent = await _googleSignIn.signInSilently();
        print("🔧 [AuthService] signInSilently => ${silent?.email}");
      } catch (e) {
        print("ℹ️ [AuthService] signInSilently wyjątek: $e");
      }

      print("▶️ [AuthService] Wywołuję GoogleSignIn.signIn()");
      final account = await _googleSignIn.signIn();

      if (account == null) {
        print("❌ [AuthService] Użytkownik nie wybrał konta (account == null)");
        return null;
      }
      print("✅ [AuthService] Wybrane konto: ${account.email}");

      final auth = await account.authentication;
      print(
        "🔧 [AuthService] authentication received. has idToken=${auth.idToken != null}, has accessToken=${auth.accessToken != null}",
      );

      final token = auth.idToken;
      if (token == null) {
        print("❌ [AuthService] Brak idToken z Google (auth.idToken == null)");
        print(
          "📌 [AuthService] Upewnij się, że WEB CLIENT ID jest w .env jako GOOGLE_CLIENT_ID_* i zgadza się z backendem.",
        );
        return null;
      }
      print("🔒 [AuthService] idToken length = ${token.length}");

      final url = "$apiUrl/auth/google?token=$token";
      print("🌐 [AuthService] Wysyłam token do backendu: $url");

      final response = await http.get(Uri.parse(url));
      print(
        "🌐 [AuthService] Odpowiedź backendu: ${response.statusCode} | ${response.reasonPhrase}",
      );

      if (response.statusCode == 200) {
        print(
          "✅ [AuthService] Logowanie zakończone sukcesem: ${account.email}",
        );
        return account.email;
      } else {
        print(
          "❌ [AuthService] Logowanie odrzucone przez backend: ${response.statusCode} | body=${response.body}",
        );
        await _googleSignIn.signOut(); // reset
        return null;
      }
    } catch (e, st) {
      print("❌ [AuthService] Błąd logowania: $e");
      print("🧵 [AuthService] Stacktrace:\n$st");
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      return null;
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In, scoped deliberately narrow for now: it authenticates the user and
/// exposes their Google display name/photo so the leaderboard name can be filled in
/// one tap instead of typed -- it does NOT turn into a cloud-synced account system.
/// Progress/streaks/bookmarks stay local-only (SharedPreferences) exactly as before;
/// signing out never loses anything since nothing was ever stored server-side against
/// the signed-in identity. Entirely optional, same pattern as LeaderboardService: every
/// method no-ops/returns null when Firebase isn't configured, so this can never block
/// or crash the app's offline-first core.
class AuthService {
  static bool get available => Firebase.apps.isNotEmpty;

  static User? get currentUser => available ? FirebaseAuth.instance.currentUser : null;

  /// Fires on sign-in/sign-out so UI can react without polling. Empty stream when
  /// Firebase isn't configured, so a `StreamBuilder` listening to this never hangs.
  static Stream<User?> get userChanges =>
      available ? FirebaseAuth.instance.authStateChanges() : const Stream<User?>.empty();

  /// Returns the signed-in [User], or null if the user cancelled the picker or
  /// sign-in isn't available/failed -- callers should treat null as "nothing
  /// happened" rather than an error to surface.
  static Future<User?> signInWithGoogle() async {
    if (!available) return null;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user cancelled the picker
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      return result.user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    if (!available) return;
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Best-effort only -- a failed sign-out must never crash the Me screen.
    }
  }
}

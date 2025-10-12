import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleSignInAccount = await _googleSignIn
          .authenticate();

      final GoogleSignInAuthentication googleSignInAuthentication =
          googleSignInAccount.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<User?> signInWithApple() async {
    try {
      final appleProvider = AppleAuthProvider();
      final UserCredential userCredential = await _auth.signInWithProvider(
        appleProvider,
      );
      return userCredential.user;
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

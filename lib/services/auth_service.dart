import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<void> initialize() async {
    await instance._googleSignIn.initialize(
      serverClientId: dotenv.env['GOOGLE_CLIENT_ID']!,
    );
  }

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
      final user = userCredential.user;
      // 로그인 직후 프로필 정보가 비어 있다면 Google 정보로 보강합니다.
      if (user != null) {
        final String? nameFromGoogle = googleSignInAccount.displayName;
        final String? photoUrlFromGoogle = googleSignInAccount.photoUrl;
        if ((user.displayName == null || user.displayName!.trim().isEmpty) &&
            nameFromGoogle != null &&
            nameFromGoogle.trim().isNotEmpty) {
          await user.updateDisplayName(nameFromGoogle);
        }
        if ((user.photoURL == null || user.photoURL!.trim().isEmpty) &&
            photoUrlFromGoogle != null &&
            photoUrlFromGoogle.trim().isNotEmpty) {
          await user.updatePhotoURL(photoUrlFromGoogle);
        }
        await user.reload();
      }
      return user;
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

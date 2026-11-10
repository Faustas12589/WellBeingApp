// Example only. Copy to auth_service.dart and set serverClientId to the
// Web client ID from Firebase Console > Authentication > Sign-in method > Google.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/user_model.dart';
import '../data/models/user_pet_progress.dart';

class AuthService {

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static Future<User?> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
      );

      final GoogleSignInAccount googleUser =
      await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        await _createUserIfNotExists(user);
      }

      return user;
    } catch (e, stackTrace) {
      print('Google Sign-In error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }


  static Future<void> _createUserIfNotExists(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      final userModel = UserModel(
        id: user.uid,
        email: user.email,
        createdAt: DateTime.now(),

        equippedPetId: 'worm_01',

        ownedPets: {
          'worm_01': UserPetProgress(
            xp: 0,
            level: 1,
            duplicateCount: 0,
            unlockedSkins: [],
            equippedSkinKey: "",
          ),
        },
      );

      final data = userModel.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);
    }
  }

  static Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
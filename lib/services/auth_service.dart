import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      return usernameQuery.docs.isEmpty;
    } catch (e) {
      throw Exception('Failed to check username: ${e.toString()}');
    }
  }

  // Sign up with email, password, username, and display name
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      // Check if username is already taken FIRST
      final isAvailable = await isUsernameAvailable(username);
      if (!isAvailable) {
        throw Exception('Username already taken');
      }

      // Create user with email and password
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Create user model
      final user = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        username: username.toLowerCase(),
        displayName: displayName,
        createdAt: DateTime.now(),
      );

      // Save user data to Firestore
      print('💾 Saving user document to Firestore...');
      await _firestore.collection('users').doc(user.uid).set(user.toJson());
      print('✅ User document saved successfully');

      return user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Sign in with email and password
  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        return UserModel.fromDocument(userDoc);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  // Get user data by UID
  Future<UserModel?> getUserById(String uid) async {
    try {
      print('📖 Fetching user data for UID: $uid');
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        print('✅ User document found');
        return UserModel.fromDocument(userDoc);
      } else {
        print('❌ User document does NOT exist in Firestore');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user: $e');
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  // Get user data by username
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromDocument(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find user: ${e.toString()}');
    }
  }

  // Search users by username (for finding users to chat with)
  Future<List<UserModel>> searchUsersByUsername(String searchTerm) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchTerm)
          .where('username', isLessThan: '${searchTerm}z')
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromDocument(doc))
          .where((user) => user.uid != currentUser?.uid) // Exclude current user
          .toList();
    } catch (e) {
      throw Exception('Failed to search users: ${e.toString()}');
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}

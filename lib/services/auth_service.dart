import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return result.user;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<User?> registerDriver(String email, String password, String name) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(result.user!.uid).set({
      'name': name,
      'role': 'driver',
    });

    return result.user;
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();
}

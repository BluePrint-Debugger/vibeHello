import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUser(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);

    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'name': user.displayName,
        'email': user.email,
        'photo': user.photoURL,
        'coins': 100,
        'level': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

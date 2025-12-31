import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../driver/driver_page.dart';
import '../admin/admin_page.dart';

class RoleChecker extends StatelessWidget {
  const RoleChecker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        var data = snapshot.data!;
        String role = data["role"];

        if (role == "driver") {
          return const DriverPage();
        } else {
          return AdminPage();
        }
      },
    );
  }
}

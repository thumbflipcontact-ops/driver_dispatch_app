import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterDriverPage extends StatefulWidget {
  const RegisterDriverPage({super.key});

  @override
  State<RegisterDriverPage> createState() => _RegisterDriverPageState();
}

class _RegisterDriverPageState extends State<RegisterDriverPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  registerDriver() async {
    try {
      setState(() => loading = true);

      final result = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(result.user!.uid)
          .set({
        "name": name.text.trim(),
        "role": "driver",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chauffeur enregistré avec succès")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Échec de l'inscription")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription Chauffeur")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration:
                  const InputDecoration(labelText: "Nom du chauffeur"),
            ),
            TextField(
              controller: email,
              decoration:
                  const InputDecoration(labelText: "Adresse e-mail"),
            ),
            TextField(
              controller: password,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: "Mot de passe"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : registerDriver,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Créer un compte"),
            ),
          ],
        ),
      ),
    );
  }
}

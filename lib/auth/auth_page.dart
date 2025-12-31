import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_driver_page.dart';

class AuthPage extends StatelessWidget {
  final email = TextEditingController();
  final password = TextEditingController();

  AuthPage({super.key});

  login(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Échec de connexion. Vérifiez vos informations.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connexion")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Veuillez vous connecter pour continuer",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Adresse e-mail"),
            ),

            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Mot de passe"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => login(context),
              child: const Text("Se connecter"),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegisterDriverPage()),
                );
              },
              child: const Text("S’inscrire comme nouveau chauffeur"),
            )
          ],
        ),
      ),
    );
  }
}

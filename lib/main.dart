import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/role_checker.dart';
import 'auth/auth_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: "Application de Dispatch",

      theme: ThemeData(primarySwatch: Colors.blue),

      // ⭐ REQUIRED for French Date & Time Picker UI
      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      // ⭐ Supports French locale
      supportedLocales: const [
        Locale('fr'),
      ],

      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return AuthPage();
          return const RoleChecker();
        },
      ),
    );
  }
}

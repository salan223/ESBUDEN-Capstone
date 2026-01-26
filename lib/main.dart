import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EsbudenApp());
}

class EsbudenApp extends StatelessWidget {
  const EsbudenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    title: 'ESBUDEN',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F80ED)),
    scaffoldBackgroundColor: const Color(0xFFF7F9FB),
    ),
    initialRoute: Routes.authLanding,
    routes: appRoutes,
    );

  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/recordatorios.dart';
import 'services/session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Session.instance.load();
  await Recordatorios.init();
  runApp(const FitGymApp());
}

class FitGymApp extends StatelessWidget {
  const FitGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitGym',
      debugShowCheckedModeBanner: false,
      theme: buildFitTheme(),
      // Si ya hay sesión guardada, el pase QR se abre directo (funciona sin conexión).
      home: Session.instance.cliente != null ? const HomeScreen() : const LoginScreen(),
    );
  }
}

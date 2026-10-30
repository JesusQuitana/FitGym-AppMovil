import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/inicio.dart';
import 'services/recordatorios.dart';
import 'services/rutinas_store.dart';
import 'services/session.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Session.instance.load();
  await RutinasStore.unificarEspacios();
  await Recordatorios.init();
  runApp(FitGymApp(inicio: await pantallaInicial()));
}

class FitGymApp extends StatelessWidget {
  const FitGymApp({super.key, required this.inicio});

  /// Bienvenida, login, pase o app personal según el modo de uso guardado
  /// (ver pantallaInicial). Con sesión guardada el pase abre sin conexión.
  final Widget inicio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitGym',
      debugShowCheckedModeBanner: false,
      theme: buildFitTheme(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: inicio,
    );
  }
}

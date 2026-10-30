import 'package:flutter/material.dart';

import '../services/session.dart';
import 'app_shell.dart';
import 'onboarding/bienvenida_screen.dart';

/// Primera pantalla: la bienvenida la primera vez; después, siempre la app.
/// La sesión del gimnasio no se cierra sola y el lugar de entrenamiento se
/// cambia en Inicio, así que no hace falta volver a iniciar sesión.
Future<Widget> pantallaInicial() async =>
    Session.instance.bienvenidaHecha ? const AppShell() : const BienvenidaScreen();

/// Reemplaza toda la navegación por la pantalla inicial.
Future<void> irAlInicio(BuildContext context) async {
  final destino = await pantallaInicial();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => destino), (_) => false);
}

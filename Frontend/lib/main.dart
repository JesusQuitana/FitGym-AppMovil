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

  /// Bienvenida o la app, según si ya pasó la bienvenida (ver pantallaInicial).
  final Widget inicio;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Session.instance.tema,
      builder: (context, modo, _) => MaterialApp(
        title: 'FitGym',
        debugShowCheckedModeBanner: false,
        theme: buildFitTheme(FitColors.temaClaro),
        darkTheme: buildFitTheme(FitColors.temaOscuro),
        themeMode: modo,
        // El cambio de colores no se anima: FitColors cambia de golpe.
        themeAnimationDuration: Duration.zero,
        scaffoldMessengerKey: scaffoldMessengerKey,
        builder: (context, child) => _PaletaActual(child: child!),
        home: inicio,
      ),
    );
  }
}

/// Mantiene [FitColors.actual] al día con el tema efectivo (el elegido o el
/// del sistema) y reconstruye las pantallas abiertas cuando cambia, para que
/// también se actualicen los widgets que no dependen del Theme.
class _PaletaActual extends StatelessWidget {
  const _PaletaActual({required this.child});
  final Widget child;

  static PaletaFit? _barraAplicada;

  @override
  Widget build(BuildContext context) {
    final paleta = Theme.of(context).brightness == Brightness.dark ? FitColors.temaOscuro : FitColors.temaClaro;
    if (!identical(_barraAplicada, paleta)) {
      // Íconos de la barra de estado según el tema de la app, no el del sistema
      // (si el teléfono está en oscuro y la app en claro, deben ser oscuros).
      _barraAplicada = paleta;
      SystemChrome.setSystemUIOverlayStyle(
        paleta.brillo == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      );
    }
    if (!identical(FitColors.actual, paleta)) {
      FitColors.actual = paleta;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) (context as Element).visitChildren(_reconstruir);
      });
    }
    return child;
  }

  static void _reconstruir(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_reconstruir);
  }
}

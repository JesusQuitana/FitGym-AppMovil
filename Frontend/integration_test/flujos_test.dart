// Pruebas de punta a punta en un dispositivo o emulador:
//   flutter test integration_test -d <dispositivo>
// Usan el modo demo, así que no necesitan el backend.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitgym/main.dart';
import 'package:fitgym/screens/inicio.dart';
import 'package:fitgym/services/session.dart';

/// Arranca la app como en el primer uso (sin datos guardados). No se llama
/// a main() para no pedir permisos del sistema (notificaciones) que un test
/// no puede aceptar.
Future<void> abrirAppLimpia(WidgetTester tester) async {
  await (await SharedPreferences.getInstance()).clear();
  await const FlutterSecureStorage().deleteAll();
  await Session.instance.load();
  await tester.pumpWidget(FitGymApp(inicio: await pantallaInicial()));
  await tester.pumpAndSettle();
}

/// Como pumpAndSettle, pero sirve en pantallas con animaciones continuas
/// (el QR dinámico se actualiza cada segundo).
Future<void> esperar(WidgetTester tester, [Duration total = const Duration(seconds: 2)]) async {
  final fin = DateTime.now().add(total);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Espera (hasta [limite]) a que [f] aparezca en pantalla. Evita fallar
/// porque la app todavía está cambiando de pantalla o cargando datos.
Future<Finder> aparece(WidgetTester tester, Finder f, {Duration limite = const Duration(seconds: 6)}) async {
  final fin = DateTime.now().add(limite);
  while (!_hay(f) && DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!_hay(f)) {
    // Para entender la falla: qué textos hay en pantalla en ese momento.
    final textos = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText()).toList();
    debugPrint('No apareció $f. En pantalla: $textos');
  }
  return f;
}

/// Espera (hasta [limite]) a que [f] ya no esté en pantalla.
Future<void> desaparece(WidgetTester tester, Finder f, {Duration limite = const Duration(seconds: 8)}) async {
  final fin = DateTime.now().add(limite);
  while (_hay(f) && DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Si el buscador encuentra algo. `.first` lanza un error cuando no hay
/// nada, en lugar de devolver vacío: se trata igual que "todavía no está".
bool _hay(Finder f) {
  try {
    return f.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

Future<void> tocar(WidgetTester tester, Finder f, {bool warnIfMissed = false}) async {
  await aparece(tester, f);
  await tester.ensureVisible(f);
  await tester.tap(f, warnIfMissed: warnIfMissed);
  await esperar(tester, const Duration(milliseconds: 800));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sin gimnasio: asistente → plantilla → entrenamiento → progreso', (tester) async {
    await abrirAppLimpia(tester);
    expect(await aparece(tester, find.text('¿Cómo quieres usar FitGym?')), findsOneWidget);

    await tocar(tester, find.text('Solo quiero entrenar'));
    await tocar(tester, find.text('Perder grasa'));
    await tocar(tester, find.text('Siguiente'));
    await tocar(tester, find.text('Principiante'));
    await tocar(tester, find.text('Siguiente'));
    await tocar(tester, find.text('Siguiente')); // 3 días de 45 min (por defecto)
    await tocar(tester, find.text('En casa, sin equipo'));
    await tocar(tester, find.text('Siguiente'));
    await tocar(tester, find.text('Ver mis plantillas'));
    await tocar(tester, find.text('Usar esta plantilla').first);

    // Entra a la app, con "En casa" elegido para hoy y sin pase (no hay gimnasio).
    expect(await aparece(tester, find.text('¿Dónde entrenas hoy?')), findsOneWidget);
    expect(find.text('Mostrar mi pase'), findsNothing);

    await tocar(tester, find.text('Rutinas'));
    expect(await aparece(tester, find.text('Circuito B')), findsWidgets);
    await tocar(tester, find.text('Circuito B').last);
    // Primero la vista previa; el entrenamiento empieza recién con el botón.
    expect(await aparece(tester, find.text('Empezar entrenamiento')), findsOneWidget);
    expect(find.text('Serie hecha'), findsNothing);
    await tocar(tester, find.text('Empezar entrenamiento'));
    await tocar(tester, find.byKey(const ValueKey('serie-hecha')));
    expect(await aparece(tester, find.text('Descanso')), findsWidgets);
    await tocar(tester, find.text('Saltar'));
    await tocar(tester, find.text('Terminar entrenamiento'));
    expect(await aparece(tester, find.text('¡Entrenamiento guardado!')), findsOneWidget);
    await tocar(tester, find.text('Listo'));
    await desaparece(tester, find.text('¡Entrenamiento guardado!'));
    await esperar(tester, const Duration(milliseconds: 600));

    // De vuelta en la vista previa de la rutina.
    expect(await aparece(tester, find.text('Empezar entrenamiento')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    await desaparece(tester, find.text('Empezar entrenamiento'));
    await esperar(tester, const Duration(milliseconds: 600));

    await tocar(tester, find.text('Inicio'));
    expect(await aparece(tester, find.textContaining('Esta semana: 1 entrenamiento')), findsOneWidget);
  });

  testWidgets('Con gimnasio: se vincula una vez y cambia de lugar sin volver a entrar', (tester) async {
    await abrirAppLimpia(tester);
    await tocar(tester, find.text('Tengo gimnasio con FitGym'));

    await aparece(tester, find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField).at(0), 'eddy@fitgym.com');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tocar(tester, find.text('Vincular'));
    await esperar(tester);

    expect(await aparece(tester, find.textContaining('Hola, Eddy')), findsOneWidget);
    expect(await aparece(tester, find.text('Mostrar mi pase')), findsOneWidget);
    // El aviso "gimnasio vinculado" flota abajo, justo sobre la tarjeta del pase.
    await desaparece(tester, find.byType(SnackBar));

    // El pase con QR dinámico.
    await tocar(tester, find.text('Mostrar mi pase'));
    expect(await aparece(tester, find.textContaining('se renueva en')), findsOneWidget);
    await tocar(tester, find.byType(BackButton));
    await desaparece(tester, find.textContaining('se renueva en'));
    await esperar(tester, const Duration(milliseconds: 600));

    // Hoy en casa: sin pase ni login; de vuelta al gimnasio, sigue vinculado.
    await tocar(tester, find.text('En casa'));
    expect(find.text('Mostrar mi pase'), findsNothing);
    await tocar(tester, find.text('Gimnasio'));
    expect(await aparece(tester, find.text('Mostrar mi pase')), findsOneWidget);

    await tocar(tester, find.text('Rutinas'));
    expect(await aparece(tester, find.textContaining('Del gimnasio ·')), findsOneWidget); // filtro con la cantidad
    expect(await aparece(tester, find.text('ASIGNADA')), findsWidgets);
    expect(await aparece(tester, find.text('Pecho · Brazos')), findsWidgets);
  });

  testWidgets('Recepción: acceso desde la bienvenida y rutinas del gimnasio', (tester) async {
    await abrirAppLimpia(tester);
    await tocar(tester, find.text('Soy personal de recepción'));

    // Solo los campos del diálogo.
    final campos = await aparece(tester, find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)));
    await tester.enterText(campos.at(0), 'admin');
    await tester.enterText(campos.at(1), 'admin123');
    await tocar(tester, find.text('Entrar'));
    await esperar(tester);

    expect(await aparece(tester, find.text('Recepción')), findsOneWidget);
    expect(await aparece(tester, find.text('Máquinas')), findsOneWidget);
    await tocar(tester, find.text('Rutinas'));
    await esperar(tester);
    expect(await aparece(tester, find.text('Rutinas del gimnasio')), findsOneWidget);
    expect(await aparece(tester, find.text('General')), findsWidgets);
  });
}

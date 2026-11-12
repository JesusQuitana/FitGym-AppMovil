import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitgym/main.dart';
import 'package:fitgym/models/cliente.dart';
import 'package:fitgym/models/maquina.dart';
import 'package:fitgym/models/rutina.dart';
import 'package:fitgym/services/api_service.dart';
import 'package:fitgym/models/ejercicio_wger.dart';
import 'package:fitgym/data/plantillas.dart';
import 'package:fitgym/services/wger.dart';
import 'package:fitgym/models/sesion.dart';
import 'package:fitgym/services/historial.dart';
import 'package:fitgym/models/rutina_gym.dart';
import 'package:fitgym/screens/inicio.dart';
import 'package:fitgym/screens/perfil_tab.dart';
import 'package:fitgym/services/gym_rutinas.dart';
import 'package:fitgym/services/plan_personal.dart';
import 'package:fitgym/services/rutinas_store.dart';
import 'package:fitgym/services/session.dart';
import 'package:fitgym/services/totp.dart';
import 'package:fitgym/theme.dart';
import 'package:fitgym/widgets/como_se_hace.dart';
import 'package:fitgym/widgets/editorial.dart';

void main() {
  // Para leer el catálogo de wger incluido en la app (rootBundle).
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Cliente.fromJson acepta los formatos del backend', () {
    final c = Cliente.fromJson({
      'id': 7,
      'nombre': 'Ana',
      'apellido': 'Pérez',
      'correo': 'ana@fitgym.com',
      'telefono': '0414',
      'membresia': {'id': 2, 'membresia': 'Premium'},
      'fecha_pago': [2026, 11, 5],
      'codigo': 42,
    });
    expect(c.membresia, Membresia.premium);
    expect(c.fechaPago, DateTime(2026, 11, 5));
    expect(c.codigo, '0042');
    expect(Membresia.fromJson(1), Membresia.vip);
    expect(Membresia.fromJson('regular'), Membresia.regular);
  });

  test('Cliente.fromJson lee el formato de Cliente.java', () {
    final c = Cliente.fromJson({
      'id': 3,
      'nombre': 'Luis',
      'apellido': 'Mora',
      'correo': 'luis@fitgym.com',
      'telefono': '0412',
      'fechaPago': '2026-12-01',
      'membresia_id': {'id': 9, 'membresia': 'VIP'},
      'user_id': {'id': 15, 'username': 'luis@fitgym.com', 'role': 'USER'},
    });
    expect(c.membresia, Membresia.vip); // prioriza el nombre sobre el id
    expect(c.userId, 15);
    expect(c.codigo, '');
    final body = c.copyWith(codigo: '1234').toApiJson();
    expect(body['membresia_id'], {'id': 1, 'membresia': 'VIP'});
    expect(body['user_id'], {'id': 15});
    expect(body.containsKey('codigo'), isFalse);
  });

  test('QR estático y dinámico', () {
    final c = Cliente.fromJson({'id': 7, 'correo': 'a@b.com', 'codigo': '0042', 'fechaPago': '2026-01-01'});
    final estatico = Cliente.parseQr(c.qrPayload);
    expect(estatico, isA<QrEstatico>());
    expect((estatico as QrEstatico).correo, 'a@b.com');
    expect(estatico.codigo, '0042');

    expect(c.qrDinamico('123456'), 'FITGYM2|7|123456');
    final dinamico = Cliente.parseQr('FITGYM2|7|123456');
    expect(dinamico, isA<QrDinamico>());
    expect((dinamico as QrDinamico).clienteId, 7);
    expect(dinamico.codigo, '123456');

    expect(Cliente.parseQr('1234'), isNull);
    expect(Cliente.parseQr('FITGYM|a@b.com|12a4'), isNull);
    expect(Cliente.parseQr('FITGYM2|x|123456'), isNull);
    expect(Cliente.parseQr('FITGYM2|7|1234'), isNull);
  });

  test('TOTP coincide con los vectores del RFC 6238', () {
    // Secreto ASCII "12345678901234567890" en Base32 (SHA1, 6 dígitos).
    const secreto = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    DateTime t(int s) => DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
    expect(Totp.codigo(secreto, t(59)), '287082');
    expect(Totp.codigo(secreto, t(1111111109)), '081804');
    expect(Totp.codigo(secreto, t(1234567890)), '005924');
    expect(Totp.codigo(secreto, t(2000000000)), '279037');
    // Tolera un intervalo de desfase, pero no dos.
    expect(Totp.verificar(secreto, '081804', t(1111111109 + 30)), isTrue);
    expect(Totp.verificar(secreto, '081804', t(1111111109 + 61)), isFalse);
    expect(Totp.segundosRestantes(t(59)), 1);
  });

  test('El escáner acepta el QR dinámico vigente y rechaza una captura vieja', () async {
    Session.instance.modoDemo = true;
    final sesion = await ApiService.instance.login('eddy@fitgym.com', '1234');
    final secreto = sesion.totpSecret!;
    final ahora = DateTime.now();

    final vigente = Cliente.parseQr(sesion.cliente.qrDinamico(Totp.codigo(secreto, ahora)))!;
    final ok = await ApiService.instance.validarAcceso(vigente);
    expect(ok.permitido, isTrue);
    expect(ok.cliente?.nombre, 'Eddy');

    final captura = Totp.codigo(secreto, ahora.subtract(const Duration(minutes: 5)));
    final viejo = await ApiService.instance.validarAcceso(QrDinamico(sesion.cliente.id!, captura));
    expect(viejo.permitido, isFalse);
    expect(viejo.motivo, contains('vencido'));
  });

  test('Maquina y Rutina se serializan', () {
    final m = Maquina.fromJson({
      'id': 4,
      'nombre': 'Remo',
      'descripcion': 'Polea baja',
      'disponibilidad': 0,
      'grupoMuscleGroup': {'id': 2, 'musculo': 'Espalda'},
    });
    expect(m.musculo?.nombre, 'Espalda');
    expect(m.disponible, isFalse);
    expect(m.toApiJson()['grupoMuscleGroup'], {'id': 2, 'musculo': 'Espalda'});

    final r = Rutina(
      id: 'r1',
      nombre: 'Espalda',
      dias: {1, 4},
      ejercicios: [EjercicioRutina.deMaquina(m, series: 4, repeticiones: 10, pesoKg: 40)],
    );
    final copia = Rutina.fromJson(r.toJson());
    expect(copia.dias, {1, 4});
    expect(copia.ejercicios.single.resumen, '4 × 10 · 40 kg');
    expect(copia.musculos, ['Espalda']);
  });

  test('ResultadoAcceso.evaluar aplica la regla de la fecha de pago', () {
    Cliente con(int dias) => Cliente(
          id: 1,
          nombre: 'A',
          apellido: 'B',
          correo: 'a@b.com',
          telefono: '0',
          membresia: Membresia.vip,
          fechaPago: DateTime.now().add(Duration(days: dias)),
          codigo: '1234',
        );
    expect(ResultadoAcceso.evaluar(null).permitido, isFalse);
    expect(ResultadoAcceso.evaluar(con(10)).permitido, isTrue);
    expect(ResultadoAcceso.evaluar(con(0)).permitido, isTrue);
    expect(ResultadoAcceso.evaluar(con(-2)).permitido, isFalse);
  });

  test('sumarMeses no desborda al mes siguiente', () {
    expect(sumarMeses(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(sumarMeses(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    expect(sumarMeses(DateTime(2027, 12, 31), 12), DateTime(2028, 12, 31));
  });

  testWidgets('Primer uso: bienvenida con los dos caminos', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    await tester.pumpWidget(FitGymApp(inicio: await pantallaInicial()));
    expect(find.text('¿Cómo quieres usar FitGym?'), findsOneWidget);
    expect(find.text('Tengo gimnasio con FitGym'), findsOneWidget);
    expect(find.text('Solo quiero entrenar'), findsOneWidget);
  });

  test('Quien eligió un modo en la versión anterior entra directo a la app', () async {
    SharedPreferences.setMockInitialValues({'modo_uso': 'personal'});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    expect(Session.instance.bienvenidaHecha, isTrue);
    expect(Session.instance.lugarHoy, LugarHoy.casa); // el modo personal pasa a "en casa"
    expect(Session.instance.conGimnasio, isFalse);
  });

  test('Rutinas e historial separados por cliente se unen en uno solo', () async {
    SharedPreferences.setMockInitialValues({
      'rutinas_personal': '[{"id":"a","nombre":"Casa","dias":[1],"ejercicios":[]}]',
      'rutinas_7': '[{"id":"a","nombre":"Casa","dias":[1],"ejercicios":[]},{"id":"b","nombre":"Gym","dias":[2],"ejercicios":[]}]',
      'historial_7': '[{"fecha":"2026-10-20T10:00:00.000","rutinaId":"b","rutinaNombre":"Gym","segundos":60,"ejercicios":[]}]',
    });
    await RutinasStore.unificarEspacios();
    final rutinas = await RutinasStore.cargar(RutinasStore.propias);
    expect(rutinas.map((r) => r.id), ['a', 'b']); // sin duplicar "a"
    expect((await Historial.cargar(RutinasStore.propias)).single.rutinaNombre, 'Gym');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('rutinas_7'), isFalse);
    expect(prefs.containsKey('historial_7'), isFalse);
  });

  test('"Al aire libre" y si el parque tiene barras se recuerdan', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    expect(Session.instance.parqueConBarras, isTrue); // la mayoría de los parques con equipos tienen barra

    await Session.instance.saveLugarHoy(LugarHoy.aireLibre);
    await Session.instance.saveParqueConBarras(false);
    await Session.instance.load();
    expect(Session.instance.lugarHoy, LugarHoy.aireLibre);
    expect(Session.instance.parqueConBarras, isFalse);
  });

  test('La URL guardada del puerto 3000 pasa al 8080', () async {
    SharedPreferences.setMockInitialValues({'base_url': 'http://10.0.2.2:3000'});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    expect(Session.instance.baseUrl, 'http://10.0.2.2:8080');
  });

  test('El tema sigue al sistema por defecto y la elección manual persiste', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    expect(Session.instance.tema.value, ThemeMode.system);

    await Session.instance.saveTema(ThemeMode.dark);
    await Session.instance.load(); // como al reabrir la app
    expect(Session.instance.tema.value, ThemeMode.dark);

    await Session.instance.saveTema(ThemeMode.system);
    await Session.instance.load();
    expect(Session.instance.tema.value, ThemeMode.system);
  });

  testWidgets('La app usa el tema del sistema salvo que se elija uno', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await Session.instance.load();
    await tester.pumpWidget(FitGymApp(inicio: await pantallaInicial()));
    await tester.pumpAndSettle();
    Color fondo() => Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
    expect(fondo(), FitColors.temaOscuro.fondo);
    expect(FitColors.background, FitColors.temaOscuro.fondo);

    await Session.instance.saveTema(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(fondo(), FitColors.temaClaro.fondo);
    expect(FitColors.background, FitColors.temaClaro.fondo);
  });

  testWidgets('Con "reducir movimiento" las entradas aparecen sin animar', (tester) async {
    Widget app(bool reducir) => MediaQuery(
          data: MediaQueryData(disableAnimations: reducir),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [Golpe(child: Text('60 KG')), Barrido(child: Text('HOY'))]),
          ),
        );
    double opacidad() => tester.widget<Opacity>(find.ancestor(of: find.text('60 KG'), matching: find.byType(Opacity))).opacity;

    await tester.pumpWidget(app(true));
    expect(opacidad(), 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(false));
    expect(opacidad(), 0); // con movimiento, empieza invisible y entra
    await tester.pumpAndSettle();
    expect(opacidad(), 1);
  });

  testWidgets('Se puede tocar un bloque mientras todavía está entrando', (tester) async {
    var toques = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Barrido(
          retraso: const Duration(milliseconds: 300),
          child: GestureDetector(
            onTap: () => toques++,
            child: const SizedBox(width: 200, height: 60, child: Text('Mostrar mi pase')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mostrar mi pase'), warnIfMissed: false); // antes de terminar de entrar
    expect(toques, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('En Perfil se elige el tema y queda guardado', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PerfilTab(perfil: null, abrir: (_) async {}, onPlantillas: () {})),
    ));
    await tester.scrollUntilVisible(find.text('Oscuro'), 200);
    expect(find.text('Sigue el tema de tu teléfono.'), findsOneWidget);

    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(Session.instance.tema.value, ThemeMode.dark);
    expect(find.textContaining('Se mantiene aunque el teléfono cambie de tema'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('tema'), 'dark');
  });

  test('Días escritos y duración estimada de una rutina', () {
    expect(Rutina.textoDiasCorto({1, 4}), 'Lun y Jue');
    expect(Rutina.textoDiasCorto({5, 1, 3}), 'Lun, Mié y Vie');
    expect(Rutina.textoDiasCorto({6}), 'Sáb');
    expect(Rutina.textoDiasCorto({}), 'Sin día fijo');
    expect(Rutina.textoDiasCorto({1, 2, 3, 4, 5, 6, 7}), 'Todos los días');

    // 3 × 10 reps (40 s por serie) + 2 × 30 s, con 90 s de descanso entre las 5 series (4 descansos).
    const r = Rutina(id: 'r', nombre: 'X', dias: {1}, ejercicios: [
      EjercicioRutina(maquina: 'Sentadilla', musculo: 'Piernas', series: 3, repeticiones: 10),
      EjercicioRutina(maquina: 'Plancha', musculo: 'Abdomen', series: 2, repeticiones: 30, medidoEnSegundos: true),
    ]);
    expect(r.duracionEstimada(), const Duration(seconds: 3 * 40 + 2 * 30 + 4 * 90));
    expect(r.duracionEstimada(descanso: const Duration(seconds: 60)), const Duration(seconds: 3 * 40 + 2 * 30 + 4 * 60));
    expect(const Rutina(id: 'v', nombre: 'Vacía', dias: {}, ejercicios: []).duracionEstimada(), Duration.zero);
  });

  test('Días del backend en texto libre', () {
    expect(Rutina.parseDias('Lunes,Jueves'), {1, 4});
    expect(Rutina.parseDias('miércoles y sábado'), {3, 6});
    expect(Rutina.parseDias('1,5'), {1, 5});
    expect(Rutina.parseDias(''), isEmpty);
    expect(Rutina.textoDias({4, 1}), 'Lunes,Jueves');
  });

  test('Rutina_Ejercicio usa "Series" y "Repeticiones" con mayúscula', () {
    const x = RutinaEjercicioGym(rutinaId: 1, ejercicioId: 2, series: 4, repeticiones: 10);
    expect(x.toApiJson(), {
      'rutina_id': {'id': 1},
      'ejercicio_id': {'id': 2},
      'Series': 4,
      'Repeticiones': 10,
    });
    final leido = RutinaEjercicioGym.fromJson({'id': 9, 'rutina_id': {'id': 1}, 'ejercicio_id': {'id': 2}, 'Series': 5, 'Repeticiones': 8});
    expect((leido.series, leido.repeticiones), (5, 8));
  });

  test('El afiliado ve las rutinas generales y las suyas, no las de otros', () async {
    Session.instance.modoDemo = true;
    final eddy = await GymRutinas.paraCliente(1);
    final jesus = await GymRutinas.paraCliente(2);
    expect(eddy.length, 3);
    expect(eddy.where((r) => r.origen == OrigenRutina.gimnasioAsignada).length, 1);
    expect(jesus.length, 2);
    expect(jesus.every((r) => r.origen == OrigenRutina.gimnasioGeneral), isTrue);
    final lunes = eddy.firstWhere((r) => r.dias.contains(1));
    expect(lunes.nombre, 'Pecho · Brazos');
    expect(lunes.ejercicios.first.resumen, '4 × 10');
  });

  test('Las plantillas respetan equipo, molestias, días y duración', () async {
    const perfil = PerfilEntrenamiento(
      objetivo: Objetivo.perderGrasa,
      nivel: Nivel.principiante,
      dias: 3,
      minutos: 30,
      lugar: Lugar.casaSinEquipo,
      lesiones: {Lesion.rodilla},
    );
    final recomendadas = PlanPersonal.recomendar(perfil);
    expect(recomendadas.first.id, 'quema_grasa');

    final catalogo = await Wger.catalogo();
    final rutinas = PlanPersonal.generar(recomendadas.first, perfil, catalogo);
    final dias = rutinas.expand((r) => r.dias).toList()..sort();
    expect(dias, [1, 3, 5]);
    final porId = {for (final e in catalogo) e.id: e};
    for (final r in rutinas) {
      expect(r.ejercicios.length, 4);
      expect(r.ejercicios.map((e) => e.nombre).toSet().length, r.ejercicios.length); // sin repetir
      for (final e in r.ejercicios) {
        final original = porId[e.wgerId]!;
        expect(original.equipo, Equipo.corporal);
        expect(original.evitarCon.contains(Lesion.rodilla), isFalse);
        expect(e.series, 2); // principiante: una serie menos
      }
    }
  });

  group('Historial', () {
    SesionEntrenamiento sesion(DateTime f, {String rutina = 'r1', int hechas = 3, double? peso = 40}) =>
        SesionEntrenamiento(
          fecha: f,
          rutinaId: rutina,
          rutinaNombre: 'Pecho',
          duracion: const Duration(minutes: 40),
          ejercicios: [
            EjercicioSesion(nombre: 'Press de banca', musculo: 'Pecho', seriesPlan: 3, repeticiones: 10, seriesHechas: hechas, pesoKg: peso),
          ],
        );
    final hoy = DateTime(2026, 10, 30); // viernes

    test('Última vez que se hizo una rutina y si ya se hizo esta semana', () {
      final s = [sesion(DateTime(2026, 10, 20)), sesion(DateTime(2026, 10, 27), rutina: 'r2'), sesion(DateTime(2026, 10, 22))];
      expect(Historial.ultimaVez(s, 'r1'), DateTime(2026, 10, 22));
      expect(Historial.ultimaVez(s, 'nunca'), isNull);
      expect(Historial.hechaEstaSemana(s, 'r2', hoy: hoy), isTrue); // martes 27, misma semana
      expect(Historial.hechaEstaSemana(s, 'r1', hoy: hoy), isFalse); // la semana pasada
    });

    test('Racha de semanas seguidas', () {
      final s = [sesion(DateTime(2026, 10, 14)), sesion(DateTime(2026, 10, 20)), sesion(DateTime(2026, 10, 28))];
      expect(Historial.rachaSemanas(s, hoy: hoy), 3);
      // Si esta semana todavía no entrenó, cuenta desde la anterior.
      expect(Historial.rachaSemanas(s.take(2).toList(), hoy: hoy), 2);
      expect(Historial.rachaSemanas([sesion(DateTime(2026, 10, 1))], hoy: hoy), 0);
    });

    test('Entrenamientos por semana', () {
      final semanas = Historial.porSemana([sesion(DateTime(2026, 10, 27)), sesion(DateTime(2026, 10, 29))], n: 3, hoy: hoy);
      expect(semanas.map((x) => x.$2), [0, 0, 2]);
      expect(semanas.last.$1, DateTime(2026, 10, 26)); // lunes de esta semana
    });

    test('Sugiere subir carga tras completar dos veces seguidas', () {
      final antes = [sesion(DateTime(2026, 10, 27))];
      final ahora = sesion(hoy);
      final sug = Historial.sugerencias(ahora, antes);
      expect(sug.single.texto, 'Sube a 42.5 kg');
      // Sin completar no se sugiere.
      expect(Historial.sugerencias(sesion(hoy, hechas: 2), antes), isEmpty);
      // Sin peso: más repeticiones.
      expect(Historial.sugerencias(sesion(hoy, peso: null), [sesion(DateTime(2026, 10, 27), peso: null)]).single.repeticiones, 12);

      const r = Rutina(id: 'r1', nombre: 'Pecho', dias: {1}, ejercicios: [
        EjercicioRutina(maquina: 'Press de banca', musculo: 'Pecho', series: 3, repeticiones: 10, pesoKg: 40),
      ]);
      expect(Historial.aplicar(r, sug).ejercicios.single.pesoKg, 42.5);
    });

    test('Evolución del peso por ejercicio', () {
      final s = [sesion(DateTime(2026, 10, 20), peso: 40), sesion(DateTime(2026, 10, 27), peso: 42.5)];
      expect(Historial.ejerciciosConPeso(s), ['Press de banca']);
      expect(Historial.evolucionPeso(s, 'Press de banca').map((x) => x.$2), [40, 42.5]);
    });
  });

  group('Catálogo de wger', () {
    test('Solo ejercicios en español con imagen o video', () async {
      final catalogo = await Wger.catalogo();
      expect(catalogo.length, greaterThan(200));
      for (final e in catalogo) {
        expect(e.nombre, isNotEmpty);
        expect(e.descripcion, isNotEmpty, reason: e.nombre);
        expect(e.imagenes.isNotEmpty || e.videos.isNotEmpty, isTrue, reason: e.nombre);
      }
      // Hay ejercicios sin equipo para cada grupo muscular (modo casa).
      final grupos = catalogo.where((e) => e.equipo == Equipo.corporal).map((e) => e.musculo).toSet();
      expect(grupos, containsAll(['Pecho', 'Espalda', 'Piernas', 'Hombros', 'Brazos', 'Abdomen', 'Cardio']));
    });

    test('Clasifica equipo, molestias y ejercicios por tiempo', () {
      const prensa = EjercicioWger(id: 1, nombre: 'Prensa de piernas', descripcion: 'x', musculo: 'Piernas');
      expect(prensa.equipo, Equipo.gimnasio); // sin equipo listado: se deduce del nombre
      expect(prensa.evitarCon, {Lesion.rodilla});
      const curl = EjercicioWger(id: 2, nombre: 'Curl', descripcion: 'x', musculo: 'Brazos', equipos: ['Dumbbell']);
      expect(curl.equipo, Equipo.mancuernas);
      expect(curl.evitarCon, isEmpty);
      const plancha = EjercicioWger(
          id: 3, nombre: 'Plancha de antebrazo', descripcion: 'x', musculo: 'Abdomen', equipos: ['none (bodyweight exercise)']);
      expect(plancha.equipo, Equipo.corporal);
      expect(plancha.porTiempo, isTrue);
    });

    test('La barra de dominadas y las paralelas son su propio equipo', () {
      const conBarra = EjercicioWger(id: 4, nombre: 'Remo invertido', descripcion: 'x', musculo: 'Espalda', equipos: ['Pull-up bar']);
      expect(conBarra.equipo, Equipo.barra);
      const dominadas = EjercicioWger(id: 5, nombre: 'Dominadas', descripcion: 'x', musculo: 'Espalda');
      expect(dominadas.equipo, Equipo.barra); // sin equipo listado: se deduce del nombre
      const fondos = EjercicioWger(id: 6, nombre: 'Fondos en paralelas', descripcion: 'x', musculo: 'Pecho');
      expect(fondos.equipo, Equipo.barra);
      const sentadilla = EjercicioWger(id: 7, nombre: 'Sentadilla con barra', descripcion: 'x', musculo: 'Piernas', equipos: ['Barbell']);
      expect(sentadilla.equipo, Equipo.gimnasio); // la barra con discos sigue siendo de gimnasio
    });

    test('Al aire libre: peso corporal, más barras si el parque las tiene', () {
      expect(PlanPersonal.equipoHoy(null, LugarHoy.aireLibre), {Equipo.corporal, Equipo.barra});
      expect(PlanPersonal.equipoHoy(null, LugarHoy.aireLibre, parqueConBarras: false), {Equipo.corporal});
      // En el gimnasio también hay barras; en casa, no.
      expect(PlanPersonal.equipoHoy(null, LugarHoy.gimnasio), contains(Equipo.barra));
      expect(PlanPersonal.equipoHoy(null, LugarHoy.casa), isNot(contains(Equipo.barra)));

      const dominadas = EjercicioWger(id: 5, nombre: 'Dominadas', descripcion: 'x', musculo: 'Espalda');
      const curl = EjercicioWger(id: 2, nombre: 'Curl', descripcion: 'x', musculo: 'Brazos', equipos: ['Dumbbell']);
      const flexiones = EjercicioWger(id: 8, nombre: 'Flexiones', descripcion: 'x', musculo: 'Pecho', equipos: ['none (bodyweight exercise)']);
      final todos = [dominadas, curl, flexiones];
      expect(PlanPersonal.aptosHoy(null, LugarHoy.aireLibre, todos), [dominadas, flexiones]);
      expect(PlanPersonal.aptosHoy(null, LugarHoy.aireLibre, todos, parqueConBarras: false), [flexiones]);

      EjercicioRutina ej(EjercicioWger e) =>
          EjercicioRutina(maquina: e.nombre, musculo: e.musculo, series: 3, repeticiones: 10, wgerId: e.id);
      final wger = {for (final e in todos) e.id: e};
      final parque = Rutina(id: 'p', nombre: 'Parque', dias: const {1}, ejercicios: [ej(dominadas), ej(flexiones)]);
      final conMancuernas = Rutina(id: 'm', nombre: 'Brazos', dias: const {1}, ejercicios: [ej(curl)]);
      final aireLibre = PlanPersonal.equipoHoy(null, LugarHoy.aireLibre);
      expect(PlanPersonal.faltaEquipo(parque, wger, aireLibre), isFalse);
      expect(PlanPersonal.faltaEquipo(conMancuernas, wger, aireLibre), isTrue);
      expect(PlanPersonal.faltaEquipo(parque, wger, {Equipo.corporal}), isTrue); // parque sin barras
      // En casa no hay barra: una rutina con dominadas sigue marcada como antes.
      expect(PlanPersonal.necesitaGimnasio(parque, wger), isTrue);
    });

    test('Convierte un registro de la API aplicando el filtro', () {
      Map<String, dynamic> registro({bool conEs = true, bool conImagen = true}) => {
            'id': 9,
            'category': {'name': 'Calves'},
            'equipment': [
              {'name': 'Dumbbell'}
            ],
            'images': conImagen
                ? [
                    {'image': 'https://wger.de/a.png', 'is_main': true, 'license_author': 'Ana'}
                  ]
                : [],
            'videos': [],
            'translations': [
              if (conEs) {'language': 4, 'name': 'Elevación de talones', 'description': '<p>Sube.</p><ul><li>Baja lento</li></ul>'},
              {'language': 2, 'name': 'Calf raise', 'description': ''},
            ],
          };
      final e = Wger.convertir(registro())!;
      expect(e.nombre, 'Elevación de talones');
      expect(e.musculo, 'Piernas'); // pantorrillas se agrupan en piernas
      expect(e.descripcion, 'Sube.\n• Baja lento');
      expect(e.autorImagen, 'Ana');
      expect(Wger.convertir(registro(conEs: false)), isNull);
      expect(Wger.convertir(registro(conImagen: false)), isNull);
    });

    test('Referencia a wger en la descripción del backend', () {
      expect(GymRutinas.wgerIdDe(const EjercicioGym(nombre: 'Press', descripcion: 'wger:73')), 73);
      expect(GymRutinas.wgerIdDe(const EjercicioGym(nombre: 'Viejo', descripcion: 'Con barra')), isNull);
    });

    test('Prioriza animaciones GIF de ExerciseDB y videos MP4, y neutraliza Dolby Vision (dvvC → free)', () async {
      final ordenados = ordenarVideosWger([
        'https://wger.de/media/exercise-video/371/32601896-b84a-49bf-ae8a-b27a8f57ab21.MOV',
        'https://wger.de/media/exercise-video/73/2bdb390c-312c-4497-a722-5eed2c823e5a.MOV',
        'https://wger.de/media/exercise-video/73/cfb72002-898f-443a-a124-a0bce8a2e6ad.MP4',
        'https://static.exercisedb.dev/media/EIeI8Vf.gif',
      ]);
      expect(esAnimacionGif(ordenados.first), isTrue);
      expect(ordenados[1], endsWith('.MP4'));
      expect(ordenados.last, endsWith('32601896-b84a-49bf-ae8a-b27a8f57ab21.MOV'));

      // Verifica que el catálogo incluya las animaciones de ExerciseDB y no tenga archivos .MOV rotos.
      final catalogo = await Wger.catalogo();
      expect(catalogo.any((e) => e.videos.any(esAnimacionGif)), isTrue);
      expect(catalogo.any((e) => e.videos.any((v) => v.toLowerCase().endsWith('.mov'))), isFalse);

      // Caja dvvC real de 32 bytes (0x00000020 + 'dvvC' + 24 bytes de payload)
      // partida en mitad de dos paquetes TCP para verificar la ventana deslizante.
      final original = Uint8List.fromList([
        0x11, 0x22, 0x33,
        0x00, 0x00, 0x00, 0x20, 0x64, 0x76, // 'dv' al final del primer paquete
        0x76, 0x43, 0x01, 0x00, 0x10, 0x2d, // 'vC' al inicio del segundo paquete
        0x44, 0x55,
      ]);
      final trozos = Stream<List<int>>.fromIterable([
        original.sublist(0, 9),
        original.sublist(9),
      ]);
      final salida = <int>[];
      await for (final c in transformarStreamMp4(trozos)) {
        salida.addAll(c);
      }
      expect(salida.length, original.length);
      // 'dvvC' (0x64, 0x76, 0x76, 0x43) pasa a 'free' (0x66, 0x72, 0x65, 0x65)
      expect(salida.sublist(3, 11), [0x00, 0x00, 0x00, 0x20, 0x66, 0x72, 0x65, 0x65]);
    });
  });
}

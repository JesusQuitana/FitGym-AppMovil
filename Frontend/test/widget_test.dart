import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitgym/main.dart';
import 'package:fitgym/models/cliente.dart';
import 'package:fitgym/models/maquina.dart';
import 'package:fitgym/models/rutina.dart';
import 'package:fitgym/services/api_service.dart';
import 'package:fitgym/services/session.dart';
import 'package:fitgym/services/totp.dart';

void main() {
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

  testWidgets('Sin sesión abre el login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await Session.instance.load();
    await tester.pumpWidget(const FitGymApp());
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}

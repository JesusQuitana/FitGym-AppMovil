import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/cliente.dart';
import '../models/maquina.dart';
import 'session.dart';
import 'totp.dart';

/// Resultado del login del afiliado.
typedef SesionAfiliado = ({Cliente cliente, String? totpSecret, Duration relojOffset});

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cliente de la API REST del backend Spring Boot (puerto 3000):
///
///   POST /auth/login                          → {token, id}       (público)
///   POST /auth/register                       → crea User USER    (público)
///   GET  /user/get/{id}, /user/all            → usuarios          (público)
///   GET  /appgym-movil/clientes               → lista             (público)
///   GET  /appgym-movil/cliente/buscar/{id}    → un cliente        (público)
///   POST /appgym-movil/cliente/agregar        → alta              (JWT)
///   PUT  /appgym-movil/cliente/editar/{id}    → edición           (JWT)
///   GET  /appgym-movil/MuscleGroups, /maquinas → catálogo         (público)
///   POST/PUT/DELETE /appgym-movil/MuscleGroup/…, /maquina/…       (JWT)
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Session get _session => Session.instance;

  Uri _uri(String path, {bool api = true}) {
    final base = _session.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base${api ? AppConfig.apiPrefix : ''}$path');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (_session.adminToken != null) 'Authorization': 'Bearer ${_session.adminToken}',
      };

  // ---------------------------------------------------------------- clientes

  Future<List<Cliente>> listarClientes() async {
    if (_session.modoDemo) return _MockDb.listar();
    final res = await _send(() => http.get(_uri('/clientes'), headers: _headers));
    _check(res);
    final data = _decode(res);
    if (data is! List) throw ApiException('Respuesta inesperada del servidor.');
    return data.map((e) => Cliente.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Cliente> buscarCliente(int id) async {
    if (_session.modoDemo) return _MockDb.buscar(id);
    final res = await _send(() => http.get(_uri('/cliente/buscar/$id'), headers: _headers));
    if (res.statusCode == 404) throw ApiException('No existe un cliente con ID $id.');
    _check(res);
    return Cliente.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  /// Registro en recepción: crea el `User` del afiliado (username = correo,
  /// password = código) y luego el `Cliente` enlazado a ese usuario.
  Future<Cliente> agregarCliente(Cliente c) async {
    if (_session.modoDemo) return _MockDb.agregar(c);
    _requiereAdmin();

    final reg = await _send(() => http.post(
          _uri('/auth/register', api: false),
          headers: _headers,
          body: jsonEncode({'username': c.correo, 'password': c.codigo}),
        ));
    if (reg.statusCode != 200) {
      throw ApiException('No se pudo crear el usuario del cliente. ¿Ya existe un usuario con ese correo?');
    }
    // /auth/register no devuelve el id del usuario creado: se busca por username.
    final userId = await _buscarUserId(c.correo);
    if (userId == null) throw ApiException('El usuario se creó pero no se encontró su id.');

    // Se envía el User con su rol: si solo va el id, el backend guarda el
    // cliente pero falla al serializar la respuesta (User.getAuthorities()
    // con role null) y devuelve 502.
    final body = c.copyWith(userId: userId).toApiJson()
      ..['user_id'] = {'id': userId, 'username': c.correo, 'role': 'USER'};
    final res = await _send(() => http.post(
          _uri('/cliente/agregar'),
          headers: _headers,
          body: jsonEncode(body),
        ));
    _check(res);
    final data = _decode(res);
    final guardado = data is Map ? Cliente.fromJson(Map<String, dynamic>.from(data)) : c;
    return guardado.copyWith(userId: userId, codigo: c.codigo);
  }

  Future<Cliente> actualizarCliente(Cliente c) async {
    if (_session.modoDemo) return _MockDb.actualizar(c);
    _requiereAdmin();
    final res = await _send(() => http.put(
          _uri('/cliente/editar/${c.id}'),
          headers: _headers,
          body: jsonEncode(c.toApiJson()),
        ));
    if (res.statusCode == 404) throw ApiException('El cliente ya no existe.');
    _check(res);
    final guardado = Cliente.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
    if (_isoDay(guardado.fechaPago) != _isoDay(c.fechaPago)) {
      throw ApiException(
        'El servidor guardó la membresía pero no la fecha de pago: '
        'falta clienteActualizar.setFechaPago(...) en ClienteController.updateCliente.',
      );
    }
    return guardado.copyWith(codigo: c.codigo);
  }

  // ------------------------------------------------------------ autenticación

  /// Login del afiliado con correo + código (su usuario y contraseña).
  ///
  /// Si el backend ya implementa el QR dinámico, la respuesta de /auth/login
  /// trae `totpSecret`; si no, el pase sigue usando el QR estático. También
  /// se mide la diferencia entre el reloj del servidor y el del teléfono.
  Future<SesionAfiliado> login(String correo, String codigo) async {
    final email = correo.trim().toLowerCase();
    if (_session.modoDemo) return _MockDb.login(email, codigo);
    final auth = await _auth(email, codigo);
    final cliente = await _clienteDeUsuario(auth.userId);
    if (cliente == null) {
      throw ApiException('Tu usuario no está vinculado a ningún cliente. Consulta en recepción.');
    }
    return (
      cliente: cliente.copyWith(codigo: codigo),
      totpSecret: auth.totpSecret,
      relojOffset: auth.horaServidor?.difference(DateTime.now()) ?? Duration.zero,
    );
  }

  /// Login de recepción. Además de validar la contraseña verifica que el
  /// usuario tenga rol ADMIN, ya que el backend acepta cualquier token.
  Future<void> loginAdmin(String usuario, String password) async {
    if (_session.modoDemo) {
      await _MockDb.latencia();
      if (usuario != AppConfig.demoAdminUser || password != AppConfig.demoAdminPassword) {
        throw ApiException('Usuario o contraseña incorrectos.');
      }
      _session.adminToken = 'demo';
      return;
    }
    final res = await _send(() => http.post(
          _uri('/auth/login', api: false),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': usuario.trim(), 'password': password}),
        ));
    if (res.statusCode != 200) throw ApiException('Usuario o contraseña incorrectos.');
    final data = Map<String, dynamic>.from(_decode(res) as Map);

    final userRes = await _send(() => http.get(_uri('/user/get/${data['id']}', api: false)));
    _check(userRes);
    final rol = (_decode(userRes) as Map)['role'];
    if (rol != 'ADMIN') throw ApiException('Este usuario no tiene rol de administrador.');
    _session.adminToken = '${data['token']}';
  }

  /// Valida en la entrada el QR del afiliado.
  ///
  /// - QR dinámico: el backend verifica el código TOTP y la fecha de pago
  ///   (POST /appgym-movil/acceso).
  /// - QR estático o validación manual: correo + código contra /auth/login y
  ///   la regla de fecha de pago se aplica en la app.
  Future<ResultadoAcceso> validarAcceso(QrAcceso qr) async {
    switch (qr) {
      case QrDinamico(:final clienteId, :final codigo):
        if (_session.modoDemo) return _MockDb.validarDinamico(clienteId, codigo, _session.ahora);
        final res = await _send(() => http.post(
              _uri('/acceso'),
              headers: _headers,
              body: jsonEncode({'clienteId': clienteId, 'codigo': codigo}),
            ));
        if (res.statusCode == 404) {
          return ResultadoAcceso(
            permitido: false,
            motivo: 'El servidor todavía no valida QR dinámicos (falta POST /appgym-movil/acceso).',
          );
        }
        _check(res);
        return ResultadoAcceso.fromJson(Map<String, dynamic>.from(_decode(res) as Map));

      case QrEstatico(:final correo, :final codigo):
        final email = correo.trim().toLowerCase();
        if (_session.modoDemo) {
          final c = await _MockDb.porCredenciales(email, codigo);
          if (c == null) return ResultadoAcceso(permitido: false, motivo: 'Correo o código incorrectos');
          return ResultadoAcceso.evaluar(c);
        }
        final int userId;
        try {
          userId = (await _auth(email, codigo)).userId;
        } on ApiException catch (e) {
          return ResultadoAcceso(permitido: false, motivo: e.message);
        }
        return ResultadoAcceso.evaluar(await _clienteDeUsuario(userId));
    }
  }

  String generarCodigo() => (1000 + Random().nextInt(9000)).toString();

  // ------------------------------------------------- músculos y máquinas

  Future<List<Musculo>> listarMusculos() async {
    if (_session.modoDemo) return _MockDb.listarMusculos();
    final res = await _send(() => http.get(_uri('/MuscleGroups'), headers: _headers));
    _check(res);
    return (_decode(res) as List).map((e) => Musculo.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Musculo> guardarMusculo(Musculo m) async {
    if (_session.modoDemo) return _MockDb.guardarMusculo(m);
    _requiereAdmin();
    final res = await _send(() => m.id == null
        ? http.post(_uri('/MuscleGroup/agregar'), headers: _headers, body: jsonEncode(m.toApiJson()))
        : http.put(_uri('/MuscleGroup/editar/${m.id}'), headers: _headers, body: jsonEncode(m.toApiJson())));
    _check(res);
    return Musculo.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  Future<void> eliminarMusculo(int id) async {
    if (_session.modoDemo) return _MockDb.eliminarMusculo(id);
    _requiereAdmin();
    final res = await _send(() => http.delete(_uri('/MuscleGroup/delete/$id'), headers: _headers));
    // Si alguna máquina lo usa, la llave foránea impide borrarlo y el backend responde 502.
    if (res.statusCode >= 500) {
      throw ApiException('No se puede eliminar: hay máquinas asociadas a este grupo muscular.');
    }
    _check(res);
  }

  Future<List<Maquina>> listarMaquinas() async {
    if (_session.modoDemo) return _MockDb.listarMaquinas();
    final res = await _send(() => http.get(_uri('/maquinas'), headers: _headers));
    _check(res);
    return (_decode(res) as List).map((e) => Maquina.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Maquina> guardarMaquina(Maquina m) async {
    if (_session.modoDemo) return _MockDb.guardarMaquina(m);
    _requiereAdmin();
    final res = await _send(() => m.id == null
        ? http.post(_uri('/maquina/agregar'), headers: _headers, body: jsonEncode(m.toApiJson()))
        : http.put(_uri('/maquina/editar/${m.id}'), headers: _headers, body: jsonEncode(m.toApiJson())));
    _check(res);
    return Maquina.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  Future<void> eliminarMaquina(int id) async {
    if (_session.modoDemo) return _MockDb.eliminarMaquina(id);
    _requiereAdmin();
    final res = await _send(() => http.delete(_uri('/maquina/delete/$id'), headers: _headers));
    _check(res);
  }

  // ----------------------------------------------------------------- helpers

  /// POST /auth/login. Con credenciales inválidas el backend responde 502
  /// (GlobalExceptionHandler) o 403. Devuelve también el secreto TOTP si el
  /// backend lo envía y la hora del servidor (cabecera Date).
  Future<({int userId, String? totpSecret, DateTime? horaServidor})> _auth(
    String username,
    String password,
  ) async {
    final res = await _send(() => http.post(
          _uri('/auth/login', api: false),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        ));
    if (res.statusCode != 200) throw ApiException('Correo o código incorrectos.');
    final data = _decode(res) as Map;
    final id = data['id'];
    if (id is! num) throw ApiException('Respuesta inesperada del servidor.');
    final secreto = data['totpSecret'] ?? data['totp_secret'];
    DateTime? hora;
    try {
      final h = res.headers['date'];
      if (h != null) hora = HttpDate.parse(h);
    } catch (_) {}
    return (
      userId: id.toInt(),
      totpSecret: secreto is String && secreto.isNotEmpty ? secreto : null,
      horaServidor: hora,
    );
  }

  Future<Cliente?> _clienteDeUsuario(int userId) async =>
      (await listarClientes()).where((c) => c.userId == userId).firstOrNull;

  Future<int?> _buscarUserId(String username) async {
    final res = await _send(() => http.get(_uri('/user/all', api: false), headers: _headers));
    _check(res);
    final data = _decode(res);
    if (data is! List) return null;
    for (final u in data) {
      if (u is Map && '${u['username']}'.toLowerCase() == username.toLowerCase()) {
        return (u['id'] as num?)?.toInt();
      }
    }
    return null;
  }

  void _requiereAdmin() {
    if (_session.adminToken == null) throw ApiException('Inicia sesión como administrador.');
  }

  void _check(http.Response res) {
    final code = res.statusCode;
    if (code >= 200 && code < 300) return;
    if (code == 401 || code == 403) {
      throw ApiException('No autorizado. Vuelve a iniciar sesión como administrador (el token dura 24 minutos).');
    }
    if (code >= 500) throw ApiException('Error del servidor ($code).');
    throw ApiException('Solicitud rechazada ($code).');
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(AppConfig.timeout);
    } on SocketException {
      throw ApiException('No se pudo conectar con el servidor. Revisa tu conexión a internet.');
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    }
  }

  dynamic _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw ApiException('Respuesta inválida del servidor.');
    }
  }

  static String _isoDay(DateTime d) => '${d.year}-${d.month}-${d.day}';
}

/// Datos de ejemplo para el modo demo (sin backend).
class _MockDb {
  static final DateTime _hoy = DateTime.now();

  static final List<Cliente> _clientes = [
    Cliente(
      id: 1,
      userId: 11,
      nombre: 'Eddy',
      apellido: 'Coello',
      correo: 'eddy@fitgym.com',
      telefono: '0414-1234567',
      membresia: Membresia.vip,
      fechaPago: _hoy.add(const Duration(days: 18)),
      codigo: '1234',
    ),
    Cliente(
      id: 2,
      userId: 12,
      nombre: 'Jesús',
      apellido: 'Quintana',
      correo: 'jesus@fitgym.com',
      telefono: '0424-7654321',
      membresia: Membresia.premium,
      fechaPago: _hoy.add(const Duration(days: 3)),
      codigo: '5678',
    ),
    Cliente(
      id: 3,
      userId: 13,
      nombre: 'Eduardo',
      apellido: 'Sarmiento',
      correo: 'eduardo@fitgym.com',
      telefono: '0412-5550000',
      membresia: Membresia.regular,
      fechaPago: _hoy.subtract(const Duration(days: 4)),
      codigo: '4321',
    ),
  ];

  /// Secretos TOTP de ejemplo (en el backend real los genera SecureRandom).
  static final Map<int, String> _secretos = {
    1: 'JBSWY3DPEHPK3PXP',
    2: 'KRSXG5CTMVRXEZLU',
    3: 'MFRGGZDFMZTWQ2LK',
  };

  static String _nuevoSecreto() {
    const alfabeto = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rnd = Random.secure();
    return List.generate(16, (_) => alfabeto[rnd.nextInt(32)]).join();
  }

  static Future<ResultadoAcceso> validarDinamico(int clienteId, String codigo, DateTime ahora) async {
    await latencia();
    final c = _clientes.where((e) => e.id == clienteId).firstOrNull;
    final secreto = _secretos[clienteId];
    if (c == null || secreto == null) {
      return ResultadoAcceso(permitido: false, motivo: 'Pase no reconocido');
    }
    if (!Totp.verificar(secreto, codigo, ahora)) {
      return ResultadoAcceso(
        permitido: false,
        motivo: 'Código vencido o inválido (¿captura de pantalla?)',
        cliente: c,
      );
    }
    return ResultadoAcceso.evaluar(c);
  }

  static final List<Musculo> _musculos = [
    const Musculo(id: 1, nombre: 'Pecho'),
    const Musculo(id: 2, nombre: 'Espalda'),
    const Musculo(id: 3, nombre: 'Piernas'),
    const Musculo(id: 4, nombre: 'Hombros'),
    const Musculo(id: 5, nombre: 'Brazos'),
    const Musculo(id: 6, nombre: 'Abdomen'),
  ];

  static final List<Maquina> _maquinas = [
    Maquina(id: 1, nombre: 'Press de banca', descripcion: 'Banco plano con barra olímpica.', disponibilidad: 3, musculo: _musculos[0]),
    Maquina(id: 2, nombre: 'Pec deck', descripcion: 'Aperturas guiadas para pectoral.', disponibilidad: 1, musculo: _musculos[0]),
    Maquina(id: 3, nombre: 'Jalón al pecho', descripcion: 'Polea alta con barra ancha.', disponibilidad: 2, musculo: _musculos[1]),
    Maquina(id: 4, nombre: 'Remo sentado', descripcion: 'Polea baja con agarre neutro.', disponibilidad: 0, musculo: _musculos[1]),
    Maquina(id: 5, nombre: 'Prensa de piernas', descripcion: 'Prensa inclinada a 45°.', disponibilidad: 2, musculo: _musculos[2]),
    Maquina(id: 6, nombre: 'Extensión de cuádriceps', descripcion: 'Sillón de extensiones.', disponibilidad: 1, musculo: _musculos[2]),
    Maquina(id: 7, nombre: 'Press militar', descripcion: 'Máquina de press de hombros sentado.', disponibilidad: 1, musculo: _musculos[3]),
    Maquina(id: 8, nombre: 'Curl predicador', descripcion: 'Banco Scott para bíceps.', disponibilidad: 2, musculo: _musculos[4]),
    Maquina(id: 9, nombre: 'Crunch abdominal', descripcion: 'Máquina de encogimientos con carga.', disponibilidad: 1, musculo: _musculos[5]),
  ];

  static int _sigId(Iterable<int?> ids) => ids.map((e) => e ?? 0).fold<int>(0, max) + 1;

  static Future<List<Musculo>> listarMusculos() async {
    await latencia();
    return List.of(_musculos);
  }

  static Future<Musculo> guardarMusculo(Musculo m) async {
    await latencia();
    if (m.id == null) {
      final nuevo = Musculo(id: _sigId(_musculos.map((e) => e.id)), nombre: m.nombre);
      _musculos.add(nuevo);
      return nuevo;
    }
    final i = _musculos.indexWhere((e) => e.id == m.id);
    _musculos[i] = m;
    for (var j = 0; j < _maquinas.length; j++) {
      final q = _maquinas[j];
      if (q.musculo?.id == m.id) {
        _maquinas[j] = Maquina(id: q.id, nombre: q.nombre, descripcion: q.descripcion, disponibilidad: q.disponibilidad, musculo: m);
      }
    }
    return m;
  }

  static Future<void> eliminarMusculo(int id) async {
    await latencia();
    if (_maquinas.any((q) => q.musculo?.id == id)) {
      throw ApiException('No se puede eliminar: hay máquinas asociadas a este grupo muscular.');
    }
    _musculos.removeWhere((e) => e.id == id);
  }

  static Future<List<Maquina>> listarMaquinas() async {
    await latencia();
    return List.of(_maquinas);
  }

  static Future<Maquina> guardarMaquina(Maquina m) async {
    await latencia();
    if (m.id == null) {
      final nueva = m.copyWith(id: _sigId(_maquinas.map((e) => e.id)));
      _maquinas.add(nueva);
      return nueva;
    }
    _maquinas[_maquinas.indexWhere((e) => e.id == m.id)] = m;
    return m;
  }

  static Future<void> eliminarMaquina(int id) async {
    await latencia();
    _maquinas.removeWhere((e) => e.id == id);
  }

  static Future<void> latencia() => Future.delayed(const Duration(milliseconds: 500));

  static Future<List<Cliente>> listar() async {
    await latencia();
    return List.of(_clientes);
  }

  static Future<Cliente> buscar(int id) async {
    await latencia();
    return _clientes.firstWhere(
      (c) => c.id == id,
      orElse: () => throw ApiException('No existe un cliente con ID $id.'),
    );
  }

  static Future<Cliente?> porCredenciales(String correo, String codigo) async {
    await latencia();
    return _clientes.where((c) => c.correo == correo && c.codigo == codigo).firstOrNull;
  }

  static Future<SesionAfiliado> login(String correo, String codigo) async {
    final c = await porCredenciales(correo, codigo);
    if (c == null) throw ApiException('Correo o código incorrectos. Verifica los datos que te dio recepción.');
    return (cliente: c, totpSecret: _secretos[c.id], relojOffset: Duration.zero);
  }

  static Future<Cliente> agregar(Cliente c) async {
    await latencia();
    if (_clientes.any((e) => e.correo == c.correo)) {
      throw ApiException('No se pudo crear el usuario del cliente. ¿Ya existe un usuario con ese correo?');
    }
    final nuevo = c.copyWith(
      id: _clientes.map((e) => e.id ?? 0).fold<int>(0, max) + 1,
      userId: _clientes.map((e) => e.userId ?? 0).fold<int>(0, max) + 1,
    );
    _clientes.add(nuevo);
    _secretos[nuevo.id!] = _nuevoSecreto();
    return nuevo;
  }

  static Future<Cliente> actualizar(Cliente c) async {
    await latencia();
    final i = _clientes.indexWhere((e) => e.id == c.id);
    if (i < 0) throw ApiException('No existe un cliente con ID ${c.id}.');
    _clientes[i] = c.copyWith(codigo: _clientes[i].codigo);
    return _clientes[i];
  }
}

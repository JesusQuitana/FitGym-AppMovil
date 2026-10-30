import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/cliente.dart';
import '../models/maquina.dart';
import '../models/rutina_gym.dart';
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
///   GET  /appgym-movil/ejercicioss, /ejercicios/musculos, /rutinas (público)
///   GET  /appmovil-gym/rutina/ejercicios                           (público)
///   POST/PUT/DELETE de las cuatro anteriores                       (JWT)
/// Las rutas que no siguen el patrón están en AppConfig.
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

    final reg = await _sendAdmin(() => http.post(
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
    final res = await _sendAdmin(() => http.post(
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
    final res = await _sendAdmin(() => http.put(
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
    _session.adminUsuario = usuario;
    _session.adminPassword = password;
    _session.adminTokenDesde = DateTime.now();
  }

  /// El backend emite el token por 24 minutos: se renueva a los 20.
  static const _vidaToken = Duration(minutes: 20);

  /// Envía una petición de recepción manteniendo viva la sesión: renueva el
  /// token antes de que venza y, si aun así el backend lo rechaza (401/403),
  /// vuelve a iniciar sesión y repite la petición una vez.
  Future<http.Response> _sendAdmin(Future<http.Response> Function() call) async {
    final puedeRenovar = !_session.modoDemo && _session.adminPassword != null;
    final desde = _session.adminTokenDesde;
    if (puedeRenovar && desde != null && DateTime.now().difference(desde) > _vidaToken) {
      await _renovarAdmin();
    }
    var res = await _send(call);
    if (puedeRenovar && (res.statusCode == 401 || res.statusCode == 403)) {
      await _renovarAdmin();
      res = await _send(call);
    }
    return res;
  }

  Future<void> _renovarAdmin() async {
    try {
      await loginAdmin(_session.adminUsuario!, _session.adminPassword!);
    } on ApiException {
      throw ApiException('La sesión de recepción venció y no se pudo renovar. Vuelve a entrar.');
    }
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
    final res = await _sendAdmin(() => m.id == null
        ? http.post(_uri('/MuscleGroup/agregar'), headers: _headers, body: jsonEncode(m.toApiJson()))
        : http.put(_uri('/MuscleGroup/editar/${m.id}'), headers: _headers, body: jsonEncode(m.toApiJson())));
    _check(res);
    return Musculo.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  Future<void> eliminarMusculo(int id) async {
    if (_session.modoDemo) return _MockDb.eliminarMusculo(id);
    _requiereAdmin();
    final res = await _sendAdmin(() => http.delete(_uri('/MuscleGroup/delete/$id'), headers: _headers));
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
    final res = await _sendAdmin(() => m.id == null
        ? http.post(_uri('/maquina/agregar'), headers: _headers, body: jsonEncode(m.toApiJson()))
        : http.put(_uri('/maquina/editar/${m.id}'), headers: _headers, body: jsonEncode(m.toApiJson())));
    _check(res);
    return Maquina.fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  // --------------------------------------------- ejercicios y rutinas gym

  /// Rutas sin el prefijo /appgym-movil (RutinaEjercicioController).
  Uri _uriRutinaEjercicios(String path) {
    final base = _session.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base${AppConfig.rutaRutinaEjercicios}$path');
  }

  Future<List<T>> _listar<T>(Uri uri, T Function(Map<String, dynamic>) fromJson) async {
    final res = await _send(() => http.get(uri, headers: _headers));
    _check(res);
    return (_decode(res) as List).map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<T> _guardar<T>(Uri crear, Uri editar, bool nuevo, Map<String, dynamic> body,
      T Function(Map<String, dynamic>) fromJson) async {
    _requiereAdmin();
    final res = await _sendAdmin(() => nuevo
        ? http.post(crear, headers: _headers, body: jsonEncode(body))
        : http.put(editar, headers: _headers, body: jsonEncode(body)));
    _check(res);
    return fromJson(Map<String, dynamic>.from(_decode(res) as Map));
  }

  Future<void> _eliminar(Uri uri, String mensajeSiEnUso) async {
    _requiereAdmin();
    final res = await _sendAdmin(() => http.delete(uri, headers: _headers));
    // Una llave foránea que impide borrar llega como 502 (GlobalExceptionHandler).
    if (res.statusCode >= 500) throw ApiException(mensajeSiEnUso);
    _check(res);
  }

  Future<List<EjercicioGym>> listarEjercicios() async {
    if (_session.modoDemo) return _MockDb.listarDe(_MockDb.ejercicios);
    return _listar(_uri(AppConfig.rutaListarEjercicios), EjercicioGym.fromJson);
  }

  Future<EjercicioGym> guardarEjercicio(EjercicioGym e) async {
    if (_session.modoDemo) {
      return _MockDb.guardar(_MockDb.ejercicios, e, e.id,
          (id) => EjercicioGym(id: id, nombre: e.nombre, descripcion: e.descripcion), (x) => x.id);
    }
    return _guardar(_uri('/ejercicios/agregar'), _uri('/ejercicios/editar/${e.id}'), e.id == null, e.toApiJson(),
        EjercicioGym.fromJson);
  }

  Future<void> eliminarEjercicio(int id) async {
    const msg = 'No se puede eliminar: el ejercicio se usa en alguna rutina.';
    if (_session.modoDemo) {
      if (_MockDb.rutinaEjercicios.any((x) => x.ejercicioId == id)) throw ApiException(msg);
      return _MockDb.eliminar(_MockDb.ejercicios, id, (x) => x.id);
    }
    return _eliminar(_uri('/ejercicios/delete/$id'), msg);
  }

  Future<List<EjercicioMusculo>> listarEjercicioMusculos() async {
    if (_session.modoDemo) return _MockDb.listarDe(_MockDb.ejercicioMusculos);
    return _listar(_uri('/ejercicios/musculos'), EjercicioMusculo.fromJson);
  }

  Future<EjercicioMusculo> guardarEjercicioMusculo(EjercicioMusculo v) async {
    if (_session.modoDemo) {
      return _MockDb.guardar(_MockDb.ejercicioMusculos, v, v.id,
          (id) => EjercicioMusculo(id: id, ejercicioId: v.ejercicioId, musculo: v.musculo, maquina: v.maquina),
          (x) => x.id);
    }
    // La respuesta trae el músculo y la máquina solo con su id; se conservan
    // los objetos completos que ya tenía la app.
    final r = await _guardar(_uri('/ejercicios/musculos/agregar'), _uri('/ejercicios/musculos/editar/${v.id}'),
        v.id == null, v.toApiJson(), EjercicioMusculo.fromJson);
    return EjercicioMusculo(id: r.id, ejercicioId: v.ejercicioId, musculo: v.musculo, maquina: v.maquina);
  }

  Future<void> eliminarEjercicioMusculo(int id) async {
    if (_session.modoDemo) return _MockDb.eliminar(_MockDb.ejercicioMusculos, id, (x) => x.id);
    return _eliminar(_uri('/ejercicios/musculos/delete/$id'), 'No se pudo eliminar el vínculo del ejercicio.');
  }

  Future<List<RutinaGym>> listarRutinasGym() async {
    if (_session.modoDemo) return _MockDb.listarDe(_MockDb.rutinas);
    return _listar(_uri('/rutinas'), RutinaGym.fromJson);
  }

  Future<RutinaGym> guardarRutinaGym(RutinaGym r) async {
    if (_session.modoDemo) {
      return _MockDb.guardar(_MockDb.rutinas, r, r.id,
          (id) => RutinaGym(id: id, diaSemana: r.diaSemana, clienteId: r.clienteId, clienteNombre: r.clienteNombre),
          (x) => x.id);
    }
    return _guardar(_uri('/rutina/agregar'), _uri('/rutina/editar/${r.id}'), r.id == null, r.toApiJson(),
        RutinaGym.fromJson);
  }

  Future<void> eliminarRutinaGym(int id) async {
    if (_session.modoDemo) return _MockDb.eliminar(_MockDb.rutinas, id, (x) => x.id);
    return _eliminar(_uri('/rutina/delete/$id'), 'No se puede eliminar: la rutina todavía tiene ejercicios.');
  }

  Future<List<RutinaEjercicioGym>> listarRutinaEjercicios() async {
    if (_session.modoDemo) return _MockDb.listarDe(_MockDb.rutinaEjercicios);
    return _listar(_uriRutinaEjercicios(''), RutinaEjercicioGym.fromJson);
  }

  Future<RutinaEjercicioGym> guardarRutinaEjercicio(RutinaEjercicioGym x) async {
    if (_session.modoDemo) {
      return _MockDb.guardar(
          _MockDb.rutinaEjercicios,
          x,
          x.id,
          (id) => RutinaEjercicioGym(
              id: id, rutinaId: x.rutinaId, ejercicioId: x.ejercicioId, series: x.series, repeticiones: x.repeticiones),
          (e) => e.id);
    }
    return _guardar(_uriRutinaEjercicios('/agregar'), _uriRutinaEjercicios('/editar/${x.id}'), x.id == null,
        x.toApiJson(), RutinaEjercicioGym.fromJson);
  }

  Future<void> eliminarRutinaEjercicio(int id) async {
    if (_session.modoDemo) return _MockDb.eliminar(_MockDb.rutinaEjercicios, id, (x) => x.id);
    return _eliminar(_uriRutinaEjercicios('/delete/$id'), 'No se pudo quitar el ejercicio de la rutina.');
  }

  Future<void> eliminarMaquina(int id) async {
    if (_session.modoDemo) return _MockDb.eliminarMaquina(id);
    _requiereAdmin();
    final res = await _sendAdmin(() => http.delete(_uri('/maquina/delete/$id'), headers: _headers));
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

  /// Copias de ejercicios de wger que usa el gimnasio (la referencia va en
  /// la descripción, como en el backend real).
  static final List<EjercicioGym> ejercicios = [
    const EjercicioGym(id: 1, nombre: 'Press de Banca', descripcion: 'wger:73'),
    const EjercicioGym(id: 2, nombre: 'Aperturas en máquina', descripcion: 'wger:135'),
    const EjercicioGym(id: 3, nombre: 'Jalón al Pecho con Agarre Cerrado', descripcion: 'wger:158'),
    const EjercicioGym(id: 4, nombre: 'Prensa de piernas', descripcion: 'wger:371'),
    const EjercicioGym(id: 5, nombre: 'Sentadilla con disco', descripcion: 'wger:203'),
    const EjercicioGym(id: 6, nombre: 'Curl de bíceps con mancuerna', descripcion: 'wger:92'),
    const EjercicioGym(id: 7, nombre: 'Abdominales', descripcion: 'wger:167'),
  ];

  static final List<EjercicioMusculo> ejercicioMusculos = [
    EjercicioMusculo(id: 1, ejercicioId: 1, musculo: _musculos[0], maquina: _maquinas[0]),
    EjercicioMusculo(id: 2, ejercicioId: 2, musculo: _musculos[0], maquina: _maquinas[1]),
    EjercicioMusculo(id: 3, ejercicioId: 3, musculo: _musculos[1], maquina: _maquinas[2]),
    EjercicioMusculo(id: 4, ejercicioId: 4, musculo: _musculos[2], maquina: _maquinas[4]),
    EjercicioMusculo(id: 5, ejercicioId: 5, musculo: _musculos[2]),
    EjercicioMusculo(id: 6, ejercicioId: 6, musculo: _musculos[4]),
    EjercicioMusculo(id: 7, ejercicioId: 7, musculo: _musculos[5]),
  ];

  static final List<RutinaGym> rutinas = [
    const RutinaGym(id: 1, diaSemana: 'Lunes,Jueves'),
    const RutinaGym(id: 2, diaSemana: 'Martes,Viernes'),
    const RutinaGym(id: 3, diaSemana: 'Miércoles', clienteId: 1, clienteNombre: 'Eddy Coello'),
  ];

  static final List<RutinaEjercicioGym> rutinaEjercicios = [
    const RutinaEjercicioGym(id: 1, rutinaId: 1, ejercicioId: 1, series: 4, repeticiones: 10),
    const RutinaEjercicioGym(id: 2, rutinaId: 1, ejercicioId: 2, series: 3, repeticiones: 12),
    const RutinaEjercicioGym(id: 3, rutinaId: 1, ejercicioId: 6, series: 3, repeticiones: 12),
    const RutinaEjercicioGym(id: 4, rutinaId: 2, ejercicioId: 4, series: 4, repeticiones: 12),
    const RutinaEjercicioGym(id: 5, rutinaId: 2, ejercicioId: 5, series: 3, repeticiones: 15),
    const RutinaEjercicioGym(id: 6, rutinaId: 2, ejercicioId: 7, series: 3, repeticiones: 20),
    const RutinaEjercicioGym(id: 7, rutinaId: 3, ejercicioId: 3, series: 4, repeticiones: 10),
    const RutinaEjercicioGym(id: 8, rutinaId: 3, ejercicioId: 7, series: 3, repeticiones: 15),
  ];

  static Future<List<T>> listarDe<T>(List<T> lista) async {
    await latencia();
    return List.of(lista);
  }

  static Future<T> guardar<T>(List<T> lista, T item, int? id, T Function(int) conId, int? Function(T) idDe) async {
    await latencia();
    if (id == null) {
      final nuevo = conId(_sigId(lista.map(idDe)));
      lista.add(nuevo);
      return nuevo;
    }
    lista[lista.indexWhere((x) => idDe(x) == id)] = item;
    return item;
  }

  static Future<void> eliminar<T>(List<T> lista, int id, int? Function(T) idDe) async {
    await latencia();
    lista.removeWhere((x) => idDe(x) == id);
  }

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

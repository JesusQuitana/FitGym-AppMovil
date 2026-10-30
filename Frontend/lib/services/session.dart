import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/cliente.dart';

/// Dónde entrena hoy la persona. Se elige en Inicio con un toque y cambia
/// qué rutinas y ejercicios se sugieren; no cierra ni abre sesiones.
enum LugarHoy { gimnasio, casa }

/// Configuración y sesión persistidas en el teléfono. El cliente autenticado
/// se guarda en caché para poder mostrar el QR aun sin cobertura en recepción.
///
/// Los datos sensibles (código de acceso y secreto TOTP) van al almacenamiento
/// cifrado del sistema (Android Keystore); el resto, a shared_preferences.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _kBaseUrl = 'base_url';
  static const _kDemo = 'modo_demo';
  static const _kCliente = 'cliente';
  static const _kRelojOffset = 'reloj_offset_ms';
  static const _kCodigo = 'codigo';
  static const _kTotp = 'totp_secret';
  static const _kBienvenida = 'bienvenida_hecha';
  static const _kLugarHoy = 'lugar_hoy';

  /// Clave de versiones anteriores, que trataban gimnasio y casa como modos.
  static const _kModoAnterior = 'modo_uso';

  /// URL que la app usaba por defecto cuando el backend escuchaba en el 3000.
  static const _urlAnterior = 'http://10.0.2.2:3000';

  late SharedPreferences _prefs;
  final _seguro = const FlutterSecureStorage();

  String baseUrl = AppConfig.defaultBaseUrl;
  bool modoDemo = AppConfig.defaultModoDemo;
  Cliente? cliente;

  /// Secreto Base32 para el QR dinámico. Null si el backend todavía no lo
  /// entrega: en ese caso el pase usa el QR estático (correo + código).
  String? totpSecret;

  /// Diferencia entre el reloj del servidor y el del teléfono, medida al
  /// iniciar sesión. Corrige teléfonos con la hora desfasada.
  Duration relojOffset = Duration.zero;

  /// JWT del administrador de recepción. Solo en memoria: se pide de nuevo
  /// cada vez que se entra al módulo (el backend lo emite por 24 minutos).
  String? adminToken;

  /// Credenciales de recepción solo en memoria, para renovar el token sin
  /// interrumpir. Se borran al salir del módulo (ver cerrarAdmin).
  String? adminUsuario;
  String? adminPassword;
  DateTime? adminTokenDesde;

  void cerrarAdmin() {
    adminToken = null;
    adminUsuario = null;
    adminPassword = null;
    adminTokenDesde = null;
  }

  /// Si ya pasó la bienvenida (vinculó su gimnasio o armó su plan).
  bool bienvenidaHecha = false;

  /// Dónde entrena hoy; se recuerda la última elección.
  LugarHoy lugarHoy = LugarHoy.gimnasio;

  /// Si vinculó un gimnasio con FitGym (inició sesión como afiliado).
  bool get conGimnasio => cliente != null;

  Future<void> marcarBienvenidaHecha() async {
    bienvenidaHecha = true;
    await _prefs.setBool(_kBienvenida, true);
  }

  Future<void> saveLugarHoy(LugarHoy l) async {
    lugarHoy = l;
    await _prefs.setString(_kLugarHoy, l.name);
  }

  /// Hora corregida con la del servidor; es la que se usa para el TOTP.
  DateTime get ahora => DateTime.now().add(relojOffset);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = _prefs.getString(_kBaseUrl) ?? AppConfig.defaultBaseUrl;
    // El backend pasó del puerto 3000 al 8080: se actualiza la URL por defecto guardada.
    if (baseUrl == _urlAnterior) baseUrl = AppConfig.defaultBaseUrl;
    // Quien ya eligió un modo en versiones anteriores no ve la bienvenida otra vez.
    bienvenidaHecha = _prefs.getBool(_kBienvenida) ?? _prefs.containsKey(_kModoAnterior);
    lugarHoy = LugarHoy.values.where((l) => l.name == _prefs.getString(_kLugarHoy)).firstOrNull ??
        (_prefs.getString(_kModoAnterior) == 'personal' ? LugarHoy.casa : LugarHoy.gimnasio);
    // Se parte de cero: lo que no esté guardado no debe quedar de antes.
    cliente = null;
    totpSecret = null;
    modoDemo = _prefs.getBool(_kDemo) ?? AppConfig.defaultModoDemo;
    relojOffset = Duration(milliseconds: _prefs.getInt(_kRelojOffset) ?? 0);
    final raw = _prefs.getString(_kCliente);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final codigo = await _leerSeguro(_kCodigo) ?? '${json['codigo'] ?? ''}';
      cliente = Cliente.fromJson(json).copyWith(codigo: codigo);
      totpSecret = await _leerSeguro(_kTotp);
    } catch (_) {
      cliente = null;
    }
  }

  Future<void> saveSettings({required String baseUrl, required bool modoDemo}) async {
    this.baseUrl = baseUrl;
    this.modoDemo = modoDemo;
    await _prefs.setString(_kBaseUrl, baseUrl);
    await _prefs.setBool(_kDemo, modoDemo);
  }

  /// Guarda la sesión del afiliado. [totpSecret] y [relojOffset] solo se
  /// reciben al iniciar sesión; en los refrescos se conservan los actuales.
  Future<void> saveCliente(Cliente c, {String? totpSecret, Duration? relojOffset}) async {
    cliente = c;
    await _prefs.setString(_kCliente, jsonEncode(c.toApiJson()));
    await _escribirSeguro(_kCodigo, c.codigo);
    if (totpSecret != null) {
      this.totpSecret = totpSecret;
      await _escribirSeguro(_kTotp, totpSecret);
    }
    if (relojOffset != null) {
      this.relojOffset = relojOffset;
      await _prefs.setInt(_kRelojOffset, relojOffset.inMilliseconds);
    }
  }

  Future<void> logout() async {
    cliente = null;
    totpSecret = null;
    await _prefs.remove(_kCliente);
    await _borrarSeguro(_kCodigo);
    await _borrarSeguro(_kTotp);
  }

  Future<String?> _leerSeguro(String key) async {
    try {
      return await _seguro.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _escribirSeguro(String key, String valor) async {
    try {
      await _seguro.write(key: key, value: valor);
    } catch (_) {}
  }

  Future<void> _borrarSeguro(String key) async {
    try {
      await _seguro.delete(key: key);
    } catch (_) {}
  }
}

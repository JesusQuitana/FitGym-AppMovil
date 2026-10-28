import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/cliente.dart';

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

  /// Hora corregida con la del servidor; es la que se usa para el TOTP.
  DateTime get ahora => DateTime.now().add(relojOffset);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = _prefs.getString(_kBaseUrl) ?? AppConfig.defaultBaseUrl;
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

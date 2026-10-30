import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rutina.dart';

/// Rutinas propias del usuario, guardadas en el teléfono.
///
/// Hay un solo espacio de rutinas propias ([propias]), entrene la persona en
/// el gimnasio o en casa. Las rutinas del gimnasio no se guardan aquí: vienen
/// del backend (ver GymRutinas).
class RutinasStore {
  RutinasStore._();

  /// Espacio único de rutinas propias e historial (la clave 'personal' se
  /// conserva para no perder datos de versiones anteriores).
  static const propias = 'personal';
  static const personal = propias;

  /// Versiones anteriores guardaban aparte las rutinas e historial de cada
  /// afiliado ('rutinas_<id>', 'historial_<id>'). Se fusionan en el espacio
  /// único, sin duplicar, y se borran las claves viejas.
  static Future<void> unificarEspacios() async {
    final prefs = await SharedPreferences.getInstance();
    final viejas = prefs.getKeys().where((k) => RegExp(r'^(rutinas|historial)_\d+$').hasMatch(k)).toList();
    for (final clave in viejas) {
      final tipo = clave.split('_').first;
      final destino = '${tipo}_$propias';
      try {
        final actuales = (jsonDecode(prefs.getString(destino) ?? '[]') as List).cast<Map>();
        final extra = (jsonDecode(prefs.getString(clave) ?? '[]') as List).cast<Map>();
        String firma(Map m) => tipo == 'rutinas' ? '${m['id']}' : '${m['fecha']}|${m['rutinaId']}';
        final vistos = actuales.map(firma).toSet();
        final unidos = [...actuales, ...extra.where((m) => !vistos.contains(firma(m)))];
        if (tipo == 'historial') unidos.sort((a, b) => '${a['fecha']}'.compareTo('${b['fecha']}'));
        await prefs.setString(destino, jsonEncode(unidos));
      } catch (_) {
        continue; // datos ilegibles: se dejan como están
      }
      await prefs.remove(clave);
    }
  }

  static String _key(String espacio) => 'rutinas_$espacio';

  static Future<List<Rutina>> cargar(String espacio) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(espacio));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Rutina.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardar(String espacio, List<Rutina> rutinas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(espacio), jsonEncode(rutinas.map((r) => r.toJson()).toList()));
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rutina.dart';

/// Rutinas del afiliado guardadas en el teléfono.
///
/// El backend todavía no tiene entidad de rutinas (solo máquinas y grupos
/// musculares). Cuando exista, basta con cambiar esta clase para que lea y
/// escriba en la API; las pantallas no cambian. Ver docs/BACKEND.md.
class RutinasStore {
  RutinasStore._();

  static String _key(int clienteId) => 'rutinas_$clienteId';

  static Future<List<Rutina>> cargar(int clienteId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(clienteId));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Rutina.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardar(int clienteId, List<Rutina> rutinas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(clienteId), jsonEncode(rutinas.map((r) => r.toJson()).toList()));
  }
}

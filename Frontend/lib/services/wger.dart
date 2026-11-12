import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ejercicio_wger.dart';

/// Catálogo central de ejercicios (wger.de). Solo ejercicios con traducción
/// al español y con al menos una imagen o un video.
///
/// Orden de carga: copia descargada guardada en el teléfono → copia incluida
/// en la app (assets/wger/catalogo.json). Así funciona sin conexión desde el
/// primer uso. En segundo plano, como máximo una vez por semana, se descarga
/// la versión actual de la API de wger con el mismo filtro.
class Wger {
  Wger._();

  static const _api = 'https://wger.de/api/v2/exerciseinfo/?format=json&limit=200';
  static const _asset = 'assets/wger/catalogo.json';
  static const _kCatalogo = 'wger_catalogo_v2';
  static const _kFecha = 'wger_catalogo_fecha_v2';
  static const _vigencia = Duration(days: 7);
  static const _idEspanol = 4;
  static const _idIngles = 2;

  /// Categorías de wger → grupos musculares de la app.
  static const _categorias = {
    'Abs': 'Abdomen',
    'Arms': 'Brazos',
    'Back': 'Espalda',
    'Calves': 'Piernas',
    'Cardio': 'Cardio',
    'Chest': 'Pecho',
    'Legs': 'Piernas',
    'Shoulders': 'Hombros',
  };

  static const credito = 'Textos e imágenes: wger.de · ExerciseDB · CC-BY-SA';

  static List<EjercicioWger>? _catalogo;
  static Map<int, EjercicioWger> _porId = {};

  static Future<List<EjercicioWger>> catalogo() async {
    if (_catalogo != null) return _catalogo!;
    final base = _parsear(await rootBundle.loadString(_asset));
    String? guardado;
    try {
      guardado = (await SharedPreferences.getInstance()).getString(_kCatalogo);
    } catch (_) {}
    if (guardado != null) {
      _usar(_combinarConBase(_parsear(guardado), base));
    } else {
      _usar(base);
    }
    unawaited(_actualizarSiHaceFalta(base));
    return _catalogo!;
  }

  /// Conserva las animaciones de ExerciseDB y fotos paso a paso incluidas en
  /// el catálogo base de la app cuando wger se sincroniza en segundo plano.
  static List<EjercicioWger> _combinarConBase(
    List<EjercicioWger> descargados,
    List<EjercicioWger> base,
  ) {
    final basePorId = {for (final e in base) e.id: e};
    final vistos = <int>{};
    final resultado = <EjercicioWger>[];

    for (final d in descargados) {
      vistos.add(d.id);
      final b = basePorId[d.id];
      if (b == null) {
        resultado.add(d);
        continue;
      }
      final imagenesCombinadas = <String>[
        ...b.imagenes,
        for (final img in d.imagenes)
          if (!b.imagenes.contains(img)) img,
      ];
      final videosCombinados = <String>[
        ...b.videos,
        for (final vid in d.videos)
          if (!b.videos.contains(vid) && !vid.toLowerCase().endsWith('.mov')) vid,
      ];
      resultado.add(EjercicioWger(
        id: d.id,
        nombre: b.nombre.isNotEmpty ? b.nombre : d.nombre,
        nombreEn: b.nombreEn.isNotEmpty ? b.nombreEn : d.nombreEn,
        descripcion: b.descripcion.isNotEmpty ? b.descripcion : d.descripcion,
        musculo: b.musculo.isNotEmpty ? b.musculo : d.musculo,
        equipos: b.equipos.isNotEmpty ? b.equipos : d.equipos,
        imagenes: imagenesCombinadas,
        videos: videosCombinados,
        autorImagen: b.autorImagen.isNotEmpty ? b.autorImagen : d.autorImagen,
      ));
    }

    for (final b in base) {
      if (!vistos.contains(b.id)) {
        resultado.add(b);
      }
    }
    return resultado;
  }

  static Future<EjercicioWger?> porId(int id) async {
    await catalogo();
    return _porId[id];
  }

  /// Busca por nombre (para datos antiguos sin id de wger).
  static Future<EjercicioWger?> porNombre(String nombre) async {
    final n = nombre.trim().toLowerCase();
    return (await catalogo()).where((e) => e.nombre.toLowerCase() == n).firstOrNull;
  }

  static void _usar(List<EjercicioWger> lista) {
    _catalogo = lista..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    _porId = {for (final e in lista) e.id: e};
  }

  static List<EjercicioWger> _parsear(String json) =>
      (jsonDecode(json) as List).map((e) => EjercicioWger.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  static Future<void> _actualizarSiHaceFalta(List<EjercicioWger> base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fecha = DateTime.tryParse(prefs.getString(_kFecha) ?? '');
      if (fecha != null && DateTime.now().difference(fecha) < _vigencia) return;
      final nuevos = await descargar();
      if (nuevos.length < 50) return; // respuesta incompleta: se conserva la copia actual
      final combinados = _combinarConBase(nuevos, base);
      await prefs.setString(_kCatalogo, jsonEncode(combinados.map((e) => e.toJson()).toList()));
      await prefs.setString(_kFecha, DateTime.now().toIso8601String());
      _usar(combinados);
    } catch (e) {
      debugPrint('No se pudo actualizar el catálogo de wger: $e');
    }
  }

  /// Descarga todo wger y aplica el filtro: español + imagen o video.
  static Future<List<EjercicioWger>> descargar() async {
    final salida = <EjercicioWger>[];
    String? url = _api;
    while (url != null) {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('wger respondió ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      for (final raw in data['results'] as List) {
        final e = convertir(Map<String, dynamic>.from(raw as Map));
        if (e != null) salida.add(e);
      }
      url = data['next'] as String?;
    }
    return salida;
  }

  /// Convierte un registro de /exerciseinfo; null si no cumple el filtro.
  static EjercicioWger? convertir(Map<String, dynamic> j) {
    final traducciones = [for (final t in j['translations'] as List) Map<String, dynamic>.from(t as Map)];
    final es = traducciones.where((t) => t['language'] == _idEspanol).firstOrNull;
    final en = traducciones.where((t) => t['language'] == _idIngles).firstOrNull;
    final imagenes = [for (final i in j['images'] as List) Map<String, dynamic>.from(i as Map)]
      ..sort((a, b) => (b['is_main'] == true ? 1 : 0) - (a['is_main'] == true ? 1 : 0));
    final videos = [for (final v in j['videos'] as List) '${(v as Map)['video']}'];
    if (es == null || (imagenes.isEmpty && videos.isEmpty)) return null;
    final categoria = '${(j['category'] as Map)['name']}';
    return EjercicioWger(
      id: (j['id'] as num).toInt(),
      nombre: '${es['name']}'.trim(),
      nombreEn: '${en?['name'] ?? ''}'.trim(),
      descripcion: textoPlano('${es['description'] ?? ''}'),
      musculo: _categorias[categoria] ?? categoria,
      equipos: [for (final q in j['equipment'] as List) '${(q as Map)['name']}'],
      imagenes: [for (final i in imagenes) '${i['image']}'],
      videos: videos,
      autorImagen: imagenes.isEmpty ? '' : '${imagenes.first['license_author'] ?? ''}',
    );
  }

  /// El HTML de las descripciones de wger, como texto con saltos de párrafo.
  static String textoPlano(String html) {
    var t = html
        .replaceAll(RegExp(r'</(p|li|ol|ul|h\d)>|<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    const entidades = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'"};
    entidades.forEach((k, v) => t = t.replaceAll(k, v));
    return t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n');
  }
}

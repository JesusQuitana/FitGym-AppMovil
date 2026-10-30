import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ejercicio_wger.dart';
import '../models/maquina.dart';
import '../models/rutina.dart';
import '../models/rutina_gym.dart';
import 'api_service.dart';
import 'wger.dart';

/// Une las tablas `rutina`, `rutina_ejercicio`, `ejercicios` y
/// `ejercicio_musculo` del backend con el catálogo de wger.
///
/// - Los ejercicios salen siempre de wger. La tabla `ejercicios` guarda una
///   copia de los que usa el gimnasio, con la referencia en `descripcion`
///   ("wger:73") porque el backend no tiene un campo para el id de wger.
/// - `ejercicio_musculo` indica su grupo muscular y, si aplica, en qué
///   máquina de este gimnasio se hace.
/// - El backend no tiene nombre de rutina: se muestra a partir de los
///   músculos ("Pecho · Brazos"). Sin cliente es general; con cliente, asignada.
class GymRutinas {
  GymRutinas._();

  static ApiService get _api => ApiService.instance;

  static const _prefijo = 'wger:';

  /// Id de wger guardado en la descripción de un ejercicio del backend.
  static int? wgerIdDe(EjercicioGym e) {
    final d = e.descripcion.trim();
    return d.startsWith(_prefijo) ? int.tryParse(d.substring(_prefijo.length).trim()) : null;
  }

  /// Catálogo para armar rutinas: los ejercicios de wger.
  static Future<List<OpcionEjercicio>> catalogo() async =>
      (await Wger.catalogo()).map(OpcionEjercicio.deWger).toList();

  /// Rutinas que ve un afiliado: las generales y las asignadas a él.
  static Future<List<Rutina>> paraCliente(int? clienteId) async {
    final todas = await paraAdmin();
    return [
      for (final (r, ejercicios, _) in todas)
        if (r.esGeneral || r.clienteId == clienteId) _aRutina(r, ejercicios),
    ];
  }

  /// Como [paraCliente], pero si no hay conexión devuelve la última copia
  /// guardada en el teléfono (el segundo valor indica que viene de la copia).
  static Future<(List<Rutina>, bool)> paraClienteConCache(int? clienteId) async {
    final key = 'cache_rutinas_gym_$clienteId';
    final prefs = await SharedPreferences.getInstance();
    try {
      final rutinas = await paraCliente(clienteId);
      await prefs.setString(key, jsonEncode(rutinas.map((r) => r.toJson()).toList()));
      return (rutinas, false);
    } catch (e) {
      final raw = prefs.getString(key);
      if (raw == null) rethrow;
      final copia = (jsonDecode(raw) as List).map((x) => Rutina.fromJson(Map<String, dynamic>.from(x as Map))).toList();
      return (copia, true);
    }
  }

  /// Todas las rutinas del backend con sus ejercicios (para recepción).
  static Future<List<(RutinaGym, List<EjercicioRutina>, List<RutinaEjercicioGym>)>> paraAdmin() async {
    final r = await Future.wait([
      _api.listarRutinasGym(),
      _api.listarRutinaEjercicios(),
      _api.listarEjercicios(),
      _api.listarEjercicioMusculos(),
      Wger.catalogo(),
    ]);
    final rutinas = r[0] as List<RutinaGym>;
    final filas = r[1] as List<RutinaEjercicioGym>;
    final porId = {for (final e in r[2] as List<EjercicioGym>) e.id: e};
    final vinculos = r[3] as List<EjercicioMusculo>;
    final wger = {for (final e in r[4] as List<EjercicioWger>) e.id: e};
    return [
      for (final rutina in rutinas)
        () {
          final propias = filas.where((f) => f.rutinaId == rutina.id).toList()
            ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
          final ejercicios = [
            for (final f in propias)
              if (porId[f.ejercicioId] != null)
                EjercicioRutina.deOpcion(
                  _opcion(porId[f.ejercicioId]!, _vinculo(vinculos, f.ejercicioId), wger),
                  series: f.series,
                  repeticiones: f.repeticiones,
                ),
          ];
          return (rutina, ejercicios, propias);
        }(),
    ];
  }

  /// Guarda una rutina y sincroniza sus ejercicios: crea los nuevos, edita
  /// los que cambiaron y borra los que se quitaron. Los ejercicios de wger
  /// que el gimnasio aún no tenía se copian a la tabla `ejercicios`.
  static Future<void> guardar(RutinaGym rutina, List<EjercicioRutina> ejercicios, List<RutinaEjercicioGym> anteriores) async {
    final guardada = await _api.guardarRutinaGym(rutina);
    final copias = await _api.listarEjercicios();
    final vinculos = await _api.listarEjercicioMusculos();
    final musculos = await _api.listarMusculos();
    final maquinas = await _api.listarMaquinas();
    final restantes = [...anteriores];
    for (final e in ejercicios) {
      final ejercicioId = await _asegurarEjercicio(e, copias, vinculos, musculos, maquinas);
      if (ejercicioId == null) continue;
      final previa = restantes.where((f) => f.ejercicioId == ejercicioId).firstOrNull;
      if (previa != null) restantes.remove(previa);
      if (previa == null || previa.series != e.series || previa.repeticiones != e.repeticiones) {
        await _api.guardarRutinaEjercicio(RutinaEjercicioGym(
          id: previa?.id,
          rutinaId: guardada.id,
          ejercicioId: ejercicioId,
          series: e.series,
          repeticiones: e.repeticiones,
        ));
      }
    }
    for (final f in restantes) {
      await _api.eliminarRutinaEjercicio(f.id!);
    }
  }

  /// Borra primero los ejercicios de la rutina (llave foránea) y luego la rutina.
  static Future<void> eliminar(int rutinaId, List<RutinaEjercicioGym> filas) async {
    for (final f in filas) {
      await _api.eliminarRutinaEjercicio(f.id!);
    }
    await _api.eliminarRutinaGym(rutinaId);
  }

  /// Devuelve el id en la tabla `ejercicios` del ejercicio de wger, creándolo
  /// si hace falta, y deja su vínculo con el músculo y la máquina al día.
  static Future<int?> _asegurarEjercicio(
    EjercicioRutina e,
    List<EjercicioGym> copias,
    List<EjercicioMusculo> vinculos,
    List<Musculo> musculos,
    List<Maquina> maquinas,
  ) async {
    final wgerId = e.wgerId;
    if (wgerId == null) return e.ejercicioId; // dato anterior a wger
    var copia = copias.where((c) => wgerIdDe(c) == wgerId).firstOrNull;
    if (copia == null) {
      copia = await _api.guardarEjercicio(EjercicioGym(nombre: e.nombre, descripcion: '$_prefijo$wgerId'));
      copias.add(copia);
    }
    final musculo = await _asegurarMusculo(e.musculo, musculos);
    final maquina = maquinas.where((m) => m.id == e.maquinaId).firstOrNull;
    final vinculo = vinculos.where((v) => v.ejercicioId == copia!.id).firstOrNull;
    if (vinculo == null || vinculo.musculo?.id != musculo?.id || vinculo.maquina?.id != maquina?.id) {
      final nuevo = await _api.guardarEjercicioMusculo(
        EjercicioMusculo(id: vinculo?.id, ejercicioId: copia.id, musculo: musculo, maquina: maquina),
      );
      vinculos
        ..remove(vinculo)
        ..add(nuevo);
    }
    return copia.id;
  }

  /// Grupos musculares de la app (categorías de wger).
  static const musculosBase = ['Abdomen', 'Brazos', 'Cardio', 'Espalda', 'Hombros', 'Pecho', 'Piernas'];

  /// Crea en el backend los grupos musculares base que falten (para
  /// clasificar las máquinas sin administrarlos a mano).
  static Future<List<Musculo>> asegurarMusculosBase() async {
    final musculos = await _api.listarMusculos();
    for (final nombre in musculosBase) {
      await _asegurarMusculo(nombre, musculos);
    }
    return musculos;
  }

  /// Los grupos musculares son las categorías de wger; se crean solos.
  static Future<Musculo?> _asegurarMusculo(String nombre, List<Musculo> musculos) async {
    if (nombre.isEmpty) return null;
    final existente = musculos.where((m) => m.nombre.toLowerCase() == nombre.toLowerCase()).firstOrNull;
    if (existente != null) return existente;
    final nuevo = await _api.guardarMusculo(Musculo(nombre: nombre));
    musculos.add(nuevo);
    return nuevo;
  }

  static Rutina _aRutina(RutinaGym r, List<EjercicioRutina> ejercicios) {
    final musculos = ejercicios.map((e) => e.musculo).where((m) => m.isNotEmpty).toSet().take(3).toList();
    return Rutina(
      id: 'gym-${r.id}',
      nombre: musculos.isEmpty ? 'Rutina del gimnasio' : musculos.join(' · '),
      dias: Rutina.parseDias(r.diaSemana),
      ejercicios: ejercicios,
      origen: r.esGeneral ? OrigenRutina.gimnasioGeneral : OrigenRutina.gimnasioAsignada,
    );
  }

  static EjercicioMusculo? _vinculo(List<EjercicioMusculo> vinculos, int? ejercicioId) =>
      vinculos.where((v) => v.ejercicioId == ejercicioId).firstOrNull;

  /// Ejercicio del backend con los datos de wger (nombre en español, imagen)
  /// y la máquina del gimnasio donde se hace.
  static OpcionEjercicio _opcion(EjercicioGym e, EjercicioMusculo? v, Map<int, EjercicioWger> wger) {
    final w = wger[wgerIdDe(e)];
    return OpcionEjercicio(
      nombre: w?.nombre ?? e.nombre,
      musculo: w?.musculo ?? v?.musculo?.nombre ?? '',
      detalle: v?.maquina?.nombre ?? w?.equipoTexto ?? '',
      descripcion: w?.descripcion ?? '',
      ejercicioId: e.id,
      maquinaId: v?.maquina?.id,
      wgerId: w?.id,
      imagen: w?.imagen,
      porTiempo: w?.porTiempo ?? false,
    );
  }
}

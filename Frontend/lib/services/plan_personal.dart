import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/plantillas.dart';
import '../models/ejercicio_wger.dart';
import '../models/rutina.dart';
import 'session.dart';

/// Dónde entrena quien no tiene gimnasio con FitGym.
enum Lugar {
  casaSinEquipo('En casa, sin equipo', {Equipo.corporal}),
  casaMancuernas('En casa, con mancuernas', {Equipo.corporal, Equipo.mancuernas}),
  gimnasio('En un gimnasio', {Equipo.corporal, Equipo.mancuernas, Equipo.gimnasio});

  const Lugar(this.etiqueta, this.equipos);
  final String etiqueta;
  final Set<Equipo> equipos;
}

/// Respuestas del asistente.
class PerfilEntrenamiento {
  const PerfilEntrenamiento({
    required this.objetivo,
    required this.nivel,
    required this.dias,
    required this.minutos,
    required this.lugar,
    required this.lesiones,
  });

  final Objetivo objetivo;
  final Nivel nivel;

  /// Días por semana (2 a 6).
  final int dias;

  /// Duración de cada sesión: 30, 45 o 60.
  final int minutos;
  final Lugar lugar;
  final Set<Lesion> lesiones;

  factory PerfilEntrenamiento.fromJson(Map<String, dynamic> j) => PerfilEntrenamiento(
        objetivo: Objetivo.values.byName(j['objetivo'] as String),
        nivel: Nivel.values.byName(j['nivel'] as String),
        dias: (j['dias'] as num).toInt(),
        minutos: (j['minutos'] as num).toInt(),
        lugar: Lugar.values.byName(j['lugar'] as String),
        lesiones: ((j['lesiones'] as List?) ?? []).map((l) => Lesion.values.byName(l as String)).toSet(),
      );

  Map<String, dynamic> toJson() => {
        'objetivo': objetivo.name,
        'nivel': nivel.name,
        'dias': dias,
        'minutos': minutos,
        'lugar': lugar.name,
        'lesiones': lesiones.map((l) => l.name).toList(),
      };
}

/// Recomienda plantillas según el perfil y las convierte en rutinas.
class PlanPersonal {
  PlanPersonal._();

  static const _kPerfil = 'perfil_entrenamiento';

  static Future<PerfilEntrenamiento?> cargarPerfil() async {
    final raw = (await SharedPreferences.getInstance()).getString(_kPerfil);
    if (raw == null) return null;
    try {
      return PerfilEntrenamiento.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardarPerfil(PerfilEntrenamiento p) async =>
      (await SharedPreferences.getInstance()).setString(_kPerfil, jsonEncode(p.toJson()));

  /// Las plantillas que encajan con los días elegidos, de mejor a peor.
  static List<Plantilla> recomendar(PerfilEntrenamiento p, {int maximo = 3}) {
    int puntaje(Plantilla t) {
      var s = 0;
      if (t.objetivos.first == p.objetivo) {
        s += 4;
      } else if (t.objetivos.contains(p.objetivo)) {
        s += 2;
      }
      if (t.niveles.contains(p.nivel)) s += 2;
      // Las divisiones por grupos necesitan equipo para tener variedad.
      if (p.lugar == Lugar.casaSinEquipo && (t.id == 'ppl' || t.id == 'torso_pierna')) s -= 2;
      return s;
    }

    final aptas = plantillas.where((t) => p.dias >= t.diasMin && p.dias <= t.diasMax).toList()
      ..sort((a, b) => puntaje(b).compareTo(puntaje(a)));
    // Full body siempre funciona como respaldo.
    if (aptas.isEmpty) aptas.add(plantillas.firstWhere((t) => t.id == 'full_body'));
    return aptas.take(maximo).toList();
  }

  /// Días de la semana sugeridos según cuántos días entrena.
  static List<int> diasSugeridos(int n) => switch (n) {
        <= 2 => [2, 4],
        3 => [1, 3, 5],
        4 => [1, 2, 4, 5],
        5 => [1, 2, 3, 4, 5],
        _ => [1, 2, 3, 4, 5, 6],
      };

  /// Series y repeticiones (o segundos) según objetivo y nivel.
  static (int series, int reps, int segundos) volumen(PerfilEntrenamiento p) {
    final (series, reps, segundos) = switch (p.objetivo) {
      Objetivo.perderGrasa => (3, 15, 40),
      Objetivo.ganarMasa => (4, 10, 30),
      Objetivo.tonificar => (3, 12, 30),
      Objetivo.resistencia => (3, 20, 60),
      Objetivo.salud => (2, 12, 30),
    };
    final ajuste = switch (p.nivel) { Nivel.principiante => -1, Nivel.intermedio => 0, Nivel.avanzado => 1 };
    return ((series + ajuste).clamp(2, 5), reps, segundos);
  }

  /// Ejercicios por sesión según la duración.
  static int ejerciciosPorSesion(int minutos) => minutos <= 30 ? 4 : (minutos <= 45 ? 5 : 6);

  static bool permitido(EjercicioWger e, PerfilEntrenamiento p) =>
      p.lugar.equipos.contains(e.equipo) && e.evitarCon.intersection(p.lesiones).isEmpty;

  /// Catálogo de wger filtrado por el equipo y las molestias del perfil.
  static List<EjercicioWger> catalogoPara(PerfilEntrenamiento? p, List<EjercicioWger> todos) =>
      p == null ? todos : todos.where((e) => permitido(e, p)).toList();

  static OpcionEjercicio opcion(EjercicioWger e) => OpcionEjercicio.deWger(e);

  /// Equipo disponible según dónde entrena hoy: en el gimnasio, todo; en
  /// casa, el de su perfil (si su perfil es "gimnasio" o no tiene, sin equipo).
  static Set<Equipo> equipoHoy(PerfilEntrenamiento? p, LugarHoy hoy) {
    if (hoy == LugarHoy.gimnasio) return Lugar.gimnasio.equipos;
    final casa = p?.lugar;
    return (casa == null || casa == Lugar.gimnasio ? Lugar.casaSinEquipo : casa).equipos;
  }

  /// Ejercicios que puede hacer hoy: según el equipo del lugar y sus molestias.
  static List<EjercicioWger> aptosHoy(PerfilEntrenamiento? p, LugarHoy hoy, List<EjercicioWger> todos) {
    final equipo = equipoHoy(p, hoy);
    final lesiones = p?.lesiones ?? const <Lesion>{};
    return todos.where((e) => equipo.contains(e.equipo) && e.evitarCon.intersection(lesiones).isEmpty).toList();
  }

  /// Si una rutina necesita equipo de gimnasio (máquinas, barras, poleas).
  static bool necesitaGimnasio(Rutina r, Map<int, EjercicioWger> wger) =>
      r.esDelGimnasio ||
      r.ejercicios.any((e) => e.maquinaId != null || wger[e.wgerId]?.equipo == Equipo.gimnasio);

  /// Convierte una plantilla en rutinas: reparte los días entre los bloques y
  /// elige para cada músculo el ejercicio que permite el perfil, evitando
  /// repetir dentro de la misma sesión.
  static List<Rutina> generar(Plantilla t, PerfilEntrenamiento p, List<EjercicioWger> catalogo) {
    final dias = diasSugeridos(p.dias);
    final (series, reps, segundos) = volumen(p);
    final cantidad = ejerciciosPorSesion(p.minutos);
    // Con más equipo disponible se prefieren los ejercicios con carga.
    final preferencia = [Equipo.gimnasio, Equipo.mancuernas, Equipo.corporal];
    final base = DateTime.now().microsecondsSinceEpoch;

    final rutinas = <Rutina>[];
    for (var b = 0; b < t.bloques.length; b++) {
      final diasBloque = {for (var i = 0; i < dias.length; i++) if (i % t.bloques.length == b) dias[i]};
      if (diasBloque.isEmpty) continue;
      final bloque = t.bloques[b];
      final usados = <String>{};
      final ejercicios = <EjercicioRutina>[];
      for (final musculo in bloque.musculos) {
        if (ejercicios.length >= cantidad) break;
        // Primero los que tienen imagen; entre ellos, los que usan más equipo.
        final candidatos = catalogo
            .where((e) => e.musculo == musculo && permitido(e, p) && !usados.contains(e.nombre))
            .toList()
          ..sort((x, y) {
            final img = (x.imagen == null ? 1 : 0).compareTo(y.imagen == null ? 1 : 0);
            return img != 0 ? img : preferencia.indexOf(x.equipo).compareTo(preferencia.indexOf(y.equipo));
          });
        if (candidatos.isEmpty) continue;
        // Rota la elección entre bloques para que A y B no sean idénticos.
        final e = candidatos[b % candidatos.length];
        usados.add(e.nombre);
        ejercicios.add(EjercicioRutina.deOpcion(opcion(e), series: series, repeticiones: e.porTiempo ? segundos : reps));
      }
      if (ejercicios.isEmpty) continue;
      rutinas.add(Rutina(id: '${base + b}', nombre: bloque.nombre, dias: diasBloque, ejercicios: ejercicios));
    }
    return rutinas;
  }
}

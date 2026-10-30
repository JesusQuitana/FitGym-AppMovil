import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/rutina.dart';
import '../models/sesion.dart';

/// Historial de entrenamientos, guardado en el teléfono (el backend no tiene
/// dónde guardarlo). [espacio] es el mismo de RutinasStore: id del cliente o
/// 'personal'.
class Historial {
  Historial._();

  /// Se conservan las últimas sesiones; suficiente para años de uso normal.
  static const maximo = 500;

  static String _key(String espacio) => 'historial_$espacio';

  static Future<List<SesionEntrenamiento>> cargar(String espacio) async {
    final raw = (await SharedPreferences.getInstance()).getString(_key(espacio));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => SesionEntrenamiento.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> agregar(String espacio, SesionEntrenamiento s) async {
    final lista = [...await cargar(espacio), s]..sort((a, b) => a.fecha.compareTo(b.fecha));
    final recortada = lista.length > maximo ? lista.sublist(lista.length - maximo) : lista;
    await (await SharedPreferences.getInstance())
        .setString(_key(espacio), jsonEncode(recortada.map((x) => x.toJson()).toList()));
  }

  /// Último peso usado en cada ejercicio (por nombre).
  static Map<String, double> ultimosPesos(List<SesionEntrenamiento> sesiones) {
    final pesos = <String, double>{};
    for (final s in sesiones) {
      for (final e in s.ejercicios) {
        if (e.pesoKg != null) pesos[e.nombre] = e.pesoKg!;
      }
    }
    return pesos;
  }

  /// Lunes (00:00) de la semana de [d].
  static DateTime inicioSemana(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

  /// Semanas seguidas con al menos un entrenamiento, contando hacia atrás
  /// desde esta semana (si esta semana aún no hay, empieza por la anterior).
  static int rachaSemanas(List<SesionEntrenamiento> sesiones, {DateTime? hoy}) {
    final semanas = sesiones.map((s) => inicioSemana(s.fecha)).toSet();
    var semana = inicioSemana(hoy ?? DateTime.now());
    if (!semanas.contains(semana)) semana = DateTime(semana.year, semana.month, semana.day - 7);
    var racha = 0;
    while (semanas.contains(semana)) {
      racha++;
      semana = DateTime(semana.year, semana.month, semana.day - 7);
    }
    return racha;
  }

  /// Entrenamientos por semana de las últimas [n] semanas (la última es la actual).
  static List<(DateTime, int)> porSemana(List<SesionEntrenamiento> sesiones, {int n = 8, DateTime? hoy}) {
    final actual = inicioSemana(hoy ?? DateTime.now());
    return [
      for (var i = n - 1; i >= 0; i--)
        () {
          final semana = DateTime(actual.year, actual.month, actual.day - 7 * i);
          return (semana, sesiones.where((s) => inicioSemana(s.fecha) == semana).length);
        }(),
    ];
  }

  /// Peso máximo usado en un ejercicio en cada sesión, en orden.
  static List<(DateTime, double)> evolucionPeso(List<SesionEntrenamiento> sesiones, String ejercicio) => [
        for (final s in sesiones)
          for (final e in s.ejercicios.where((e) => e.nombre == ejercicio && e.pesoKg != null && e.seriesHechas > 0))
            (s.fecha, e.pesoKg!),
      ];

  /// Ejercicios con al menos dos registros de peso (los que tienen evolución).
  static List<String> ejerciciosConPeso(List<SesionEntrenamiento> sesiones) {
    final conteo = <String, int>{};
    for (final s in sesiones) {
      for (final e in s.ejercicios) {
        if (e.pesoKg != null && e.seriesHechas > 0) conteo[e.nombre] = (conteo[e.nombre] ?? 0) + 1;
      }
    }
    return conteo.entries.where((e) => e.value >= 2).map((e) => e.key).toList()..sort();
  }

  /// Sugerencias de progresión: si un ejercicio se completó entero en esta
  /// sesión y en la anterior de la misma rutina, propone subir la carga.
  static List<Sugerencia> sugerencias(SesionEntrenamiento actual, List<SesionEntrenamiento> anteriores) {
    final previa = anteriores.where((s) => s.rutinaId == actual.rutinaId).lastOrNull;
    if (previa == null) return [];
    final resultado = <Sugerencia>[];
    for (final e in actual.ejercicios.where((e) => e.completo)) {
      final antes = previa.ejercicios.where((x) => x.nombre == e.nombre).firstOrNull;
      if (antes == null || !antes.completo) continue;
      if (e.porTiempo) {
        resultado.add(Sugerencia(e.nombre, 'Sube a ${e.repeticiones + 10} s', repeticiones: e.repeticiones + 10));
      } else if (e.pesoKg != null && e.pesoKg! > 0) {
        final nuevo = e.pesoKg! + (e.pesoKg! < 20 ? 1 : 2.5);
        resultado.add(Sugerencia(e.nombre, 'Sube a ${_kg(nuevo)} kg', pesoKg: nuevo));
      } else if (e.repeticiones < 20) {
        resultado.add(Sugerencia(e.nombre, 'Sube a ${e.repeticiones + 2} repeticiones', repeticiones: e.repeticiones + 2));
      }
    }
    return resultado;
  }

  /// Aplica las sugerencias a los ejercicios de una rutina.
  static Rutina aplicar(Rutina r, List<Sugerencia> sugerencias) {
    final porNombre = {for (final s in sugerencias) s.ejercicio: s};
    return Rutina(
      id: r.id,
      nombre: r.nombre,
      dias: {...r.dias},
      origen: r.origen,
      ejercicios: [
        for (final e in r.ejercicios)
          porNombre[e.nombre] == null
              ? e
              : e.copyWith(repeticiones: porNombre[e.nombre]!.repeticiones, pesoKg: porNombre[e.nombre]!.pesoKg),
      ],
    );
  }

  static String _kg(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class Sugerencia {
  const Sugerencia(this.ejercicio, this.texto, {this.pesoKg, this.repeticiones});
  final String ejercicio;
  final String texto;
  final double? pesoKg;
  final int? repeticiones;
}

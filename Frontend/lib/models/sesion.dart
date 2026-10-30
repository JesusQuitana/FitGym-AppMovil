/// Lo que se hizo de un ejercicio en un entrenamiento.
class EjercicioSesion {
  const EjercicioSesion({
    required this.nombre,
    required this.musculo,
    required this.seriesPlan,
    required this.repeticiones,
    required this.seriesHechas,
    this.pesoKg,
    this.porTiempo = false,
  });

  final String nombre;
  final String musculo;
  final int seriesPlan;

  /// Repeticiones (o segundos si [porTiempo]) por serie.
  final int repeticiones;
  final int seriesHechas;
  final double? pesoKg;
  final bool porTiempo;

  bool get completo => seriesHechas >= seriesPlan;

  /// Kilos movidos: series × repeticiones × peso (0 sin peso o por tiempo).
  double get volumenKg => porTiempo || pesoKg == null ? 0 : seriesHechas * repeticiones * pesoKg!;

  factory EjercicioSesion.fromJson(Map<String, dynamic> j) => EjercicioSesion(
        nombre: '${j['nombre'] ?? ''}',
        musculo: '${j['musculo'] ?? ''}',
        seriesPlan: (j['seriesPlan'] as num?)?.toInt() ?? 0,
        repeticiones: (j['repeticiones'] as num?)?.toInt() ?? 0,
        seriesHechas: (j['seriesHechas'] as num?)?.toInt() ?? 0,
        pesoKg: (j['pesoKg'] as num?)?.toDouble(),
        porTiempo: j['porTiempo'] == true,
      );

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'musculo': musculo,
        'seriesPlan': seriesPlan,
        'repeticiones': repeticiones,
        'seriesHechas': seriesHechas,
        'pesoKg': pesoKg,
        'porTiempo': porTiempo,
      };
}

/// Un entrenamiento terminado.
class SesionEntrenamiento {
  const SesionEntrenamiento({
    required this.fecha,
    required this.rutinaId,
    required this.rutinaNombre,
    required this.duracion,
    required this.ejercicios,
  });

  final DateTime fecha;
  final String rutinaId;
  final String rutinaNombre;
  final Duration duracion;
  final List<EjercicioSesion> ejercicios;

  int get seriesHechas => ejercicios.fold(0, (a, e) => a + e.seriesHechas);
  int get seriesPlan => ejercicios.fold(0, (a, e) => a + e.seriesPlan);
  double get volumenKg => ejercicios.fold(0.0, (a, e) => a + e.volumenKg);

  factory SesionEntrenamiento.fromJson(Map<String, dynamic> j) => SesionEntrenamiento(
        fecha: DateTime.parse(j['fecha'] as String),
        rutinaId: '${j['rutinaId'] ?? ''}',
        rutinaNombre: '${j['rutinaNombre'] ?? ''}',
        duracion: Duration(seconds: (j['segundos'] as num?)?.toInt() ?? 0),
        ejercicios: ((j['ejercicios'] as List?) ?? [])
            .map((e) => EjercicioSesion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'rutinaId': rutinaId,
        'rutinaNombre': rutinaNombre,
        'segundos': duracion.inSeconds,
        'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
      };
}

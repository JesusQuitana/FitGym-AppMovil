/// Ejercicio del catálogo central de wger (https://wger.de). Solo se usan
/// los que tienen traducción al español y al menos una imagen o un video.
/// Textos e imágenes: wger.de, licencia CC-BY-SA.
library;

/// Nivel de equipo que requiere un ejercicio (de menos a más).
enum Equipo {
  corporal('Peso corporal'),
  mancuernas('Mancuernas o equipo de casa'),
  gimnasio('Máquina o barra');

  const Equipo(this.etiqueta);
  final String etiqueta;
}

enum Lesion {
  rodilla('Rodilla'),
  espalda('Espalda baja'),
  hombro('Hombro');

  const Lesion(this.etiqueta);
  final String etiqueta;
}

class EjercicioWger {
  const EjercicioWger({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.musculo,
    this.nombreEn = '',
    this.equipos = const [],
    this.imagenes = const [],
    this.videos = const [],
    this.autorImagen = '',
  });

  final int id;
  final String nombre;
  final String nombreEn;

  /// Instrucciones en español, en texto plano.
  final String descripcion;

  /// Grupo muscular con los mismos nombres que usa la app (Pecho, Espalda…).
  final String musculo;

  /// Equipo según wger ("Dumbbell", "Barbell", "none (bodyweight exercise)"…).
  final List<String> equipos;
  final List<String> imagenes;
  final List<String> videos;
  final String autorImagen;

  String? get imagen => imagenes.isEmpty ? null : imagenes.first;

  String get _nombres => _sinTildes('$nombre $nombreEn'.toLowerCase());

  static const _equipoGimnasio = {'Barbell', 'SZ-Bar', 'Cable machine', 'Incline bench', 'Pull-up bar'};
  static const _equipoCasa = {'Dumbbell', 'Kettlebell', 'Bench', 'Resistance band', 'Swiss Ball'};

  /// Equipo que necesita. Si wger no lo indica, se deduce del nombre.
  Equipo get equipo {
    if (equipos.any(_equipoGimnasio.contains)) return Equipo.gimnasio;
    if (equipos.any(_equipoCasa.contains)) return Equipo.mancuernas;
    if (equipos.isNotEmpty) return Equipo.corporal;
    final n = _nombres;
    if (RegExp(r'maquina|machine|polea|cable|barra|barbell|prensa|smith|press de banca|jalon|lat pull').hasMatch(n)) {
      return Equipo.gimnasio;
    }
    if (RegExp(r'mancuerna|dumbbell|kettlebell|banco|bench|disco|plate').hasMatch(n)) return Equipo.mancuernas;
    return Equipo.corporal;
  }

  /// Molestias con las que conviene evitarlo. wger no trae este dato: se
  /// infiere por palabras clave del nombre, así que es orientativo.
  Set<Lesion> get evitarCon {
    final n = _nombres;
    return {
      if (RegExp(r'sentadilla|squat|zancada|lunge|salto|jump|burpee|pistol|step.?up|subida|prensa|leg press|cajon|box')
          .hasMatch(n))
        Lesion.rodilla,
      if (RegExp(r'peso muerto|deadlift|buenos dias|good morning|superman|hiperextension|lumbar|remo con barra|bent over|swing')
          .hasMatch(n))
        Lesion.espalda,
      if (RegExp(r'press militar|overhead|press de hombro|shoulder press|fondos|dips|pike|pino|handstand|remo al menton|upright|tras nuca|behind')
          .hasMatch(n))
        Lesion.hombro,
    };
  }

  /// Se mide en segundos (cardio, planchas, isométricos).
  bool get porTiempo =>
      musculo == 'Cardio' || RegExp(r'plancha|plank|isometric|wall sit|en pared|hold').hasMatch(_nombres);

  /// Texto para mostrar el equipo ("Mancuernas", "Polea"…).
  String get equipoTexto {
    const traducciones = {
      'Barbell': 'Barra',
      'SZ-Bar': 'Barra Z',
      'Cable machine': 'Polea',
      'Dumbbell': 'Mancuernas',
      'Kettlebell': 'Kettlebell',
      'Bench': 'Banco',
      'Incline bench': 'Banco inclinado',
      'Pull-up bar': 'Barra de dominadas',
      'Resistance band': 'Banda elástica',
      'Swiss Ball': 'Pelota suiza',
      'Gym mat': 'Colchoneta',
      'none (bodyweight exercise)': 'Peso corporal',
    };
    if (equipos.isEmpty) return equipo.etiqueta;
    return equipos.map((e) => traducciones[e] ?? e).join(' · ');
  }

  factory EjercicioWger.fromJson(Map<String, dynamic> j) => EjercicioWger(
        id: (j['id'] as num).toInt(),
        nombre: '${j['nombre'] ?? ''}',
        nombreEn: '${j['nombreEn'] ?? ''}',
        descripcion: '${j['descripcion'] ?? ''}',
        musculo: '${j['musculo'] ?? ''}',
        equipos: [for (final e in (j['equipos'] as List? ?? const [])) '$e'],
        imagenes: [for (final e in (j['imagenes'] as List? ?? const [])) '$e'],
        videos: [for (final e in (j['videos'] as List? ?? const [])) '$e'],
        autorImagen: '${j['autorImagen'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'nombreEn': nombreEn,
        'descripcion': descripcion,
        'musculo': musculo,
        'equipos': equipos,
        'imagenes': imagenes,
        'videos': videos,
        'autorImagen': autorImagen,
      };

  static String _sinTildes(String s) => s
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');
}

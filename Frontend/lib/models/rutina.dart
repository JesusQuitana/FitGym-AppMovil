import 'ejercicio_wger.dart';
import 'maquina.dart';

/// Un ejercicio que se puede agregar a una rutina. Sale del catálogo central
/// de wger; en el gimnasio puede indicar además la máquina donde se hace.
class OpcionEjercicio {
  const OpcionEjercicio({
    required this.nombre,
    required this.musculo,
    this.detalle = '',
    this.descripcion = '',
    this.ejercicioId,
    this.maquinaId,
    this.wgerId,
    this.imagen,
    this.porTiempo = false,
  });

  final String nombre;
  final String musculo;

  /// Máquina o equipo con que se hace ("Press de banca", "Mancuernas"…).
  final String detalle;
  final String descripcion;

  /// Id en la tabla `ejercicios` del backend (solo ejercicios del gimnasio).
  final int? ejercicioId;
  final int? maquinaId;

  /// Id del ejercicio en wger (imágenes, video e instrucciones).
  final int? wgerId;
  final String? imagen;
  final bool porTiempo;

  factory OpcionEjercicio.deWger(EjercicioWger e, {Maquina? maquina, int? ejercicioId}) => OpcionEjercicio(
        nombre: e.nombre,
        musculo: e.musculo,
        detalle: maquina?.nombre ?? e.equipoTexto,
        descripcion: e.descripcion,
        wgerId: e.id,
        imagen: e.imagen,
        maquinaId: maquina?.id,
        ejercicioId: ejercicioId,
        porTiempo: e.porTiempo,
      );

  factory OpcionEjercicio.deMaquina(Maquina m) => OpcionEjercicio(
        nombre: m.nombre,
        musculo: m.musculo?.nombre ?? '',
        detalle: m.disponible ? 'Máquina' : 'Máquina fuera de servicio',
        descripcion: m.descripcion,
        maquinaId: m.id,
      );
}

/// Un ejercicio dentro de una rutina con sus series, repeticiones y peso.
/// Se guarda una copia del nombre y del músculo para que la rutina se siga
/// viendo bien aunque el catálogo cambie.
class EjercicioRutina {
  const EjercicioRutina({
    required this.maquina,
    required this.musculo,
    required this.series,
    required this.repeticiones,
    this.maquinaId,
    this.ejercicioId,
    this.wgerId,
    this.detalle = '',
    this.pesoKg,
    this.medidoEnSegundos = false,
  });

  /// Nombre del ejercicio (se llama `maquina` por compatibilidad con las
  /// rutinas guardadas antes, que siempre eran máquinas).
  final String maquina;
  final String musculo;
  final int series;
  final int repeticiones;
  final int? maquinaId;
  final int? ejercicioId;

  /// Id en wger: imágenes, video e instrucciones del ejercicio.
  final int? wgerId;
  final String detalle;
  final double? pesoKg;

  /// Se mide en segundos (cardio, planchas). Las rutinas guardadas antes lo
  /// indicaban con un detalle que empezaba por "Por tiempo".
  final bool medidoEnSegundos;

  String get nombre => maquina;

  factory EjercicioRutina.deMaquina(Maquina m, {int series = 3, int repeticiones = 12, double? pesoKg}) =>
      EjercicioRutina.deOpcion(OpcionEjercicio.deMaquina(m), series: series, repeticiones: repeticiones, pesoKg: pesoKg);

  factory EjercicioRutina.deOpcion(OpcionEjercicio o, {int series = 3, int repeticiones = 12, double? pesoKg}) =>
      EjercicioRutina(
        maquina: o.nombre,
        musculo: o.musculo,
        detalle: o.detalle,
        maquinaId: o.maquinaId,
        ejercicioId: o.ejercicioId,
        wgerId: o.wgerId,
        medidoEnSegundos: o.porTiempo,
        series: series,
        repeticiones: repeticiones,
        pesoKg: pesoKg,
      );

  EjercicioRutina copyWith({int? series, int? repeticiones, double? pesoKg, bool quitarPeso = false}) =>
      EjercicioRutina(
        maquina: maquina,
        musculo: musculo,
        detalle: detalle,
        maquinaId: maquinaId,
        ejercicioId: ejercicioId,
        wgerId: wgerId,
        medidoEnSegundos: medidoEnSegundos,
        series: series ?? this.series,
        repeticiones: repeticiones ?? this.repeticiones,
        pesoKg: quitarPeso ? null : (pesoKg ?? this.pesoKg),
      );

  factory EjercicioRutina.fromJson(Map<String, dynamic> j) => EjercicioRutina(
        maquinaId: (j['maquinaId'] as num?)?.toInt(),
        ejercicioId: (j['ejercicioId'] as num?)?.toInt(),
        wgerId: (j['wgerId'] as num?)?.toInt(),
        medidoEnSegundos: j['porTiempo'] == true,
        maquina: '${j['maquina'] ?? ''}',
        musculo: '${j['musculo'] ?? ''}',
        detalle: '${j['detalle'] ?? ''}',
        series: (j['series'] as num?)?.toInt() ?? 3,
        repeticiones: (j['repeticiones'] as num?)?.toInt() ?? 12,
        pesoKg: (j['pesoKg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'maquinaId': maquinaId,
        'ejercicioId': ejercicioId,
        'wgerId': wgerId,
        'porTiempo': medidoEnSegundos,
        'maquina': maquina,
        'musculo': musculo,
        'detalle': detalle,
        'series': series,
        'repeticiones': repeticiones,
        'pesoKg': pesoKg,
      };

  /// Ejercicio medido en segundos (cardio, plancha) en vez de repeticiones.
  bool get porTiempo => medidoEnSegundos || detalle.startsWith('Por tiempo');

  String get resumen {
    final peso = pesoKg == null ? '' : ' · ${_numero(pesoKg!)} kg';
    return porTiempo ? '$series × $repeticiones s$peso' : '$series × $repeticiones$peso';
  }

  static String _numero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// De dónde viene una rutina.
enum OrigenRutina {
  /// Creada por el usuario (se guarda en el teléfono).
  propia,

  /// Del backend, general para todos los afiliados (rutina sin cliente).
  gimnasioGeneral,

  /// Del backend, asignada por el gimnasio a este afiliado.
  gimnasioAsignada,
}

/// Rutina de entrenamiento: nombre, días de la semana y ejercicios.
class Rutina {
  const Rutina({
    required this.id,
    required this.nombre,
    required this.dias,
    required this.ejercicios,
    this.origen = OrigenRutina.propia,
  });

  final String id;
  final String nombre;

  /// Días de la semana (1 = lunes … 7 = domingo, como DateTime.weekday).
  final Set<int> dias;
  final List<EjercicioRutina> ejercicios;
  final OrigenRutina origen;

  static const nombresDias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  static const inicialesDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  bool get esHoy => dias.contains(DateTime.now().weekday);
  bool get esDelGimnasio => origen != OrigenRutina.propia;

  String? get etiqueta => switch (origen) {
        OrigenRutina.propia => null,
        OrigenRutina.gimnasioGeneral => 'Del gimnasio',
        OrigenRutina.gimnasioAsignada => 'Asignada a ti',
      };

  /// Músculos que trabaja, sin repetir y en el orden de los ejercicios.
  List<String> get musculos => ejercicios.map((e) => e.musculo).where((m) => m.isNotEmpty).toSet().toList();

  /// Convierte días como texto ("Lunes,Jueves", "lun", "1,4"…) en números.
  static Set<int> parseDias(String texto) {
    final dias = <int>{};
    for (final parte in texto.toLowerCase().split(RegExp(r'[,;/\s]+|\by\b'))) {
      final p = parte.trim();
      if (p.isEmpty) continue;
      final n = int.tryParse(p);
      if (n != null && n >= 1 && n <= 7) {
        dias.add(n);
        continue;
      }
      for (var i = 0; i < 7; i++) {
        final nombre = _sinTildes(nombresDias[i].toLowerCase());
        if (_sinTildes(p).startsWith(nombre.substring(0, 3))) dias.add(i + 1);
      }
    }
    return dias;
  }

  static String textoDias(Set<int> dias) => (dias.toList()..sort()).map((d) => nombresDias[d - 1]).join(',');

  static String _sinTildes(String s) => s
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  Rutina copyWith({String? id, String? nombre, OrigenRutina? origen}) => Rutina(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        dias: {...dias},
        ejercicios: [...ejercicios],
        origen: origen ?? this.origen,
      );

  factory Rutina.fromJson(Map<String, dynamic> j) => Rutina(
        id: '${j['id']}',
        nombre: '${j['nombre'] ?? ''}',
        dias: ((j['dias'] as List?) ?? []).map((d) => (d as num).toInt()).toSet(),
        ejercicios: ((j['ejercicios'] as List?) ?? [])
            .map((e) => EjercicioRutina.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        origen: OrigenRutina.values.where((o) => o.name == j['origen']).firstOrNull ?? OrigenRutina.propia,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'dias': (dias.toList()..sort()),
        'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
        if (origen != OrigenRutina.propia) 'origen': origen.name,
      };
}

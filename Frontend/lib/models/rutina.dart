import 'maquina.dart';

/// Un ejercicio dentro de una rutina: una máquina del gimnasio con sus
/// series, repeticiones y peso. Se guarda una copia del nombre y del músculo
/// para que la rutina se siga viendo bien aunque la máquina cambie.
class EjercicioRutina {
  const EjercicioRutina({
    required this.maquinaId,
    required this.maquina,
    required this.musculo,
    required this.series,
    required this.repeticiones,
    this.pesoKg,
  });

  final int? maquinaId;
  final String maquina;
  final String musculo;
  final int series;
  final int repeticiones;
  final double? pesoKg;

  factory EjercicioRutina.deMaquina(Maquina m, {int series = 3, int repeticiones = 12, double? pesoKg}) =>
      EjercicioRutina(
        maquinaId: m.id,
        maquina: m.nombre,
        musculo: m.musculo?.nombre ?? '',
        series: series,
        repeticiones: repeticiones,
        pesoKg: pesoKg,
      );

  factory EjercicioRutina.fromJson(Map<String, dynamic> j) => EjercicioRutina(
        maquinaId: (j['maquinaId'] as num?)?.toInt(),
        maquina: '${j['maquina'] ?? ''}',
        musculo: '${j['musculo'] ?? ''}',
        series: (j['series'] as num?)?.toInt() ?? 3,
        repeticiones: (j['repeticiones'] as num?)?.toInt() ?? 12,
        pesoKg: (j['pesoKg'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'maquinaId': maquinaId,
        'maquina': maquina,
        'musculo': musculo,
        'series': series,
        'repeticiones': repeticiones,
        'pesoKg': pesoKg,
      };

  String get resumen {
    final peso = pesoKg == null ? '' : ' · ${_numero(pesoKg!)} kg';
    return '$series × $repeticiones$peso';
  }

  static String _numero(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Rutina de entrenamiento del afiliado: nombre, días de la semana en que
/// la hace y lista de ejercicios.
class Rutina {
  const Rutina({
    required this.id,
    required this.nombre,
    required this.dias,
    required this.ejercicios,
  });

  final String id;
  final String nombre;

  /// Días de la semana (1 = lunes … 7 = domingo, como DateTime.weekday).
  final Set<int> dias;
  final List<EjercicioRutina> ejercicios;

  static const nombresDias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  static const inicialesDias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  bool get esHoy => dias.contains(DateTime.now().weekday);

  /// Músculos que trabaja, sin repetir y en el orden de los ejercicios.
  List<String> get musculos => ejercicios.map((e) => e.musculo).where((m) => m.isNotEmpty).toSet().toList();

  factory Rutina.fromJson(Map<String, dynamic> j) => Rutina(
        id: '${j['id']}',
        nombre: '${j['nombre'] ?? ''}',
        dias: ((j['dias'] as List?) ?? []).map((d) => (d as num).toInt()).toSet(),
        ejercicios: ((j['ejercicios'] as List?) ?? [])
            .map((e) => EjercicioRutina.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'dias': (dias.toList()..sort()),
        'ejercicios': ejercicios.map((e) => e.toJson()).toList(),
      };
}

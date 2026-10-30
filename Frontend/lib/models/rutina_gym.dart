import 'maquina.dart';

/// Tablas de rutinas y ejercicios del backend, tal como las devuelve la API.
/// Los nombres de las claves siguen los getters de las entidades Java.

int? _id(dynamic v) => v is Map ? (v['id'] as num?)?.toInt() : (v as num?)?.toInt();

/// Entidad `Ejercicios` (tabla `ejercicios`).
class EjercicioGym {
  const EjercicioGym({this.id, required this.nombre, this.descripcion = ''});

  final int? id;
  final String nombre;
  final String descripcion;

  factory EjercicioGym.fromJson(Map<String, dynamic> j) => EjercicioGym(
        id: (j['id'] as num?)?.toInt(),
        nombre: '${j['nombre'] ?? ''}',
        descripcion: '${j['descripcion'] ?? ''}',
      );

  Map<String, dynamic> toApiJson() => {if (id != null) 'id': id, 'nombre': nombre, 'descripcion': descripcion};
}

/// Entidad `Ejercicio_Musculo`: une un ejercicio con su músculo y,
/// opcionalmente, la máquina con que se hace.
class EjercicioMusculo {
  const EjercicioMusculo({this.id, required this.ejercicioId, this.musculo, this.maquina});

  final int? id;
  final int? ejercicioId;
  final Musculo? musculo;
  final Maquina? maquina;

  factory EjercicioMusculo.fromJson(Map<String, dynamic> j) {
    final m = j['musculo_id'];
    final q = j['maquina_id'];
    return EjercicioMusculo(
      id: (j['id'] as num?)?.toInt(),
      ejercicioId: _id(j['ejercicio_id']),
      musculo: m is Map ? Musculo.fromJson(Map<String, dynamic>.from(m)) : null,
      maquina: q is Map ? Maquina.fromJson(Map<String, dynamic>.from(q)) : null,
    );
  }

  Map<String, dynamic> toApiJson() => {
        if (id != null) 'id': id,
        'ejercicio_id': {'id': ejercicioId},
        'musculo_id': musculo == null ? null : {'id': musculo!.id},
        'maquina_id': maquina == null ? null : {'id': maquina!.id},
      };
}

/// Entidad `Rutina`: un día (o días) de entrenamiento. Sin cliente es una
/// rutina general del gimnasio; con cliente, asignada a esa persona.
class RutinaGym {
  const RutinaGym({this.id, required this.diaSemana, this.clienteId, this.clienteNombre = ''});

  final int? id;

  /// Texto libre del backend; la app escribe los días separados por coma
  /// ("Lunes,Jueves") y lee también formatos como "lun" o "1,4".
  final String diaSemana;
  final int? clienteId;
  final String clienteNombre;

  bool get esGeneral => clienteId == null;

  factory RutinaGym.fromJson(Map<String, dynamic> j) {
    final c = j['cliente_id'];
    return RutinaGym(
      id: (j['id'] as num?)?.toInt(),
      diaSemana: '${j['dia_semana'] ?? ''}',
      clienteId: _id(c),
      clienteNombre: c is Map ? '${c['nombre'] ?? ''} ${c['apellido'] ?? ''}'.trim() : '',
    );
  }

  Map<String, dynamic> toApiJson() => {
        if (id != null) 'id': id,
        'dia_semana': diaSemana,
        'cliente_id': clienteId == null ? null : {'id': clienteId},
      };
}

/// Entidad `Rutina_Ejercicio`. Ojo: en el JSON las claves son "Series" y
/// "Repeticiones" con mayúscula (así se llaman los campos en Java); en
/// minúscula el backend las ignora y guarda null.
class RutinaEjercicioGym {
  const RutinaEjercicioGym({
    this.id,
    required this.rutinaId,
    required this.ejercicioId,
    required this.series,
    required this.repeticiones,
  });

  final int? id;
  final int? rutinaId;
  final int? ejercicioId;
  final int series;
  final int repeticiones;

  factory RutinaEjercicioGym.fromJson(Map<String, dynamic> j) => RutinaEjercicioGym(
        id: (j['id'] as num?)?.toInt(),
        rutinaId: _id(j['rutina_id']),
        ejercicioId: _id(j['ejercicio_id']),
        series: ((j['Series'] ?? j['series']) as num?)?.toInt() ?? 3,
        repeticiones: ((j['Repeticiones'] ?? j['repeticiones']) as num?)?.toInt() ?? 12,
      );

  Map<String, dynamic> toApiJson() => {
        if (id != null) 'id': id,
        'rutina_id': {'id': rutinaId},
        'ejercicio_id': {'id': ejercicioId},
        'Series': series,
        'Repeticiones': repeticiones,
      };
}

/// Entidad `MuscleGroup` del backend (tabla `muscle_group`).
class Musculo {
  const Musculo({this.id, required this.nombre});

  final int? id;
  final String nombre;

  factory Musculo.fromJson(Map<String, dynamic> j) => Musculo(
        id: (j['id'] as num?)?.toInt(),
        nombre: '${j['musculo'] ?? ''}',
      );

  /// Cuerpo para POST /MuscleGroup/agregar y PUT /MuscleGroup/editar/{id}.
  Map<String, dynamic> toApiJson() => {
        if (id != null) 'id': id,
        'musculo': nombre,
      };

  @override
  bool operator ==(Object other) => other is Musculo && other.id == id && other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, nombre);
}

/// Entidad `Maquinas` del backend (tabla `maquinas`).
class Maquina {
  const Maquina({
    this.id,
    required this.nombre,
    required this.descripcion,
    required this.disponibilidad,
    this.musculo,
  });

  final int? id;
  final String nombre;
  final String descripcion;

  /// Unidades de esta máquina en servicio (0 = fuera de servicio).
  final int disponibilidad;

  /// Grupo muscular que trabaja (`grupoMuscleGroup` en el JSON).
  final Musculo? musculo;

  bool get disponible => disponibilidad > 0;

  factory Maquina.fromJson(Map<String, dynamic> j) {
    final m = j['grupoMuscleGroup'];
    return Maquina(
      id: (j['id'] as num?)?.toInt(),
      nombre: '${j['nombre'] ?? ''}',
      descripcion: '${j['descripcion'] ?? ''}',
      disponibilidad: (j['disponibilidad'] as num?)?.toInt() ?? 0,
      musculo: m is Map ? Musculo.fromJson(Map<String, dynamic>.from(m)) : null,
    );
  }

  /// Cuerpo para POST /maquina/agregar y PUT /maquina/editar/{id}. Los
  /// nombres siguen los getters de Maquinas.java.
  Map<String, dynamic> toApiJson() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'disponibilidad': disponibilidad,
        'grupoMuscleGroup': musculo?.toApiJson(),
      };

  Maquina copyWith({int? id}) => Maquina(
        id: id ?? this.id,
        nombre: nombre,
        descripcion: descripcion,
        disponibilidad: disponibilidad,
        musculo: musculo,
      );
}

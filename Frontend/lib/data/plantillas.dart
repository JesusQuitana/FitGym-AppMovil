/// Plantillas de rutinas para quienes entrenan por su cuenta. Cada bloque es
/// una sesión y lista los músculos en orden; el ejercicio concreto se elige
/// según el equipo y las molestias de la persona (ver PlanPersonal).
library;

enum Objetivo {
  perderGrasa('Perder grasa', 'Quemar calorías y bajar de peso'),
  ganarMasa('Ganar masa muscular', 'Aumentar tamaño y fuerza'),
  tonificar('Tonificar', 'Definir sin aumentar mucho de tamaño'),
  resistencia('Mejorar resistencia', 'Aguantar más y cansarte menos'),
  salud('Salud general', 'Moverte más y sentirte mejor');

  const Objetivo(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;
}

enum Nivel {
  principiante('Principiante', 'Empiezo o hace meses que no entreno'),
  intermedio('Intermedio', 'Entreno con regularidad hace algunos meses'),
  avanzado('Avanzado', 'Más de un año entrenando constante');

  const Nivel(this.etiqueta, this.descripcion);
  final String etiqueta;
  final String descripcion;
}

class BloquePlantilla {
  const BloquePlantilla(this.nombre, this.musculos);
  final String nombre;
  final List<String> musculos;
}

class Plantilla {
  const Plantilla({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.objetivos,
    required this.niveles,
    required this.diasMin,
    required this.diasMax,
    required this.bloques,
  });

  final String id;
  final String nombre;
  final String descripcion;

  /// El primero es el objetivo principal de la plantilla.
  final List<Objetivo> objetivos;
  final Set<Nivel> niveles;
  final int diasMin;
  final int diasMax;
  final List<BloquePlantilla> bloques;
}

const plantillas = <Plantilla>[
  Plantilla(
    id: 'full_body',
    nombre: 'Full body',
    descripcion: 'Todo el cuerpo en cada sesión. La base ideal para empezar.',
    objetivos: [Objetivo.salud, Objetivo.tonificar, Objetivo.ganarMasa, Objetivo.perderGrasa],
    niveles: {Nivel.principiante, Nivel.intermedio},
    diasMin: 2,
    diasMax: 4,
    bloques: [
      BloquePlantilla('Full body A', ['Piernas', 'Pecho', 'Espalda', 'Hombros', 'Abdomen', 'Brazos']),
      BloquePlantilla('Full body B', ['Piernas', 'Espalda', 'Pecho', 'Brazos', 'Abdomen', 'Hombros']),
    ],
  ),
  Plantilla(
    id: 'torso_pierna',
    nombre: 'Torso / Pierna',
    descripcion: 'Alterna tren superior e inferior para entrenar más volumen.',
    objetivos: [Objetivo.ganarMasa, Objetivo.tonificar],
    niveles: {Nivel.intermedio, Nivel.avanzado},
    diasMin: 4,
    diasMax: 4,
    bloques: [
      BloquePlantilla('Torso', ['Pecho', 'Espalda', 'Hombros', 'Pecho', 'Espalda', 'Brazos']),
      BloquePlantilla('Pierna', ['Piernas', 'Piernas', 'Piernas', 'Abdomen', 'Piernas', 'Abdomen']),
    ],
  ),
  Plantilla(
    id: 'ppl',
    nombre: 'Empuje / Tirón / Pierna',
    descripcion: 'Divide por movimientos. Para 3 o 6 días de gimnasio.',
    objetivos: [Objetivo.ganarMasa],
    niveles: {Nivel.intermedio, Nivel.avanzado},
    diasMin: 3,
    diasMax: 6,
    bloques: [
      BloquePlantilla('Empuje', ['Pecho', 'Hombros', 'Pecho', 'Brazos', 'Hombros', 'Brazos']),
      BloquePlantilla('Tirón', ['Espalda', 'Espalda', 'Brazos', 'Hombros', 'Espalda', 'Abdomen']),
      BloquePlantilla('Pierna', ['Piernas', 'Piernas', 'Piernas', 'Piernas', 'Abdomen', 'Abdomen']),
    ],
  ),
  Plantilla(
    id: 'quema_grasa',
    nombre: 'Circuito quema grasa',
    descripcion: 'Fuerza y cardio intercalados con poco descanso.',
    objetivos: [Objetivo.perderGrasa, Objetivo.resistencia],
    niveles: {Nivel.principiante, Nivel.intermedio, Nivel.avanzado},
    diasMin: 3,
    diasMax: 5,
    bloques: [
      BloquePlantilla('Circuito A', ['Cardio', 'Piernas', 'Pecho', 'Cardio', 'Espalda', 'Abdomen']),
      BloquePlantilla('Circuito B', ['Cardio', 'Piernas', 'Espalda', 'Cardio', 'Hombros', 'Abdomen']),
    ],
  ),
  Plantilla(
    id: 'resistencia',
    nombre: 'Fuerza-resistencia',
    descripcion: 'Muchas repeticiones y cardio para aguantar más.',
    objetivos: [Objetivo.resistencia, Objetivo.perderGrasa],
    niveles: {Nivel.intermedio, Nivel.avanzado},
    diasMin: 3,
    diasMax: 5,
    bloques: [
      BloquePlantilla('Resistencia A', ['Cardio', 'Piernas', 'Espalda', 'Cardio', 'Pecho', 'Abdomen']),
      BloquePlantilla('Resistencia B', ['Cardio', 'Piernas', 'Hombros', 'Cardio', 'Brazos', 'Abdomen']),
    ],
  ),
  Plantilla(
    id: 'salud',
    nombre: 'Salud y movilidad',
    descripcion: 'Sesiones suaves para moverte, ganar fuerza básica y sentirte mejor.',
    objetivos: [Objetivo.salud],
    niveles: {Nivel.principiante, Nivel.intermedio},
    diasMin: 2,
    diasMax: 3,
    bloques: [
      BloquePlantilla('Salud', ['Cardio', 'Piernas', 'Espalda', 'Pecho', 'Abdomen', 'Cardio']),
    ],
  ),
];

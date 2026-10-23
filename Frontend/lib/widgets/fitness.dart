import 'package:flutter/material.dart';

import '../models/maquina.dart';
import '../theme.dart';

const _paleta = [
  Color(0xFFFF7A45),
  Color(0xFF4DA3FF),
  Color(0xFF34C77B),
  Color(0xFFB57BFF),
  Color(0xFFFFC23D),
  Color(0xFFFF5C8A),
  Color(0xFF2EC4B6),
];

/// Color estable por grupo muscular (los nombres los define recepción).
Color colorMusculo(String nombre) {
  if (nombre.isEmpty) return FitColors.textMuted;
  final h = nombre.toLowerCase().codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return _paleta[h % _paleta.length];
}

IconData iconoMusculo(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('pierna') || n.contains('cuádr') || n.contains('glúte') || n.contains('glute')) {
    return Icons.directions_run;
  }
  if (n.contains('abdo') || n.contains('core')) return Icons.accessibility_new;
  if (n.contains('espalda') || n.contains('dorsal')) return Icons.airline_seat_recline_extra;
  if (n.contains('cardio')) return Icons.monitor_heart_outlined;
  return Icons.fitness_center;
}

class MusculoChip extends StatelessWidget {
  const MusculoChip(this.nombre, {super.key});
  final String nombre;

  @override
  Widget build(BuildContext context) {
    final color = colorMusculo(nombre);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        nombre.isEmpty ? 'Sin grupo' : nombre,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class DisponibilidadBadge extends StatelessWidget {
  const DisponibilidadBadge(this.maquina, {super.key});
  final Maquina maquina;

  @override
  Widget build(BuildContext context) {
    final ok = maquina.disponible;
    final color = ok ? FitColors.ok : FitColors.danger;
    final texto = ok
        ? '${maquina.disponibilidad} ${maquina.disponibilidad == 1 ? 'disponible' : 'disponibles'}'
        : 'Fuera de servicio';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.build_circle, size: 14, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class MaquinaTile extends StatelessWidget {
  const MaquinaTile({super.key, required this.maquina, this.onTap, this.trailing});
  final Maquina maquina;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final musculo = maquina.musculo?.nombre ?? '';
    final color = colorMusculo(musculo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(14)),
                  child: Icon(iconoMusculo(musculo), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(maquina.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (maquina.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          maquina.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: FitColors.textMuted, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          MusculoChip(musculo),
                          const SizedBox(width: 8),
                          Flexible(child: DisponibilidadBadge(maquina)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de filtros por grupo muscular ("Todos" + uno por músculo).
class FiltroMusculos extends StatelessWidget {
  const FiltroMusculos({super.key, required this.musculos, required this.seleccionado, required this.onChanged});
  final List<Musculo> musculos;
  final int? seleccionado;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int? id) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: seleccionado == id,
            selectedColor: (id == null ? FitColors.primary : colorMusculo(label)).withAlpha(60),
            onSelected: (_) => onChanged(id),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Todos', null),
          for (final m in musculos) chip(m.nombre, m.id),
        ],
      ),
    );
  }
}

class VacioMensaje extends StatelessWidget {
  const VacioMensaje({super.key, required this.icon, required this.texto, this.accion});
  final IconData icon;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48, left: 24, right: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: FitColors.textMuted),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: FitColors.textMuted, height: 1.4)),
          if (accion != null) ...[const SizedBox(height: 8), accion!],
        ],
      ),
    );
  }
}

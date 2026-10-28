import 'package:flutter/material.dart';

import '../../models/rutina.dart';
import '../../theme.dart';
import '../../widgets/fitness.dart';
import 'rutina_editor_screen.dart';
import 'rutinas_tab.dart';

/// Detalle de una rutina con una lista para ir marcando los ejercicios
/// hechos durante el entrenamiento.
class RutinaDetalleScreen extends StatefulWidget {
  const RutinaDetalleScreen({
    super.key,
    required this.rutina,
    required this.onGuardar,
    required this.onEliminar,
  });

  final Rutina rutina;
  final Future<void> Function(Rutina) onGuardar;
  final Future<void> Function() onEliminar;

  @override
  State<RutinaDetalleScreen> createState() => _RutinaDetalleScreenState();
}

class _RutinaDetalleScreenState extends State<RutinaDetalleScreen> {
  late Rutina _rutina = widget.rutina;
  final Set<int> _hechos = {};

  Future<void> _editar() async {
    final r = await Navigator.of(context).push<Rutina>(
      MaterialPageRoute(builder: (_) => RutinaEditorScreen(rutina: _rutina)),
    );
    if (r == null) return;
    await widget.onGuardar(r);
    if (mounted) {
      setState(() {
        _rutina = r;
        _hechos.clear();
      });
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar "${_rutina.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FitColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.onEliminar();
    if (mounted) Navigator.pop(context);
  }

  void _terminar() {
    mostrarExito(context, '¡Buen trabajo! Completaste ${_hechos.length} de ${_rutina.ejercicios.length} ejercicios.');
    setState(_hechos.clear);
  }

  @override
  Widget build(BuildContext context) {
    final total = _rutina.ejercicios.length;
    final progreso = total == 0 ? 0.0 : _hechos.length / total;
    return Scaffold(
      appBar: AppBar(
        title: Text(_rutina.nombre),
        actions: [
          IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: _editar),
          IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
        ],
      ),
      bottomNavigationBar: _hechos.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _terminar,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Terminar entrenamiento'),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          DiasSemana(dias: _rutina.dias),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 8,
                    backgroundColor: FitColors.surfaceHigh,
                    color: FitColors.ok,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_hechos.length}/$total', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < total; i++)
            _EjercicioItem(
              numero: i + 1,
              ejercicio: _rutina.ejercicios[i],
              hecho: _hechos.contains(i),
              onChanged: (v) => setState(() => v ? _hechos.add(i) : _hechos.remove(i)),
            ),
        ],
      ),
    );
  }
}

class _EjercicioItem extends StatelessWidget {
  const _EjercicioItem({required this.numero, required this.ejercicio, required this.hecho, required this.onChanged});
  final int numero;
  final EjercicioRutina ejercicio;
  final bool hecho;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: hecho ? FitColors.ok.withAlpha(25) : FitColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(!hecho),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: colorMusculo(ejercicio.musculo).withAlpha(45),
                  child: Text('$numero',
                      style: TextStyle(color: colorMusculo(ejercicio.musculo), fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ejercicio.maquina,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          decoration: hecho ? TextDecoration.lineThrough : null,
                          color: hecho ? FitColors.textMuted : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          MusculoChip(ejercicio.musculo),
                          const SizedBox(width: 8),
                          Text(ejercicio.resumen, style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                Checkbox(value: hecho, onChanged: (v) => onChanged(v ?? false), activeColor: FitColors.ok),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

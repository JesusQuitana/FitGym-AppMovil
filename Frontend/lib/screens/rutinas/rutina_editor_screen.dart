import 'package:flutter/material.dart';

import '../../models/maquina.dart';
import '../../models/rutina.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fitness.dart';

/// Crea o edita una rutina. Devuelve la rutina con Navigator.pop.
class RutinaEditorScreen extends StatefulWidget {
  const RutinaEditorScreen({super.key, this.rutina});
  final Rutina? rutina;

  @override
  State<RutinaEditorScreen> createState() => _RutinaEditorScreenState();
}

class _RutinaEditorScreenState extends State<RutinaEditorScreen> {
  late final _nombre = TextEditingController(text: widget.rutina?.nombre ?? '');
  late final Set<int> _dias = {...?widget.rutina?.dias};
  late final List<EjercicioRutina> _ejercicios = [...?widget.rutina?.ejercicios];

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final maquina = await showModalBottomSheet<Maquina>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _SelectorMaquina(),
    );
    if (maquina == null || !mounted) return;
    final e = await _configurar(EjercicioRutina.deMaquina(maquina));
    if (e != null) setState(() => _ejercicios.add(e));
  }

  Future<void> _editarEjercicio(int i) async {
    final e = await _configurar(_ejercicios[i]);
    if (e != null) setState(() => _ejercicios[i] = e);
  }

  Future<EjercicioRutina?> _configurar(EjercicioRutina e) => showDialog<EjercicioRutina>(
        context: context,
        builder: (_) => _ConfigEjercicio(ejercicio: e),
      );

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return showError(context, 'Ponle un nombre a la rutina.');
    if (_ejercicios.isEmpty) return showError(context, 'Agrega al menos un ejercicio.');
    Navigator.pop(
      context,
      Rutina(
        id: widget.rutina?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: nombre,
        dias: _dias,
        ejercicios: _ejercicios,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rutina == null ? 'Nueva rutina' : 'Editar rutina'),
        actions: [TextButton(onPressed: _guardar, child: const Text('Guardar'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        backgroundColor: FitColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: fitInput('Nombre de la rutina', Icons.edit_note, hint: 'Ej. Pecho y tríceps'),
          ),
          const SizedBox(height: 20),
          const Text('Días de la semana', style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(Rutina.nombresDias[d - 1].substring(0, 3)),
                  selected: _dias.contains(d),
                  selectedColor: FitColors.primary.withAlpha(70),
                  onSelected: (v) => setState(() => v ? _dias.add(d) : _dias.remove(d)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Ejercicios (${_ejercicios.length})', style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          if (_ejercicios.isEmpty)
            const VacioMensaje(
              icon: Icons.fitness_center,
              texto: 'Agrega ejercicios eligiendo las máquinas del gimnasio.',
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (a, b) => setState(() => _ejercicios.insert(b, _ejercicios.removeAt(a))),
              children: [
                for (var i = 0; i < _ejercicios.length; i++)
                  Padding(
                    key: ValueKey('${_ejercicios[i].maquinaId}-$i'),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: FitColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        onTap: () => _editarEjercicio(i),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_indicator, color: FitColors.textMuted),
                        ),
                        title: Text(_ejercicios[i].maquina, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${_ejercicios[i].musculo} · ${_ejercicios[i].resumen}',
                            style: const TextStyle(color: FitColors.textMuted)),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _ejercicios.removeAt(i)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Lista de máquinas del gimnasio para elegir un ejercicio.
class _SelectorMaquina extends StatefulWidget {
  const _SelectorMaquina();

  @override
  State<_SelectorMaquina> createState() => _SelectorMaquinaState();
}

class _SelectorMaquinaState extends State<_SelectorMaquina> {
  late final Future<(List<Musculo>, List<Maquina>)> _datos = _cargar();
  int? _musculoId;

  Future<(List<Musculo>, List<Maquina>)> _cargar() async {
    final api = ApiService.instance;
    final r = await Future.wait([api.listarMusculos(), api.listarMaquinas()]);
    return (r[0] as List<Musculo>, r[1] as List<Maquina>);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: FutureBuilder(
          future: _datos,
          builder: (context, snap) {
            if (snap.hasError) {
              return VacioMensaje(icon: Icons.cloud_off, texto: '${snap.error}');
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (musculos, maquinas) = snap.data!;
            final visibles = maquinas.where((m) => _musculoId == null || m.musculo?.id == _musculoId).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Elige una máquina', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                FiltroMusculos(
                  musculos: musculos,
                  seleccionado: _musculoId,
                  onChanged: (id) => setState(() => _musculoId = id),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final m in visibles)
                        MaquinaTile(
                          maquina: m,
                          onTap: () => Navigator.pop(context, m),
                          trailing: const Icon(Icons.add_circle_outline, color: FitColors.primary),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Series, repeticiones y peso de un ejercicio.
class _ConfigEjercicio extends StatefulWidget {
  const _ConfigEjercicio({required this.ejercicio});
  final EjercicioRutina ejercicio;

  @override
  State<_ConfigEjercicio> createState() => _ConfigEjercicioState();
}

class _ConfigEjercicioState extends State<_ConfigEjercicio> {
  late int _series = widget.ejercicio.series;
  late int _reps = widget.ejercicio.repeticiones;
  late final _peso = TextEditingController(
    text: widget.ejercicio.pesoKg == null ? '' : widget.ejercicio.pesoKg.toString(),
  );

  @override
  void dispose() {
    _peso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.ejercicio;
    return AlertDialog(
      backgroundColor: FitColors.surface,
      title: Text(e.maquina),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Contador(label: 'Series', valor: _series, min: 1, max: 10, onChanged: (v) => setState(() => _series = v)),
          _Contador(label: 'Repeticiones', valor: _reps, min: 1, max: 50, onChanged: (v) => setState(() => _reps = v)),
          const SizedBox(height: 8),
          TextField(
            controller: _peso,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: fitInput('Peso (kg, opcional)', Icons.monitor_weight_outlined),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EjercicioRutina(
              maquinaId: e.maquinaId,
              maquina: e.maquina,
              musculo: e.musculo,
              series: _series,
              repeticiones: _reps,
              pesoKg: double.tryParse(_peso.text.replaceAll(',', '.')),
            ),
          ),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.label, required this.valor, required this.min, required this.max, required this.onChanged});
  final String label;
  final int valor;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton.filledTonal(
          onPressed: valor > min ? () => onChanged(valor - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 44,
          child: Text('$valor',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        IconButton.filledTonal(
          onPressed: valor < max ? () => onChanged(valor + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

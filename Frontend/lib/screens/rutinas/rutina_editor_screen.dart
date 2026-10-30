import 'package:flutter/material.dart';

import '../../models/rutina.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/como_se_hace.dart';
import '../../widgets/fitness.dart';

/// Crea o edita una rutina propia. Devuelve la rutina con Navigator.pop.
class RutinaEditorScreen extends StatefulWidget {
  const RutinaEditorScreen({super.key, this.rutina, required this.catalogo});
  final Rutina? rutina;

  /// Ejercicios que se pueden agregar (gimnasio, máquinas o catálogo personal).
  final Future<List<OpcionEjercicio>> Function() catalogo;

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
    final opcion = await showModalBottomSheet<OpcionEjercicio>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SelectorEjercicio(catalogo: widget.catalogo),
    );
    if (opcion == null || !mounted) return;
    final base = EjercicioRutina.deOpcion(opcion);
    final e = await _configurar(base.porTiempo ? base.copyWith(repeticiones: 40) : base);
    if (e != null) setState(() => _ejercicios.add(e));
  }

  Future<void> _editarEjercicio(int i) async {
    final e = await _configurar(_ejercicios[i]);
    if (e != null) setState(() => _ejercicios[i] = e);
  }

  Future<EjercicioRutina?> _configurar(EjercicioRutina e) => configurarEjercicio(context, e);

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
            const VacioMensaje(icon: Icons.fitness_center, texto: 'Agrega ejercicios desde el catálogo.')
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (a, b) => setState(() => _ejercicios.insert(b, _ejercicios.removeAt(a))),
              children: [
                for (var i = 0; i < _ejercicios.length; i++)
                  Padding(
                    key: ValueKey('${_ejercicios[i].nombre}-$i'),
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
                        title: Text(_ejercicios[i].nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
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

/// Lista de ejercicios para elegir uno, filtrable por grupo muscular.
class SelectorEjercicio extends StatefulWidget {
  const SelectorEjercicio({super.key, required this.catalogo, this.titulo = 'Elige un ejercicio'});
  final Future<List<OpcionEjercicio>> Function() catalogo;
  final String titulo;

  @override
  State<SelectorEjercicio> createState() => _SelectorEjercicioState();
}

class _SelectorEjercicioState extends State<SelectorEjercicio> {
  late final Future<List<OpcionEjercicio>> _datos = widget.catalogo();
  String? _musculo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: FutureBuilder(
          future: _datos,
          builder: (context, snap) {
            if (snap.hasError) return VacioMensaje(icon: Icons.cloud_off, texto: '${snap.error}');
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final opciones = snap.data!;
            final musculos = opciones.map((o) => o.musculo).where((m) => m.isNotEmpty).toSet().toList()..sort();
            final visibles = opciones.where((o) => _musculo == null || o.musculo == _musculo).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final m in [null, ...musculos])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(m ?? 'Todos'),
                            selected: _musculo == m,
                            selectedColor: (m == null ? FitColors.primary : colorMusculo(m)).withAlpha(60),
                            onSelected: (_) => setState(() => _musculo = m),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: visibles.isEmpty
                      ? const VacioMensaje(icon: Icons.search_off, texto: 'No hay ejercicios disponibles.')
                      : ListView(
                          children: [
                            for (final o in visibles)
                              OpcionEjercicioTile(
                                opcion: o,
                                onTap: () => Navigator.pop(context, o),
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

/// Tarjeta de un ejercicio del catálogo.
class OpcionEjercicioTile extends StatelessWidget {
  const OpcionEjercicioTile({super.key, required this.opcion, this.onTap, this.trailing});
  final OpcionEjercicio opcion;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
                MiniaturaEjercicio(musculo: opcion.musculo, imagen: opcion.imagen, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opcion.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (opcion.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(opcion.descripcion.replaceAll(RegExp(r'\s+'), ' '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MusculoChip(opcion.musculo),
                          if (opcion.detalle.isNotEmpty)
                            Text(opcion.detalle, style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
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

/// Pide series, repeticiones (o segundos) y, si [conPeso], el peso.
Future<EjercicioRutina?> configurarEjercicio(BuildContext context, EjercicioRutina e, {bool conPeso = true}) =>
    showDialog<EjercicioRutina>(context: context, builder: (_) => _ConfigEjercicio(ejercicio: e, conPeso: conPeso));

class _ConfigEjercicio extends StatefulWidget {
  const _ConfigEjercicio({required this.ejercicio, required this.conPeso});
  final EjercicioRutina ejercicio;

  /// Las rutinas del gimnasio no guardan peso (el backend no tiene ese campo).
  final bool conPeso;

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
      title: Text(e.nombre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Contador(label: 'Series', valor: _series, min: 1, max: 10, onChanged: (v) => setState(() => _series = v)),
          if (e.porTiempo)
            _Contador(
              label: 'Segundos',
              valor: _reps,
              min: 10,
              max: 300,
              paso: 5,
              onChanged: (v) => setState(() => _reps = v),
            )
          else
            _Contador(label: 'Repeticiones', valor: _reps, min: 1, max: 50, onChanged: (v) => setState(() => _reps = v)),
          if (widget.conPeso) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _peso,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: fitInput('Peso (kg, opcional)', Icons.monitor_weight_outlined),
          ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final peso = double.tryParse(_peso.text.replaceAll(',', '.'));
            Navigator.pop(
              context,
              e.copyWith(series: _series, repeticiones: _reps, pesoKg: peso, quitarPeso: peso == null),
            );
          },
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.label,
    required this.valor,
    required this.min,
    required this.max,
    required this.onChanged,
    this.paso = 1,
  });
  final String label;
  final int valor;
  final int min;
  final int max;
  final int paso;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton.filledTonal(
          onPressed: valor > min ? () => onChanged((valor - paso).clamp(min, max)) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 48,
          child: Text('$valor',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        IconButton.filledTonal(
          onPressed: valor < max ? () => onChanged((valor + paso).clamp(min, max)) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

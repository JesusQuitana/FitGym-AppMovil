import 'package:flutter/material.dart';

import '../../models/cliente.dart';
import '../../models/maquina.dart';
import '../../models/rutina.dart';
import '../../models/rutina_gym.dart';
import '../../services/api_service.dart';
import '../../services/gym_rutinas.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fitness.dart';
import '../rutinas/rutina_editor_screen.dart' show SelectorEjercicio, configurarEjercicio;
import '../rutinas/rutinas_tab.dart' show DiasSemana;

/// Rutinas que publica el gimnasio (tablas `rutina` y `rutina_ejercicio`):
/// generales para todos los afiliados o asignadas a uno en particular.
class RutinasGymAdminScreen extends StatefulWidget {
  const RutinasGymAdminScreen({super.key});

  @override
  State<RutinasGymAdminScreen> createState() => _RutinasGymAdminScreenState();
}

class _RutinasGymAdminScreenState extends State<RutinasGymAdminScreen> {
  List<(RutinaGym, List<EjercicioRutina>, List<RutinaEjercicioGym>)> _rutinas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await GymRutinas.paraAdmin();
      if (mounted) setState(() => _rutinas = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([(RutinaGym, List<EjercicioRutina>, List<RutinaEjercicioGym>)? actual]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _EditorRutinaGym(rutina: actual?.$1, ejercicios: actual?.$2 ?? [], filas: actual?.$3 ?? []),
    ));
    if (ok == true) await _cargar();
  }

  Future<void> _eliminar(RutinaGym r, List<RutinaEjercicioGym> filas) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Eliminar rutina'),
        content: const Text('Los afiliados dejarán de verla. ¿Eliminarla?'),
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
    try {
      await GymRutinas.eliminar(r.id!, filas);
      await _cargar();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas del gimnasio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        backgroundColor: FitColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva rutina'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: FitColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            const Text(
              'Las rutinas generales las ven todos los afiliados; las asignadas, solo esa persona.',
              style: TextStyle(color: FitColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (_cargando)
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              VacioMensaje(
                icon: Icons.cloud_off,
                texto: _error!,
                accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              )
            else if (_rutinas.isEmpty)
              const VacioMensaje(icon: Icons.event_note_outlined, texto: 'Todavía no hay rutinas publicadas.')
            else
              for (final item in _rutinas) _Tarjeta(item: item, onTap: () => _editar(item), onEliminar: () => _eliminar(item.$1, item.$3)),
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.item, required this.onTap, required this.onEliminar});
  final (RutinaGym, List<EjercicioRutina>, List<RutinaEjercicioGym>) item;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final (r, ejercicios, _) = item;
    final musculos = ejercicios.map((e) => e.musculo).where((m) => m.isNotEmpty).toSet().toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.esGeneral ? Icons.storefront : Icons.person_pin, size: 18, color: FitColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.esGeneral ? 'General' : 'Asignada a ${r.clienteNombre.isEmpty ? 'cliente #${r.clienteId}' : r.clienteNombre}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('${ejercicios.length} ejercicios', style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                    IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: onEliminar),
                  ],
                ),
                DiasSemana(dias: Rutina.parseDias(r.diaSemana)),
                if (musculos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final m in musculos) MusculoChip(m)]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorRutinaGym extends StatefulWidget {
  const _EditorRutinaGym({required this.rutina, required this.ejercicios, required this.filas});
  final RutinaGym? rutina;
  final List<EjercicioRutina> ejercicios;
  final List<RutinaEjercicioGym> filas;

  @override
  State<_EditorRutinaGym> createState() => _EditorRutinaGymState();
}

class _EditorRutinaGymState extends State<_EditorRutinaGym> {
  late final Set<int> _dias = Rutina.parseDias(widget.rutina?.diaSemana ?? '');
  late int? _clienteId = widget.rutina?.clienteId;
  late final List<EjercicioRutina> _ejercicios = [...widget.ejercicios];
  late final Future<List<Cliente>> _clientes = ApiService.instance.listarClientes();
  bool _guardando = false;

  late final Future<List<Maquina>> _maquinas = ApiService.instance.listarMaquinas();

  /// Ejercicios de wger que todavía no están en la rutina.
  Future<List<OpcionEjercicio>> _catalogo() async {
    final usados = _ejercicios.map((e) => e.wgerId).toSet();
    return (await GymRutinas.catalogo()).where((o) => !usados.contains(o.wgerId)).toList();
  }

  /// Máquina de este gimnasio donde se hace (opcional); primero las del
  /// mismo grupo muscular. null = cancelado; (null,) = sin máquina.
  Future<(Maquina?,)?> _elegirMaquina(OpcionEjercicio o) async {
    final todas = await _maquinas;
    if (!mounted) return null;
    final lista = [...todas]
      ..sort((a, b) => (a.musculo?.nombre == o.musculo ? 0 : 1).compareTo(b.musculo?.nombre == o.musculo ? 0 : 1));
    return showDialog<(Maquina?,)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: FitColors.surface,
        title: Text('¿En qué máquina se hace "${o.nombre}"?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, (null,)),
            child: Text('Ninguna en particular (${o.detalle})'),
          ),
          for (final m in lista)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, (m,)),
              child: Text(m.musculo == null ? m.nombre : '${m.nombre} · ${m.musculo!.nombre}'),
            ),
        ],
      ),
    );
  }

  Future<void> _agregar() async {
    final o = await showModalBottomSheet<OpcionEjercicio>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SelectorEjercicio(catalogo: _catalogo),
    );
    if (o == null || !mounted) return;
    final eleccion = await _elegirMaquina(o);
    if (eleccion == null || !mounted) return;
    final (maquina,) = eleccion;
    final base = EjercicioRutina.deOpcion(maquina == null
        ? o
        : OpcionEjercicio(
            nombre: o.nombre,
            musculo: o.musculo,
            detalle: maquina.nombre,
            descripcion: o.descripcion,
            wgerId: o.wgerId,
            imagen: o.imagen,
            maquinaId: maquina.id,
            porTiempo: o.porTiempo,
          ));
    final e = await configurarEjercicio(context, base, conPeso: false);
    if (e != null) setState(() => _ejercicios.add(e));
  }

  Future<void> _guardar() async {
    if (_dias.isEmpty) return showError(context, 'Elige al menos un día.');
    if (_ejercicios.isEmpty) return showError(context, 'Agrega al menos un ejercicio.');
    setState(() => _guardando = true);
    try {
      await GymRutinas.guardar(
        RutinaGym(id: widget.rutina?.id, diaSemana: Rutina.textoDias(_dias), clienteId: _clienteId),
        _ejercicios,
        widget.filas,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rutina == null ? 'Nueva rutina' : 'Editar rutina'),
        actions: [
          TextButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
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
          const Text('Días', style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          DiasSemana(dias: _dias, onTap: (d) => setState(() => _dias.contains(d) ? _dias.remove(d) : _dias.add(d))),
          const SizedBox(height: 20),
          FutureBuilder(
            future: _clientes,
            builder: (context, snap) => DropdownButtonFormField<int?>(
              initialValue: _clienteId,
              dropdownColor: FitColors.surfaceHigh,
              decoration: fitInput('¿Para quién?', Icons.groups_outlined),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos los afiliados (general)')),
                for (final c in snap.data ?? const <Cliente>[])
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.nombreCompleto)),
                // Si la lista aún no carga, conserva el cliente ya asignado.
                if (_clienteId != null && !(snap.data ?? const <Cliente>[]).any((c) => c.id == _clienteId))
                  DropdownMenuItem<int?>(
                    value: _clienteId,
                    child: Text(widget.rutina?.clienteNombre.isNotEmpty == true
                        ? widget.rutina!.clienteNombre
                        : 'Cliente #$_clienteId'),
                  ),
              ],
              onChanged: (v) => setState(() => _clienteId = v),
            ),
          ),
          const SizedBox(height: 20),
          Text('Ejercicios (${_ejercicios.length})', style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          if (_ejercicios.isEmpty)
            const VacioMensaje(icon: Icons.fitness_center, texto: 'Agrega ejercicios del catálogo del gimnasio.')
          else
            for (var i = 0; i < _ejercicios.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: FitColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onTap: () async {
                      final e = await configurarEjercicio(context, _ejercicios[i], conPeso: false);
                      if (e != null) setState(() => _ejercicios[i] = e);
                    },
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
    );
  }
}

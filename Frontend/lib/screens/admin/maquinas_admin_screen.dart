import 'package:flutter/material.dart';

import '../../models/maquina.dart';
import '../../services/api_service.dart';
import '../../services/gym_rutinas.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fitness.dart';

/// CRUD de máquinas para recepción (/maquina/...).
class MaquinasAdminScreen extends StatefulWidget {
  const MaquinasAdminScreen({super.key});

  @override
  State<MaquinasAdminScreen> createState() => _MaquinasAdminScreenState();
}

class _MaquinasAdminScreenState extends State<MaquinasAdminScreen> {
  List<Musculo> _musculos = [];
  List<Maquina> _maquinas = [];
  bool _cargando = true;
  String? _error;
  int? _musculoId;

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
      final api = ApiService.instance;
      // Los grupos musculares son las categorías de wger y se crean solos.
      final r = await Future.wait([GymRutinas.asegurarMusculosBase(), api.listarMaquinas()]);
      if (!mounted) return;
      setState(() {
        _musculos = r[0] as List<Musculo>;
        _maquinas = (r[1] as List<Maquina>)..sort((a, b) => a.nombre.compareTo(b.nombre));
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([Maquina? actual]) async {
    if (_musculos.isEmpty) {
      showError(context, 'No se pudieron cargar los grupos musculares. Reintenta.');
      return;
    }
    final guardada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditorMaquina(maquina: actual, musculos: _musculos),
    );
    if (guardada == true) await _cargar();
  }

  Future<void> _eliminar(Maquina m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Eliminar máquina'),
        content: Text('¿Eliminar "${m.nombre}"?'),
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
      await ApiService.instance.eliminarMaquina(m.id!);
      await _cargar();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _maquinas.where((m) => _musculoId == null || m.musculo?.id == _musculoId).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Máquinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        backgroundColor: FitColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva máquina'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: FitColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            FiltroMusculos(
              musculos: _musculos,
              seleccionado: _musculoId,
              onChanged: (id) => setState(() => _musculoId = id),
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
            else if (visibles.isEmpty)
              const VacioMensaje(icon: Icons.fitness_center, texto: 'No hay máquinas registradas.')
            else
              for (final m in visibles)
                MaquinaTile(
                  maquina: m,
                  onTap: () => _editar(m),
                  trailing: IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _eliminar(m),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _EditorMaquina extends StatefulWidget {
  const _EditorMaquina({required this.maquina, required this.musculos});
  final Maquina? maquina;
  final List<Musculo> musculos;

  @override
  State<_EditorMaquina> createState() => _EditorMaquinaState();
}

class _EditorMaquinaState extends State<_EditorMaquina> {
  late final _nombre = TextEditingController(text: widget.maquina?.nombre ?? '');
  late final _descripcion = TextEditingController(text: widget.maquina?.descripcion ?? '');
  late int _disponibilidad = widget.maquina?.disponibilidad ?? 1;
  late int? _musculoId = widget.maquina?.musculo?.id ?? widget.musculos.first.id;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'El nombre es obligatorio.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ApiService.instance.guardarMaquina(Maquina(
        id: widget.maquina?.id,
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        disponibilidad: _disponibilidad,
        musculo: widget.musculos.firstWhere((m) => m.id == _musculoId),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Dentro de la hoja: un SnackBar quedaría tapado por ella.
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.maquina == null ? 'Nueva máquina' : 'Editar máquina',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: fitInput('Nombre', Icons.fitness_center),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: fitInput('Descripción', Icons.notes),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _musculoId,
                dropdownColor: FitColors.surfaceHigh,
                decoration: fitInput('Grupo muscular', Icons.accessibility_new),
                items: [
                  for (final m in widget.musculos) DropdownMenuItem(value: m.id, child: Text(m.nombre)),
                ],
                onChanged: (v) => setState(() => _musculoId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Unidades en servicio')),
                  IconButton.filledTonal(
                    onPressed: _disponibilidad > 0 ? () => setState(() => _disponibilidad--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('$_disponibilidad',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setState(() => _disponibilidad++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_disponibilidad == 0)
                const Text('Con 0 unidades se muestra como "Fuera de servicio".',
                    style: TextStyle(color: FitColors.warning, fontSize: 12)),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: FitColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../models/maquina.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fitness.dart';

/// CRUD de grupos musculares para recepción (/MuscleGroup/...).
class MusculosAdminScreen extends StatefulWidget {
  const MusculosAdminScreen({super.key});

  @override
  State<MusculosAdminScreen> createState() => _MusculosAdminScreenState();
}

class _MusculosAdminScreenState extends State<MusculosAdminScreen> {
  List<Musculo> _musculos = [];
  Map<int?, int> _maquinasPorMusculo = {};
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
      final api = ApiService.instance;
      final r = await Future.wait([api.listarMusculos(), api.listarMaquinas()]);
      final conteo = <int?, int>{};
      for (final m in r[1] as List<Maquina>) {
        conteo[m.musculo?.id] = (conteo[m.musculo?.id] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _musculos = (r[0] as List<Musculo>)..sort((a, b) => a.nombre.compareTo(b.nombre));
        _maquinasPorMusculo = conteo;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([Musculo? actual]) async {
    final ctrl = TextEditingController(text: actual?.nombre ?? '');
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: Text(actual == null ? 'Nuevo grupo muscular' : 'Editar grupo muscular'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: fitInput('Nombre', Icons.accessibility_new, hint: 'Ej. Pecho'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (nombre == null || nombre.trim().isEmpty) return;
    try {
      await ApiService.instance.guardarMusculo(Musculo(id: actual?.id, nombre: nombre.trim()));
      await _cargar();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _eliminar(Musculo m) async {
    final ok = await _confirmar(context, '¿Eliminar el grupo "${m.nombre}"?');
    if (!ok) return;
    try {
      await ApiService.instance.eliminarMusculo(m.id!);
      await _cargar();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos musculares')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        backgroundColor: FitColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo grupo'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: FitColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            if (_cargando)
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              VacioMensaje(
                icon: Icons.cloud_off,
                texto: _error!,
                accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              )
            else if (_musculos.isEmpty)
              const VacioMensaje(icon: Icons.accessibility_new, texto: 'No hay grupos musculares registrados.')
            else
              for (final m in _musculos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: FitColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onTap: () => _editar(m),
                      leading: CircleAvatar(
                        backgroundColor: colorMusculo(m.nombre).withAlpha(45),
                        child: Icon(iconoMusculo(m.nombre), color: colorMusculo(m.nombre)),
                      ),
                      title: Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${_maquinasPorMusculo[m.id] ?? 0} máquinas',
                        style: const TextStyle(color: FitColors.textMuted),
                      ),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _eliminar(m),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmar(BuildContext context, String texto) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: FitColors.surface,
      title: const Text('Confirmar'),
      content: Text(texto),
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
  return ok == true;
}

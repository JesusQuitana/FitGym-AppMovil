import 'package:flutter/material.dart';

import '../../models/maquina.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/fitness.dart';

/// Catálogo de máquinas del gimnasio para el afiliado (GET /maquinas y
/// GET /MuscleGroups): filtro por grupo muscular, búsqueda y disponibilidad.
class MaquinasCatalogo extends StatefulWidget {
  const MaquinasCatalogo({super.key});

  @override
  State<MaquinasCatalogo> createState() => _MaquinasCatalogoState();
}

class _MaquinasCatalogoState extends State<MaquinasCatalogo> {
  List<Musculo> _musculos = [];
  List<Maquina> _maquinas = [];
  bool _cargando = true;
  String? _error;
  int? _musculoId;
  String _busqueda = '';

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

  List<Maquina> get _visibles {
    final q = _busqueda.trim().toLowerCase();
    return _maquinas.where((m) {
      if (_musculoId != null && m.musculo?.id != _musculoId) return false;
      return q.isEmpty || m.nombre.toLowerCase().contains(q) || m.descripcion.toLowerCase().contains(q);
    }).toList();
  }

  void _detalle(Maquina m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FitColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconoMusculo(m.musculo?.nombre ?? ''), color: colorMusculo(m.musculo?.nombre ?? ''), size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(m.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [MusculoChip(m.musculo?.nombre ?? ''), const SizedBox(width: 10), DisponibilidadBadge(m)]),
              const SizedBox(height: 14),
              Text(
                m.descripcion.isEmpty ? 'Sin descripción.' : m.descripcion,
                style: const TextStyle(color: FitColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    final disponibles = _maquinas.where((m) => m.disponible).length;
    return RefreshIndicator(
      onRefresh: _cargar,
      color: FitColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text('Máquinas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            _cargando ? 'Cargando…' : '$disponibles de ${_maquinas.length} en servicio',
            style: const TextStyle(color: FitColors.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: fitInput('Buscar máquina', Icons.search),
          ),
          const SizedBox(height: 10),
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
            const VacioMensaje(icon: Icons.search_off, texto: 'No hay máquinas que coincidan.')
          else
            for (final m in visibles) MaquinaTile(maquina: m, onTap: () => _detalle(m)),
        ],
      ),
    );
  }
}

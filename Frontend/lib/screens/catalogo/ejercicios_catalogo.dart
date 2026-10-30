import 'package:flutter/material.dart';

import '../../models/ejercicio_wger.dart';
import '../../services/plan_personal.dart';
import '../../services/session.dart';
import '../../services/wger.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/como_se_hace.dart';
import '../rutinas/rutina_editor_screen.dart' show OpcionEjercicioTile;
import 'maquinas_catalogo.dart';

/// Pestaña Ejercicios: el catálogo de wger filtrado según dónde entrena hoy
/// y, si vinculó un gimnasio, las máquinas de ese gimnasio.
class EjerciciosCatalogo extends StatefulWidget {
  const EjerciciosCatalogo({super.key, required this.perfil});
  final PerfilEntrenamiento? perfil;

  @override
  State<EjerciciosCatalogo> createState() => _EjerciciosCatalogoState();
}

class _EjerciciosCatalogoState extends State<EjerciciosCatalogo> {
  final Future<List<EjercicioWger>> _todos = Wger.catalogo();
  bool _verMaquinas = false;
  String? _musculo;
  String _busqueda = '';
  bool _soloAptos = true;

  @override
  Widget build(BuildContext context) {
    final conGimnasio = Session.instance.conGimnasio;
    return Column(
      children: [
        if (conGimnasio)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Ejercicios'), icon: Icon(Icons.sports_gymnastics)),
                ButtonSegment(value: true, label: Text('Máquinas'), icon: Icon(Icons.fitness_center)),
              ],
              selected: {_verMaquinas},
              onSelectionChanged: (s) => setState(() => _verMaquinas = s.first),
            ),
          ),
        Expanded(
          child: _verMaquinas && conGimnasio
              ? const MaquinasCatalogo()
              : FutureBuilder(
                  future: _todos,
                  builder: (context, snap) =>
                      snap.hasData ? _lista(snap.data!) : const Center(child: CircularProgressIndicator()),
                ),
        ),
      ],
    );
  }

  Widget _lista(List<EjercicioWger> todos) {
    final hoy = Session.instance.lugarHoy;
    final base = _soloAptos ? PlanPersonal.aptosHoy(widget.perfil, hoy, todos) : todos;
    final musculos = todos.map((e) => e.musculo).toSet().toList()..sort();
    final q = _busqueda.trim().toLowerCase();
    final visibles = base
        .where((e) => _musculo == null || e.musculo == _musculo)
        .where((e) => q.isEmpty || e.nombre.toLowerCase().contains(q))
        .toList();
    final dondeHoy = hoy == LugarHoy.gimnasio
        ? 'en el gimnasio (todo el equipo)'
        : 'en casa (${PlanPersonal.equipoHoy(widget.perfil, hoy).map((e) => e.etiqueta.toLowerCase()).join(', ')})';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('Ejercicios', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('${visibles.length} ejercicios · catálogo de wger.de', style: const TextStyle(color: FitColors.textMuted)),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => _busqueda = v),
          decoration: fitInput('Buscar ejercicio', Icons.search),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _soloAptos,
          onChanged: (v) => setState(() => _soloAptos = v),
          title: const Text('Solo los que puedo hacer hoy'),
          subtitle: Text('Entrenas $dondeHoy', style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
        ),
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
                    onSelected: (_) => setState(() => _musculo = m),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final e in visibles)
          OpcionEjercicioTile(
            opcion: PlanPersonal.opcion(e),
            onTap: () => mostrarComoSeHace(context, wgerId: e.id, nombre: e.nombre, musculo: e.musculo),
            trailing: const Icon(Icons.info_outline, color: FitColors.textMuted),
          ),
      ],
    );
  }
}

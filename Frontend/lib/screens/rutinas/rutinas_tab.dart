import 'package:flutter/material.dart';

import '../../models/rutina.dart';
import '../../services/rutinas_store.dart';
import '../../theme.dart';
import '../../widgets/fitness.dart';
import 'rutina_detalle_screen.dart';
import 'rutina_editor_screen.dart';

/// Planificador de rutinas del afiliado: las de hoy primero y luego todas.
class RutinasTab extends StatefulWidget {
  const RutinasTab({super.key, required this.clienteId});
  final int clienteId;

  @override
  State<RutinasTab> createState() => _RutinasTabState();
}

class _RutinasTabState extends State<RutinasTab> {
  List<Rutina> _rutinas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final r = await RutinasStore.cargar(widget.clienteId);
    if (mounted) {
      setState(() {
        _rutinas = r;
        _cargando = false;
      });
    }
  }

  Future<void> _guardar(List<Rutina> rutinas) async {
    setState(() => _rutinas = rutinas);
    await RutinasStore.guardar(widget.clienteId, rutinas);
  }

  Future<void> _nueva() async {
    final r = await Navigator.of(context).push<Rutina>(
      MaterialPageRoute(builder: (_) => const RutinaEditorScreen()),
    );
    if (r != null) await _guardar([..._rutinas, r]);
  }

  void _abrir(Rutina r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RutinaDetalleScreen(
        rutina: r,
        onGuardar: (nueva) => _guardar([for (final x in _rutinas) x.id == nueva.id ? nueva : x]),
        onEliminar: () => _guardar(_rutinas.where((x) => x.id != r.id).toList()),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().weekday;
    final deHoy = _rutinas.where((r) => r.esHoy).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mis rutinas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('Hoy es ${Rutina.nombresDias[hoy - 1].toLowerCase()}',
                      style: const TextStyle(color: FitColors.textMuted)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _nueva,
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_cargando)
          const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
        else if (_rutinas.isEmpty)
          VacioMensaje(
            icon: Icons.event_note_outlined,
            texto: 'Todavía no tienes rutinas.\nArma una con las máquinas del gimnasio y asígnale días de la semana.',
            accion: FilledButton.tonal(onPressed: _nueva, child: const Text('Crear mi primera rutina')),
          )
        else ...[
          if (deHoy.isNotEmpty) ...[
            const _Titulo('Para hoy'),
            for (final r in deHoy) _RutinaCard(rutina: r, destacada: true, onTap: () => _abrir(r)),
            const SizedBox(height: 10),
          ],
          const _Titulo('Todas'),
          for (final r in _rutinas) _RutinaCard(rutina: r, onTap: () => _abrir(r)),
        ],
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          texto.toUpperCase(),
          style: const TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      );
}

class _RutinaCard extends StatelessWidget {
  const _RutinaCard({required this.rutina, required this.onTap, this.destacada = false});
  final Rutina rutina;
  final VoidCallback onTap;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FitColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: destacada ? const BorderSide(color: FitColors.primary, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(rutina.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    Text(
                      '${rutina.ejercicios.length} ${rutina.ejercicios.length == 1 ? 'ejercicio' : 'ejercicios'}',
                      style: const TextStyle(color: FitColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DiasSemana(dias: rutina.dias),
                if (rutina.musculos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final m in rutina.musculos) MusculoChip(m)]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Los 7 días de la semana resaltando los de la rutina y el día de hoy.
class DiasSemana extends StatelessWidget {
  const DiasSemana({super.key, required this.dias});
  final Set<int> dias;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().weekday;
    return Row(
      children: [
        for (var d = 1; d <= 7; d++)
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dias.contains(d) ? FitColors.primary.withAlpha(dias.contains(d) && d == hoy ? 255 : 70) : FitColors.surfaceHigh,
              shape: BoxShape.circle,
              border: d == hoy ? Border.all(color: Colors.white54) : null,
            ),
            child: Text(
              Rutina.inicialesDias[d - 1],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dias.contains(d) ? Colors.white : FitColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// Muestra un mensaje breve de éxito.
void mostrarExito(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto), backgroundColor: FitColors.ok));
}

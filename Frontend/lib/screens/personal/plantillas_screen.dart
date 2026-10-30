import 'package:flutter/material.dart';

import '../../data/plantillas.dart';
import '../../models/ejercicio_wger.dart';
import '../../models/rutina.dart';
import '../../services/plan_personal.dart';
import '../../services/rutinas_store.dart';
import '../../services/wger.dart';
import '../../theme.dart';
import '../../widgets/fitness.dart';
import '../inicio.dart';
import '../../widgets/common.dart';

/// Plantillas recomendadas según el perfil, con vista previa de las rutinas
/// que generan. Elegir una agrega sus rutinas a "Mis rutinas".
class PlantillasScreen extends StatefulWidget {
  const PlantillasScreen({super.key, required this.perfil, this.desdeAsistente = false});
  final PerfilEntrenamiento perfil;

  /// En el primer uso, al terminar se entra a la app personal.
  final bool desdeAsistente;

  @override
  State<PlantillasScreen> createState() => _PlantillasScreenState();
}

class _PlantillasScreenState extends State<PlantillasScreen> {
  late final List<Plantilla> _recomendadas = PlanPersonal.recomendar(widget.perfil);
  late final List<Plantilla> _otras = PlanPersonal.recomendar(widget.perfil, maximo: plantillas.length)
      .where((t) => !_recomendadas.contains(t))
      .toList();
  String? _abierta;
  bool _guardando = false;
  List<EjercicioWger>? _catalogo;

  @override
  void initState() {
    super.initState();
    Wger.catalogo().then((c) {
      if (mounted) setState(() => _catalogo = c);
    });
  }

  Future<void> _usar(Plantilla t) async {
    setState(() => _guardando = true);
    final nuevas = PlanPersonal.generar(t, widget.perfil, _catalogo!);
    final actuales = await RutinasStore.cargar(RutinasStore.personal);
    await RutinasStore.guardar(RutinasStore.personal, [...actuales, ...nuevas]);
    if (!mounted) return;
    await _terminar('Agregamos ${nuevas.length} ${nuevas.length == 1 ? 'rutina' : 'rutinas'} de "${t.nombre}".');
  }

  Future<void> _terminar([String? mensaje]) async {
    // Esta pantalla se cierra al terminar: el mensaje va por el messenger global.
    final messenger = scaffoldMessengerKey.currentState;
    if (widget.desdeAsistente) {
      await irAlInicio(context);
    } else {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    if (mensaje != null) {
      messenger?.showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: FitColors.ok));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.perfil;
    final catalogo = _catalogo;
    if (catalogo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plantillas para ti')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas para ti')),
      body: AbsorbPointer(
        absorbing: _guardando,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              '${p.objetivo.etiqueta} · ${p.nivel.etiqueta} · ${p.dias} días de ${p.minutos} min · ${p.lugar.etiqueta.toLowerCase()}',
              style: const TextStyle(color: FitColors.textMuted),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _recomendadas.length; i++)
              _TarjetaPlantilla(
                plantilla: _recomendadas[i],
                perfil: p,
                catalogo: catalogo,
                recomendada: i == 0,
                abierta: _abierta == _recomendadas[i].id,
                onToggle: () => setState(() => _abierta = _abierta == _recomendadas[i].id ? null : _recomendadas[i].id),
                onUsar: () => _usar(_recomendadas[i]),
              ),
            if (_otras.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text('OTRAS QUE ENCAJAN CON TUS DÍAS',
                    style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ),
              for (final t in _otras)
                _TarjetaPlantilla(
                  plantilla: t,
                  perfil: p,
                  catalogo: catalogo,
                  abierta: _abierta == t.id,
                  onToggle: () => setState(() => _abierta = _abierta == t.id ? null : t.id),
                  onUsar: () => _usar(t),
                ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _terminar(),
              icon: const Icon(Icons.edit_note),
              label: const Text('Prefiero armar la mía desde cero'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPlantilla extends StatelessWidget {
  const _TarjetaPlantilla({
    required this.plantilla,
    required this.perfil,
    required this.catalogo,
    required this.abierta,
    required this.onToggle,
    required this.onUsar,
    this.recomendada = false,
  });

  final Plantilla plantilla;
  final PerfilEntrenamiento perfil;
  final List<EjercicioWger> catalogo;
  final bool abierta;
  final bool recomendada;
  final VoidCallback onToggle;
  final VoidCallback onUsar;

  @override
  Widget build(BuildContext context) {
    final rutinas = PlanPersonal.generar(plantilla, perfil, catalogo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: FitColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: recomendada ? const BorderSide(color: FitColors.primary, width: 1.5) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recomendada)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('★ RECOMENDADA',
                      style: TextStyle(color: FitColors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              Text(plantilla.nombre, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(plantilla.descripcion, style: const TextStyle(color: FitColors.textMuted, height: 1.35)),
              const SizedBox(height: 10),
              Text(
                '${rutinas.length} ${rutinas.length == 1 ? 'sesión distinta' : 'sesiones distintas'} · '
                '${PlanPersonal.ejerciciosPorSesion(perfil.minutos)} ejercicios por sesión',
                style: const TextStyle(fontSize: 13),
              ),
              if (abierta) ...[
                const Divider(height: 24),
                for (final r in rutinas) _Vista(rutina: r),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: onToggle, child: Text(abierta ? 'Ocultar' : 'Ver ejercicios')),
                  const Spacer(),
                  FilledButton(onPressed: onUsar, child: const Text('Usar esta plantilla')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({required this.rutina});
  final Rutina rutina;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(rutina.nombre, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(
                (rutina.dias.toList()..sort()).map((d) => Rutina.nombresDias[d - 1].substring(0, 3)).join(' · '),
                style: const TextStyle(color: FitColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final e in rutina.ejercicios)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: colorMusculo(e.musculo), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.nombre, style: const TextStyle(fontSize: 13))),
                  Text(e.resumen, style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

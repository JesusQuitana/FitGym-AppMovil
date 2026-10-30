import 'package:flutter/material.dart';

import '../../models/rutina.dart';
import '../../models/sesion.dart';
import '../../services/historial.dart';
import '../../services/recordatorios.dart';
import '../../services/rutinas_store.dart';
import '../../theme.dart';
import '../../widgets/fitness.dart';
import '../progreso/progreso_screen.dart';
import 'rutina_detalle_screen.dart';
import 'rutina_editor_screen.dart';

/// Planificador de rutinas. En modo gimnasio muestra también las rutinas
/// publicadas por el gimnasio (solo lectura, se pueden duplicar); las del
/// usuario se guardan en el teléfono.
class RutinasTab extends StatefulWidget {
  const RutinasTab({
    super.key,
    required this.espacio,
    required this.catalogo,
    this.rutinasGimnasio,
    this.onPlantillas,
  });

  /// Espacio de RutinasStore: id del cliente o 'personal'.
  final String espacio;

  /// Ejercicios disponibles para armar rutinas propias.
  final Future<List<OpcionEjercicio>> Function() catalogo;

  /// Rutinas del gimnasio (solo en modo gimnasio). El booleano indica que
  /// vienen de la copia guardada por falta de conexión.
  final Future<(List<Rutina>, bool)> Function()? rutinasGimnasio;

  /// Abre las plantillas sugeridas (solo en modo personal).
  final VoidCallback? onPlantillas;

  @override
  State<RutinasTab> createState() => _RutinasTabState();
}

class _RutinasTabState extends State<RutinasTab> {
  List<Rutina> _mias = [];
  List<Rutina> _gimnasio = [];
  bool _cargando = true;
  String? _errorGimnasio;
  bool _gimnasioDesdeCopia = false;
  List<SesionEntrenamiento> _historial = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final mias = await RutinasStore.cargar(widget.espacio);
    final historial = await Historial.cargar(widget.espacio);
    var gym = <Rutina>[];
    var desdeCopia = false;
    String? error;
    if (widget.rutinasGimnasio != null) {
      try {
        (gym, desdeCopia) = await widget.rutinasGimnasio!();
      } catch (e) {
        error = '$e';
      }
    }
    if (!mounted) return;
    setState(() {
      _mias = mias;
      _historial = historial;
      _gimnasio = gym;
      _gimnasioDesdeCopia = desdeCopia;
      _errorGimnasio = error;
      _cargando = false;
    });
    _reprogramarAvisos();
  }

  Future<void> _guardar(List<Rutina> rutinas) async {
    setState(() => _mias = rutinas);
    await RutinasStore.guardar(widget.espacio, rutinas);
    _reprogramarAvisos();
  }

  /// Recordatorio semanal para cada día que tiene alguna rutina.
  void _reprogramarAvisos() {
    final porDia = <int, List<String>>{};
    for (final r in [..._gimnasio, ..._mias]) {
      for (final d in r.dias) {
        porDia.putIfAbsent(d, () => []).add(r.nombre);
      }
    }
    Recordatorios.programarEntrenamientos(porDia);
  }

  Future<void> _configurarAviso() async {
    final cambio = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: FitColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AvisoEntrenamiento(),
    );
    if (cambio == true) _reprogramarAvisos();
  }

  Future<void> _nueva([Rutina? base]) async {
    final r = await Navigator.of(context).push<Rutina>(
      MaterialPageRoute(builder: (_) => RutinaEditorScreen(rutina: base, catalogo: widget.catalogo)),
    );
    if (r != null) await _guardar([..._mias, r]);
  }

  /// Copia una rutina del gimnasio a "Mías" para poder modificarla.
  Future<void> _duplicar(Rutina r) => _nueva(Rutina(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: '${r.nombre} (mi versión)',
        dias: {...r.dias},
        ejercicios: [...r.ejercicios],
      ));

  Future<void> _progreso() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgresoScreen(espacio: widget.espacio)));
    await _cargar();
  }

  Future<void> _abrir(Rutina r) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => r.esDelGimnasio
          ? RutinaDetalleScreen(
              rutina: r,
              catalogo: widget.catalogo,
              espacio: widget.espacio,
              onDuplicar: () => _duplicar(r),
            )
          : RutinaDetalleScreen(
              rutina: r,
              catalogo: widget.catalogo,
              espacio: widget.espacio,
              onGuardar: (nueva) => _guardar([for (final x in _mias) x.id == nueva.id ? nueva : x]),
              onEliminar: () => _guardar(_mias.where((x) => x.id != r.id).toList()),
            ),
    ));
    // Puede haberse registrado un entrenamiento.
    _historial = await Historial.cargar(widget.espacio);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().weekday;
    final conGimnasio = widget.rutinasGimnasio != null;
    final deHoy = [..._gimnasio, ..._mias].where((r) => r.esHoy).toList();
    return RefreshIndicator(
      onRefresh: _cargar,
      color: FitColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rutinas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Hoy es ${Rutina.nombresDias[hoy - 1].toLowerCase()}',
                        style: const TextStyle(color: FitColors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Recordatorio de entrenamiento',
                onPressed: _configurarAviso,
                icon: const Icon(Icons.notifications_none),
              ),
              if (widget.onPlantillas != null) ...[
                IconButton.filledTonal(
                  tooltip: 'Plantillas',
                  onPressed: widget.onPlantillas,
                  icon: const Icon(Icons.auto_awesome),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(onPressed: _nueva, icon: const Icon(Icons.add), label: const Text('Nueva')),
            ],
          ),
          const SizedBox(height: 14),
          _ResumenProgreso(historial: _historial, onTap: _progreso),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else ...[
            if (deHoy.isNotEmpty) ...[
              const _Titulo('Para hoy'),
              for (final r in deHoy) _RutinaCard(rutina: r, destacada: true, onTap: () => _abrir(r)),
              const SizedBox(height: 10),
            ],
            if (conGimnasio) ...[
              const _Titulo('De tu gimnasio'),
              if (_errorGimnasio != null)
                VacioMensaje(
                  icon: Icons.cloud_off,
                  texto: 'No se pudieron cargar las rutinas del gimnasio.\n$_errorGimnasio',
                  accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                )
              else if (_gimnasio.isEmpty)
                const _Nota('Tu gimnasio todavía no publicó rutinas.')
              else ...[
                if (_gimnasioDesdeCopia)
                  const _Nota('Sin conexión: mostrando la última copia guardada. Desliza hacia abajo para actualizar.'),
                for (final r in _gimnasio) _RutinaCard(rutina: r, onTap: () => _abrir(r)),
              ],
              const SizedBox(height: 10),
            ],
            _Titulo(conGimnasio ? 'Mías' : 'Mis rutinas'),
            if (_mias.isEmpty)
              VacioMensaje(
                icon: Icons.event_note_outlined,
                texto: conGimnasio
                    ? 'Crea tus propias rutinas o duplica una del gimnasio para personalizarla.'
                    : 'Todavía no tienes rutinas.\nElige una plantilla o arma la tuya desde cero.',
                accion: Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.onPlantillas != null)
                      FilledButton.tonal(onPressed: widget.onPlantillas, child: const Text('Ver plantillas')),
                    OutlinedButton(onPressed: _nueva, child: const Text('Crear desde cero')),
                  ],
                ),
              )
            else
              for (final r in _mias) _RutinaCard(rutina: r, onTap: () => _abrir(r)),
          ],
        ],
      ),
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

class _Nota extends StatelessWidget {
  const _Nota(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(texto, style: const TextStyle(color: FitColors.textMuted)),
      );
}

class _RutinaCard extends StatelessWidget {
  const _RutinaCard({required this.rutina, required this.onTap, this.destacada = false});
  final Rutina rutina;
  final VoidCallback onTap;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final etiqueta = rutina.etiqueta;
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
                if (etiqueta != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        rutina.origen == OrigenRutina.gimnasioAsignada ? Icons.person_pin : Icons.storefront,
                        size: 14,
                        color: FitColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(etiqueta,
                          style: const TextStyle(color: FitColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
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
  const DiasSemana({super.key, required this.dias, this.onTap});
  final Set<int> dias;

  /// Si se indica, cada día se puede tocar para activarlo o desactivarlo.
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().weekday;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var d = 1; d <= 7; d++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(d),
            child: Container(
              width: onTap == null ? 30 : 38,
              height: onTap == null ? 30 : 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dias.contains(d) ? FitColors.primary.withAlpha(d == hoy ? 255 : 110) : FitColors.surfaceHigh,
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
          ),
      ],
    );
  }
}

/// Tarjeta con la semana actual y la racha; abre "Mi progreso".
class _ResumenProgreso extends StatelessWidget {
  const _ResumenProgreso({required this.historial, required this.onTap});
  final List<SesionEntrenamiento> historial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semana = Historial.porSemana(historial, n: 1).first.$2;
    final racha = Historial.rachaSemanas(historial);
    return Material(
      color: FitColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              const Icon(Icons.insights, color: FitColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  historial.isEmpty
                      ? 'Registra tus entrenamientos y mira tu progreso'
                      : 'Esta semana: $semana ${semana == 1 ? 'entrenamiento' : 'entrenamientos'}'
                          '${racha > 1 ? ' · racha de $racha semanas 🔥' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, color: FitColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoEntrenamiento extends StatefulWidget {
  const _AvisoEntrenamiento();

  @override
  State<_AvisoEntrenamiento> createState() => _AvisoEntrenamientoState();
}

class _AvisoEntrenamientoState extends State<_AvisoEntrenamiento> {
  bool? _activo;
  int _minutos = 18 * 60;

  @override
  void initState() {
    super.initState();
    Recordatorios.preferenciaEntrenar().then((p) {
      if (mounted) {
        setState(() {
          _activo = p.$1;
          _minutos = p.$2;
        });
      }
    });
  }

  String get _hora => '${(_minutos ~/ 60).toString().padLeft(2, '0')}:${(_minutos % 60).toString().padLeft(2, '0')}';

  Future<void> _elegirHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutos ~/ 60, minute: _minutos % 60),
    );
    if (t != null) setState(() => _minutos = t.hour * 60 + t.minute);
  }

  @override
  Widget build(BuildContext context) {
    final activo = _activo;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: activo == null
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Recordatorio de entrenamiento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Te avisamos los días que tienes una rutina.', style: TextStyle(color: FitColors.textMuted)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: activo,
                    onChanged: (v) => setState(() => _activo = v),
                    title: const Text('Recordarme entrenar'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: activo,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Hora del aviso'),
                    trailing: Text(_hora, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    onTap: _elegirHora,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      await Recordatorios.guardarPreferenciaEntrenar(activo, _minutos);
                      if (context.mounted) Navigator.pop(context, true);
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Muestra un mensaje breve de éxito.
void mostrarExito(BuildContext context, String texto) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto), backgroundColor: FitColors.ok));
}

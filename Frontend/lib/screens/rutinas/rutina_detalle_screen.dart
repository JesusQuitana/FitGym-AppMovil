import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/rutina.dart';
import '../../models/sesion.dart';
import '../../services/historial.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/como_se_hace.dart';
import '../../widgets/fitness.dart';
import 'rutina_editor_screen.dart';
import 'rutinas_tab.dart';

/// Detalle de una rutina y modo entrenamiento: se marcan las series hechas,
/// se anota el peso, corre un temporizador de descanso y al terminar se
/// guarda la sesión en el historial con sugerencias de progresión.
class RutinaDetalleScreen extends StatefulWidget {
  const RutinaDetalleScreen({
    super.key,
    required this.rutina,
    required this.catalogo,
    required this.espacio,
    this.onGuardar,
    this.onEliminar,
    this.onDuplicar,
  });

  final Rutina rutina;
  final Future<List<OpcionEjercicio>> Function() catalogo;

  /// Espacio del historial (id del cliente o 'personal').
  final String espacio;

  /// Solo para rutinas propias; las del gimnasio son de solo lectura.
  final Future<void> Function(Rutina)? onGuardar;
  final Future<void> Function()? onEliminar;

  /// Para rutinas del gimnasio: copiarla a "Mías" para personalizarla.
  final Future<void> Function()? onDuplicar;

  @override
  State<RutinaDetalleScreen> createState() => _RutinaDetalleScreenState();
}

class _RutinaDetalleScreenState extends State<RutinaDetalleScreen> {
  static const _opcionesDescanso = [60, 90, 120];

  late Rutina _rutina = widget.rutina;

  /// Series hechas por ejercicio (índice → cantidad).
  final Map<int, int> _hechas = {};

  /// Peso anotado por ejercicio en esta sesión.
  final Map<int, double?> _pesos = {};
  List<SesionEntrenamiento> _historial = [];
  DateTime? _inicio;

  int _descansoTotal = 90;
  int? _descansoRestante;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Precarga el peso: el último usado en ese ejercicio o el de la rutina.
  Future<void> _cargarHistorial() async {
    final h = await Historial.cargar(widget.espacio);
    if (!mounted) return;
    final ultimos = Historial.ultimosPesos(h);
    setState(() {
      _historial = h;
      for (var i = 0; i < _rutina.ejercicios.length; i++) {
        final e = _rutina.ejercicios[i];
        _pesos[i] = ultimos[e.nombre] ?? e.pesoKg;
      }
    });
  }

  int get _totalSeries => _rutina.ejercicios.fold(0, (a, e) => a + e.series);
  int get _seriesHechas => _hechas.values.fold(0, (a, b) => a + b);

  void _tocarSerie(int i, int serie) {
    final actuales = _hechas[i] ?? 0;
    // Tocar una serie ya marcada la desmarca (y las siguientes).
    final nuevas = serie < actuales ? serie : serie + 1;
    setState(() {
      _hechas[i] = nuevas;
      _inicio ??= DateTime.now();
    });
    if (nuevas > actuales && _seriesHechas < _totalSeries) _iniciarDescanso();
  }

  void _iniciarDescanso() {
    _timer?.cancel();
    setState(() => _descansoRestante = _descansoTotal);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final r = (_descansoRestante ?? 0) - 1;
      if (r <= 0) {
        t.cancel();
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        if (mounted) setState(() => _descansoRestante = null);
      } else if (mounted) {
        setState(() => _descansoRestante = r);
      }
    });
  }

  void _saltarDescanso() {
    _timer?.cancel();
    setState(() => _descansoRestante = null);
  }

  Future<void> _anotarPeso(int i) async {
    final ctrl = TextEditingController(text: _pesos[i] == null ? '' : _kg(_pesos[i]!));
    final valor = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: Text(_rutina.ejercicios[i].nombre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: fitInput('Peso usado (kg)', Icons.monitor_weight_outlined, hint: 'Vacío = sin peso'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Listo')),
        ],
      ),
    );
    if (valor != null) setState(() => _pesos[i] = double.tryParse(valor.replaceAll(',', '.')));
  }

  Future<void> _terminar() async {
    _saltarDescanso();
    final sesion = SesionEntrenamiento(
      fecha: DateTime.now(),
      rutinaId: _rutina.id,
      rutinaNombre: _rutina.nombre,
      duracion: DateTime.now().difference(_inicio ?? DateTime.now()),
      ejercicios: [
        for (var i = 0; i < _rutina.ejercicios.length; i++)
          EjercicioSesion(
            nombre: _rutina.ejercicios[i].nombre,
            musculo: _rutina.ejercicios[i].musculo,
            seriesPlan: _rutina.ejercicios[i].series,
            repeticiones: _rutina.ejercicios[i].repeticiones,
            seriesHechas: _hechas[i] ?? 0,
            pesoKg: _pesos[i],
            porTiempo: _rutina.ejercicios[i].porTiempo,
          ),
      ],
    );
    final sugerencias = Historial.sugerencias(sesion, _historial);
    await Historial.agregar(widget.espacio, sesion);
    if (!mounted) return;
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (_) => _Resumen(sesion: sesion, sugerencias: sugerencias, puedeAplicar: widget.onGuardar != null),
    );
    if (aplicar == true && sugerencias.isNotEmpty) {
      final nueva = Historial.aplicar(_rutina, sugerencias);
      await widget.onGuardar!(nueva);
      _rutina = nueva;
    }
    if (!mounted) return;
    setState(() {
      _hechas.clear();
      _inicio = null;
    });
    await _cargarHistorial();
  }

  Future<void> _editar() async {
    final r = await Navigator.of(context).push<Rutina>(
      MaterialPageRoute(builder: (_) => RutinaEditorScreen(rutina: _rutina, catalogo: widget.catalogo)),
    );
    if (r == null) return;
    await widget.onGuardar!(r);
    if (!mounted) return;
    setState(() {
      _rutina = r;
      _hechas.clear();
    });
    await _cargarHistorial();
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar "${_rutina.nombre}"? Esta acción no se puede deshacer.'),
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
    await widget.onEliminar!();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalSeries;
    final progreso = total == 0 ? 0.0 : _seriesHechas / total;
    return Scaffold(
      appBar: AppBar(
        title: Text(_rutina.nombre),
        actions: [
          if (widget.onDuplicar != null)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await widget.onDuplicar!();
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Duplicar'),
            ),
          if (widget.onGuardar != null)
            IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: _editar),
          if (widget.onEliminar != null)
            IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
        ],
      ),
      bottomNavigationBar: _seriesHechas == 0 && _descansoRestante == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_descansoRestante != null) ...[
                    _Descanso(
                      restante: _descansoRestante!,
                      total: _descansoTotal,
                      onMas: () => setState(() => _descansoRestante = _descansoRestante! + 15),
                      onSaltar: _saltarDescanso,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_seriesHechas > 0)
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _terminar,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Terminar entrenamiento'),
                      ),
                    ),
                ],
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_rutina.etiqueta != null) ...[
            Text(
              _rutina.origen == OrigenRutina.gimnasioAsignada
                  ? 'Tu gimnasio preparó esta rutina para ti. Para cambiarla, toca "Duplicar".'
                  : 'Rutina publicada por tu gimnasio. Para cambiarla, toca "Duplicar".',
              style: const TextStyle(color: FitColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          DiasSemana(dias: _rutina.dias),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 8,
                    backgroundColor: FitColors.surfaceHigh,
                    color: FitColors.ok,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$_seriesHechas/$total series', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: FitColors.textMuted),
              const SizedBox(width: 6),
              const Text('Descanso', style: TextStyle(color: FitColors.textMuted)),
              const SizedBox(width: 8),
              for (final s in _opcionesDescanso)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$s s'),
                    visualDensity: VisualDensity.compact,
                    selected: _descansoTotal == s,
                    selectedColor: FitColors.primary.withAlpha(70),
                    onSelected: (_) => setState(() => _descansoTotal = s),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _rutina.ejercicios.length; i++)
            _EjercicioItem(
              numero: i + 1,
              ejercicio: _rutina.ejercicios[i],
              hechas: _hechas[i] ?? 0,
              pesoKg: _pesos[i],
              onSerie: (s) => _tocarSerie(i, s),
              onPeso: () => _anotarPeso(i),
            ),
          const SizedBox(height: 4),
          const Text(
            'Toca cada círculo al terminar una serie: arranca el descanso. Toca el peso para anotarlo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FitColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _kg(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _duracion(Duration d) {
  final m = d.inMinutes;
  return m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
}

class _EjercicioItem extends StatelessWidget {
  const _EjercicioItem({
    required this.numero,
    required this.ejercicio,
    required this.hechas,
    required this.pesoKg,
    required this.onSerie,
    required this.onPeso,
  });

  final int numero;
  final EjercicioRutina ejercicio;
  final int hechas;
  final double? pesoKg;
  final ValueChanged<int> onSerie;
  final VoidCallback onPeso;

  @override
  Widget build(BuildContext context) {
    final completo = hechas >= ejercicio.series;
    final color = colorMusculo(ejercicio.musculo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: completo ? FitColors.ok.withAlpha(25) : FitColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: color.withAlpha(45),
                  child: completo
                      ? const Icon(Icons.check, size: 16, color: FitColors.ok)
                      : Text('$numero', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => mostrarComoSeHace(
                          context,
                          wgerId: ejercicio.wgerId,
                          nombre: ejercicio.nombre,
                          musculo: ejercicio.musculo,
                          detalle: ejercicio.detalle,
                        ),
                        child: Row(
                          children: [
                            Flexible(child: Text(ejercicio.nombre, style: const TextStyle(fontWeight: FontWeight.w700))),
                            const SizedBox(width: 4),
                            const Icon(Icons.info_outline, size: 16, color: FitColors.textMuted),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MusculoChip(ejercicio.musculo),
                          Text(ejercicio.resumen, style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                          if (ejercicio.detalle.isNotEmpty && !ejercicio.porTiempo)
                            Text(ejercicio.detalle, style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!ejercicio.porTiempo)
                  ActionChip(
                    avatar: const Icon(Icons.monitor_weight_outlined, size: 16),
                    label: Text(pesoKg == null ? 'Peso' : '${_kg(pesoKg!)} kg'),
                    onPressed: onPeso,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var s = 0; s < ejercicio.series; s++)
                  Semantics(
                    key: ValueKey('serie-${numero - 1}-$s'),
                    button: true,
                    label: 'Serie ${s + 1}${s < hechas ? ', hecha' : ''}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onSerie(s),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s < hechas ? FitColors.ok : FitColors.surfaceHigh,
                        ),
                        child: Text(
                          s < hechas ? '✓' : '${s + 1}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: s < hechas ? Colors.black : Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Descanso extends StatelessWidget {
  const _Descanso({required this.restante, required this.total, required this.onMas, required this.onSaltar});
  final int restante;
  final int total;
  final VoidCallback onMas;
  final VoidCallback onSaltar;

  @override
  Widget build(BuildContext context) {
    final texto = '${restante ~/ 60}:${(restante % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: FitColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: restante / (restante > total ? restante : total),
              strokeWidth: 4,
              backgroundColor: FitColors.surface,
              color: FitColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Descanso', style: TextStyle(color: FitColors.textMuted, fontSize: 12)),
                Text(texto,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          TextButton(onPressed: onMas, child: const Text('+15 s')),
          TextButton(onPressed: onSaltar, child: const Text('Saltar')),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.sesion, required this.sugerencias, required this.puedeAplicar});
  final SesionEntrenamiento sesion;
  final List<Sugerencia> sugerencias;
  final bool puedeAplicar;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FitColors.surface,
      icon: const Icon(Icons.emoji_events_outlined, color: FitColors.vip, size: 44),
      title: const Text('¡Entrenamiento guardado!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Dato(valor: _duracion(sesion.duracion), etiqueta: 'Duración'),
              _Dato(valor: '${sesion.seriesHechas}/${sesion.seriesPlan}', etiqueta: 'Series'),
              _Dato(valor: '${_kg(sesion.volumenKg)} kg', etiqueta: 'Volumen'),
            ],
          ),
          if (sugerencias.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('Completaste estos ejercicios dos veces seguidas. ¡Es momento de subir!',
                style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            for (final s in sugerencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, size: 18, color: FitColors.ok),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${s.ejercicio}: ${s.texto.toLowerCase()}')),
                  ],
                ),
              ),
          ],
        ],
      ),
      actions: [
        if (sugerencias.isNotEmpty && puedeAplicar) ...[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aplicar a la rutina')),
        ] else
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Listo')),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(etiqueta, style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
        ],
      );
}

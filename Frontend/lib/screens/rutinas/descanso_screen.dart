import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import '../../widgets/editorial.dart';

/// Duración del descanso recordada por ejercicio (en el teléfono).
class Descansos {
  Descansos._();

  static const porDefecto = 90;
  static const minimo = 15;
  static const maximo = 600;

  static String clave(String ejercicio) => 'descanso_$ejercicio';

  static Future<int> cargar(String ejercicio) async {
    try {
      final s = (await SharedPreferences.getInstance()).getInt(clave(ejercicio));
      return (s ?? porDefecto).clamp(minimo, maximo);
    } catch (_) {
      return porDefecto;
    }
  }

  static Future<void> guardar(String ejercicio, int segundos) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(clave(ejercicio), segundos);
    } catch (_) {}
  }
}

/// Descanso entre series: pantalla oscura (en los dos temas) con la cuenta
/// atrás, −15 s / +15 s / Saltar, lo que viene y las series ya hechas. Se
/// cierra sola al llegar a cero (vibra y suena) o al tocar "Saltar".
class DescansoScreen extends StatefulWidget {
  const DescansoScreen({
    super.key,
    required this.ejercicio,
    required this.serieGuardada,
    required this.siguienteTitulo,
    required this.siguienteDetalle,
    required this.hechas,
    required this.series,
    required this.seriesHechas,
    required this.inicio,
  });

  /// Ejercicio cuya serie se acaba de guardar (su descanso se recuerda).
  final String ejercicio;
  final int serieGuardada;

  /// "Serie 3 de 4" y "Prensa de piernas · 12 reps · 80 kg".
  final String siguienteTitulo;
  final String siguienteDetalle;

  /// Series hechas del ejercicio, ya como texto ("12 × 80 kg").
  final List<String> hechas;

  /// Series planeadas y hechas por ejercicio (para los segmentos de arriba).
  final List<int> series;
  final List<int> seriesHechas;
  final DateTime inicio;

  @override
  State<DescansoScreen> createState() => _DescansoScreenState();
}

class _DescansoScreenState extends State<DescansoScreen> {
  static const _papel = FitColors.papel;
  static final _suave = FitColors.temaOscuro.textoSuave;
  static final _linea = FitColors.temaOscuro.linea;
  static const _borde = Color(0xFF3A3A36);
  static final _rojo = FitColors.temaOscuro.danger;

  int? _total;
  int _restante = Descansos.porDefecto;
  Timer? _timer;
  bool _cerrado = false;

  @override
  void initState() {
    super.initState();
    Descansos.cargar(widget.ejercicio).then((s) {
      if (!mounted) return;
      setState(() {
        _total = s;
        _restante = s;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tic() {
    final r = _restante - 1;
    if (r <= 0) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      _salir();
    } else if (mounted) {
      setState(() => _restante = r);
    }
  }

  void _salir() {
    if (_cerrado || !mounted) return;
    _cerrado = true;
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  void _ajustar(int delta) {
    final total = _total;
    if (total == null) return;
    final nuevo = (total + delta).clamp(Descansos.minimo, Descansos.maximo);
    setState(() {
      _total = nuevo;
      _restante = (_restante + delta).clamp(1, Descansos.maximo);
    });
    Descansos.guardar(widget.ejercicio, nuevo);
  }

  @override
  Widget build(BuildContext context) {
    final total = _total ?? Descansos.porDefecto;
    final texto = '${_restante ~/ 60}:${(_restante % 60).toString().padLeft(2, '0')}';
    final fraccion = (_restante / (_restante > total ? _restante : total)).clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: FitColors.carbon,
        body: SafeArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: _papel),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SegmentosProgreso(
                                series: widget.series,
                                hechas: widget.seriesHechas,
                                lleno: _papel,
                                vacio: _borde,
                              ),
                            ),
                            const SizedBox(width: 10),
                            RelojTranscurrido(inicio: widget.inicio, color: _papel),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Row(
                          children: [
                            Text('Descanso', style: estiloEtiqueta(color: _rojo, size: 12).copyWith(letterSpacing: 2)),
                            Flexible(
                              child: Text(
                                ' · serie ${widget.serieGuardada} guardada',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: estiloEtiqueta(color: _rojo, size: 12).copyWith(letterSpacing: 2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          label: 'Quedan $_restante segundos de descanso',
                          excludeSemantics: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              texto,
                              style: estiloCifra(150, color: _papel)
                                  .copyWith(height: 0.85, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          height: 8,
                          color: _borde,
                          alignment: Alignment.centerLeft,
                          child: AnimatedFractionallySizedBox(
                            duration: sinMovimiento(context) ? Duration.zero : const Duration(seconds: 1),
                            curve: Curves.linear,
                            widthFactor: fraccion,
                            heightFactor: 1,
                            child: ColoredBox(color: FitColors.accent),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: _BotonDescanso(texto: '−15 s', borde: _borde, onTap: () => _ajustar(-15))),
                            const SizedBox(width: 8),
                            Expanded(child: _BotonDescanso(texto: '+15 s', borde: _borde, onTap: () => _ajustar(15))),
                            const SizedBox(width: 8),
                            Expanded(child: _BotonDescanso(texto: 'Saltar', borde: _papel, onTap: _salir)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Se recuerda para la próxima: $total s en este ejercicio.',
                          style: TextStyle(color: _suave, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: FitColors.temaOscuro.superficie,
                            border: Border.all(color: _linea),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LO QUE VIENE', style: estiloEtiqueta(color: _suave).copyWith(letterSpacing: 2)),
                              const SizedBox(height: 6),
                              Text(
                                widget.siguienteTitulo.toUpperCase(),
                                style: estiloCifra(30, color: _papel),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.siguienteDetalle,
                                style: const TextStyle(color: _papel, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < widget.hechas.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _linea))),
                            child: Row(
                              children: [
                                Text('Serie ${i + 1}', style: TextStyle(color: _suave, fontSize: 13)),
                                const Spacer(),
                                Text(
                                  '${widget.hechas[i]} ✓',
                                  style: const TextStyle(color: _papel, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonDescanso extends StatelessWidget {
  const _BotonDescanso({required this.texto, required this.borde, required this.onTap});
  final String texto;
  final Color borde;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: borde, width: 2)),
            child: Text(
              texto,
              style: const TextStyle(color: FitColors.papel, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
}

/// Segmentos de progreso: uno por ejercicio, de ancho proporcional a sus
/// series, llenos según las series hechas.
class SegmentosProgreso extends StatelessWidget {
  const SegmentosProgreso({
    super.key,
    required this.series,
    required this.hechas,
    required this.lleno,
    required this.vacio,
    this.etiqueta,
  });
  final List<int> series;
  final List<int> hechas;
  final Color lleno;
  final Color vacio;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final total = series.fold(0, (a, b) => a + b);
    final hechasTotal = hechas.fold(0, (a, b) => a + b);
    return Semantics(
      label: etiqueta ?? '$hechasTotal de $total series hechas',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < series.length; i++)
            if (series[i] > 0)
              Expanded(
                flex: series[i],
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  child: Container(
                    height: 6,
                    color: vacio,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (hechas[i] / series[i]).clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: ColoredBox(color: lleno),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Tiempo transcurrido desde [inicio] ("12:48"), actualizado cada segundo.
class RelojTranscurrido extends StatefulWidget {
  const RelojTranscurrido({super.key, required this.inicio, required this.color});
  final DateTime inicio;
  final Color color;

  @override
  State<RelojTranscurrido> createState() => _RelojTranscurridoState();
}

class _RelojTranscurridoState extends State<RelojTranscurrido> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.inicio);
    final s = d.inSeconds % 60;
    final m = d.inMinutes % 60;
    final texto = d.inHours > 0
        ? '${d.inHours}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
    return Semantics(
      label: 'Tiempo de entrenamiento',
      child: Text(
        texto,
        style: estiloCifra(18, color: widget.color, weight: FontWeight.w800)
            .copyWith(fontStyle: FontStyle.normal, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

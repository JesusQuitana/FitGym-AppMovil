import 'package:flutter/material.dart';

import '../../models/ejercicio_wger.dart';
import '../../models/rutina.dart';
import '../../models/sesion.dart';
import '../../theme.dart';
import '../../widgets/como_se_hace.dart';
import '../../widgets/editorial.dart';
import 'descanso_screen.dart';

/// Modo entrenamiento: una serie a la vez. Se ajustan peso y repeticiones,
/// "Serie hecha" guarda la serie y arranca el descanso; tras la última serie
/// (o con "Terminar entrenamiento") se arma la sesión y se entrega a
/// [onTerminar], que la guarda y muestra el resumen.
class EntrenamientoScreen extends StatefulWidget {
  const EntrenamientoScreen({
    super.key,
    required this.rutina,
    required this.ultimosPesos,
    required this.onTerminar,
    this.imagenes = const {},
    this.wgerEjercicios = const {},
  });

  final Rutina rutina;

  /// Último peso usado por ejercicio (por nombre), de [Historial.ultimosPesos].
  final Map<String, double> ultimosPesos;

  /// Imagen de cada ejercicio (por índice), si se encontró en wger.
  final Map<int, String?> imagenes;

  /// Ejercicios completos de wger precargados (por índice).
  final Map<int, EjercicioWger?> wgerEjercicios;

  /// Guarda la sesión y muestra el resumen; al volver se cierra esta pantalla.
  final Future<void> Function(SesionEntrenamiento sesion) onTerminar;

  @override
  State<EntrenamientoScreen> createState() => _EntrenamientoScreenState();
}

class _EntrenamientoScreenState extends State<EntrenamientoScreen> {
  static const _pasoPeso = 2.5;

  final DateTime _inicio = DateTime.now();

  /// Ejercicio actual (índice).
  int _ej = 0;

  /// Series hechas por ejercicio (índice → cantidad).
  final Map<int, int> _hechas = {};

  /// Peso y repeticiones (o segundos) que se van a anotar, por ejercicio.
  final Map<int, double?> _pesos = {};
  final Map<int, int> _reps = {};

  /// Lo hecho en cada serie, por ejercicio: (repeticiones, peso).
  final Map<int, List<(int, double?)>> _registro = {};
  bool _terminando = false;

  List<EjercicioRutina> get _ejercicios => widget.rutina.ejercicios;
  EjercicioRutina get _actual => _ejercicios[_ej];
  int get _seriesHechas => _hechas.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _ejercicios.length; i++) {
      final e = _ejercicios[i];
      _pesos[i] = widget.ultimosPesos[e.nombre] ?? e.pesoKg;
      _reps[i] = e.repeticiones;
    }
    _ej = _pendienteDesde(0) ?? 0;
  }

  /// Primer ejercicio desde [i] al que le quedan series, o null si no hay.
  int? _pendienteDesde(int i) {
    for (var j = i; j < _ejercicios.length; j++) {
      if ((_hechas[j] ?? 0) < _ejercicios[j].series) return j;
    }
    return null;
  }

  /// Siguiente ejercicio distinto del actual al que le quedan series.
  int? get _despues => _pendienteDesde(_ej + 1);

  Future<void> _serieHecha() async {
    if (_terminando || _ejercicios.isEmpty) return;
    final i = _ej;
    final e = _actual;
    if ((_hechas[i] ?? 0) >= e.series) return; // rutina sin series pendientes
    setState(() {
      _registro.putIfAbsent(i, () => []).add((_reps[i] ?? e.repeticiones, e.porTiempo ? null : _pesos[i]));
      _hechas[i] = (_hechas[i] ?? 0) + 1;
    });
    final siguiente = _pendienteDesde(i);
    if (siguiente == null) {
      await _terminar();
      return;
    }
    setState(() => _ej = siguiente);
    final sig = _ejercicios[siguiente];
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DescansoScreen(
        ejercicio: e.nombre,
        serieGuardada: _hechas[i]!,
        siguienteTitulo: 'Serie ${(_hechas[siguiente] ?? 0) + 1} de ${sig.series}',
        siguienteDetalle: [
          sig.nombre,
          sig.porTiempo ? '${_reps[siguiente]} s' : '${_reps[siguiente]} reps',
          if (!sig.porTiempo && _pesos[siguiente] != null) '${kgTexto(_pesos[siguiente]!)} kg',
        ].join(' · '),
        hechas: [for (final (r, p) in _registro[i]!) _textoSerie(e, r, p)],
        series: [for (final x in _ejercicios) x.series],
        seriesHechas: [for (var j = 0; j < _ejercicios.length; j++) _hechas[j] ?? 0],
        inicio: _inicio,
      ),
    ));
  }

  static String _textoSerie(EjercicioRutina e, int reps, double? peso) {
    if (e.porTiempo) return '$reps s';
    return peso == null ? '$reps reps' : '$reps × ${kgTexto(peso)} kg';
  }

  /// Termina con lo hecho hasta ahora. Sin ninguna serie hecha, solo sale.
  Future<void> _terminar() async {
    if (_terminando) return;
    _terminando = true;
    if (_seriesHechas == 0) {
      Navigator.of(context).pop();
      return;
    }
    final ahora = DateTime.now();
    final sesion = SesionEntrenamiento(
      fecha: ahora,
      rutinaId: widget.rutina.id,
      rutinaNombre: widget.rutina.nombre,
      duracion: ahora.difference(_inicio),
      ejercicios: [
        for (var i = 0; i < _ejercicios.length; i++)
          EjercicioSesion(
            nombre: _ejercicios[i].nombre,
            musculo: _ejercicios[i].musculo,
            seriesPlan: _ejercicios[i].series,
            repeticiones: _ejercicios[i].repeticiones,
            seriesHechas: _hechas[i] ?? 0,
            pesoKg: _pesos[i],
            porTiempo: _ejercicios[i].porTiempo,
          ),
      ],
    );
    await widget.onTerminar(sesion);
    if (mounted) Navigator.of(context).pop();
  }

  /// Salir sin guardar (con confirmación si ya hay series hechas).
  Future<void> _salir() async {
    if (_terminando) return;
    if (_seriesHechas > 0) {
      final salir = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: FitColors.surface,
          title: const Text('Salir del entrenamiento'),
          content: const Text('Lo que llevas no se guardará. Para guardarlo, toca "Terminar entrenamiento".'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: FitColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir sin guardar'),
            ),
          ],
        ),
      );
      if (salir != true) return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_ejercicios.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Esta rutina no tiene ejercicios.')));
    }
    final e = _actual;
    final serie = e.series <= 0 ? 0 : (_hechas[_ej] ?? 0).clamp(0, e.series - 1);
    final despues = _despues;
    final ultimo = widget.ultimosPesos[e.nombre];
    final reps = _reps[_ej] ?? e.repeticiones;
    final peso = _pesos[_ej];
    return PopScope(
      canPop: _seriesHechas == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Salir del entrenamiento',
                      icon: Icon(Icons.close, color: FitColors.ink),
                      onPressed: _salir,
                    ),
                    Expanded(
                      child: SegmentosProgreso(
                        series: [for (final x in _ejercicios) x.series],
                        hechas: [for (var j = 0; j < _ejercicios.length; j++) _hechas[j] ?? 0],
                        lleno: FitColors.ink,
                        vacio: FitColors.line,
                        etiqueta: 'Ejercicio ${_ej + 1} de ${_ejercicios.length}, serie ${serie + 1} de ${e.series}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    RelojTranscurrido(inicio: _inicio, color: FitColors.ink),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  children: [
                    VisorEjercicioAnimado(
                      key: ValueKey('visor-$_ej'),
                      musculo: e.musculo,
                      nombre: e.nombre,
                      wgerId: e.wgerId,
                      ejercicioWger: widget.wgerEjercicios[_ej],
                      imagenInicial: widget.imagenes[_ej],
                      height: 180,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ejercicio ${_ej + 1} de ${_ejercicios.length}'.toUpperCase(),
                      style: estiloEtiqueta(color: FitColors.primary, size: 12).copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Barrido(
                            key: ValueKey('nombre-$_ej'),
                            child: Text(e.nombre.toUpperCase(), style: estiloCifra(40, color: FitColors.ink)),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: FitColors.ink,
                            minimumSize: const Size(44, 44),
                            shape: const RoundedRectangleBorder(),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                          ),
                          onPressed: () => mostrarComoSeHace(
                            context,
                            wgerId: e.wgerId,
                            nombre: e.nombre,
                            musculo: e.musculo,
                            detalle: e.detalle,
                          ),
                          child: const Text('Cómo se hace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Golpe(
                          key: ValueKey('cifra-serie-$_ej-$serie'),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${serie + 1}'),
                              TextSpan(
                                text: '/${e.series}',
                                style: TextStyle(fontSize: 40, color: FitColors.textMuted),
                              ),
                            ]),
                            semanticsLabel: 'Serie ${serie + 1} de ${e.series}',
                            style: estiloCifra(88, color: FitColors.ink).copyWith(height: 0.8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('SERIE\nACTUAL', style: estiloEtiqueta(color: FitColors.ink, size: 12)),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ExcludeSemantics(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var s = 0; s < e.series; s++)
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: s < serie
                                        ? BoxDecoration(color: FitColors.accent)
                                        : BoxDecoration(
                                            border: Border.all(
                                              color: s == serie ? FitColors.ink : FitColors.line,
                                              width: 2,
                                            ),
                                          ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!e.porTiempo) ...[
                            Expanded(
                              child: _Ajuste(
                                etiqueta: 'Peso',
                                valor: peso == null ? '—' : kgTexto(peso),
                                sufijo: peso == null ? '' : 'KG',
                                nota: ultimo != null
                                    ? 'La vez pasada: ${kgTexto(ultimo)} kg'
                                    : peso == null
                                        ? 'Sin peso'
                                        : 'Primera vez',
                                menos: 'Bajar peso',
                                mas: 'Subir peso',
                                onMenos: peso == null
                                    ? null
                                    : () => setState(() => _pesos[_ej] = peso <= _pasoPeso ? null : peso - _pasoPeso),
                                onMas: () => setState(() => _pesos[_ej] = (peso ?? 0) + _pasoPeso),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: _Ajuste(
                              etiqueta: e.porTiempo ? 'Segundos' : 'Repeticiones',
                              valor: '$reps',
                              sufijo: e.porTiempo ? 'S' : '',
                              nota: 'Objetivo: ${e.repeticiones}${e.porTiempo ? ' s' : ''}',
                              menos: e.porTiempo ? 'Menos segundos' : 'Menos repeticiones',
                              mas: e.porTiempo ? 'Más segundos' : 'Más repeticiones',
                              onMenos: reps <= (e.porTiempo ? 5 : 1)
                                  ? null
                                  : () => setState(() => _reps[_ej] = reps - (e.porTiempo ? 5 : 1)),
                              onMas: () => setState(() => _reps[_ej] = reps + (e.porTiempo ? 5 : 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: FitColors.line))),
                      child: despues == null
                          ? Text('Es el último ejercicio.', style: TextStyle(color: FitColors.textMuted, fontSize: 13))
                          : Text.rich(
                              TextSpan(children: [
                                const TextSpan(text: 'Después: '),
                                TextSpan(
                                  text: _ejercicios[despues].nombre,
                                  style: TextStyle(color: FitColors.ink, fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: ' · ${_planTexto(_ejercicios[despues])}'),
                              ]),
                              style: TextStyle(color: FitColors.textMuted, fontSize: 13),
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: BotonPrincipal(
                  key: const ValueKey('serie-hecha'),
                  texto: 'Serie hecha',
                  fondo: FitColors.accent,
                  color: FitColors.carbon,
                  icono: Icons.check,
                  centrado: true,
                  alto: 64,
                  onPressed: _serieHecha,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: FitColors.ink,
                    minimumSize: const Size.fromHeight(44),
                    shape: const RoundedRectangleBorder(),
                    textStyle: estiloEtiqueta(size: 13).copyWith(decoration: TextDecoration.underline),
                  ),
                  onPressed: _terminar,
                  child: const Text('Terminar entrenamiento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _planTexto(EjercicioRutina e) =>
      e.porTiempo ? '${e.series} × ${e.repeticiones} s' : '${e.series} × ${e.repeticiones}';
}

/// Kilos sin decimales innecesarios ("80", "82.5").
String kgTexto(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Tarjeta con una cifra que se ajusta con − / +.
class _Ajuste extends StatelessWidget {
  const _Ajuste({
    required this.etiqueta,
    required this.valor,
    required this.nota,
    required this.menos,
    required this.mas,
    required this.onMenos,
    required this.onMas,
    this.sufijo = '',
  });
  final String etiqueta;
  final String valor;
  final String sufijo;
  final String nota;
  final String menos;
  final String mas;
  final VoidCallback? onMenos;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: FitColors.surface, border: Border.all(color: FitColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(etiqueta.toUpperCase(), style: estiloEtiqueta(color: FitColors.textMuted)),
            const SizedBox(height: 4),
            Row(
              children: [
                _BotonAjuste(simbolo: '−', etiqueta: menos, onTap: onMenos),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: valor),
                          if (sufijo.isNotEmpty) TextSpan(text: sufijo, style: const TextStyle(fontSize: 16)),
                        ]),
                        style: estiloCifra(32, color: FitColors.ink),
                      ),
                    ),
                  ),
                ),
                _BotonAjuste(simbolo: '+', etiqueta: mas, onTap: onMas),
              ],
            ),
            const SizedBox(height: 4),
            Text(nota, style: TextStyle(color: FitColors.textMuted, fontSize: 11)),
          ],
        ),
      );
}

class _BotonAjuste extends StatelessWidget {
  const _BotonAjuste({required this.simbolo, required this.etiqueta, required this.onTap});
  final String simbolo;
  final String etiqueta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? FitColors.line : FitColors.ink;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: etiqueta,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
          child: Text(simbolo, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
        ),
      ),
    );
  }
}

/// Botón principal editorial: bloque recto, texto condensado en itálica y
/// flecha (o el ícono indicado).
class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.fondo,
    required this.color,
    required this.onPressed,
    this.icono = Icons.arrow_forward,
    this.centrado = false,
    this.alto = 60,
  });
  final String texto;
  final Color fondo;
  final Color color;
  final VoidCallback? onPressed;
  final IconData icono;
  final bool centrado;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final etiqueta = Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: estiloCifra(centrado ? 28 : 24, color: color).copyWith(letterSpacing: 1, height: 1),
    );
    return Material(
      color: onPressed == null ? fondo.withAlpha(90) : fondo,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: alto,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: centrado
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icono, color: color, size: 26),
                      const SizedBox(width: 10),
                      Flexible(child: etiqueta),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: etiqueta),
                      Icon(icono, color: color, size: 26),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

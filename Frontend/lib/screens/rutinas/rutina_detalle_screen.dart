import 'package:flutter/material.dart';

import '../../models/ejercicio_wger.dart';
import '../../models/rutina.dart';
import '../../models/sesion.dart';
import '../../services/historial.dart';
import '../../services/wger.dart';
import '../../theme.dart';
import '../../widgets/editorial.dart';
import '../../widgets/como_se_hace.dart';
import 'entrenamiento_screen.dart';
import 'rutina_editor_screen.dart';

/// Vista previa de una rutina: origen y días, totales y los ejercicios con lo
/// que se usó la vez pasada. El entrenamiento empieza con "Empezar
/// entrenamiento" (ver [EntrenamientoScreen]); al terminar se guarda la sesión
/// en el historial y se muestra el resumen con sugerencias de progresión.
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

enum _Accion { duplicar, editar, eliminar }

class _RutinaDetalleScreenState extends State<RutinaDetalleScreen> {
  late Rutina _rutina = widget.rutina;

  List<SesionEntrenamiento> _historial = [];
  Map<String, double> _ultimosPesos = {};

  /// Ejercicios hechos alguna vez (aunque sin peso).
  Set<String> _hechosAntes = {};

  /// Imagen de wger por índice de ejercicio.
  Map<int, String?> _imagenes = {};
  Map<int, EjercicioWger?> _wgerEjercicios = {};
  late Future<void> _carga;

  @override
  void initState() {
    super.initState();
    _carga = _cargarHistorial();
    _cargarImagenes();
  }

  Future<void> _cargarHistorial() async {
    final h = await Historial.cargar(widget.espacio);
    if (!mounted) return;
    setState(() {
      _historial = h;
      _ultimosPesos = Historial.ultimosPesos(h);
      _hechosAntes = {
        for (final s in h)
          for (final e in s.ejercicios)
            if (e.seriesHechas > 0) e.nombre,
      };
    });
  }

  Future<void> _cargarImagenes() async {
    final ejercicios = _rutina.ejercicios;
    final imagenes = <int, String?>{};
    final wger = <int, EjercicioWger?>{};
    for (var i = 0; i < ejercicios.length; i++) {
      final e = ejercicios[i];
      try {
        final w = e.wgerId != null ? await Wger.porId(e.wgerId!) : await Wger.porNombre(e.nombre);
        wger[i] = w;
        imagenes[i] = w?.imagen;
      } catch (_) {}
    }
    if (mounted && identical(ejercicios, _rutina.ejercicios)) {
      setState(() {
        _imagenes = imagenes;
        _wgerEjercicios = wger;
      });
    }
  }

  Future<void> _empezar() async {
    await _carga;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => EntrenamientoScreen(
        rutina: _rutina,
        ultimosPesos: _ultimosPesos,
        imagenes: _imagenes,
        wgerEjercicios: _wgerEjercicios,
        onTerminar: _guardarSesion,
      ),
    ));
  }

  /// Guarda la sesión en el historial y muestra el resumen ("HECHO.").
  Future<void> _guardarSesion(SesionEntrenamiento sesion) async {
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
      if (mounted) setState(() => _rutina = nueva);
    }
    // Sin esperar la recarga: la pantalla de entrenamiento se cierra ya y la
    // vista previa se actualiza sola cuando termina de leer el historial.
    if (mounted) {
      _carga = _cargarHistorial();
      // setState is called inside _cargarHistorial when the data is ready.
    }
  }

  Future<void> _editar() async {
    final r = await Navigator.of(context).push<Rutina>(
      MaterialPageRoute(builder: (_) => RutinaEditorScreen(rutina: _rutina, catalogo: widget.catalogo)),
    );
    if (r == null) return;
    await widget.onGuardar!(r);
    if (!mounted) return;
    setState(() => _rutina = r);
    _cargarImagenes();
    _carga = _cargarHistorial();
    await _carga;
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

  Future<void> _accion(_Accion a) async {
    switch (a) {
      case _Accion.duplicar:
        Navigator.pop(context);
        await widget.onDuplicar!();
      case _Accion.editar:
        await _editar();
      case _Accion.eliminar:
        await _eliminar();
    }
  }

  /// "la vez pasada 80 kg", "peso corporal" o "primera vez".
  String _antes(EjercicioRutina e) {
    final ultimo = _ultimosPesos[e.nombre];
    if (ultimo != null) return 'la vez pasada ${kgTexto(ultimo)} kg';
    if (_hechosAntes.contains(e.nombre)) return 'peso corporal';
    return 'primera vez';
  }

  @override
  Widget build(BuildContext context) {
    final ejercicios = _rutina.ejercicios;
    final series = ejercicios.fold(0, (a, e) => a + e.series);
    final minutos = (_rutina.duracionEstimada().inSeconds / 60).round();
    final acciones = [
      if (widget.onDuplicar != null) _Accion.duplicar,
      if (widget.onGuardar != null) _Accion.editar,
      if (widget.onEliminar != null) _Accion.eliminar,
    ];
    final dias = Rutina.textoDiasCorto(_rutina.dias).toUpperCase();
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (acciones.isNotEmpty)
            PopupMenuButton<_Accion>(
              tooltip: 'Más opciones',
              icon: const Icon(Icons.more_horiz),
              shape: const RoundedRectangleBorder(),
              color: FitColors.surface,
              onSelected: _accion,
              itemBuilder: (_) => [
                for (final a in acciones)
                  PopupMenuItem(
                    value: a,
                    child: Row(
                      children: [
                        Icon(
                          switch (a) {
                            _Accion.duplicar => Icons.copy_all_outlined,
                            _Accion.editar => Icons.edit_outlined,
                            _Accion.eliminar => Icons.delete_outline,
                          },
                          size: 20,
                          color: a == _Accion.eliminar ? FitColors.danger : FitColors.ink,
                        ),
                        const SizedBox(width: 12),
                        Text(switch (a) {
                          _Accion.duplicar => 'Duplicar',
                          _Accion.editar => 'Editar',
                          _Accion.eliminar => 'Eliminar',
                        }),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: FitColors.background,
          border: Border(top: BorderSide(color: FitColors.line)),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: BotonPrincipal(
            texto: 'Empezar entrenamiento',
            fondo: FitColors.ink,
            color: FitColors.background,
            onPressed: ejercicios.isEmpty ? null : _empezar,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: FitColors.ink,
                child: Text(
                  (_rutina.etiqueta ?? 'Mía').toUpperCase(),
                  style: TextStyle(
                    color: FitColors.background,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                _rutina.esHoy ? 'HOY · $dias' : dias,
                style: TextStyle(color: FitColors.primary, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Barrido(
            child: Text(
              _rutina.nombre.toUpperCase(),
              style: estiloCifra(52, color: FitColors.ink).copyWith(height: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: FitColors.ink)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Marcador(valor: '${ejercicios.length}', etiqueta: 'Ejercicios', primera: true)),
                  Expanded(child: _Marcador(valor: '$series', etiqueta: 'Series')),
                  Expanded(child: _Marcador(valor: '≈$minutos', sufijo: 'MIN', etiqueta: 'Duración')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (ejercicios.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Esta rutina todavía no tiene ejercicios.', style: TextStyle(color: FitColors.textMuted)),
            ),
          for (var i = 0; i < ejercicios.length; i++)
            _FilaEjercicio(
              numero: i + 1,
              ejercicio: ejercicios[i],
              imagen: _imagenes[i],
              antes: _antes(ejercicios[i]),
            ),
          if (_rutina.esDelGimnasio) ...[
            const SizedBox(height: 16),
            Text(
              'Es una rutina de tu gimnasio. Para cambiarla, hazte una copia desde ⋯',
              style: TextStyle(color: FitColors.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

String _kg(double v) => kgTexto(v);

String _duracion(Duration d) {
  final m = d.inMinutes;
  return m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
}

/// Celda del marcador de la vista previa.
class _Marcador extends StatelessWidget {
  const _Marcador({required this.valor, required this.etiqueta, this.sufijo = '', this.primera = false});
  final String valor;
  final String sufijo;
  final String etiqueta;
  final bool primera;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(primera ? 0 : 12, 10, 4, 10),
        decoration: BoxDecoration(
          border: primera ? null : Border(left: BorderSide(color: FitColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: valor),
                  if (sufijo.isNotEmpty) TextSpan(text: sufijo, style: const TextStyle(fontSize: 16)),
                ]),
                style: estiloCifra(34, color: FitColors.ink),
              ),
            ),
            const SizedBox(height: 2),
            Text(etiqueta.toUpperCase(), style: estiloEtiqueta(color: FitColors.ink).copyWith(letterSpacing: 1.2)),
          ],
        ),
      );
}

/// Fila numerada de un ejercicio: miniatura, nombre, plan y la vez pasada.
class _FilaEjercicio extends StatelessWidget {
  const _FilaEjercicio({required this.numero, required this.ejercicio, required this.imagen, required this.antes});
  final int numero;
  final EjercicioRutina ejercicio;
  final String? imagen;
  final String antes;

  @override
  Widget build(BuildContext context) {
    final e = ejercicio;
    final plan = e.porTiempo ? '${e.series} × ${e.repeticiones} s' : '${e.series} × ${e.repeticiones}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: FitColors.line))),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              numero.toString().padLeft(2, '0'),
              style: estiloCifra(22, color: FitColors.textMuted).copyWith(fontStyle: FontStyle.normal),
            ),
          ),
          const SizedBox(width: 10),
          MiniaturaEjercicio(musculo: e.musculo, imagen: imagen, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.nombre.toUpperCase(),
                  style: estiloCifra(20, color: FitColors.ink).copyWith(fontStyle: FontStyle.normal, height: 1),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$plan · '),
                    TextSpan(text: antes, style: TextStyle(color: FitColors.textMuted)),
                  ]),
                  style: TextStyle(color: FitColors.ink, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: FitColors.ink,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              shape: const RoundedRectangleBorder(),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
            ),
            onPressed: () => mostrarComoSeHace(
              context,
              wgerId: e.wgerId,
              nombre: e.nombre,
              musculo: e.musculo,
              detalle: e.detalle,
            ),
            child: Text('Cómo', semanticsLabel: 'Cómo se hace ${e.nombre}'),
          ),
        ],
      ),
    );
  }
}

/// Resumen al terminar: pantalla "HECHO.". En claro, todo rojo con texto
/// carbón; en oscuro, fondo del tema con el título en rojo.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.sesion, required this.sugerencias, required this.puedeAplicar});
  final SesionEntrenamiento sesion;
  final List<Sugerencia> sugerencias;
  final bool puedeAplicar;

  @override
  Widget build(BuildContext context) {
    final oscuro = FitColors.oscuro;
    final fondo = oscuro ? FitColors.background : FitColors.accent;
    final texto = oscuro ? FitColors.ink : FitColors.carbon;
    final titulo = oscuro ? FitColors.accent : FitColors.carbon;
    final regla = oscuro ? FitColors.line : FitColors.carbon;
    final botonFondo = oscuro ? FitColors.ink : FitColors.carbon;
    final botonTexto = oscuro ? FitColors.background : FitColors.papel;
    final volumen = sesion.volumenKg;
    final aplicar = sugerencias.isNotEmpty && puedeAplicar;

    return Dialog.fullscreen(
      backgroundColor: fondo,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: texto),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: -60,
              child: SizedBox(
                height: 330,
                child: DiagonalRoja(
                  ancho: 220,
                  color: oscuro ? FitColors.accent : FitColors.carbon,
                  opacidad: oscuro ? 0.18 : 0.12,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${sesion.rutinaNombre} · ${_duracion(sesion.duracion)}'.toUpperCase(),
                              style: estiloEtiqueta(color: texto, size: 12).copyWith(letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            Golpe(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text('HECHO.', style: estiloCifra(120, color: titulo).copyWith(height: 0.85)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '¡Entrenamiento guardado!',
                              style: TextStyle(color: texto, fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 20),
                            Barrido(
                              retraso: const Duration(milliseconds: 200),
                              child: Container(
                                color: oscuro ? FitColors.surface : FitColors.carbon,
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _Dato(
                                          valor: '${sesion.seriesHechas}',
                                          sufijo: '/${sesion.seriesPlan}',
                                          etiqueta: 'Series',
                                          primera: true,
                                        ),
                                      ),
                                      Expanded(
                                        child: volumen >= 1000
                                            ? _Dato(
                                                valor: (volumen / 1000).toStringAsFixed(1),
                                                sufijo: 'T',
                                                etiqueta: 'Volumen',
                                              )
                                            : _Dato(valor: _kg(volumen), sufijo: 'KG', etiqueta: 'Volumen'),
                                      ),
                                      Expanded(
                                        child: _Dato(
                                          valor: '${sesion.duracion.inMinutes}',
                                          sufijo: 'MIN',
                                          etiqueta: 'Duración',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (sugerencias.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Barrido(
                                retraso: const Duration(milliseconds: 300),
                                child: Container(
                                  padding: const EdgeInsets.only(top: 14),
                                  decoration: BoxDecoration(border: Border(top: BorderSide(color: regla, width: 2))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Completaste estos ejercicios dos veces seguidas. ¡Es momento de subir!',
                                        style: TextStyle(
                                            color: texto, fontSize: 15, fontWeight: FontWeight.w600, height: 1.45),
                                      ),
                                      const SizedBox(height: 10),
                                      for (final s in sugerencias)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Text.rich(
                                            TextSpan(children: [
                                              TextSpan(
                                                text: s.ejercicio,
                                                style: const TextStyle(fontWeight: FontWeight.w900),
                                              ),
                                              TextSpan(text: ': ${s.texto.toLowerCase()}'),
                                            ]),
                                            style: TextStyle(color: texto, fontSize: 15, height: 1.4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (aplicar) ...[
                      BotonPrincipal(
                        texto: 'Aplicar a la rutina',
                        fondo: botonFondo,
                        color: botonTexto,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: texto,
                          minimumSize: const Size.fromHeight(44),
                          shape: const RoundedRectangleBorder(),
                          textStyle: estiloEtiqueta(size: 13),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Ahora no'),
                      ),
                    ] else
                      BotonPrincipal(
                        texto: 'Listo',
                        fondo: botonFondo,
                        color: botonTexto,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta, this.sufijo = '', this.primera = false});
  final String valor;
  final String sufijo;
  final String etiqueta;
  final bool primera;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
        decoration: BoxDecoration(
          border: primera ? null : Border(left: BorderSide(color: FitColors.papel.withAlpha(40))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: valor),
                  if (sufijo.isNotEmpty) TextSpan(text: sufijo, style: const TextStyle(fontSize: 20)),
                ]),
                style: estiloCifra(42, color: FitColors.papel),
              ),
            ),
            const SizedBox(height: 4),
            Text(etiqueta.toUpperCase(), style: estiloEtiqueta(color: FitColors.papel.withAlpha(185))),
          ],
        ),
      );
}

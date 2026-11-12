import 'package:flutter/material.dart';

import '../../models/rutina.dart';
import '../../models/sesion.dart';
import '../../services/historial.dart';
import '../../services/recordatorios.dart';
import '../../services/rutinas_store.dart';
import '../../theme.dart';
import '../../widgets/editorial.dart';
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
  _Filtro _filtro = _Filtro.todas;

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
    final conGimnasio = widget.rutinasGimnasio != null;
    final todas = [..._gimnasio, ..._mias];
    final deHoy = todas.where((r) => r.esHoy).firstOrNull;
    final conFiltros = conGimnasio && todas.isNotEmpty;
    final filtro = conFiltros ? _filtro : _Filtro.todas;
    final filtradas = switch (filtro) {
      _Filtro.todas => todas,
      _Filtro.gimnasio => _gimnasio,
      _Filtro.mias => _mias,
    };
    final verGimnasio = conGimnasio && filtro != _Filtro.mias;
    return RefreshIndicator(
      onRefresh: _cargar,
      color: FitColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Barrido(
            child: _Encabezado(
              onAviso: _configurarAviso,
              onPlantillas: widget.onPlantillas,
              onNueva: _nueva,
            ),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else ...[
            if (todas.isNotEmpty) ...[
              const Etiqueta('Hoy'),
              const SizedBox(height: 6),
              if (deHoy != null)
                Barrido(
                  retraso: const Duration(milliseconds: 80),
                  child: _BloqueHoy(
                    rutina: deHoy,
                    ultimaVez: Historial.ultimaVez(_historial, deHoy.id),
                    onTap: () => _abrir(deHoy),
                  ),
                )
              else
                Text('Hoy no tienes rutina: día de descanso.', style: TextStyle(color: FitColors.textMuted)),
              const SizedBox(height: 18),
              const Etiqueta('Esta semana'),
              const SizedBox(height: 4),
              _Agenda(rutinas: todas, historial: _historial),
              const SizedBox(height: 18),
            ],
            if (conFiltros) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (f, texto, n) in [
                    (_Filtro.todas, 'Todas', todas.length),
                    (_Filtro.gimnasio, 'Del gimnasio', _gimnasio.length),
                    (_Filtro.mias, 'Mías', _mias.length),
                  ])
                    _Chip(
                      texto: '$texto · $n',
                      seleccionado: filtro == f,
                      onTap: () => setState(() => _filtro = f),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (verGimnasio && _errorGimnasio != null)
              VacioMensaje(
                icon: Icons.cloud_off,
                texto: 'No se pudieron cargar las rutinas del gimnasio.\n$_errorGimnasio',
                accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              ),
            if (verGimnasio && _errorGimnasio == null && _gimnasio.isEmpty && (filtro == _Filtro.gimnasio || todas.isEmpty))
              const _Nota('Tu gimnasio todavía no publicó rutinas.'),
            if (verGimnasio && _gimnasioDesdeCopia && _gimnasio.isNotEmpty)
              const _Nota('Sin conexión: mostrando la última copia guardada. Desliza hacia abajo para actualizar.'),
            for (final r in filtradas)
              _FilaRutina(rutina: r, ultimaVez: Historial.ultimaVez(_historial, r.id), onTap: () => _abrir(r)),
            if (filtradas.isEmpty && filtro != _Filtro.gimnasio)
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
              ),
            const SizedBox(height: 20),
            _ResumenProgreso(historial: _historial, onTap: _progreso),
          ],
        ],
      ),
    );
  }
}

enum _Filtro { todas, gimnasio, mias }

const _diasAgenda = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

String _plural(int n, String singular, String plural) => '$n ${n == 1 ? singular : plural}';

/// Minutos aproximados de la rutina, redondeados hacia arriba (null si no tiene ejercicios).
int? _minutos(Rutina r) {
  final d = r.duracionEstimada();
  return d == Duration.zero ? null : (d.inSeconds / 60).ceil();
}

/// "hoy", "ayer" o "hace N días" contando días de calendario.
String _haceCuanto(DateTime fecha) {
  final ahora = DateTime.now();
  final dias = (DateTime(ahora.year, ahora.month, ahora.day).difference(DateTime(fecha.year, fecha.month, fecha.day)).inHours / 24)
      .round();
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  return 'hace $dias días';
}

String _origenTexto(OrigenRutina o) => switch (o) {
      OrigenRutina.propia => 'Tuya',
      OrigenRutina.gimnasioGeneral => 'Del gimnasio',
      OrigenRutina.gimnasioAsignada => 'Asignada a ti',
    };

/// Título "RUTINAS" con el día, regla de tinta y las acciones.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.onAviso, required this.onNueva, this.onPlantillas});
  final VoidCallback onAviso;
  final VoidCallback onNueva;
  final VoidCallback? onPlantillas;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now().weekday;
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: FitColors.ink, width: 3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('RUTINAS', style: estiloCifra(40, color: FitColors.ink)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hoy es ${Rutina.nombresDias[hoy - 1].toLowerCase()}',
                  style: estiloEtiqueta(color: FitColors.textMuted, size: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recordatorio de entrenamiento',
            visualDensity: VisualDensity.compact,
            onPressed: onAviso,
            icon: const Icon(Icons.notifications_none),
          ),
          if (onPlantillas != null)
            IconButton(
              tooltip: 'Plantillas',
              visualDensity: VisualDensity.compact,
              onPressed: onPlantillas,
              icon: const Icon(Icons.auto_awesome),
            ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onNueva,
            style: FilledButton.styleFrom(
              backgroundColor: FitColors.ink,
              foregroundColor: FitColors.background,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text('+ NUEVA', style: estiloCifra(18)),
          ),
        ],
      ),
    );
  }
}

/// Bloque con la rutina que toca hoy.
class _BloqueHoy extends StatelessWidget {
  const _BloqueHoy({required this.rutina, required this.ultimaVez, required this.onTap});
  final Rutina rutina;
  final DateTime? ultimaVez;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final series = rutina.ejercicios.fold<int>(0, (s, e) => s + e.series);
    final minutos = _minutos(rutina);
    final resumen = [
      _plural(rutina.ejercicios.length, 'ejercicio', 'ejercicios'),
      _plural(series, 'serie', 'series'),
      if (minutos != null) '≈ $minutos min',
    ].join(' · ');
    return Material(
      color: FitColors.block,
      child: InkWell(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(border: Border.all(color: FitColors.blockLine)),
          child: Stack(
            children: [
              const Positioned(top: 0, bottom: 0, right: -30, child: DiagonalRoja(ancho: 110)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiqueta(_origenTexto(rutina.origen), color: FitColors.onBlockMuted),
                    const SizedBox(height: 4),
                    Text(rutina.nombre, style: estiloCifra(36, color: FitColors.papel)),
                    const SizedBox(height: 8),
                    Text(resumen,
                        style: const TextStyle(color: FitColors.papel, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      ultimaVez == null ? 'Primera vez' : 'La última vez: ${_haceCuanto(ultimaVez!)}',
                      style: TextStyle(color: FitColors.onBlockMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agenda de la semana: solo los días con rutina (y hoy, aunque sea descanso).
class _Agenda extends StatelessWidget {
  const _Agenda({required this.rutinas, required this.historial});
  final List<Rutina> rutinas;
  final List<SesionEntrenamiento> historial;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final hoy = ahora.weekday;
    final inicio = Historial.inicioSemana(ahora);
    // Veces que se hizo cada rutina esta semana: marcan sus primeros días.
    final veces = <String, int>{};
    for (final s in historial) {
      if (!s.fecha.isBefore(inicio)) veces[s.rutinaId] = (veces[s.rutinaId] ?? 0) + 1;
    }
    final filas = <Widget>[];
    for (var d = 1; d <= 7; d++) {
      final delDia = rutinas.where((r) => r.dias.contains(d)).toList();
      if (delDia.isEmpty && d == hoy) filas.add(_FilaAgenda(dia: d, esHoy: true, texto: 'Descanso', descanso: true));
      for (final r in delDia) {
        final hecha = (r.dias.toList()..sort()).indexOf(d) < (veces[r.id] ?? 0);
        filas.add(_FilaAgenda(
          dia: d,
          esHoy: d == hoy,
          texto: r.nombre,
          estado: hecha ? '✓ Hecha' : (d == hoy ? 'Hoy' : null),
          hecha: hecha,
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: FitColors.ink))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filas),
    );
  }
}

class _FilaAgenda extends StatelessWidget {
  const _FilaAgenda({
    required this.dia,
    required this.esHoy,
    required this.texto,
    this.estado,
    this.hecha = false,
    this.descanso = false,
  });
  final int dia;
  final bool esHoy;
  final String texto;
  final String? estado;
  final bool hecha;
  final bool descanso;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: EdgeInsets.only(left: esHoy ? 8 : 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FitColors.line),
          left: esHoy ? BorderSide(color: FitColors.accent, width: 3) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              _diasAgenda[dia - 1],
              style: TextStyle(
                fontSize: 12,
                fontWeight: esHoy ? FontWeight.w900 : FontWeight.w800,
                color: esHoy ? FitColors.primary : FitColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: descanso ? FontWeight.w400 : (esHoy ? FontWeight.w800 : FontWeight.w600),
                color: descanso ? FitColors.textMuted : FitColors.ink,
              ),
            ),
          ),
          if (estado != null) ...[
            const SizedBox(width: 8),
            Text(
              estado!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: hecha ? FontWeight.w700 : FontWeight.w800,
                color: hecha ? FitColors.ok : FitColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Filtro cuadrado: relleno de tinta cuando está elegido.
class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.seleccionado, required this.onTap});
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: seleccionado,
      button: true,
      child: Material(
        color: seleccionado ? FitColors.ink : FitColors.surface,
        shape: seleccionado ? const RoundedRectangleBorder() : RoundedRectangleBorder(side: BorderSide(color: FitColors.line)),
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w600,
                  color: seleccionado ? FitColors.background : FitColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una rutina de la lista: nombre, origen, días, ejercicios, duración y última vez.
class _FilaRutina extends StatelessWidget {
  const _FilaRutina({required this.rutina, required this.ultimaVez, required this.onTap});
  final Rutina rutina;
  final DateTime? ultimaVez;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutos = _minutos(rutina);
    final meta = [
      Rutina.textoDiasCorto(rutina.dias),
      _plural(rutina.ejercicios.length, 'ejercicio', 'ejercicios'),
      if (minutos != null) '≈ $minutos min',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: FitColors.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        rutina.nombre,
                        style: estiloCifra(20, color: FitColors.ink).copyWith(fontStyle: FontStyle.normal, height: 1.1),
                      ),
                      _Insignia(rutina.origen),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(meta, style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
                  if (ultimaVez != null)
                    Text('Última vez: ${_haceCuanto(ultimaVez!)}', style: TextStyle(color: FitColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, color: FitColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Insignia cuadrada del origen: ASIGNADA (rellena), DEL GIMNASIO o TUYA.
class _Insignia extends StatelessWidget {
  const _Insignia(this.origen);
  final OrigenRutina origen;

  @override
  Widget build(BuildContext context) {
    final rellena = origen == OrigenRutina.gimnasioAsignada;
    final texto = switch (origen) {
      OrigenRutina.gimnasioAsignada => 'ASIGNADA',
      OrigenRutina.gimnasioGeneral => 'DEL GIMNASIO',
      OrigenRutina.propia => 'TUYA',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: rellena ? FitColors.ink : null,
        border: Border.all(color: FitColors.ink),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: rellena ? FitColors.background : FitColors.ink,
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Text(texto, style: TextStyle(color: FitColors.textMuted)),
      );
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
                border: d == hoy ? Border.all(color: FitColors.ink) : null,
              ),
              child: Text(
                Rutina.inicialesDias[d - 1],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dias.contains(d) ? FitColors.onPrimary : FitColors.textMuted,
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
      borderRadius: BorderRadius.zero,
      child: InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              Icon(Icons.insights, color: FitColors.primary),
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
              Icon(Icons.chevron_right, color: FitColors.textMuted),
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
                  Text('Te avisamos los días que tienes una rutina.', style: TextStyle(color: FitColors.textMuted)),
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

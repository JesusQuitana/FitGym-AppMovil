import 'package:flutter/material.dart';

import '../models/ejercicio_wger.dart';
import '../models/rutina.dart';
import '../models/sesion.dart';
import '../services/gym_rutinas.dart';
import '../services/historial.dart';
import '../services/plan_personal.dart';
import '../services/recordatorios.dart';
import '../services/rutinas_store.dart';
import '../services/session.dart';
import '../services/wger.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/editorial.dart';
import 'catalogo/ejercicios_catalogo.dart';
import 'login_screen.dart';
import 'pase_screen.dart';
import 'perfil_tab.dart';
import 'personal/asistente_screen.dart';
import 'personal/plantillas_screen.dart';
import 'progreso/progreso_screen.dart';
import 'rutinas/rutina_detalle_screen.dart';
import 'rutinas/rutina_editor_screen.dart';
import 'rutinas/rutinas_tab.dart';

/// La app: una sola, tenga o no gimnasio vinculado. Dónde se entrena hoy
/// (gimnasio o casa) se elige en Inicio con un toque, sin cambiar de modo ni
/// iniciar sesión otra vez.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  PerfilEntrenamiento? _perfil;

  /// Cambia para recargar las pestañas al volver de otras pantallas.
  int _version = 0;

  Session get _s => Session.instance;

  @override
  void initState() {
    super.initState();
    _recargar();
    final c = _s.cliente;
    if (c != null) {
      Recordatorios.programar(c);
      actualizarCliente().then((_) => mounted ? setState(() {}) : null);
    }
  }

  Future<void> _recargar() async {
    final p = await PlanPersonal.cargarPerfil();
    if (mounted) {
      setState(() {
        _perfil = p;
        _version++;
      });
    }
  }

  Future<List<OpcionEjercicio>> _catalogo() async =>
      (await Wger.catalogo()).map(OpcionEjercicio.deWger).toList();

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    await _recargar();
  }

  /// Plantillas si ya tiene plan; si no, el asistente para crearlo.
  Future<void> _plantillas() => _abrir(_perfil == null
      ? const AsistenteScreen(soloPlan: true)
      : PlantillasScreen(perfil: _perfil!));

  @override
  Widget build(BuildContext context) {
    final cliente = _s.cliente;
    return Scaffold(
      appBar: AppBar(title: const FitLogoInline()),
      body: switch (_tab) {
        0 => InicioTab(
            key: ValueKey('inicio-$_version'),
            perfil: _perfil,
            catalogo: _catalogo,
            onLugar: (l) async {
              await _s.saveLugarHoy(l);
              setState(() => _version++);
            },
            onVerRutinas: () => setState(() => _tab = 1),
            onPlantillas: _plantillas,
            abrir: _abrir,
          ),
        1 => RutinasTab(
            key: ValueKey('rutinas-$_version'),
            espacio: RutinasStore.propias,
            catalogo: _catalogo,
            rutinasGimnasio: cliente == null ? null : () => GymRutinas.paraClienteConCache(cliente.id),
            onPlantillas: _plantillas,
          ),
        2 => EjerciciosCatalogo(key: ValueKey('ejercicios-$_version'), perfil: _perfil),
        _ => PerfilTab(key: ValueKey('perfil-$_version'), perfil: _perfil, abrir: _abrir, onPlantillas: _plantillas),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _version++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Rutinas'),
          NavigationDestination(icon: Icon(Icons.sports_gymnastics), label: 'Ejercicios'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Inicio: dónde entrena hoy, acceso al pase y lo que le toca hoy.
class InicioTab extends StatefulWidget {
  const InicioTab({
    super.key,
    required this.perfil,
    required this.catalogo,
    required this.onLugar,
    required this.onVerRutinas,
    required this.onPlantillas,
    required this.abrir,
  });

  final PerfilEntrenamiento? perfil;
  final Future<List<OpcionEjercicio>> Function() catalogo;
  final ValueChanged<LugarHoy> onLugar;
  final VoidCallback onVerRutinas;
  final VoidCallback onPlantillas;
  final Future<void> Function(Widget) abrir;

  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  List<Rutina> _mias = [];
  List<Rutina> _gimnasio = [];
  List<SesionEntrenamiento> _historial = [];
  Map<int, EjercicioWger> _wger = {};
  bool _cargando = true;

  Session get _s => Session.instance;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final mias = await RutinasStore.cargar(RutinasStore.propias);
    final historial = await Historial.cargar(RutinasStore.propias);
    final wger = {for (final e in await Wger.catalogo()) e.id: e};
    var gym = <Rutina>[];
    final c = _s.cliente;
    if (c != null && _s.lugarHoy == LugarHoy.gimnasio) {
      try {
        gym = (await GymRutinas.paraClienteConCache(c.id)).$1;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _mias = mias;
      _historial = historial;
      _wger = wger;
      _gimnasio = gym;
      _cargando = false;
    });
  }

  Future<void> _abrirRutina(Rutina r) async {
    await widget.abrir(r.esDelGimnasio
        ? RutinaDetalleScreen(
            rutina: r,
            catalogo: widget.catalogo,
            espacio: RutinasStore.propias,
            onDuplicar: () async {
              final copia = await Navigator.of(context).push<Rutina>(MaterialPageRoute(
                builder: (_) => RutinaEditorScreen(
                  catalogo: widget.catalogo,
                  rutina: Rutina(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    nombre: '${r.nombre} (mi versión)',
                    dias: {...r.dias},
                    ejercicios: [...r.ejercicios],
                  ),
                ),
              ));
              if (copia != null) await RutinasStore.guardar(RutinasStore.propias, [..._mias, copia]);
            },
          )
        : RutinaDetalleScreen(
            rutina: r,
            catalogo: widget.catalogo,
            espacio: RutinasStore.propias,
            onGuardar: (n) => RutinasStore.guardar(RutinasStore.propias, [for (final x in _mias) x.id == n.id ? n : x]),
            onEliminar: () => RutinasStore.guardar(RutinasStore.propias, _mias.where((x) => x.id != r.id).toList()),
          ));
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _s.cliente;
    final lugar = _s.lugarHoy;
    final hoy = DateTime.now();
    final enCasa = lugar == LugarHoy.casa;
    final alAireLibre = lugar == LugarHoy.aireLibre;
    final enGimnasio = lugar == LugarHoy.gimnasio;
    // Hoy: en el gimnasio, las del gimnasio y las propias; en casa, primero
    // las propias que se pueden hacer sin máquinas; al aire libre, las que
    // alcanzan con el peso corporal (y la barra, si el parque tiene).
    final propiasHoy = _mias.where((r) => r.esHoy).toList();
    final hayAfuera = PlanPersonal.equipoHoy(widget.perfil, lugar, parqueConBarras: _s.parqueConBarras);
    final aptas = switch (lugar) {
      LugarHoy.casa => propiasHoy.where((r) => !PlanPersonal.necesitaGimnasio(r, _wger)).toList(),
      LugarHoy.aireLibre => propiasHoy.where((r) => !PlanPersonal.faltaEquipo(r, _wger, hayAfuera)).toList(),
      LugarHoy.gimnasio => propiasHoy,
    };
    final paraHoy = enGimnasio ? [..._gimnasio.where((r) => r.esHoy), ...propiasHoy] : aptas;
    final noAptas = enGimnasio ? const <Rutina>[] : propiasHoy.where((r) => !aptas.contains(r)).toList();
    final faltaQue = alAireLibre ? 'Necesita equipo que no hay en el parque' : 'Necesita equipo de gimnasio';
    final semana = Historial.porSemana(_historial, n: 1).first.$2;
    final racha = Historial.rachaSemanas(_historial);
    final pesos = [
      for (final s in _historial)
        for (final e in s.ejercicios)
          if (e.pesoKg != null) e.pesoKg!,
    ];
    final record = pesos.isEmpty ? null : pesos.reduce((a, b) => a > b ? a : b);
    final meta = widget.perfil?.dias ?? 0;

    return RefreshIndicator(
      color: FitColors.primary,
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _Cabecera(saludo: cliente == null ? 'Hola' : 'Hola, ${cliente.nombre}', fecha: _fechaCorta(hoy)),
          const SizedBox(height: 14),
          Text('¿Dónde entrenas hoy?', style: estiloEtiqueta(color: FitColors.textMuted)),
          Barrido(
            child: Row(
              children: [
                _Lugar(texto: 'Gimnasio', seleccionado: enGimnasio, onTap: () => widget.onLugar(LugarHoy.gimnasio)),
                const SizedBox(width: 18),
                _Lugar(texto: 'En casa', seleccionado: enCasa, onTap: () => widget.onLugar(LugarHoy.casa)),
                const SizedBox(width: 18),
                _Lugar(texto: 'Al aire libre', seleccionado: alAireLibre, onTap: () => widget.onLugar(LugarHoy.aireLibre)),
              ],
            ),
          ),
          if (alAireLibre)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Hay barras o paralelas en el parque', style: TextStyle(fontWeight: FontWeight.w600)),
              value: _s.parqueConBarras,
              onChanged: (v) async {
                await _s.saveParqueConBarras(v);
                if (mounted) setState(() {});
              },
            ),
          const SizedBox(height: 14),
          if (_cargando)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (paraHoy.isEmpty)
            Barrido(
              retraso: const Duration(milliseconds: 80),
              child: _BloqueSinRutina(
                mensaje: noAptas.isEmpty
                    ? 'No tienes rutina programada para hoy.'
                    : alAireLibre
                        ? 'Tu rutina de hoy necesita equipo que no hay en el parque.'
                        : 'Tu rutina de hoy necesita equipo de gimnasio.',
                textoPlan: widget.perfil == null ? 'Crear mi plan' : 'Elegir una plantilla',
                onVerRutinas: widget.onVerRutinas,
                onPlantillas: widget.onPlantillas,
              ),
            )
          else ...[
            Barrido(
              retraso: const Duration(milliseconds: 80),
              child: _BloqueHoy(rutina: paraHoy.first, lugar: lugar, onEmpezar: () => _abrirRutina(paraHoy.first)),
            ),
            if (paraHoy.length > 1) ...[
              const SizedBox(height: 14),
              const Etiqueta('También hoy'),
              const SizedBox(height: 6),
              for (final r in paraHoy.skip(1)) _RutinaHoy(rutina: r, onTap: () => _abrirRutina(r)),
            ],
          ],
          if (noAptas.isNotEmpty && paraHoy.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final r in noAptas) _RutinaHoy(rutina: r, necesitaGimnasio: true, motivo: faltaQue, onTap: () => _abrirRutina(r)),
          ],
          const SizedBox(height: 18),
          _Marcador(semana: semana, meta: meta, racha: racha, record: record),
          if (meta > 0) ...[
            const SizedBox(height: 16),
            _MetaSemanal(valor: semana / meta),
          ],
          const SizedBox(height: 18),
          _Fila(
            icon: Icons.insights,
            titulo: _historial.isEmpty ? 'Mi progreso' : 'Esta semana: $semana ${semana == 1 ? 'entrenamiento' : 'entrenamientos'}',
            detalle: Text(
              _historial.isEmpty
                  ? 'Registra tus entrenamientos y mira cómo avanzas'
                  : (racha > 1 ? 'Racha de $racha semanas seguidas' : 'Ver historial y evolución'),
              style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onTap: () => widget.abrir(const ProgresoScreen(espacio: RutinasStore.propias)),
          ),
          if (enGimnasio && cliente != null) ...[
            const SizedBox(height: 10),
            _Fila(
              icon: Icons.qr_code_2,
              titulo: 'Mostrar mi pase',
              detalle: EstadoPagoChip(cliente),
              destacada: true,
              onTap: () => widget.abrir(const PaseScreen()),
            ),
          ] else if (enGimnasio) ...[
            const SizedBox(height: 10),
            _Fila(
              icon: Icons.link,
              titulo: '¿Tu gimnasio usa FitGym?',
              detalle: Text('Vincúlalo para tener tu pase QR y sus rutinas',
                  style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              onTap: () => widget.abrir(const LoginScreen()),
            ),
          ],
        ],
      ),
    );
  }
}

const _mesesCortos = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

/// "VIE 06 · NOV".
String _fechaCorta(DateTime d) =>
    '${Rutina.nombresDias[d.weekday - 1].substring(0, 3)} ${d.day.toString().padLeft(2, '0')} · ${_mesesCortos[d.month - 1]}'
        .toUpperCase();

String _kg(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Saludo y fecha sobre una regla gruesa de tinta.
class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.saludo, required this.fecha});
  final String saludo;
  final String fecha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: FitColors.ink, width: 3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(saludo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: estiloCifra(30, color: FitColors.ink).copyWith(letterSpacing: -0.5, height: 1)),
          ),
          const SizedBox(width: 12),
          Text(fecha, style: estiloEtiqueta(color: FitColors.ink, size: 12)),
        ],
      ),
    );
  }
}

/// Pestaña subrayada: Gimnasio / En casa.
class _Lugar extends StatelessWidget {
  const _Lugar({required this.texto, required this.seleccionado, required this.onTap});
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: seleccionado,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: seleccionado ? FitColors.accent : Colors.transparent, width: 3),
            ),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.2,
              fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w700,
              color: seleccionado ? FitColors.ink : FitColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bloque oscuro con diagonal roja: lo que toca hoy y el botón para empezar.
class _BloqueHoy extends StatelessWidget {
  const _BloqueHoy({required this.rutina, required this.lugar, required this.onEmpezar});
  final Rutina rutina;
  final LugarHoy lugar;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context) {
    final origen = switch (lugar) {
      LugarHoy.casa => 'en casa',
      LugarHoy.aireLibre => 'al aire libre',
      LugarHoy.gimnasio => rutina.esDelGimnasio ? 'del gimnasio' : 'tuya',
    };
    final musculos = rutina.musculos.take(2).join(' · ');
    const meta = TextStyle(color: FitColors.papel, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1);
    return _Bloque(
      children: [
        Text('HOY TOCA · ${origen.toUpperCase()}', style: estiloEtiqueta(color: FitColors.onBlockMuted, size: 12)),
        const SizedBox(height: 14),
        Text(
          rutina.nombre.toUpperCase(),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: estiloCifra(60, color: FitColors.papel).copyWith(height: 0.85),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          children: [
            Text('${rutina.ejercicios.length} EJERCICIOS', style: meta),
            if (musculos.isNotEmpty) ...[
              Text('/', style: meta.copyWith(color: FitColors.onBlockMuted)),
              Text(musculos.toUpperCase(), style: meta),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Material(
          color: FitColors.papel,
          child: InkWell(
            onTap: onEmpezar,
            child: SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('EMPEZAR', style: estiloCifra(26, color: FitColors.carbon).copyWith(letterSpacing: 1)),
                    const Icon(Icons.arrow_forward, color: FitColors.carbon, size: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// El mismo bloque, cuando hoy no hay rutina: mensaje y salidas.
class _BloqueSinRutina extends StatelessWidget {
  const _BloqueSinRutina({
    required this.mensaje,
    required this.textoPlan,
    required this.onVerRutinas,
    required this.onPlantillas,
  });
  final String mensaje;
  final String textoPlan;
  final VoidCallback onVerRutinas;
  final VoidCallback onPlantillas;

  @override
  Widget build(BuildContext context) {
    return _Bloque(
      children: [
        Text('HOY', style: estiloEtiqueta(color: FitColors.onBlockMuted, size: 12)),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 70),
          child: Text(mensaje, style: const TextStyle(color: FitColors.papel, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: FitColors.papel, foregroundColor: FitColors.carbon),
              onPressed: onVerRutinas,
              child: const Text('Ver mis rutinas'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: FitColors.papel,
                side: const BorderSide(color: FitColors.papel, width: 1.5),
              ),
              onPressed: onPlantillas,
              child: Text(textoPlan),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fondo de bloque, borde fino y la diagonal roja a la derecha.
class _Bloque extends StatelessWidget {
  const _Bloque({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: FitColors.block, border: Border.all(color: FitColors.blockLine)),
      child: Stack(
        children: [
          const Positioned(top: 0, bottom: 0, right: -40, child: DiagonalRoja(ancho: 170)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

/// Marcador de tres columnas entre reglas de tinta.
class _Marcador extends StatelessWidget {
  const _Marcador({required this.semana, required this.meta, required this.racha, required this.record});
  final int semana;
  final int meta;
  final int racha;
  final double? record;

  @override
  Widget build(BuildContext context) {
    final celdas = <Widget>[
      _Celda(
        retraso: 250,
        etiqueta: 'Esta semana',
        cifra: Text.rich(TextSpan(children: [
          TextSpan(text: '$semana'),
          if (meta > 0) TextSpan(text: '/$meta', style: TextStyle(color: FitColors.textMuted)),
        ])),
        color: FitColors.ink,
      ),
      _Celda(retraso: 320, etiqueta: 'Semanas racha', cifra: Text('$racha'), color: FitColors.primary),
      if (record != null)
        _Celda(
          retraso: 390,
          etiqueta: 'Récord',
          cifra: Text.rich(TextSpan(children: [
            TextSpan(text: _kg(record!)),
            const TextSpan(text: 'KG', style: TextStyle(fontSize: 22)),
          ])),
          color: FitColors.ink,
        ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: FitColors.ink)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < celdas.length; i++)
              Expanded(
                child: Container(
                  padding: EdgeInsets.fromLTRB(i == 0 ? 0 : 12, 12, 4, 12),
                  decoration: BoxDecoration(
                    border: i == celdas.length - 1 ? null : Border(right: BorderSide(color: FitColors.line)),
                  ),
                  child: celdas[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.retraso, required this.etiqueta, required this.cifra, required this.color});
  final int retraso;
  final String etiqueta;
  final Widget cifra;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Golpe(
          retraso: Duration(milliseconds: retraso),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(style: estiloCifra(44, color: color), child: cifra),
          ),
        ),
        const SizedBox(height: 4),
        Text(etiqueta.toUpperCase(), style: estiloEtiqueta(color: FitColors.ink)),
      ],
    );
  }
}

/// Barra de la meta semanal (entrenamientos hechos / días del plan).
class _MetaSemanal extends StatelessWidget {
  const _MetaSemanal({required this.valor});
  final double valor;

  @override
  Widget build(BuildContext context) {
    final pct = (valor.clamp(0.0, 1.0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('META SEMANAL', style: estiloEtiqueta(color: FitColors.ink)),
            Text('$pct%', style: estiloEtiqueta(color: FitColors.ink)),
          ],
        ),
        const SizedBox(height: 6),
        BarraLlenado(valor: valor, color: FitColors.ink, fondo: FitColors.line),
      ],
    );
  }
}

/// Fila de acceso: progreso, pase o vincular gimnasio.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.icon,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.destacada = false,
  });
  final IconData icon;
  final String titulo;
  final Widget detalle;
  final VoidCallback onTap;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FitColors.surface,
      shape: Border.all(color: destacada ? FitColors.ink : FitColors.line, width: destacada ? 2 : 1),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(icon, color: FitColors.ink, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: TextStyle(
                          fontFamily: fuenteTitulos,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.1,
                          color: FitColors.ink,
                        )),
                    const SizedBox(height: 2),
                    detalle,
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: FitColors.ink, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Otra rutina de hoy, en fila con regla fina.
class _RutinaHoy extends StatelessWidget {
  const _RutinaHoy({
    required this.rutina,
    required this.onTap,
    this.necesitaGimnasio = false,
    this.motivo = 'Necesita equipo de gimnasio',
  });
  final Rutina rutina;
  final VoidCallback onTap;
  final bool necesitaGimnasio;
  final String motivo;

  @override
  Widget build(BuildContext context) {
    final etiqueta = necesitaGimnasio ? motivo : (rutina.etiqueta ?? 'Tuya');
    return Material(
      color: Colors.transparent,
      shape: Border(bottom: BorderSide(color: FitColors.line)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rutina.nombre,
                        style: TextStyle(
                          fontFamily: fuenteTitulos,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          height: 1.1,
                          color: necesitaGimnasio ? FitColors.textMuted : FitColors.ink,
                        )),
                    const SizedBox(height: 2),
                    Text('${rutina.ejercicios.length} ejercicios · $etiqueta',
                        style: TextStyle(
                          color: necesitaGimnasio ? FitColors.warning : FitColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: necesitaGimnasio ? FitColors.textMuted : FitColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

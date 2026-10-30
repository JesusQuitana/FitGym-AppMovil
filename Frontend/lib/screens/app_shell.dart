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
        backgroundColor: FitColors.surface,
        indicatorColor: FitColors.primary.withAlpha(50),
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
    // Hoy: en el gimnasio, las del gimnasio y las propias; en casa, primero
    // las propias que se pueden hacer sin máquinas.
    final propiasHoy = _mias.where((r) => r.esHoy).toList();
    final aptasCasa = propiasHoy.where((r) => !PlanPersonal.necesitaGimnasio(r, _wger)).toList();
    final paraHoy = enCasa ? aptasCasa : [..._gimnasio.where((r) => r.esHoy), ...propiasHoy];
    final noAptas = enCasa ? propiasHoy.where((r) => !aptasCasa.contains(r)).toList() : const <Rutina>[];
    final semana = Historial.porSemana(_historial, n: 1).first.$2;
    final racha = Historial.rachaSemanas(_historial);

    return RefreshIndicator(
      color: FitColors.primary,
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(cliente == null ? 'Hola 👋' : 'Hola, ${cliente.nombre} 👋',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text('${Rutina.nombresDias[hoy.weekday - 1]} ${fechaLarga(hoy)}',
              style: const TextStyle(color: FitColors.textMuted)),
          const SizedBox(height: 18),
          const Text('¿Dónde entrenas hoy?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              _Lugar(
                icon: Icons.storefront,
                texto: 'Gimnasio',
                seleccionado: !enCasa,
                onTap: () => widget.onLugar(LugarHoy.gimnasio),
              ),
              const SizedBox(width: 10),
              _Lugar(
                icon: Icons.home_outlined,
                texto: 'En casa',
                seleccionado: enCasa,
                onTap: () => widget.onLugar(LugarHoy.casa),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!enCasa && cliente != null) ...[
            _Tarjeta(
              color: FitColors.primary,
              icon: Icons.qr_code_2,
              titulo: 'Mostrar mi pase',
              detalle: 'Para el escáner de la entrada',
              trailing: EstadoPagoChip(cliente, compact: true),
              onTap: () => widget.abrir(const PaseScreen()),
            ),
            const SizedBox(height: 12),
          ] else if (!enCasa) ...[
            _Tarjeta(
              icon: Icons.link,
              titulo: '¿Tu gimnasio usa FitGym?',
              detalle: 'Vincúlalo para tener tu pase QR y sus rutinas',
              onTap: () => widget.abrir(const LoginScreen()),
            ),
            const SizedBox(height: 12),
          ],
          const Text('PARA HOY',
              style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          if (_cargando)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (paraHoy.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enCasa && noAptas.isNotEmpty
                        ? 'Tu rutina de hoy necesita equipo de gimnasio.'
                        : 'No tienes rutina programada para hoy.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(onPressed: widget.onVerRutinas, child: const Text('Ver mis rutinas')),
                      OutlinedButton(
                        onPressed: widget.onPlantillas,
                        child: Text(widget.perfil == null ? 'Crear mi plan' : 'Elegir una plantilla'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            for (final r in paraHoy) _RutinaHoy(rutina: r, onTap: () => _abrirRutina(r)),
          if (noAptas.isNotEmpty && paraHoy.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final r in noAptas) _RutinaHoy(rutina: r, necesitaGimnasio: true, onTap: () => _abrirRutina(r)),
          ],
          const SizedBox(height: 16),
          _Tarjeta(
            icon: Icons.insights,
            titulo: _historial.isEmpty ? 'Mi progreso' : 'Esta semana: $semana ${semana == 1 ? 'entrenamiento' : 'entrenamientos'}',
            detalle: _historial.isEmpty
                ? 'Registra tus entrenamientos y mira cómo avanzas'
                : (racha > 1 ? 'Racha de $racha semanas seguidas 🔥' : 'Ver historial y evolución'),
            onTap: () => widget.abrir(const ProgresoScreen(espacio: RutinasStore.propias)),
          ),
        ],
      ),
    );
  }
}

class _Lugar extends StatelessWidget {
  const _Lugar({required this.icon, required this.texto, required this.seleccionado, required this.onTap});
  final IconData icon;
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: seleccionado,
        button: true,
        child: Material(
          color: seleccionado ? FitColors.primary.withAlpha(45) : FitColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: seleccionado ? FitColors.primary : Colors.transparent, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(icon, color: seleccionado ? FitColors.primary : FitColors.textMuted, size: 28),
                  const SizedBox(height: 6),
                  Text(texto, style: TextStyle(fontWeight: FontWeight.w700, color: seleccionado ? Colors.white : FitColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icon,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.color,
    this.trailing,
  });
  final IconData icon;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final destacada = color != null;
    return Material(
      color: destacada ? color : FitColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Icon(icon, color: destacada ? Colors.white : FitColors.primary, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: destacada ? Colors.white : null)),
                    Text(detalle, style: TextStyle(color: destacada ? Colors.white70 : FitColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(99)),
                  child: trailing,
                )
              else
                Icon(Icons.chevron_right, color: destacada ? Colors.white : FitColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RutinaHoy extends StatelessWidget {
  const _RutinaHoy({required this.rutina, required this.onTap, this.necesitaGimnasio = false});
  final Rutina rutina;
  final VoidCallback onTap;
  final bool necesitaGimnasio;

  @override
  Widget build(BuildContext context) {
    final etiqueta = necesitaGimnasio ? 'Necesita equipo de gimnasio' : (rutina.etiqueta ?? 'Tuya');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: onTap,
          leading: Icon(
            rutina.esDelGimnasio ? Icons.storefront : Icons.event_note,
            color: necesitaGimnasio ? FitColors.textMuted : FitColors.primary,
          ),
          title: Text(rutina.nombre,
              style: TextStyle(fontWeight: FontWeight.w700, color: necesitaGimnasio ? FitColors.textMuted : null)),
          subtitle: Text('${rutina.ejercicios.length} ejercicios · $etiqueta',
              style: TextStyle(color: necesitaGimnasio ? FitColors.warning : FitColors.textMuted, fontSize: 12)),
          trailing: const Icon(Icons.play_circle_outline, color: FitColors.primary),
        ),
      ),
    );
  }
}

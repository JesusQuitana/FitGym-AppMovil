import 'package:flutter/material.dart';

import '../../models/ejercicio_wger.dart';
import '../../data/plantillas.dart';
import '../../services/plan_personal.dart';
import '../../services/session.dart';
import '../../theme.dart';
import 'plantillas_screen.dart';

/// Asistente para quien entrena por su cuenta: objetivo, nivel, días y
/// duración, lugar y molestias. Al final muestra las plantillas sugeridas.
class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key, this.inicial, this.soloPlan = false});

  /// Perfil a editar ("Ajustar mi plan"); null si se crea uno nuevo.
  final PerfilEntrenamiento? inicial;

  /// Se crea el plan desde dentro de la app (no desde la bienvenida): no
  /// cambia dónde entrena hoy.
  final bool soloPlan;

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  static const _totalPasos = 5;

  int _paso = 0;
  late Objetivo? _objetivo = widget.inicial?.objetivo;
  late Nivel? _nivel = widget.inicial?.nivel;
  late int _dias = widget.inicial?.dias ?? 3;
  late int _minutos = widget.inicial?.minutos ?? 45;
  late Lugar? _lugar = widget.inicial?.lugar;
  late final Set<Lesion> _lesiones = {...?widget.inicial?.lesiones};

  bool get _puedeSeguir => switch (_paso) {
        0 => _objetivo != null,
        1 => _nivel != null,
        3 => _lugar != null,
        _ => true,
      };

  Future<void> _siguiente() async {
    if (_paso < _totalPasos - 1) {
      setState(() => _paso++);
      return;
    }
    final perfil = PerfilEntrenamiento(
      objetivo: _objetivo!,
      nivel: _nivel!,
      dias: _dias,
      minutos: _minutos,
      lugar: _lugar!,
      lesiones: _lesiones,
    );
    await PlanPersonal.guardarPerfil(perfil);
    if (widget.inicial == null) {
      await Session.instance.marcarBienvenidaHecha();
      // Quien llega desde "Solo quiero entrenar" empieza entrenando en casa.
      if (!widget.soloPlan && !Session.instance.conGimnasio) await Session.instance.saveLugarHoy(LugarHoy.casa);
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlantillasScreen(perfil: perfil, desdeAsistente: widget.inicial == null),
    ));
  }

  void _atras() {
    if (_paso > 0) {
      setState(() => _paso--);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _atras();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _paso > 0 || Navigator.of(context).canPop() ? BackButton(onPressed: _atras) : null,
          title: Text('Paso ${_paso + 1} de $_totalPasos'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_paso + 1) / _totalPasos,
              backgroundColor: FitColors.surfaceHigh,
              color: FitColors.primary,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _puedeSeguir ? _siguiente : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: Text(_paso == _totalPasos - 1 ? 'Ver mis plantillas' : 'Siguiente'),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_paso), child: _contenido()),
        ),
      ),
    );
  }

  Widget _contenido() => switch (_paso) {
        0 => _Paso(
            titulo: '¿Cuál es tu objetivo?',
            hijos: [
              for (final o in Objetivo.values)
                _Tarjeta(
                  icon: _iconoObjetivo(o),
                  titulo: o.etiqueta,
                  detalle: o.descripcion,
                  seleccionada: _objetivo == o,
                  onTap: () => setState(() => _objetivo = o),
                ),
            ],
          ),
        1 => _Paso(
            titulo: '¿Cuál es tu nivel?',
            hijos: [
              for (final n in Nivel.values)
                _Tarjeta(
                  icon: Icons.signal_cellular_alt,
                  titulo: n.etiqueta,
                  detalle: n.descripcion,
                  seleccionada: _nivel == n,
                  onTap: () => setState(() => _nivel = n),
                ),
            ],
          ),
        2 => _Paso(
            titulo: '¿Cuánto tiempo tienes?',
            hijos: [
              const Text('Días por semana', style: TextStyle(color: FitColors.textMuted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var d = 2; d <= 6; d++)
                    ChoiceChip(
                      label: Text('$d días'),
                      selected: _dias == d,
                      selectedColor: FitColors.primary.withAlpha(70),
                      onSelected: (_) => setState(() => _dias = d),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Duración de cada sesión', style: TextStyle(color: FitColors.textMuted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  for (final m in const [30, 45, 60])
                    ChoiceChip(
                      label: Text(m == 60 ? '60 min o más' : '$m min'),
                      selected: _minutos == m,
                      selectedColor: FitColors.primary.withAlpha(70),
                      onSelected: (_) => setState(() => _minutos = m),
                    ),
                ],
              ),
            ],
          ),
        3 => _Paso(
            titulo: '¿Dónde vas a entrenar?',
            hijos: [
              for (final l in Lugar.values)
                _Tarjeta(
                  icon: switch (l) {
                    Lugar.casaSinEquipo => Icons.home_outlined,
                    Lugar.casaMancuernas => Icons.fitness_center,
                    Lugar.gimnasio => Icons.storefront,
                  },
                  titulo: l.etiqueta,
                  detalle: l.equipos.map((e) => e.etiqueta).join(' · '),
                  seleccionada: _lugar == l,
                  onTap: () => setState(() => _lugar = l),
                ),
            ],
          ),
        _ => _Paso(
            titulo: '¿Tienes alguna molestia?',
            subtitulo: 'Evitaremos los ejercicios que suelen cargar esas zonas. Si tienes una lesión, '
                'consulta a un profesional de la salud antes de empezar.',
            hijos: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Ninguna'),
                    selected: _lesiones.isEmpty,
                    selectedColor: FitColors.ok.withAlpha(60),
                    onSelected: (_) => setState(_lesiones.clear),
                  ),
                  for (final l in Lesion.values)
                    FilterChip(
                      label: Text(l.etiqueta),
                      selected: _lesiones.contains(l),
                      selectedColor: FitColors.warning.withAlpha(60),
                      onSelected: (v) => setState(() => v ? _lesiones.add(l) : _lesiones.remove(l)),
                    ),
                ],
              ),
            ],
          ),
      };

  static IconData _iconoObjetivo(Objetivo o) => switch (o) {
        Objetivo.perderGrasa => Icons.local_fire_department_outlined,
        Objetivo.ganarMasa => Icons.fitness_center,
        Objetivo.tonificar => Icons.auto_awesome_outlined,
        Objetivo.resistencia => Icons.directions_run,
        Objetivo.salud => Icons.favorite_outline,
      };
}

class _Paso extends StatelessWidget {
  const _Paso({required this.titulo, required this.hijos, this.subtitulo});
  final String titulo;
  final String? subtitulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        if (subtitulo != null) ...[
          const SizedBox(height: 8),
          Text(subtitulo!, style: const TextStyle(color: FitColors.textMuted, height: 1.4)),
        ],
        const SizedBox(height: 20),
        ...hijos,
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icon,
    required this.titulo,
    required this.detalle,
    required this.seleccionada,
    required this.onTap,
  });
  final IconData icon;
  final String titulo;
  final String detalle;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: seleccionada ? FitColors.primary.withAlpha(35) : FitColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: seleccionada ? FitColors.primary : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: seleccionada ? FitColors.primary : FitColors.textMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(detalle, style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                if (seleccionada) const Icon(Icons.check_circle, color: FitColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

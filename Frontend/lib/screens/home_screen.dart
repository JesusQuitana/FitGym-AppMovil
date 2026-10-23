import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../models/cliente.dart';
import '../services/api_service.dart';
import '../services/pantalla_segura.dart';
import '../services/recordatorios.dart';
import '../services/session.dart';
import '../services/totp.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'catalogo/maquinas_catalogo.dart';
import 'login_screen.dart';
import 'rutinas/rutinas_tab.dart';

/// Pantalla principal del afiliado: pase QR, rutinas, máquinas y sus datos.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  late Cliente _cliente = Session.instance.cliente!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _aplicarBrillo();
    Recordatorios.programar(_cliente);
    _actualizar(silencioso: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restaurarBrillo();
    PantallaSegura.desproteger();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _aplicarBrillo();
  }

  /// Mientras se muestra el pase: brillo al máximo (para que el escáner lea
  /// el QR al primer intento) y capturas de pantalla bloqueadas. En las demás
  /// pestañas se restablece todo.
  Future<void> _aplicarBrillo() async {
    if (_tab != 0) {
      PantallaSegura.desproteger();
      return _restaurarBrillo();
    }
    PantallaSegura.proteger();
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  Future<void> _restaurarBrillo() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  /// Refresca los datos desde GET /buscar/{id}. Si no hay conexión se sigue
  /// mostrando la copia en caché, así el QR siempre está disponible.
  Future<void> _actualizar({bool silencioso = false}) async {
    final id = _cliente.id;
    if (id == null) return;
    try {
      // El servidor no conoce el código (es la contraseña cifrada): se conserva el local.
      final c = (await ApiService.instance.buscarCliente(id)).copyWith(codigo: _cliente.codigo);
      await Session.instance.saveCliente(c);
      if (c.fechaPago != _cliente.fechaPago) Recordatorios.programar(c);
      if (mounted) setState(() => _cliente = c);
    } catch (e) {
      if (!silencioso && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sin conexión: mostrando datos guardados. ($e)')),
        );
      }
    }
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Cerrar sesión'),
        content: const Text('Tendrás que ingresar de nuevo tu correo y código para ver tu pase.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    if (ok != true) return;
    await Recordatorios.cancelar();
    await Session.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FitLogoInline(),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: switch (_tab) {
        0 => RefreshIndicator(
            onRefresh: _actualizar,
            color: FitColors.primary,
            child: _PaseTab(cliente: _cliente),
          ),
        1 => RutinasTab(clienteId: _cliente.id ?? 0),
        2 => const MaquinasCatalogo(),
        _ => RefreshIndicator(
            onRefresh: _actualizar,
            color: FitColors.primary,
            child: _DatosTab(cliente: _cliente),
          ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: FitColors.surface,
        indicatorColor: FitColors.primary.withAlpha(50),
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _aplicarBrillo();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Mi pase'),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Rutinas',
          ),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Máquinas'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Mis datos'),
        ],
      ),
    );
  }
}

class FitLogoInline extends StatelessWidget {
  const FitLogoInline({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Fit'),
        TextSpan(text: 'Gym', style: TextStyle(color: FitColors.primary)),
      ]),
      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
    );
  }
}

class _PaseTab extends StatelessWidget {
  const _PaseTab({required this.cliente});
  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final vencido = cliente.estadoPago == EstadoPago.vencido;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Hola, ${cliente.nombre} 👋',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Muestra este código en el escáner de la entrada.',
          style: TextStyle(color: FitColors.textMuted),
        ),
        const SizedBox(height: 20),
        FitCard(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MembresiaBadge(cliente.membresia),
                  Text('ID #${cliente.id ?? '-'}', style: const TextStyle(color: FitColors.textMuted)),
                ],
              ),
              const SizedBox(height: 22),
              _QrPase(cliente: cliente),
              const SizedBox(height: 18),
              Text(
                cliente.nombreCompleto,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FitCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: FitColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_available, color: FitColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Próxima fecha de pago', style: TextStyle(color: FitColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(fechaLarga(cliente.fechaPago),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    EstadoPagoChip(cliente),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (vencido) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FitColors.danger.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FitColors.danger.withAlpha(90)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: FitColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tu mensualidad está vencida. Acércate a recepción para renovarla y mantener tu acceso.',
                    style: TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// QR del pase. Con secreto TOTP es dinámico: cambia cada 30 s, muestra la
/// cuenta regresiva y un reloj en vivo para que recepción distinga la pantalla
/// real de una captura. Sin secreto (backend aún sin TOTP) usa el QR estático.
class _QrPase extends StatefulWidget {
  const _QrPase({required this.cliente});
  final Cliente cliente;

  @override
  State<_QrPase> createState() => _QrPaseState();
}

class _QrPaseState extends State<_QrPase> {
  Timer? _timer;

  String? get _secreto => Session.instance.totpSecret;

  @override
  void initState() {
    super.initState();
    if (_secreto != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secreto = _secreto;
    return LayoutBuilder(builder: (context, c) {
      final size = (c.maxWidth - 32).clamp(160, 260).toDouble();
      if (secreto == null) {
        return Column(
          children: [
            PaseQr(data: widget.cliente.qrPayload, size: size),
            const SizedBox(height: 12),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: FitColors.warning),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'QR estático: tu gimnasio aún no activa el QR dinámico.',
                    style: TextStyle(color: FitColors.warning, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        );
      }
      final ahora = Session.instance.ahora;
      final codigo = Totp.codigo(secreto, ahora);
      final restantes = Totp.segundosRestantes(ahora);
      final reloj = '${_dos(ahora.hour)}:${_dos(ahora.minute)}:${_dos(ahora.second)}';
      return Column(
        children: [
          PaseQr(data: widget.cliente.qrDinamico(codigo), size: size),
          const SizedBox(height: 14),
          SizedBox(
            width: size,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: restantes / Totp.periodo,
                minHeight: 6,
                backgroundColor: FitColors.surfaceHigh,
                color: restantes <= 5 ? FitColors.warning : FitColors.ok,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _PuntoEnVivo(),
              const SizedBox(width: 6),
              Text(
                '$reloj · se renueva en $restantes s',
                style: const TextStyle(
                  color: FitColors.textMuted,
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      );
    });
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
}

/// Punto verde que parpadea: indica a recepción que el pase está "en vivo".
class _PuntoEnVivo extends StatefulWidget {
  const _PuntoEnVivo();

  @override
  State<_PuntoEnVivo> createState() => _PuntoEnVivoState();
}

class _PuntoEnVivoState extends State<_PuntoEnVivo> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(_anim),
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(color: FitColors.ok, shape: BoxShape.circle),
      ),
    );
  }
}

class _DatosTab extends StatelessWidget {
  const _DatosTab({required this.cliente});
  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Center(child: Avatar(cliente, radius: 42)),
        const SizedBox(height: 12),
        Center(
          child: Text(cliente.nombreCompleto,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Center(child: MembresiaBadge(cliente.membresia)),
        const SizedBox(height: 22),
        const _SectionTitle('Datos personales'),
        FitCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              InfoTile(icon: Icons.badge_outlined, label: 'Nombre', value: cliente.nombre),
              InfoTile(icon: Icons.badge_outlined, label: 'Apellido', value: cliente.apellido),
              InfoTile(icon: Icons.mail_outline, label: 'Correo electrónico', value: cliente.correo),
              InfoTile(icon: Icons.phone_outlined, label: 'Teléfono', value: cliente.telefono),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Membresía'),
        FitCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              InfoTile(
                icon: iconoMembresia(cliente.membresia),
                label: 'Categoría',
                value: '${cliente.membresia.id} - ${cliente.membresia.nombre}',
              ),
              InfoTile(
                icon: Icons.calendar_month_outlined,
                label: 'Fecha de pago',
                value: fechaCorta(cliente.fechaPago),
                trailing: EstadoPagoChip(cliente, compact: true),
              ),
              InfoTile(icon: Icons.pin_outlined, label: 'Código de acceso', value: '•' * cliente.codigo.length),
              InfoTile(icon: Icons.tag, label: 'ID de afiliado', value: '${cliente.id ?? '-'}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '¿Algún dato es incorrecto? Solicita la corrección en recepción.',
          textAlign: TextAlign.center,
          style: TextStyle(color: FitColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: FitColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

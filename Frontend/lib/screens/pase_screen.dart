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

/// Pase de acceso al gimnasio (QR dinámico). Mientras está abierto sube el
/// brillo al máximo para que el escáner lo lea al primer intento y bloquea
/// las capturas de pantalla. Al abrirse refresca los datos del afiliado.
class PaseScreen extends StatefulWidget {
  const PaseScreen({super.key});

  @override
  State<PaseScreen> createState() => _PaseScreenState();
}

class _PaseScreenState extends State<PaseScreen> with WidgetsBindingObserver {
  late Cliente _cliente = Session.instance.cliente!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _proteger();
    actualizarCliente().then((c) {
      if (c != null && mounted) setState(() => _cliente = c);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PantallaSegura.desproteger();
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError((_) {});
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _proteger();
  }

  Future<void> _proteger() async {
    PantallaSegura.proteger();
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi pase')),
      body: RefreshIndicator(
        color: FitColors.primary,
        onRefresh: () async {
          final c = await actualizarCliente(avisar: context);
          if (c != null && mounted) setState(() => _cliente = c);
        },
        child: _PaseTab(cliente: _cliente),
      ),
    );
  }
}

/// Refresca los datos del afiliado desde el backend (GET /buscar/{id}) y
/// reprograma los avisos de pago si cambió la fecha. Sin conexión devuelve
/// null y se sigue usando la copia guardada.
Future<Cliente?> actualizarCliente({BuildContext? avisar}) async {
  final actual = Session.instance.cliente;
  final id = actual?.id;
  if (actual == null || id == null) return null;
  try {
    // El servidor no conoce el código (es la contraseña cifrada): se conserva el local.
    final c = (await ApiService.instance.buscarCliente(id)).copyWith(codigo: actual.codigo);
    await Session.instance.saveCliente(c);
    if (c.fechaPago != actual.fechaPago) Recordatorios.programar(c);
    return c;
  } catch (e) {
    if (avisar != null && avisar.mounted) {
      ScaffoldMessenger.of(avisar).showSnackBar(
        SnackBar(content: Text('Sin conexión: mostrando datos guardados. ($e)')),
      );
    }
    return null;
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

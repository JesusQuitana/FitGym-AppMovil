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
import '../widgets/editorial.dart';

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
      backgroundColor: FitColors.background,
      appBar: AppBar(
        backgroundColor: FitColors.background,
        foregroundColor: FitColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text('PASE DE ACCESO', style: estiloCifra(24, color: FitColors.ink)),
      ),
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
    final dinamico = Session.instance.totpSecret != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Barrido(child: _Ticket(cliente: cliente)),
        if (vencido) ...[
          const SizedBox(height: 16),
          _NotaRegla(
            color: FitColors.danger,
            texto: 'Tu mensualidad está vencida. Acércate a recepción para renovarla y mantener tu acceso.',
            fuerte: true,
          ),
        ],
        const SizedBox(height: 18),
        _NotaRegla(
          color: FitColors.accent,
          texto: dinamico
              ? 'Acerca la pantalla al escáner. El código cambia cada ${Totp.periodo} s y no sirve en capturas.'
              : 'Acerca la pantalla al escáner de la entrada.',
        ),
      ],
    );
  }
}

/// Colores fijos del boleto: siempre oscuro sobre papel, sin importar el tema,
/// porque el escáner lee mejor ese contraste.
abstract final class _Boleto {
  static const tinta = FitColors.carbon;
  static const suave = Color(0xFF6B6B66);
  static const perforado = Color(0xFFBDBDB5);
  static const pista = Color(0xFFDADAD3);
  static const alDia = Color(0xFF1E7A3E);
  static const porVencer = Color(0xFF8A5A00);
  static const vencido = Color(0xFFB3261E);
}

/// Pase como boleto de evento: datos arriba, perforado y QR abajo.
/// El boleto siempre es papel; la página alrededor sigue el tema.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.cliente});
  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final oscuro = FitColors.oscuro;
    final estado = _estado;
    return Container(
      decoration: BoxDecoration(
        color: oscuro ? FitColors.papel : Colors.white,
        border: oscuro ? null : Border.all(color: FitColors.carbon, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('FITGYM', style: estiloCifra(22, color: _Boleto.tinta)),
                    Container(
                      color: FitColors.carbon,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Text(
                        cliente.membresia.nombre.toUpperCase(),
                        style: const TextStyle(
                          color: FitColors.papel,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Golpe(
                  retraso: const Duration(milliseconds: 250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LineaNombre(cliente.nombre),
                      if (cliente.apellido.isNotEmpty) _LineaNombre(cliente.apellido),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _Campo(etiqueta: 'Estado', valor: estado.$1, color: estado.$2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Campo(
                        etiqueta: 'Próximo pago',
                        valor: fechaCorta(cliente.fechaPago).replaceAll('/', ' / '),
                        color: _Boleto.tinta,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _Perforado(fondo: FitColors.background),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: _QrPase(cliente: cliente),
          ),
        ],
      ),
    );
  }

  (String, Color) get _estado {
    final dias = cliente.diasParaPago;
    return switch (cliente.estadoPago) {
      EstadoPago.alDia => ('Al día', _Boleto.alDia),
      EstadoPago.porVencer => (
          dias == 0 ? 'Vence hoy' : 'Vence en $dias ${dias == 1 ? 'día' : 'días'}',
          _Boleto.porVencer,
        ),
      EstadoPago.vencido => ('Vencida', _Boleto.vencido),
    };
  }
}

/// Una línea del nombre en grande; se encoge si no cabe en vez de cortarse.
class _LineaNombre extends StatelessWidget {
  const _LineaNombre(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          texto.toUpperCase(),
          maxLines: 1,
          style: estiloCifra(52, color: _Boleto.tinta).copyWith(height: 0.88),
        ),
      );
}

class _Campo extends StatelessWidget {
  const _Campo({required this.etiqueta, required this.valor, required this.color});
  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta.toUpperCase(), style: estiloEtiqueta(color: _Boleto.suave, size: 10)),
          const SizedBox(height: 2),
          Text(valor, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      );
}

/// Línea perforada con dos muescas recortadas del color de la página.
class _Perforado extends StatelessWidget {
  const _Perforado({required this.fondo});
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    Widget muesca() => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
        );
    return SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _Guiones())),
          Positioned(left: -14, top: 0, child: muesca()),
          Positioned(right: -14, top: 0, child: muesca()),
        ],
      ),
    );
  }
}

class _Guiones extends CustomPainter {
  const _Guiones();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _Boleto.perforado
      ..strokeWidth = 2;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 10) {
      final fin = x + 6 > size.width ? size.width : x + 6;
      canvas.drawLine(Offset(x, y), Offset(fin, y), p);
    }
  }

  @override
  bool shouldRepaint(_Guiones oldDelegate) => false;
}

/// Nota bajo el boleto con regla izquierda de 3 px.
class _NotaRegla extends StatelessWidget {
  const _NotaRegla({required this.color, required this.texto, this.fuerte = false});
  final Color color;
  final String texto;
  final bool fuerte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
        child: Text(
          texto,
          style: TextStyle(
            color: fuerte ? FitColors.ink : FitColors.textMuted,
            fontSize: 13,
            height: 1.45,
            fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );
}

/// QR del pase. Con secreto TOTP es dinámico: cambia cada 30 s, muestra la
/// cuenta regresiva (barra roja que se vacía) y un reloj en vivo para que
/// recepción distinga la pantalla real de una captura. Sin secreto (backend
/// aún sin TOTP) usa el QR estático.
class _QrPase extends StatefulWidget {
  const _QrPase({required this.cliente});
  final Cliente cliente;

  @override
  State<_QrPase> createState() => _QrPaseState();
}

class _QrPaseState extends State<_QrPase> {
  Timer? _timer;
  double _fraccionAnterior = 1;

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
      final size = (c.maxWidth - 32).clamp(160, 240).toDouble();
      if (secreto == null) {
        return Column(
          children: [
            PaseQr(data: widget.cliente.qrPayload, size: size),
            const SizedBox(height: 12),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: _Boleto.porVencer),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'QR estático: tu gimnasio aún no activa el QR dinámico.',
                    style: TextStyle(color: _Boleto.porVencer, fontSize: 12, fontWeight: FontWeight.w600),
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
      final fraccion = restantes / Totp.periodo;
      // Se vacía de forma continua; al renovarse el código vuelve a llenarse de golpe.
      final animar = !sinMovimiento(context) && fraccion <= _fraccionAnterior;
      _fraccionAnterior = fraccion;
      const estiloFila = TextStyle(
        color: _Boleto.tinta,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        fontFeatures: [FontFeature.tabularFigures()],
      );
      return Column(
        children: [
          PaseQr(data: widget.cliente.qrDinamico(codigo), size: size),
          const SizedBox(height: 14),
          Row(
            children: [
              const _PuntoEnVivo(),
              const SizedBox(width: 6),
              Expanded(child: Text('El código se renueva en $restantes s', style: estiloFila)),
              Text(reloj, style: estiloFila),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            color: _Boleto.pista,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraccion),
              duration: animar ? const Duration(seconds: 1) : Duration.zero,
              curve: Curves.linear,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                heightFactor: 1,
                child: ColoredBox(color: FitColors.accent),
              ),
            ),
          ),
        ],
      );
    });
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');
}

/// Punto verde que parpadea: indica a recepción que el pase está "en vivo".
/// Con movimiento reducido queda fijo (el reloj sigue probando que es en vivo).
class _PuntoEnVivo extends StatefulWidget {
  const _PuntoEnVivo();

  @override
  State<_PuntoEnVivo> createState() => _PuntoEnVivoState();
}

class _PuntoEnVivoState extends State<_PuntoEnVivo> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (sinMovimiento(context)) {
      _anim.value = 1;
    } else if (!_anim.isAnimating) {
      _anim.repeat(reverse: true);
    }
  }

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
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: _Boleto.alDia, shape: BoxShape.circle),
      ),
    );
  }
}

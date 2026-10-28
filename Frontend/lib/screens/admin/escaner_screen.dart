import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/cliente.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Control de acceso en la entrada: la cámara del dispositivo de recepción
/// lee el QR del afiliado y valida su membresía (POST /acceso).
class EscanerScreen extends StatefulWidget {
  const EscanerScreen({super.key});

  @override
  State<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends State<EscanerScreen> {
  static const _duracionResultado = Duration(seconds: 4);

  final _camara = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  ResultadoAcceso? _resultado;
  bool _validando = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _camara.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture captura) {
    // Mientras se valida o se muestra un resultado se ignoran nuevas lecturas.
    if (_validando || _resultado != null) return;
    final valor = captura.barcodes.firstOrNull?.rawValue?.trim();
    if (valor == null || valor.isEmpty) return;
    final datos = Cliente.parseQr(valor);
    if (datos == null) {
      _mostrar(ResultadoAcceso(permitido: false, motivo: 'QR no válido: no es un pase FitGym'));
      return;
    }
    _validar(datos);
  }

  Future<void> _validar(QrAcceso qr) async {
    setState(() => _validando = true);
    try {
      _mostrar(await ApiService.instance.validarAcceso(qr));
    } catch (e) {
      _mostrar(ResultadoAcceso(permitido: false, motivo: '$e'));
    } finally {
      if (mounted) setState(() => _validando = false);
    }
  }

  void _mostrar(ResultadoAcceso r) {
    if (!mounted) return;
    r.permitido ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    setState(() => _resultado = r);
    _timer?.cancel();
    _timer = Timer(_duracionResultado, _siguiente);
  }

  void _siguiente() {
    _timer?.cancel();
    if (mounted) setState(() => _resultado = null);
  }

  Future<void> _codigoManual() async {
    final correo = TextEditingController();
    final codigo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Validar manualmente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: correo,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: fitInput('Correo del afiliado', Icons.mail_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codigo,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fitInput('Código de 4 dígitos', Icons.pin_outlined),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Validar')),
        ],
      ),
    );
    if (ok == true && correo.text.trim().isNotEmpty && codigo.text.length == 4) {
      _siguiente();
      _validar(QrEstatico(correo.text, codigo.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Control de acceso'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _camara.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cambiar cámara',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _camara.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camara,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ErrorCamara(onManual: _codigoManual),
          ),
          const _Visor(),
          if (_validando) const Center(child: CircularProgressIndicator(color: Colors.white)),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _resultado == null
                ? _Instrucciones(onManual: _codigoManual)
                : _TarjetaResultado(resultado: _resultado!, onCerrar: _siguiente),
          ),
        ],
      ),
    );
  }
}

class _Visor extends StatelessWidget {
  const _Visor();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(200), width: 3),
          ),
        ),
      ),
    );
  }
}

class _Instrucciones extends StatelessWidget {
  const _Instrucciones({required this.onManual});
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withAlpha(160), borderRadius: BorderRadius.circular(99)),
          child: const Text('Apunta al código QR del afiliado', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onManual,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          icon: const Icon(Icons.keyboard_outlined),
          label: const Text('Ingresar código manualmente'),
        ),
      ],
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({required this.resultado, required this.onCerrar});
  final ResultadoAcceso resultado;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final ok = resultado.permitido;
    final color = ok ? FitColors.ok : FitColors.danger;
    final c = resultado.cliente;
    return GestureDetector(
      onTap: onCerrar,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.block, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ok ? 'ACCESO PERMITIDO' : 'ACCESO DENEGADO',
                        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(resultado.motivo, style: const TextStyle(color: FitColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            if (c != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Avatar(c),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('Pago: ${fechaCorta(c.fechaPago)}',
                            style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  MembresiaBadge(c.membresia, compact: true),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara({required this.onManual});
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            const Text(
              'No se pudo abrir la cámara. Revisa el permiso de cámara de la app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onManual, child: const Text('Ingresar código manualmente')),
          ],
        ),
      ),
    );
  }
}

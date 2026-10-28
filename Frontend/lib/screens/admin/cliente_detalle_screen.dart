import 'package:flutter/material.dart';

import '../../models/cliente.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class ClienteDetalleScreen extends StatefulWidget {
  const ClienteDetalleScreen({super.key, required this.cliente});
  final Cliente cliente;

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  late Cliente _cliente = widget.cliente;

  Future<void> _registrarPago() async {
    final renovado = await showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FitColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _RenovacionSheet(cliente: _cliente),
    );
    if (renovado == null || !mounted) return;
    setState(() => _cliente = renovado);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Pago registrado. Próximo pago: ${fechaLarga(renovado.fechaPago)}.'),
      backgroundColor: FitColors.ok,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cliente = _cliente;
    return Scaffold(
      appBar: AppBar(title: Text('Cliente #${cliente.id ?? '-'}')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _registrarPago,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Registrar pago / renovar'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              Avatar(cliente, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente.nombreCompleto,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    MembresiaBadge(cliente.membresia, compact: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cliente.codigo.isNotEmpty)
            FitCard(
              child: Column(
                children: [
                  PaseQr(data: cliente.qrPayload, size: 180),
                  const SizedBox(height: 12),
                  Text(
                    cliente.codigo,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 10),
                  ),
                  const Text('Código de acceso', style: TextStyle(color: FitColors.textMuted)),
                ],
              ),
            )
          else
            const FitCard(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: FitColors.textMuted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'El código de acceso es la contraseña del usuario y el servidor lo guarda cifrado. '
                      'El afiliado ve su QR en la app al iniciar sesión.',
                      style: TextStyle(color: FitColors.textMuted, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          FitCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                InfoTile(icon: Icons.mail_outline, label: 'Correo electrónico', value: cliente.correo),
                InfoTile(icon: Icons.phone_outlined, label: 'Teléfono', value: cliente.telefono),
                InfoTile(
                  icon: iconoMembresia(cliente.membresia),
                  label: 'Membresía',
                  value: '${cliente.membresia.id} - ${cliente.membresia.nombre}',
                ),
                InfoTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Fecha de pago',
                  value: fechaLarga(cliente.fechaPago),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 2),
                  child: Align(alignment: Alignment.centerLeft, child: EstadoPagoChip(cliente)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Registra un pago: extiende la fecha de pago N meses (desde hoy si ya
/// estaba vencida) y permite cambiar de membresía. Usa PUT /actualizar/{id}.
class _RenovacionSheet extends StatefulWidget {
  const _RenovacionSheet({required this.cliente});
  final Cliente cliente;

  @override
  State<_RenovacionSheet> createState() => _RenovacionSheetState();
}

class _RenovacionSheetState extends State<_RenovacionSheet> {
  static const _opcionesMeses = [1, 3, 6, 12];

  late Membresia _membresia = widget.cliente.membresia;
  int _meses = 1;
  bool _guardando = false;
  String? _error;

  DateTime get _nuevaFecha {
    final c = widget.cliente;
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final base = c.estadoPago == EstadoPago.vencido ? hoy : c.fechaPago;
    return sumarMeses(base, _meses);
  }

  Future<void> _confirmar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizado = await ApiService.instance.actualizarCliente(
        widget.cliente.copyWith(membresia: _membresia, fechaPago: _nuevaFecha),
      );
      if (mounted) Navigator.pop(context, actualizado);
    } catch (e) {
      // Se muestra dentro de la hoja: un SnackBar quedaría tapado por ella.
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: FitColors.textMuted, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Registrar pago', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(c.nombreCompleto, style: const TextStyle(color: FitColors.textMuted)),
            const SizedBox(height: 18),
            const Text('Membresía', style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            MembresiaSelector(value: _membresia, onChanged: (m) => setState(() => _membresia = m)),
            const SizedBox(height: 18),
            const Text('Meses pagados', style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in _opcionesMeses)
                  ChoiceChip(
                    label: Text(m == 1 ? '1 mes' : '$m meses'),
                    selected: _meses == m,
                    selectedColor: FitColors.primary.withAlpha(70),
                    onSelected: (_) => setState(() => _meses = m),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FitCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Actual', style: TextStyle(color: FitColors.textMuted, fontSize: 12)),
                        Text(fechaCorta(c.fechaPago), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: FitColors.textMuted),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Nueva fecha de pago', style: TextStyle(color: FitColors.textMuted, fontSize: 12)),
                        Text(
                          fechaCorta(_nuevaFecha),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: FitColors.ok, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (c.estadoPago == EstadoPago.vencido)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'La membresía estaba vencida: el nuevo periodo empieza hoy.',
                  style: TextStyle(color: FitColors.warning, fontSize: 12),
                ),
              ),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FitColors.danger.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FitColors.danger.withAlpha(90)),
                ),
                child: Text(_error!, style: const TextStyle(color: FitColors.danger, fontSize: 13, height: 1.35)),
              ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _guardando ? null : _confirmar,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Confirmar pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

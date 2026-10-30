import 'package:flutter/material.dart';

import '../models/cliente.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'pase_screen.dart';

/// Datos personales y membresía del afiliado vinculado.
class MisDatosScreen extends StatefulWidget {
  const MisDatosScreen({super.key});

  @override
  State<MisDatosScreen> createState() => _MisDatosScreenState();
}

class _MisDatosScreenState extends State<MisDatosScreen> {
  late Cliente _cliente = Session.instance.cliente!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos')),
      body: RefreshIndicator(
        color: FitColors.primary,
        onRefresh: () async {
          final c = await actualizarCliente(avisar: context);
          if (c != null && mounted) setState(() => _cliente = c);
        },
        child: _DatosTab(cliente: _cliente),
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

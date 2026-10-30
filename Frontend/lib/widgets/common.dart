import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/cliente.dart';
import '../theme.dart';

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String fechaCorta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fechaLarga(DateTime d) => '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

Color colorMembresia(Membresia m) => switch (m) {
      Membresia.vip => FitColors.vip,
      Membresia.premium => FitColors.premium,
      Membresia.regular => FitColors.regular,
    };

IconData iconoMembresia(Membresia m) => switch (m) {
      Membresia.vip => Icons.workspace_premium,
      Membresia.premium => Icons.star_rounded,
      Membresia.regular => Icons.fitness_center,
    };

InputDecoration fitInput(String label, IconData icon, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: FitColors.surfaceHigh,
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: FitColors.primary, width: 1.5),
      ),
    );

/// Permite mostrar mensajes aunque la pantalla que los originó ya se cerró.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('$error'),
    backgroundColor: FitColors.danger,
  ));
}

class FitLogo extends StatelessWidget {
  const FitLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(
              colors: [FitColors.primary, Color(0xFFFF8A3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(Icons.fitness_center, color: Colors.white, size: size * 0.55),
        ),
        const SizedBox(height: 12),
        Text.rich(
          const TextSpan(children: [
            TextSpan(text: 'Fit'),
            TextSpan(text: 'Gym', style: TextStyle(color: FitColors.primary)),
          ]),
          style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ],
    );
  }
}

class MembresiaBadge extends StatelessWidget {
  const MembresiaBadge(this.membresia, {super.key, this.compact = false});
  final Membresia membresia;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = colorMembresia(membresia);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 3 : 6),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconoMembresia(membresia), size: compact ? 13 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            membresia.nombre.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 13,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class EstadoPagoChip extends StatelessWidget {
  const EstadoPagoChip(this.cliente, {super.key, this.compact = false});
  final Cliente cliente;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dias = cliente.diasParaPago;
    final (Color color, IconData icon, String texto) = switch (cliente.estadoPago) {
      EstadoPago.alDia => (FitColors.ok, Icons.check_circle, compact ? 'Al día' : 'Al día · faltan $dias días'),
      EstadoPago.porVencer => (
          FitColors.warning,
          Icons.schedule,
          dias == 0 ? 'Vence hoy' : (compact ? 'Por vencer' : 'Vence en $dias ${dias == 1 ? 'día' : 'días'}')
        ),
      EstadoPago.vencido => (
          FitColors.danger,
          Icons.error,
          compact ? 'Vencida' : 'Vencida hace ${-dias} ${dias == -1 ? 'día' : 'días'}'
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 14 : 18, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: compact ? 12 : 14)),
      ],
    );
  }
}

/// QR negro sobre blanco con zona de silencio: máximo contraste para el
/// escáner óptico de la entrada.
class PaseQr extends StatelessWidget {
  const PaseQr({super.key, required this.data, this.size = 240});
  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.icon, required this.label, required this.value, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FitColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: FitColors.textMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class FitCard extends StatelessWidget {
  const FitCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: child,
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.cliente, {super.key, this.radius = 22});
  final Cliente cliente;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = colorMembresia(cliente.membresia);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withAlpha(45),
      child: Text(
        cliente.iniciales,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: radius * 0.75),
      ),
    );
  }
}

class MembresiaSelector extends StatelessWidget {
  const MembresiaSelector({super.key, required this.value, required this.onChanged});
  final Membresia value;
  final ValueChanged<Membresia> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in Membresia.values) ...[
          Expanded(
            child: _MembresiaOpcion(membresia: m, selected: value == m, onTap: () => onChanged(m)),
          ),
          if (m != Membresia.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _MembresiaOpcion extends StatelessWidget {
  const _MembresiaOpcion({required this.membresia, required this.selected, required this.onTap});
  final Membresia membresia;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colorMembresia(membresia);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(40) : FitColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(iconoMembresia(membresia), color: selected ? color : FitColors.textMuted),
            const SizedBox(height: 6),
            Text(
              membresia.nombre,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? color : Colors.white,
              ),
            ),
            Text('Plan ${membresia.id}', style: const TextStyle(color: FitColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Logo en una línea para la barra superior.
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

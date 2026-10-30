import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/common.dart';
import '../login_screen.dart';
import '../personal/asistente_screen.dart';

/// Primera pantalla (una sola vez). Dos caminos claros; ambos llevan a la
/// misma app, y lo que no se elija ahora se puede sumar después desde Perfil.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            const Center(child: FitLogo(size: 72)),
            const SizedBox(height: 36),
            const Text('¿Cómo quieres usar FitGym?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 8),
            const Text(
              'Puedes tener las dos cosas: tu gimnasio y tu plan para entrenar en casa. '
              'Lo que no elijas ahora lo sumas después desde tu perfil.',
              style: TextStyle(color: FitColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 28),
            _Opcion(
              icon: Icons.storefront,
              titulo: 'Tengo gimnasio con FitGym',
              detalle: 'Si recepción te dio un código de 4 dígitos. Lo vinculas una sola vez y tendrás '
                  'tu pase QR y las rutinas de tu gimnasio.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
            _Opcion(
              icon: Icons.self_improvement,
              titulo: 'Solo quiero entrenar',
              detalle: 'En casa o en cualquier gimnasio. Te armamos un plan según tu objetivo en menos de un minuto.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AsistenteScreen())),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () => abrirAccesoRecepcion(context),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                label: const Text('Soy personal de recepción'),
                style: TextButton.styleFrom(foregroundColor: FitColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.icon, required this.titulo, required this.detalle, required this.onTap});
  final IconData icon;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: FitColors.primary.withAlpha(40), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: FitColors.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(detalle, style: const TextStyle(color: FitColors.textMuted, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: FitColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

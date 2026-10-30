import 'package:flutter/material.dart';

import '../services/plan_personal.dart';
import '../services/recordatorios.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'mis_datos_screen.dart';
import 'pase_screen.dart';
import 'personal/asistente_screen.dart';
import 'settings_screen.dart';

/// Perfil: el gimnasio vinculado (si lo hay), el plan para entrenar y el
/// acceso de recepción. Vincular o desvincular el gimnasio no afecta las
/// rutinas propias ni el historial.
class PerfilTab extends StatefulWidget {
  const PerfilTab({super.key, required this.perfil, required this.abrir, required this.onPlantillas});
  final PerfilEntrenamiento? perfil;
  final Future<void> Function(Widget) abrir;
  final VoidCallback onPlantillas;

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  Future<void> _desvincular() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Desvincular gimnasio'),
        content: const Text(
          'Dejarás de ver tu pase y las rutinas del gimnasio en este teléfono. '
          'Tus rutinas propias y tu historial se conservan. Para volver a vincularlo necesitarás tu código.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FitColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Recordatorios.cancelarPagos();
    await Session.instance.logout();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cliente = Session.instance.cliente;
    final p = widget.perfil;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            if (cliente != null) Avatar(cliente, radius: 28) else const CircleAvatar(radius: 28, child: Icon(Icons.person)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cliente?.nombreCompleto ?? 'Mi perfil', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  if (cliente != null) ...[
                    const SizedBox(height: 4),
                    MembresiaBadge(cliente.membresia, compact: true),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _Seccion('Mi gimnasio'),
        if (cliente != null) ...[
          _Accion(Icons.qr_code_2, 'Mi pase', 'QR para el escáner de la entrada', () => widget.abrir(const PaseScreen())),
          _Accion(Icons.badge_outlined, 'Mis datos y membresía', 'Fecha de pago: ${fechaCorta(cliente.fechaPago)}',
              () => widget.abrir(const MisDatosScreen())),
          _Accion(Icons.link_off, 'Desvincular gimnasio', 'Tus rutinas propias se conservan', _desvincular,
              color: FitColors.danger),
        ] else
          _Accion(Icons.link, 'Vincular mi gimnasio', 'Si recepción te dio un código de 4 dígitos',
              () => widget.abrir(const LoginScreen())),
        const SizedBox(height: 18),
        const _Seccion('Mi plan para entrenar'),
        if (p != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                _Dato(Icons.flag_outlined, 'Objetivo', p.objetivo.etiqueta),
                _Dato(Icons.signal_cellular_alt, 'Nivel', p.nivel.etiqueta),
                _Dato(Icons.calendar_month_outlined, 'Frecuencia', '${p.dias} días · ${p.minutos} min'),
                _Dato(Icons.home_outlined, 'En casa', p.lugar.etiqueta),
                _Dato(Icons.healing_outlined, 'Molestias',
                    p.lesiones.isEmpty ? 'Ninguna' : p.lesiones.map((l) => l.etiqueta).join(', ')),
              ],
            ),
          ),
          _Accion(Icons.tune, 'Ajustar mi plan', 'Vuelve a responder el asistente',
              () => widget.abrir(AsistenteScreen(inicial: p))),
          _Accion(Icons.auto_awesome, 'Ver plantillas', 'Agrega rutinas sugeridas para tu objetivo', widget.onPlantillas),
        ] else
          _Accion(Icons.auto_awesome, 'Crear mi plan', 'Objetivo, nivel y equipo: te sugerimos rutinas',
              widget.onPlantillas),
        const SizedBox(height: 18),
        const _Seccion('Más'),
        _Accion(Icons.admin_panel_settings_outlined, 'Acceso de recepción', 'Solo para el personal del gimnasio',
            () => abrirAccesoRecepcion(context)),
        _Accion(Icons.settings_outlined, 'Ajustes de conexión', 'Servidor y modo demo',
            () => widget.abrir(const SettingsScreen())),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(texto.toUpperCase(),
            style: const TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      );
}

class _Dato extends StatelessWidget {
  const _Dato(this.icon, this.label, this.valor);
  final IconData icon;
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 20, color: FitColors.textMuted),
            const SizedBox(width: 12),
            SizedBox(width: 90, child: Text(label, style: const TextStyle(color: FitColors.textMuted))),
            Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _Accion extends StatelessWidget {
  const _Accion(this.icon, this.titulo, this.detalle, this.onTap, {this.color});
  final IconData icon;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: onTap,
            leading: Icon(icon, color: color ?? FitColors.primary),
            title: Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            subtitle: Text(detalle, style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: FitColors.textMuted),
          ),
        ),
      );
}

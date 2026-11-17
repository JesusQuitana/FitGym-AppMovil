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
            decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(2)),
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
        const _Seccion('Apariencia'),
        const _SelectorTema(),
        const SizedBox(height: 18),
        const _Seccion('Más'),
        _Accion(Icons.privacy_tip_outlined, 'Política de privacidad', 'Uso de datos personales y cámara',
            () => mostrarPoliticaPrivacidad(context)),
        _Accion(Icons.delete_forever_outlined, 'Eliminar cuenta y datos', 'Borrar mis datos de este teléfono y solicitar baja',
            () => confirmarEliminarCuentaYDatos(context, onCompletado: () {
                  if (mounted) setState(() {});
                }),
            color: FitColors.danger),
        _Accion(Icons.admin_panel_settings_outlined, 'Acceso de recepción', 'Solo para el personal del gimnasio',
            () => abrirAccesoRecepcion(context)),
        _Accion(Icons.settings_outlined, 'Ajustes de conexión', 'Servidor y modo demo',
            () => widget.abrir(const SettingsScreen())),
      ],
    );
  }
}

/// Muestra la Política de Privacidad de FitGym dentro de la app (requisito de
/// Google Play para apps con cuentas de usuario y permiso de cámara).
Future<void> mostrarPoliticaPrivacidad(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FitColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Text('Política de privacidad', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(
            'FitGym respeta tu privacidad y protege tus datos personales. '
            'Esta política describe qué información maneja la aplicación y con qué finalidad:',
            style: TextStyle(color: FitColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          const Text('1. Datos personales y de membresía', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Si vinculas tu gimnasio, la app muestra tu nombre, apellido, correo electrónico, '
            'teléfono y fecha de vencimiento de pago registrados por la recepción de tu gimnasio, '
            'con el único fin de generar tu pase de entrada QR y mostrarte las rutinas asignadas.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          const Text('2. Uso de la cámara (android.permission.CAMERA)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'El permiso de cámara se utiliza exclusivamente en el módulo de recepción del gimnasio '
            'para escanear los códigos QR de acceso de los afiliados. No se graban videos ni se '
            'almacenan ni envían fotografías.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          const Text('3. Almacenamiento seguro y entrenamiento local', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Las credenciales de acceso y el secreto TOTP de tu pase dinámico se guardan cifrados '
            'en el teléfono mediante Android Keystore. Tus rutinas personales, plan e historial de '
            'entrenamiento se guardan localmente en tu dispositivo y no se comparten con terceros.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          const Text('4. Eliminación de cuenta y datos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Puedes borrar en cualquier momento todos tus datos locales, rutinas, historial y sesión '
            'desde Perfil → Eliminar cuenta y datos, así como solicitar en recepción la eliminación '
            'definitiva de tu ficha de afiliado en el servidor del gimnasio.',
            style: TextStyle(height: 1.45),
          ),
        ],
      ),
    ),
  );
}

/// Diálogo de confirmación para borrar todos los datos del dispositivo y
/// desvincular/solicitar la baja de la cuenta (requisito de Google Play).
Future<void> confirmarEliminarCuentaYDatos(BuildContext context, {VoidCallback? onCompletado}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: FitColors.surface,
      title: const Text('Eliminar cuenta y datos'),
      content: const Text(
        'Esta acción borrará de este teléfono tu sesión vinculada, credenciales, '
        'rutinas propias, plan personal e historial de entrenamientos.\n\n'
        'Si además deseas dar de baja tu ficha de afiliado en la base de datos de tu gimnasio, '
        'solicítalo en recepción presentando tu correo registrado.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: FitColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar mis datos'),
        ),
      ],
    ),
  );
  if (confirmar != true) return;
  await Recordatorios.cancelarPagos();
  await Session.instance.eliminarDatosLocales();
  onCompletado?.call();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Se eliminaron tus datos y credenciales de este dispositivo.')),
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
            style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
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
            SizedBox(width: 90, child: Text(label, style: TextStyle(color: FitColors.textMuted))),
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
          borderRadius: BorderRadius.circular(2),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            onTap: onTap,
            leading: Icon(icon, color: color ?? FitColors.primary),
            title: Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            subtitle: Text(detalle, style: TextStyle(color: FitColors.textMuted, fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: FitColors.textMuted),
          ),
        ),
      );
}

/// Sistema / Claro / Oscuro. "Sistema" sigue al teléfono; las otras dos
/// opciones se guardan y se mantienen aunque el teléfono cambie de tema.
class _SelectorTema extends StatelessWidget {
  const _SelectorTema();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Session.instance.tema,
      builder: (context, modo, _) {
        final aviso = switch (modo) {
          ThemeMode.system => 'Sigue el tema de tu teléfono.',
          ThemeMode.light => 'Elegiste claro. Se mantiene aunque el teléfono cambie de tema.',
          ThemeMode.dark => 'Elegiste oscuro. Se mantiene aunque el teléfono cambie de tema.',
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto_outlined)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {modo},
                onSelectionChanged: (s) => Session.instance.saveTema(s.first),
              ),
              const SizedBox(height: 8),
              Text(aviso, style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}

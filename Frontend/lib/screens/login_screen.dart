import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin/admin_home_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  bool _cargando = false;
  bool _verCodigo = false;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      final sesion = await ApiService.instance.login(_correo.text, _codigo.text);
      await Session.instance.saveCliente(
        sesion.cliente,
        totpSecret: sesion.totpSecret,
        relojOffset: sesion.relojOffset,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _accesoAdmin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdminLoginDialog(),
    );
    if (ok == true && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Ajustes de conexión',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen()))
                .then((_) => setState(() {})),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: FitLogo(size: 80)),
                  const SizedBox(height: 28),
                  const Text(
                    'Bienvenido',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ingresa con tu correo y el código de 4 dígitos que te entregó recepción para obtener tu pase QR.',
                    style: TextStyle(color: FitColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: fitInput('Correo electrónico', Icons.mail_outline, hint: 'tucorreo@ejemplo.com'),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Ingresa tu correo';
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Correo no válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    obscureText: !_verCodigo,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _ingresar(),
                    style: const TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: fitInput('Código de 4 dígitos', Icons.pin_outlined).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_verCodigo ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _verCodigo = !_verCodigo),
                      ),
                    ),
                    validator: (v) => (v?.length ?? 0) == 4 ? null : 'El código debe tener 4 dígitos',
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _cargando ? null : _ingresar,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: _cargando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Text('Ingresar'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (Session.instance.modoDemo)
                    const FitCard(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: FitColors.warning, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Modo demo: prueba con eddy@fitgym.com y el código 1234.',
                              style: TextStyle(color: FitColors.textMuted, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _accesoAdmin,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Soy administrador'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inicio de sesión de recepción contra POST /auth/login (usuario con rol ADMIN).
class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ApiService.instance.loginAdmin(_usuario.text, _password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FitColors.surface,
      title: const Text('Acceso administrador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _usuario,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: fitInput('Usuario', Icons.person_outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            onSubmitted: (_) => _entrar(),
            decoration: fitInput('Contraseña', Icons.lock_outline),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: FitColors.danger, fontSize: 13)),
          ],
          if (Session.instance.modoDemo) ...[
            const SizedBox(height: 10),
            const Text(
              'Modo demo: ${AppConfig.demoAdminUser} / ${AppConfig.demoAdminPassword}',
              style: TextStyle(color: FitColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _cargando ? null : _entrar,
          child: _cargando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Entrar'),
        ),
      ],
    );
  }
}

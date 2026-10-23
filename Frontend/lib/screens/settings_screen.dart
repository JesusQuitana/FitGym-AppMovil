import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Ajustes de conexión con el backend Spring Boot.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController(text: Session.instance.baseUrl);
  bool _demo = Session.instance.modoDemo;
  bool _probando = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    await Session.instance.saveSettings(baseUrl: _url.text.trim(), modoDemo: _demo);
  }

  Future<void> _probar() async {
    await _guardar();
    setState(() => _probando = true);
    try {
      final n = (await ApiService.instance.listarClientes()).length;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Conexión correcta: $n clientes registrados.'),
        backgroundColor: FitColors.ok,
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Ajustes de conexión')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FitCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: SwitchListTile(
                value: _demo,
                onChanged: (v) {
                  setState(() => _demo = v);
                  _guardar();
                },
                title: const Text('Modo demo'),
                subtitle: const Text(
                  'Usa datos de ejemplo sin necesidad del servidor.',
                  style: TextStyle(color: FitColors.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _url,
              enabled: !_demo,
              onChanged: (_) => _guardar(),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: fitInput('URL del servidor (API REST)', Icons.dns_outlined,
                  hint: 'http://192.168.1.50:3000'),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Emulador Android: http://10.0.2.2:3000\n'
              '• Teléfono físico: http://<IP de la PC en la red Wi-Fi>:3000',
              style: TextStyle(color: FitColors.textMuted, height: 1.6, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _probando ? null : _probar,
                icon: _probando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: const Text('Probar conexión (GET /clientes)'),
              ),
            ),
          ],
        ),
    );
  }
}

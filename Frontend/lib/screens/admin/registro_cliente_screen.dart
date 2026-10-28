import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/cliente.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Registro presencial en recepción (POST /agregar). Al guardar se muestra el
/// código de 4 dígitos que el administrador le entrega al cliente.
class RegistroClienteScreen extends StatefulWidget {
  const RegistroClienteScreen({super.key});

  @override
  State<RegistroClienteScreen> createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _codigo = TextEditingController();
  Membresia _membresia = Membresia.regular;
  DateTime _fechaPago = DateTime.now().add(const Duration(days: 30));
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _generarCodigo();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _correo, _telefono, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _generarCodigo() => _codigo.text = ApiService.instance.generarCodigo();

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: hoy.subtract(const Duration(days: 365)),
      lastDate: hoy.add(const Duration(days: 730)),
      helpText: 'Fecha de pago',
    );
    if (f != null) setState(() => _fechaPago = f);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    try {
      final existentes = await ApiService.instance.listarClientes();
      final correo = _correo.text.trim().toLowerCase();
      if (existentes.any((c) => c.correo.toLowerCase() == correo)) {
        throw ApiException('Ya existe un cliente registrado con ese correo.');
      }
      final nuevo = await ApiService.instance.agregarCliente(Cliente(
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        correo: correo,
        telefono: _telefono.text.trim(),
        membresia: _membresia,
        fechaPago: _fechaPago,
        codigo: _codigo.text,
      ));
      if (!mounted) return;
      await _confirmacion(nuevo);
      if (mounted) Navigator.of(context).pop(nuevo);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmacion(Cliente c) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        icon: const Icon(Icons.check_circle, color: FitColors.ok, size: 48),
        title: const Text('Cliente registrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrega este código a ${c.nombre}. Con él y su correo podrá ingresar a la app desde su casa.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FitColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: FitColors.primary.withAlpha(35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                c.codigo,
                style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 12),
              ),
            ),
            const SizedBox(height: 10),
            Text(c.correo, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo, dar acceso')),
        ],
      ),
    );
  }

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar cliente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _Seccion('Datos personales'),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: fitInput('Nombre', Icons.person_outline),
              validator: _requerido,
            ),
            gap,
            TextFormField(
              controller: _apellido,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: fitInput('Apellido', Icons.person_outline),
              validator: _requerido,
            ),
            gap,
            TextFormField(
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: fitInput('Correo electrónico', Icons.mail_outline),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Campo obligatorio';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Correo no válido';
                return null;
              },
            ),
            gap,
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
              decoration: fitInput('Teléfono', Icons.phone_outlined, hint: '0414-1234567'),
              validator: (v) => (v?.replaceAll(RegExp(r'\D'), '').length ?? 0) < 7 ? 'Teléfono no válido' : null,
            ),
            const SizedBox(height: 24),
            const _Seccion('Membresía'),
            MembresiaSelector(
              value: _membresia,
              onChanged: (m) => setState(() => _membresia = m),
            ),
            gap,
            Material(
              color: FitColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('Fecha de pago', style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
                subtitle: Text(fechaLarga(_fechaPago),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _elegirFecha,
              ),
            ),
            const SizedBox(height: 24),
            const _Seccion('Código de acceso'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 8),
                    decoration: fitInput('4 dígitos', Icons.pin_outlined),
                    validator: (v) => (v?.length ?? 0) == 4 ? null : 'Debe tener 4 dígitos',
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Generar otro código',
                  onPressed: _generarCodigo,
                  icon: const Icon(Icons.casino_outlined),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Icon(Icons.how_to_reg),
                label: const Text('Registrar y dar acceso'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/cliente.dart';
import '../../services/api_service.dart';
import '../../services/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'cliente_detalle_screen.dart';
import 'escaner_screen.dart';
import 'maquinas_admin_screen.dart';
import 'registro_cliente_screen.dart';
import 'rutinas_gym_admin_screen.dart';

/// Módulo administrativo de recepción: consulta (GET /clientes, GET /buscar/{id})
/// y alta de clientes (POST /agregar).
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;
  String _filtro = '';
  Membresia? _filtroMembresia;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    // Al salir de recepción se descarta el token de administrador.
    Session.instance.cerrarAdmin();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ApiService.instance.listarClientes();
      lista.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      if (mounted) setState(() => _clientes = lista);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Cliente> get _visibles {
    final q = _filtro.trim().toLowerCase();
    return _clientes.where((c) {
      if (_filtroMembresia != null && c.membresia != _filtroMembresia) return false;
      if (q.isEmpty) return true;
      return c.nombreCompleto.toLowerCase().contains(q) ||
          c.correo.toLowerCase().contains(q) ||
          c.codigo.contains(q);
    }).toList();
  }

  Future<void> _buscarPorId() async {
    final ctrl = TextEditingController();
    final id = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FitColors.surface,
        title: const Text('Buscar por ID'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: fitInput('ID del cliente', Icons.tag),
          onSubmitted: (v) => Navigator.pop(ctx, int.tryParse(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    if (id == null || !mounted) return;
    try {
      final c = await ApiService.instance.buscarCliente(id);
      if (!mounted) return;
      _abrir(c);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _abrir(Cliente c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClienteDetalleScreen(cliente: c)));
    // Puede haberse registrado un pago en el detalle.
    if (mounted) _cargar();
  }

  void _escanear() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EscanerScreen()));
  }

  Future<void> _registrar() async {
    final nuevo = await Navigator.of(context).push<Cliente>(
      MaterialPageRoute(builder: (_) => const RegistroClienteScreen()),
    );
    if (nuevo != null) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final alDia = _clientes.where((c) => c.estadoPago == EstadoPago.alDia).length;
    final porVencer = _clientes.where((c) => c.estadoPago == EstadoPago.porVencer).length;
    final vencidos = _clientes.where((c) => c.estadoPago == EstadoPago.vencido).length;
    final visibles = _visibles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recepción', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Buscar por ID', icon: const Icon(Icons.manage_search), onPressed: _buscarPorId),
          IconButton(tooltip: 'Recargar', icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrar,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Registrar cliente'),
        backgroundColor: FitColors.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        color: FitColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            Material(
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [FitColors.primary, Color(0xFFFF8A3D)]),
                ),
                child: InkWell(
                  onTap: _escanear,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 36),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Control de acceso',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                              Text('Escanear el QR de un afiliado en la entrada',
                                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Acceso(
                  icon: Icons.fitness_center,
                  label: 'Máquinas',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MaquinasAdminScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                _Acceso(
                  icon: Icons.event_note_outlined,
                  label: 'Rutinas',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RutinasGymAdminScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Stat(label: 'Clientes', value: _clientes.length, color: FitColors.primary),
                const SizedBox(width: 8),
                _Stat(label: 'Al día', value: alDia, color: FitColors.ok),
                const SizedBox(width: 8),
                _Stat(label: 'Por vencer', value: porVencer, color: FitColors.warning),
                const SizedBox(width: 8),
                _Stat(label: 'Vencidos', value: vencidos, color: FitColors.danger),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _filtro = v),
              decoration: fitInput('Buscar por nombre, correo o código', Icons.search),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filtroChip('Todas', null),
                  for (final m in Membresia.values) _filtroChip(m.nombre, m),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _Vacio(
                icon: Icons.cloud_off,
                texto: _error!,
                accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
              )
            else if (visibles.isEmpty)
              const _Vacio(icon: Icons.person_search, texto: 'No hay clientes que coincidan.')
            else
              for (final c in visibles) _ClienteTile(cliente: c, onTap: () => _abrir(c)),
          ],
        ),
      ),
    );
  }

  Widget _filtroChip(String label, Membresia? m) {
    final selected = _filtroMembresia == m;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: (m == null ? FitColors.primary : colorMembresia(m)).withAlpha(60),
        onSelected: (_) => setState(() => _filtroMembresia = m),
      ),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: FitColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right, color: FitColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        decoration: BoxDecoration(
          color: FitColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 3,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FitColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  const _ClienteTile({required this.cliente, required this.onTap});
  final Cliente cliente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FitColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Avatar(cliente),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              cliente.nombreCompleto,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MembresiaBadge(cliente.membresia, compact: true),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cliente.correo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: FitColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          EstadoPagoChip(cliente, compact: true),
                          const Spacer(),
                          Text(
                            'Pago ${fechaCorta(cliente.fechaPago)}',
                            style: const TextStyle(color: FitColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.icon, required this.texto, this.accion});
  final IconData icon;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: FitColors.textMuted),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: FitColors.textMuted)),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

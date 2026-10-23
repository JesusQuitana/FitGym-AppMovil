/// Tipos de membresía según la tabla `membresia` de app_gym_db.
enum Membresia {
  vip(1, 'VIP'),
  premium(2, 'Premium'),
  regular(3, 'Regular');

  const Membresia(this.id, this.nombre);

  final int id;
  final String nombre;

  static Membresia fromId(int? id) =>
      Membresia.values.firstWhere((m) => m.id == id, orElse: () => Membresia.regular);

  /// Acepta el formato que devuelva el backend: un objeto JPA
  /// `{"id":1,"membresia":"VIP"}`, un entero (FK) o el nombre como texto.
  /// En el objeto se prioriza el nombre, por si los id de la tabla difieren.
  static Membresia fromJson(dynamic value) {
    if (value is Map) {
      final nombre = value['membresia'] ?? value['nombre'];
      if (nombre is String && nombre.isNotEmpty) return fromJson(nombre);
      return fromId(_toInt(value['id']));
    }
    if (value is num) return fromId(value.toInt());
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return fromId(asInt);
      return Membresia.values.firstWhere(
        (m) => m.nombre.toLowerCase() == value.toLowerCase(),
        orElse: () => Membresia.regular,
      );
    }
    return Membresia.regular;
  }
}

enum EstadoPago { alDia, porVencer, vencido }

/// Entidad `Cliente` del backend (FitGym-AppMovil/Backend).
///
/// El código de 4 dígitos no existe en la tabla `cliente`: es la contraseña
/// del `User` enlazado (username = correo), que el servidor guarda cifrada.
/// Por eso solo se conoce en el teléfono del afiliado (al iniciar sesión) o
/// en recepción al momento del registro.
class Cliente {
  Cliente({
    this.id,
    this.userId,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.telefono,
    required this.membresia,
    required this.fechaPago,
    this.codigo = '',
  });

  final int? id;

  /// Id del `User` enlazado (columna `user_id`).
  final int? userId;
  final String nombre;
  final String apellido;
  final String correo;
  final String telefono;
  final Membresia membresia;
  final DateTime fechaPago;

  /// Código de 4 dígitos asignado por el administrador ('' si no se conoce).
  final String codigo;

  /// QR estático (compatibilidad): correo + código de 4 dígitos. Expone la
  /// contraseña, por eso solo se usa mientras el backend no entregue el
  /// secreto TOTP.
  String get qrPayload => 'FITGYM|$correo|$codigo';

  /// QR dinámico: id del cliente + código TOTP de 6 dígitos, que cambia cada
  /// 30 s y no sirve para iniciar sesión.
  String qrDinamico(String codigoTotp) => 'FITGYM2|$id|$codigoTotp';

  /// Interpreta el contenido de un QR de acceso; null si no es un pase FitGym.
  static QrAcceso? parseQr(String raw) {
    final partes = raw.trim().split('|');
    if (partes.length != 3) return null;
    if (partes[0] == 'FITGYM2') {
      final id = int.tryParse(partes[1]);
      if (id == null || !RegExp(r'^\d{6}$').hasMatch(partes[2])) return null;
      return QrDinamico(id, partes[2]);
    }
    if (partes[0] == 'FITGYM' && RegExp(r'^\d{4}$').hasMatch(partes[2])) {
      return QrEstatico(partes[1], partes[2]);
    }
    return null;
  }

  String get nombreCompleto => '$nombre $apellido'.trim();

  String get iniciales {
    final a = nombre.isNotEmpty ? nombre[0] : '';
    final b = apellido.isNotEmpty ? apellido[0] : '';
    return (a + b).toUpperCase();
  }

  /// Días que faltan para la fecha de pago (negativo si ya venció).
  int get diasParaPago {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final pago = DateTime(fechaPago.year, fechaPago.month, fechaPago.day);
    return pago.difference(hoy).inDays;
  }

  EstadoPago get estadoPago {
    final d = diasParaPago;
    if (d < 0) return EstadoPago.vencido;
    if (d <= 5) return EstadoPago.porVencer;
    return EstadoPago.alDia;
  }

  Cliente copyWith({int? id, int? userId, Membresia? membresia, DateTime? fechaPago, String? codigo}) =>
      Cliente(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        nombre: nombre,
        apellido: apellido,
        correo: correo,
        telefono: telefono,
        membresia: membresia ?? this.membresia,
        fechaPago: fechaPago ?? this.fechaPago,
        codigo: codigo ?? this.codigo,
      );

  factory Cliente.fromJson(Map<String, dynamic> j) {
    final user = j['user_id'] ?? j['user'];
    final codigoRaw = j['codigo'] ?? '';
    return Cliente(
      id: _toInt(j['id']),
      userId: user is Map ? _toInt(user['id']) : _toInt(j['userId'] ?? user),
      nombre: '${j['nombre'] ?? ''}',
      apellido: '${j['apellido'] ?? ''}',
      correo: '${j['correo'] ?? ''}',
      telefono: '${j['telefono'] ?? ''}',
      membresia: Membresia.fromJson(j['membresia_id'] ?? j['membresia']),
      fechaPago: _toDate(j['fechaPago'] ?? j['fecha_pago']) ?? DateTime.now(),
      codigo: '$codigoRaw'.isEmpty ? '' : '$codigoRaw'.padLeft(4, '0'),
    );
  }

  /// Cuerpo para POST /cliente/agregar y PUT /cliente/editar/{id}. Los
  /// nombres siguen los getters de Cliente.java (`getMembresia_id`, `getUser_id`).
  Map<String, dynamic> toApiJson() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'correo': correo,
        'telefono': telefono,
        'fechaPago': _isoDate(fechaPago),
        'membresia_id': {'id': membresia.id, 'membresia': membresia.nombre},
        if (userId != null) 'user_id': {'id': userId},
      };

  /// Copia guardada en el teléfono del afiliado (incluye su código).
  Map<String, dynamic> toJson() => {
        ...toApiJson(),
        'codigo': codigo,
      };
}

/// Contenido de un QR de acceso leído por el escáner.
sealed class QrAcceso {
  const QrAcceso();
}

class QrDinamico extends QrAcceso {
  const QrDinamico(this.clienteId, this.codigo);
  final int clienteId;
  final String codigo;
}

class QrEstatico extends QrAcceso {
  const QrEstatico(this.correo, this.codigo);
  final String correo;
  final String codigo;
}

/// Resultado de validar un ingreso en la entrada.
class ResultadoAcceso {
  ResultadoAcceso({required this.permitido, required this.motivo, this.cliente});

  final bool permitido;
  final String motivo;
  final Cliente? cliente;

  /// Regla de acceso: el cliente debe existir y su fecha de pago no puede
  /// haber pasado.
  factory ResultadoAcceso.evaluar(Cliente? c) {
    if (c == null) {
      return ResultadoAcceso(permitido: false, motivo: 'El usuario no está vinculado a ningún cliente');
    }
    final dias = c.diasParaPago;
    if (dias < 0) {
      return ResultadoAcceso(
        permitido: false,
        motivo: 'Membresía vencida hace ${-dias} ${dias == -1 ? 'día' : 'días'}',
        cliente: c,
      );
    }
    final aviso = switch (dias) {
      0 => ' · su pago vence hoy',
      <= 5 => ' · su pago vence en $dias ${dias == 1 ? 'día' : 'días'}',
      _ => '',
    };
    return ResultadoAcceso(permitido: true, motivo: 'Membresía al día$aviso', cliente: c);
  }

  /// Respuesta de POST /appgym-movil/acceso (ver docs/BACKEND.md).
  factory ResultadoAcceso.fromJson(Map<String, dynamic> j) => ResultadoAcceso(
        permitido: j['permitido'] == true,
        motivo: '${j['motivo'] ?? ''}',
        cliente: j['cliente'] is Map ? Cliente.fromJson(Map<String, dynamic>.from(j['cliente'] as Map)) : null,
      );
}

/// Suma meses a una fecha sin desbordar al mes siguiente (31 ene + 1 → 28/29 feb).
DateTime sumarMeses(DateTime d, int meses) {
  final destino = DateTime(d.year, d.month + meses, 1);
  final ultimoDia = DateTime(destino.year, destino.month + 1, 0).day;
  return DateTime(destino.year, destino.month, d.day > ultimoDia ? ultimoDia : d.day);
}

int? _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  // Jackson puede serializar LocalDate como [yyyy, mm, dd].
  if (v is List && v.length >= 3) {
    return DateTime(_toInt(v[0])!, _toInt(v[1])!, _toInt(v[2])!);
  }
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return DateTime.tryParse('$v');
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

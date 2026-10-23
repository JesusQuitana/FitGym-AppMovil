import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Códigos temporales del pase (TOTP, RFC 6238): HMAC-SHA1, 6 dígitos,
/// intervalos de 30 s. Es el mismo algoritmo de Google Authenticator, así
/// que el backend puede validarlo con cualquier librería TOTP estándar.
///
/// El secreto lo genera el backend (aleatorio, una sola vez) y llega en
/// Base32; el teléfono solo calcula el código a partir del secreto y la hora.
class Totp {
  Totp._();

  static const periodo = 30;
  static const digitos = 6;

  static String codigo(String secretoBase32, DateTime ahora) =>
      codigoEnPaso(base32Decode(secretoBase32), paso(ahora));

  static int paso(DateTime t) => t.millisecondsSinceEpoch ~/ 1000 ~/ periodo;

  static int segundosRestantes(DateTime t) => periodo - (t.millisecondsSinceEpoch ~/ 1000) % periodo;

  static String codigoEnPaso(List<int> secreto, int paso) {
    final mensaje = ByteData(8)..setInt64(0, paso);
    final hash = Hmac(sha1, secreto).convert(mensaje.buffer.asUint8List()).bytes;
    final offset = hash.last & 0x0f;
    final valor = ((hash[offset] & 0x7f) << 24) |
        (hash[offset + 1] << 16) |
        (hash[offset + 2] << 8) |
        hash[offset + 3];
    return (valor % 1000000).toString().padLeft(digitos, '0');
  }

  /// Acepta el código del intervalo actual y de [ventana] intervalos antes y
  /// después, para tolerar relojes levemente desfasados. Solo se usa en modo
  /// demo: con el servidor real la verificación la hace el backend.
  static bool verificar(String secretoBase32, String codigo, DateTime ahora, {int ventana = 1}) {
    final secreto = base32Decode(secretoBase32);
    final actual = paso(ahora);
    for (var i = -ventana; i <= ventana; i++) {
      if (codigoEnPaso(secreto, actual + i) == codigo) return true;
    }
    return false;
  }

  static const _alfabeto = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static List<int> base32Decode(String texto) {
    final limpio = texto.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
    final salida = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final c in limpio.split('')) {
      final v = _alfabeto.indexOf(c);
      if (v < 0) throw FormatException('Secreto TOTP inválido: carácter "$c".');
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        salida.add((buffer >> bits) & 0xff);
      }
    }
    return salida;
  }
}

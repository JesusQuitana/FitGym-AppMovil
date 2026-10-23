import 'package:flutter/services.dart';

/// Bloquea capturas y grabación de pantalla (FLAG_SECURE de Android) mientras
/// se muestra el pase. Es un complemento: no impide fotografiar la pantalla
/// con otro teléfono, para eso está el QR dinámico.
class PantallaSegura {
  PantallaSegura._();

  static const _canal = MethodChannel('fitgym/pantalla');

  static Future<void> proteger() => _invocar('proteger');

  static Future<void> desproteger() => _invocar('desproteger');

  static Future<void> _invocar(String metodo) async {
    try {
      await _canal.invokeMethod<void>(metodo);
    } on MissingPluginException {
      // Plataforma sin implementación (tests, iOS): no hace nada.
    } on PlatformException {
      // Igual que arriba: la protección es opcional.
    }
  }
}

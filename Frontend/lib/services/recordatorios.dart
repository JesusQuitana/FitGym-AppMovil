import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/cliente.dart';

/// Notificaciones locales que avisan al afiliado antes de su fecha de pago.
/// Se programan en el propio teléfono: no requieren servidor ni Firebase.
class Recordatorios {
  Recordatorios._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;

  static const _horaAviso = 9;
  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'pagos',
      'Recordatorios de pago',
      channelDescription: 'Avisos antes de que venza tu mensualidad',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    try {
      // No se carga la base de zonas horarias: solo se usa tz.UTC (ver programar).
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _listo = true;
    } catch (e) {
      debugPrint('Recordatorios no disponibles: $e');
    }
  }

  /// Reprograma los avisos: 3 días antes y el mismo día del pago, a las 9:00.
  static Future<void> programar(Cliente c) async {
    if (!_listo) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin.cancelAll();

      final pago = DateTime(c.fechaPago.year, c.fechaPago.month, c.fechaPago.day, _horaAviso);
      final avisos = [
        (1, pago.subtract(const Duration(days: 3)), 'Tu mensualidad vence en 3 días',
            'Renueva en recepción antes del ${_fecha(pago)} para no perder tu acceso.'),
        (2, pago, 'Hoy vence tu mensualidad',
            'Pasa por recepción para renovar tu membresía ${c.membresia.nombre}.'),
      ];
      final ahora = DateTime.now();
      for (final (id, cuando, titulo, cuerpo) in avisos) {
        if (!cuando.isAfter(ahora)) continue;
        await _plugin.zonedSchedule(
          id: id,
          // La fecha local se convierte al instante equivalente en UTC, así no
          // hace falta conocer la zona horaria del teléfono.
          scheduledDate: tz.TZDateTime.from(cuando, tz.UTC),
          notificationDetails: _detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: titulo,
          body: cuerpo,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar los recordatorios: $e');
    }
  }

  static Future<void> cancelar() async {
    if (_listo) await _plugin.cancelAll();
  }

  static String _fecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

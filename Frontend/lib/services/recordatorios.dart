import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Solo los avisos de pago: los recordatorios de entrenamiento se conservan.
      await _plugin.cancel(id: 1);
      await _plugin.cancel(id: 2);

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

  /// Solo los avisos de pago (al desvincular el gimnasio); los recordatorios
  /// de entrenamiento siguen.
  static Future<void> cancelarPagos() async {
    if (!_listo) return;
    await _plugin.cancel(id: 1);
    await _plugin.cancel(id: 2);
  }

  // ------------------------------------------------ recordatorio de entrenar

  static const _kEntrenar = 'recordar_entrenar';
  static const _kHora = 'recordar_entrenar_minutos';
  static const _detallesEntreno = NotificationDetails(
    android: AndroidNotificationDetails(
      'entrenamiento',
      'Recordatorio de entrenamiento',
      channelDescription: 'Aviso los días que tienes una rutina',
    ),
  );

  /// Si está activo y a qué hora (minutos desde medianoche; 18:00 por defecto).
  static Future<(bool, int)> preferenciaEntrenar() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_kEntrenar) ?? false, prefs.getInt(_kHora) ?? 18 * 60);
  }

  static Future<void> guardarPreferenciaEntrenar(bool activo, int minutos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEntrenar, activo);
    await prefs.setInt(_kHora, minutos);
  }

  /// Programa un aviso semanal para cada día que tiene rutina
  /// ([rutinasPorDia]: 1 = lunes … 7 = domingo → nombres de las rutinas).
  static Future<void> programarEntrenamientos(Map<int, List<String>> rutinasPorDia) async {
    if (!_listo) return;
    try {
      for (var d = 1; d <= 7; d++) {
        await _plugin.cancel(id: 100 + d);
      }
      final (activo, minutos) = await preferenciaEntrenar();
      if (!activo) return;
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final ahora = DateTime.now();
      for (final MapEntry(key: dia, value: nombres) in rutinasPorDia.entries) {
        if (nombres.isEmpty) continue;
        var cuando = DateTime(ahora.year, ahora.month, ahora.day, minutos ~/ 60, minutos % 60);
        while (cuando.weekday != dia || !cuando.isAfter(ahora)) {
          cuando = cuando.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id: 100 + dia,
          // Se repite cada semana el mismo día y hora. Al usar el instante en
          // UTC, en zonas con horario de verano puede correrse una hora.
          scheduledDate: tz.TZDateTime.from(cuando, tz.UTC),
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          notificationDetails: _detallesEntreno,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Hoy toca entrenar 💪',
          body: nombres.join(' · '),
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar los recordatorios de entrenamiento: $e');
    }
  }

  static String _fecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

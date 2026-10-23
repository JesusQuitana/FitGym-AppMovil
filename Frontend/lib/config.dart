class AppConfig {
  /// 10.0.2.2 es el localhost de la PC vista desde el emulador de Android.
  /// En un teléfono físico usar la IP de la PC en la red Wi-Fi, p. ej.
  /// http://192.168.1.50:3000 (se puede cambiar desde Ajustes en la app).
  static const defaultBaseUrl = 'http://10.0.2.2:3000';

  /// Prefijo de los controladores REST (@RequestMapping("appgym-movil")).
  /// Las rutas de autenticación (/auth/...) no lo llevan.
  static const apiPrefix = '/appgym-movil';

  /// Con el modo demo activo la app usa datos locales de ejemplo y no
  /// necesita el backend encendido.
  static const defaultModoDemo = true;

  /// Credenciales del administrador en modo demo. Con el backend real se usa
  /// un `User` con rol ADMIN de la tabla `user`.
  static const demoAdminUser = 'admin';
  static const demoAdminPassword = 'admin123';

  static const timeout = Duration(seconds: 10);
}

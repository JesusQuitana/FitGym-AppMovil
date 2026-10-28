# FitGym – App móvil (Flutter)

Frontend Android del sistema FitGym: control de acceso mediante QR y gestión de membresías. Consume la API REST de `../Backend` (Spring Boot, puerto 3000).

## Funcionalidades

**Afiliado**
- Login con correo + código de 4 dígitos (es su usuario y contraseña en `/auth/login`).
- Pase digital con **QR dinámico** (TOTP): cambia cada 30 s, funciona sin internet y no contiene la contraseña. Muestra cuenta regresiva y reloj en vivo, sube el brillo al máximo y bloquea capturas de pantalla. Mientras el backend no entregue el secreto TOTP, usa el QR estático (correo + código).
- **Rutinas**: planificador con días de la semana y ejercicios armados con las máquinas del gimnasio (series, repeticiones, peso), con checklist durante el entrenamiento. Se guardan en el teléfono hasta que el backend tenga rutinas.
- **Máquinas**: catálogo por grupo muscular con su disponibilidad.
- Datos personales, membresía (VIP · Premium · Regular), fecha de pago y estado (al día / por vencer / vencida).
- Sesión guardada en el teléfono: el QR se muestra aunque no haya cobertura en recepción.
- Recordatorios de pago: notificación local 3 días antes y el mismo día del vencimiento, a las 9:00.

**Recepción** – botón "Soy administrador", con un usuario de rol `ADMIN` del backend
- **Control de acceso**: escanea el QR con la cámara y muestra ✅ permitido / ⛔ denegado según la fecha de pago. También permite validar a mano con correo + código.
- Lista de clientes con buscador, filtro por membresía y resumen de pagos. Búsqueda por ID.
- Registro de cliente: crea su usuario (correo + código generado) y el cliente enlazado.
- **Registrar pago / renovar**: extiende la fecha 1, 3, 6 o 12 meses y permite cambiar la membresía.
- **Máquinas y grupos musculares**: alta, edición y baja (CRUD del backend).

## Puesta en marcha

Requiere Flutter 3.24 o superior.

```bash
cd Frontend
flutter pub get
flutter run
```

La app arranca en **modo demo** (datos de ejemplo, sin backend):
- Afiliado: `eddy@fitgym.com` / `1234`
- Recepción: `admin` / `admin123`

### Conectar con el backend

1. Levantar `Backend/` (JDK 21 y MySQL 8 en `localhost:3306`): `./mvnw spring-boot:run`.
2. En la app: login → ⚙️ Ajustes de conexión → desactivar "Modo demo".
3. URL: `http://10.0.2.2:3000` (emulador) o `http://<IP de la PC>:3000` (teléfono en la misma Wi-Fi) → "Probar conexión".

El `AndroidManifest.xml` ya permite HTTP sin cifrar para desarrollo.

**Antes de usar recepción** hay que crear un administrador (`/auth/register` siempre crea rol USER) y cargar la tabla `membresia` con 1 VIP, 2 Premium y 3 Regular. Ver [docs/BACKEND.md](docs/BACKEND.md).

> ⚠️ "Registrar pago" no funcionará contra el backend hasta agregar `setFechaPago` en `ClienteController.updateCliente`. La app avisa del problema.

## Estructura

```
lib/
  main.dart                     arranque y sesión
  config.dart                   URL por defecto, prefijo /appgym-movil, modo demo
  theme.dart                    colores y tema
  models/cliente.dart           Cliente, Membresia, formato JSON y contenido del QR
  services/api_service.dart     API REST + JWT + datos demo
  services/session.dart         persistencia local (shared_preferences)
  services/recordatorios.dart   notificaciones de pago
  widgets/common.dart           QR, insignias, tarjetas
  screens/login_screen.dart     login del afiliado y de recepción
  screens/home_screen.dart      pase QR + mis datos
  screens/settings_screen.dart
  screens/admin/                lista, detalle/renovación, registro y escáner
docs/BACKEND.md                 rutas que usa la app y lo pendiente en el backend
```

Compilar el APK para compartir: `flutter build apk --release --split-per-abi` (usar `app-arm64-v8a-release.apk`).

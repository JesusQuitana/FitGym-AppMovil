## Rutas que usa la app

| Acción en la app | Petición | Requiere JWT |
|---|---|---|
| Login del afiliado (correo + código) | `POST /auth/login` → `{token, id}` y luego `GET /appgym-movil/clientes` para buscar el cliente con `user_id.id == id` | No |
| Login de recepción | `POST /auth/login` y luego `GET /user/get/{id}` para exigir `role == "ADMIN"` | No |
| Lista de clientes / refrescar pase | `GET /appgym-movil/clientes`, `GET /appgym-movil/cliente/buscar/{id}` | No |
| Registrar cliente | `POST /auth/register` (username = correo, password = código), `GET /user/all` para obtener el id del usuario creado y `POST /appgym-movil/cliente/agregar` | Sí (la última) |
| Registrar pago / renovar | `PUT /appgym-movil/cliente/editar/{id}` | Sí |
| Escáner, QR dinámico | `POST /appgym-movil/acceso` **(pendiente, ver abajo)** | No |
| Escáner, QR estático o validación manual | `POST /auth/login` con el correo y el código, y luego la regla de `fechaPago` en la app | No |
| Catálogo de máquinas (afiliado) | `GET /appgym-movil/maquinas`, `GET /appgym-movil/MuscleGroups` | No |
| Administrar máquinas | `POST /maquina/agregar`, `PUT /maquina/editar/{id}`, `DELETE /maquina/delete/{id}` | Sí |
| Administrar grupos musculares | `POST /MuscleGroup/agregar`, `PUT /MuscleGroup/editar/{id}`, `DELETE /MuscleGroup/delete/{id}` | Sí |
| Rutinas del afiliado | Ninguna: se guardan en el teléfono **(no existen en el backend, ver propuesta abajo)** | — |


---

## QR dinámico:

El backend genera una vez un secreto aleatorio por usuario y se lo entrega a la app al iniciar sesión. Con ese secreto y la hora, la app calcula cada 30 s un código de 6 dígitos (estándar TOTP, RFC 6238: HMAC-SHA1, 6 dígitos, 30 s) y muestra el QR `FITGYM2|<idCliente>|<código>`. El escáner envía ese contenido al backend, que hace el mismo cálculo y compara. El QR ya no contiene la contraseña y una captura caduca en segundos.

### 1. Columna nueva en `User`
```java
@JsonIgnore                 // nunca debe salir en GET /user/... ni en /clientes
String totpSecret;          // Base32, p. ej. "JBSWY3DPEHPK3PXP"
```

### 2. `POST /auth/login` debe devolver el secreto
```json
{ "token": "eyJ...", "id": 3, "totpSecret": "JBSWY3DPEHPK3PXP" }
```
- Agregar `String totpSecret` a `AuthResponse`.
- En `AuthService.login`, si el usuario no tiene secreto, generarlo y guardarlo:
```java
if (user.getTotpSecret() == null) {
    user.setTotpSecret(new DefaultSecretGenerator().generate());   // 32 caracteres Base32 (SecureRandom)
    usuarioRepository.save(user);
}
return AuthResponse.builder().token(token).id(user.getId()).totpSecret(user.getTotpSecret()).build();
```
- La app también lee la cabecera HTTP `Date` de esta respuesta para corregir teléfonos con la hora desfasada. Spring la envía por defecto.

### 3. Endpoint de validación (público: lo llama el escáner)
**Petición**
```json
{ "clienteId": 3, "codigo": "482913" }
```
**Respuesta** (siempre `200`)
```json
{ "permitido": true, "motivo": "Membresía al día", "cliente": { ...Cliente... } }
```
| Caso | `permitido` | `motivo` |
|---|---|---|
| Cliente inexistente o sin secreto | `false` | `"Pase no reconocido"` |
| Código que no coincide (captura vieja) | `false` | `"Código vencido o inválido"` |
| Código ya usado (anti-reuso) | `false` | `"Este pase ya fue usado"` |
| `fechaPago` anterior a hoy | `false` | `"Membresía vencida desde 2026-10-01"` |
| Todo correcto | `true` | `"Membresía al día"` |

Con la librería `dev.samstevens.totp:totp:1.7.1` en el `pom.xml`:
```java
// model/AccesoSolicitud.java
public record AccesoSolicitud(Integer clienteId, String codigo) {}
// model/AccesoRespuesta.java
public record AccesoRespuesta(boolean permitido, String motivo, Cliente cliente) {}

// controller/ClienteController.java
private final CodeVerifier verificador = crearVerificador();
private final Set<String> codigosUsados = ConcurrentHashMap.newKeySet();

private static CodeVerifier crearVerificador() {
    DefaultCodeVerifier v = new DefaultCodeVerifier(new DefaultCodeGenerator(), new SystemTimeProvider());
    v.setTimePeriod(30);
    v.setAllowedTimePeriodDiscrepancy(1);   // tolera ±30 s de desfase de reloj
    return v;
}

@PostMapping("/acceso")
public AccesoRespuesta acceso(@RequestBody AccesoSolicitud s) {
    Cliente c = clienteServicio.buscarClienteId(s.clienteId());
    if (c == null || c.getUser_id() == null || c.getUser_id().getTotpSecret() == null)
        return new AccesoRespuesta(false, "Pase no reconocido", null);
    if (!verificador.isValidCode(c.getUser_id().getTotpSecret(), s.codigo()))
        return new AccesoRespuesta(false, "Código vencido o inválido", c);
    if (!codigosUsados.add(c.getId() + ":" + s.codigo()))   // anti-reuso dentro del mismo intervalo
        return new AccesoRespuesta(false, "Este pase ya fue usado", c);
    if (c.getFechaPago().isBefore(LocalDate.now()))
        return new AccesoRespuesta(false, "Membresía vencida desde " + c.getFechaPago(), c);
    return new AccesoRespuesta(true, "Membresía al día", c);
}
```

## Rutinas

Hay que crear las tablas:

```
rutina            (id, nombre, dias VARCHAR "1,4,6", cliente_id → cliente.id)
rutina_ejercicio  (id, rutina_id → rutina.id, maquina_id → maquinas.id, orden, series, repeticiones, peso_kg)
```
Con los endpoints `GET /appgym-movil/rutinas/cliente/{clienteId}`, `POST /rutina/agregar`, `PUT /rutina/editar/{id}` y `DELETE /rutina/delete/{id}`. El JSON que ya maneja la app es:
```json
{ "id": "…", "nombre": "Pecho y tríceps", "dias": [1, 4],
  "ejercicios": [ { "maquinaId": 1, "maquina": "Press de banca", "musculo": "Pecho",
                    "series": 4, "repeticiones": 10, "pesoKg": 40 } ] }
```

## Máquinas y grupos musculares

- `disponibilidad` se interpreta como **unidades en servicio** (0 = "Fuera de servicio").
- Borrar un grupo muscular que tiene máquinas falla por la llave foránea `maquinas.musculo_id`. El backend responde 502, y la app muestra "hay máquinas asociadas".

### Formato de `Cliente` (según los getters de `Cliente.java`)
```json
{
  "id": 1, "nombre": "Ana", "apellido": "Pérez", "correo": "ana@fitgym.com", "telefono": "0414",
  "fechaPago": "2026-11-30",
  "membresia_id": { "id": 3, "membresia": "Regular" },
  "user_id": { "id": 3, "username": "ana@fitgym.com", "role": "USER" }
}
```
La app identifica la membresía **por su nombre** (`VIP`, `Premium`, `Regular`), y al enviar usa los id **1 = VIP, 2 = Premium, 3 = Regular**. La tabla `membresia` debe tener esos tres registros con esos id.

### Primer administrador
`/auth/register` siempre crea usuarios con rol `USER`. Para tener un administrador:
```sql
-- después de POST /auth/register {"username":"admin","password":"..."}
UPDATE user SET role = 'ADMIN' WHERE username = 'admin';
```

---

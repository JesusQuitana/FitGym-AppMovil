import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/ejercicio_wger.dart';
import '../services/wger.dart';
import '../theme.dart';
import 'fitness.dart';

/// Videos en wger que superan los 100 MB cuando el mismo ejercicio ya tiene
/// otra toma mucho más liviana. Se dejan al final como último recurso.
const _videosPesadosConAlternativa = <String>{
  '32601896-b84a-49bf-ae8a-b27a8f57ab21.MOV', // 333 MB (Prensa tiene otro de 55 MB)
  'db382bd9-f633-47cd-8b02-c52db835e41d.MOV', // 115 MB
  'e96295da-58b8-4b6f-921e-4cb1af3c6cfc.MOV', // 372 MB (Peso muerto rumano tiene otro de 36 MB)
  '7d6862eb-8848-4f5d-a288-764b0d113108.MOV', // 150 MB (Hip thrust tiene otro de 83 MB)
};

/// Indica si una URL corresponde a una animación GIF (como las de ExerciseDB).
@visibleForTesting
bool esAnimacionGif(String url) => url.toLowerCase().split('?').first.endsWith('.gif');

/// Ordena las URLs de video/animación de un ejercicio priorizando:
/// 1. GIFs animados de ExerciseDB (`.gif`, ~120 KB, compatibles con cualquier teléfono).
/// 2. Contenedores MP4 (H.264/AVC fast-start).
/// 3. Contenedores MOV normales.
/// 4. Tomas MOV duplicadas de más de 100 MB al final.
@visibleForTesting
List<String> ordenarVideosWger(List<String> videos) {
  int prioridad(String url) {
    final u = url.toLowerCase().split('?').first;
    final archivo = url.split('/').last;
    if (u.endsWith('.gif')) return -1;
    if (u.endsWith('.mp4')) return 0;
    if (_videosPesadosConAlternativa.contains(archivo)) return 2;
    return 1;
  }

  final copia = List<String>.from(videos);
  copia.sort((a, b) => prioridad(a).compareTo(prioridad(b)));
  return copia;
}

/// Reemplaza en el sitio las etiquetas de caja Dolby Vision (`dvvC`, `dvcC`,
/// `dvwC`) por cajas de relleno estándar (`free`) sin alterar ningún tamaño ni
/// desplazamiento de bytes del contenedor MP4/MOV.
///
/// Motivo: 30 ejercicios de wger fueron grabados en iPhone con Dolby Vision
/// Profile 8.4 (`hvc1` + `dvvC`). Al ver `dvvC`, `BoxParser` de ExoPlayer
/// cambia el MIME de `video/hevc` a `video/dolby-vision` e inyecta
/// `KEY_PROFILE = 256` sobre el decodificador `video/hevc` en teléfonos sin
/// soporte Dolby Vision (como Samsung Galaxy), provocando que `MediaCodec`
/// falle al inicializar.
@visibleForTesting
bool parchearDolbyVisionInPlace(Uint8List buf) {
  var modificado = false;
  final limite = buf.length - 8;
  for (var i = 0; i <= limite; i++) {
    // Caja ISO BMFF: [0x00, 0x00, 0x00, size (16..64), 'd', 'v', ('v'|'c'|'w'), 'C']
    if (buf[i] == 0x00 &&
        buf[i + 1] == 0x00 &&
        buf[i + 2] == 0x00 &&
        buf[i + 3] >= 0x10 &&
        buf[i + 3] <= 0x40 &&
        buf[i + 4] == 0x64 && // 'd'
        buf[i + 5] == 0x76 && // 'v'
        (buf[i + 6] == 0x76 || buf[i + 6] == 0x63 || buf[i + 6] == 0x77) &&
        buf[i + 7] == 0x43) { // 'C'
      buf[i + 4] = 0x66; // 'f'
      buf[i + 5] = 0x72; // 'r'
      buf[i + 6] = 0x65; // 'e'
      buf[i + 7] = 0x65; // 'e'
      modificado = true;
      i += 7;
    }
  }
  return modificado;
}

/// Transforma un flujo de bytes MP4/MOV aplicando [parchearDolbyVisionInPlace]
/// con una ventana deslizante de 7 bytes para cubrir secuencias partidas entre
/// dos paquetes de red, conservando exactamente la longitud total del flujo.
@visibleForTesting
Stream<Uint8List> transformarStreamMp4(Stream<List<int>> source) async* {
  var pendiente = Uint8List(0);
  await for (final chunk in source) {
    if (chunk.isEmpty) continue;
    final combinado = Uint8List(pendiente.length + chunk.length);
    combinado.setRange(0, pendiente.length, pendiente);
    combinado.setRange(pendiente.length, combinado.length, chunk);

    parchearDolbyVisionInPlace(combinado);

    if (combinado.length > 7) {
      final emitirLen = combinado.length - 7;
      yield Uint8List.sublistView(combinado, 0, emitirLen);
      pendiente = Uint8List.fromList(Uint8List.sublistView(combinado, emitirLen));
    } else {
      pendiente = combinado;
    }
  }
  if (pendiente.isNotEmpty) {
    parchearDolbyVisionInPlace(pendiente);
    yield pendiente;
  }
}

/// Proxy HTTP local (`127.0.0.1`) que reenvía peticiones `Range` de ExoPlayer
/// hacia wger.de neutralizando al vuelo el átomo `dvvC` de los videos `.MOV`.
class _WgerVideoProxy {
  _WgerVideoProxy._();

  static HttpServer? _server;
  static HttpClient? _client;
  static Future<HttpServer>? _iniciando;

  static Future<Uri> urlPara(String remoteUrl) async {
    if (kIsWeb || !remoteUrl.toLowerCase().endsWith('.mov')) {
      return Uri.parse(remoteUrl);
    }
    try {
      final srv = await _asegurarServidor();
      return Uri.parse(
        'http://127.0.0.1:${srv.port}/video.mp4?u=${Uri.encodeQueryComponent(remoteUrl)}',
      );
    } catch (_) {
      return Uri.parse(remoteUrl);
    }
  }

  static Future<HttpServer> _asegurarServidor() {
    if (_server != null) return Future.value(_server!);
    return _iniciando ??= _arrancar();
  }

  static Future<HttpServer> _arrancar() async {
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 20);
    _client = client;
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = srv;
    srv.listen(_manejarPeticion, cancelOnError: false);
    return srv;
  }

  static Future<void> _manejarPeticion(HttpRequest req) async {
    final target = req.uri.queryParameters['u'];
    if (target == null || target.isEmpty) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }

    HttpClientResponse? upstream;
    try {
      final targetUri = Uri.parse(target);
      final clientReq = await _client!.openUrl(req.method, targetUri);
      clientReq.followRedirects = true;
      clientReq.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        clientReq.headers.set(HttpHeaders.rangeHeader, range);
      }
      final ifRange = req.headers.value(HttpHeaders.ifRangeHeader);
      if (ifRange != null) {
        clientReq.headers.set(HttpHeaders.ifRangeHeader, ifRange);
      }

      upstream = await clientReq.close();
      final res = req.response;
      res.statusCode = upstream.statusCode;
      res.bufferOutput = false;
      res.headers.set(HttpHeaders.contentTypeHeader, 'video/mp4');

      const copiarHeaders = [
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.etagHeader,
        HttpHeaders.lastModifiedHeader,
      ];
      for (final h in copiarHeaders) {
        final v = upstream.headers.value(h);
        if (v != null) res.headers.set(h, v);
      }
      if (upstream.headers.value(HttpHeaders.acceptRangesHeader) == null) {
        res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      }

      if (req.method.toUpperCase() == 'HEAD') {
        await res.close();
        return;
      }

      await res.addStream(transformarStreamMp4(upstream));
      await res.close();
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }
}

/// Intenta inicializar un [VideoPlayerController] probando las URLs del
/// ejercicio en orden de compatibilidad (`.mp4` primero, `.mov` vía proxy
/// anti-Dolby-Vision después) y alternando entre `textureView` y `platformView`
/// (`SurfaceView` nativo para decodificadores HEVC 10-bit HDR).
Future<VideoPlayerController> _iniciarVideoCompatible(
  List<String> videos, {
  required bool Function() sigueMontado,
}) async {
  final candidatos = ordenarVideosWger(videos);
  Object? ultimoError;

  final vistas = <VideoViewType>[
    VideoViewType.textureView,
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) VideoViewType.platformView,
  ];

  for (final url in candidatos) {
    final uri = await _WgerVideoProxy.urlPara(url);
    for (final viewType in vistas) {
      if (!sigueMontado()) throw StateError('Widget desmontado');
      final vc = VideoPlayerController.networkUrl(uri, viewType: viewType);
      try {
        await vc.initialize().timeout(const Duration(seconds: 25));
        if (vc.value.hasError) {
          throw Exception(vc.value.errorDescription ?? 'Error de decodificación');
        }
        await vc.setLooping(true);
        await vc.play();
        return vc;
      } catch (e) {
        ultimoError = e;
        try {
          await vc.dispose();
        } catch (_) {}
      }
    }
  }

  throw ultimoError ?? Exception('No se pudo inicializar ningún video');
}

/// Visor interactivo para la pantalla de entrenamiento:
/// - Si el ejercicio tiene múltiples imágenes en wger, las rota en secuencia
///   continua con transición suave de desvanecimiento (fade) a intervalo corto,
///   mostrando la animación completa de la ejecución del ejercicio.
/// - Si el ejercicio tiene video, ofrece un botón de acceso directo ("VER VIDEO")
///   para reproducirlo en bucle directamente en la vista.
class VisorEjercicioAnimado extends StatefulWidget {
  const VisorEjercicioAnimado({
    super.key,
    required this.musculo,
    required this.nombre,
    this.wgerId,
    this.ejercicioWger,
    this.imagenInicial,
    this.height = 180,
  });

  final String musculo;
  final String nombre;
  final int? wgerId;
  final EjercicioWger? ejercicioWger;
  final String? imagenInicial;
  final double height;

  @override
  State<VisorEjercicioAnimado> createState() => _VisorEjercicioAnimadoState();
}

class _VisorEjercicioAnimadoState extends State<VisorEjercicioAnimado> {
  List<String> _imagenes = [];
  List<String> _videos = [];
  int _indice = 0;
  Timer? _timerAnimacion;
  bool _mostrandoVideo = false;
  VideoPlayerController? _videoController;
  bool _videoIniciado = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void didUpdateWidget(covariant VisorEjercicioAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wgerId != widget.wgerId ||
        oldWidget.nombre != widget.nombre ||
        oldWidget.ejercicioWger != widget.ejercicioWger) {
      _limpiarVideo();
      _limpiarTimer();
      _indice = 0;
      _mostrandoVideo = false;
      _inicializar();
    }
  }

  @override
  void dispose() {
    _limpiarTimer();
    _limpiarVideo();
    super.dispose();
  }

  void _limpiarTimer() {
    _timerAnimacion?.cancel();
    _timerAnimacion = null;
  }

  void _limpiarVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoIniciado = false;
    _videoError = false;
  }

  Future<void> _inicializar() async {
    EjercicioWger? w = widget.ejercicioWger;
    if (w == null) {
      if (widget.wgerId != null) {
        w = await Wger.porId(widget.wgerId!);
      } else {
        w = await Wger.porNombre(widget.nombre);
      }
    }
    if (!mounted) return;

    final imgs = <String>[];
    if (w != null && w.imagenes.isNotEmpty) {
      imgs.addAll(w.imagenes);
    } else if (widget.imagenInicial != null) {
      imgs.add(widget.imagenInicial!);
    }

    setState(() {
      _imagenes = imgs;
      _videos = w?.videos ?? const [];
      _indice = 0;
    });

    _arrancarTimer();
  }

  void _arrancarTimer() {
    _limpiarTimer();
    if (_imagenes.length > 1 && !_mostrandoVideo) {
      _timerAnimacion = Timer.periodic(const Duration(milliseconds: 1100), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          _indice = (_indice + 1) % _imagenes.length;
        });
      });
    }
  }

  String? get _gifUrl => ordenarVideosWger(_videos).where(esAnimacionGif).firstOrNull;

  Future<void> _toggleVideo() async {
    if (_videos.isEmpty) return;
    final nuevoEstado = !_mostrandoVideo;
    if (nuevoEstado) {
      _limpiarTimer();
      setState(() {
        _mostrandoVideo = true;
        _videoError = false;
      });
      // Si el ejercicio cuenta con animación GIF (ExerciseDB), se reproduce
      // directamente como imagen animada en bucle sin inicializar ExoPlayer.
      if (_gifUrl != null) return;
      if (_videoController == null) {
        try {
          final vc = await _iniciarVideoCompatible(
            _videos,
            sigueMontado: () => mounted && _mostrandoVideo,
          );
          if (!mounted || !_mostrandoVideo) {
            await vc.dispose();
            return;
          }
          vc.addListener(() {
            if (mounted && vc.value.hasError && !_videoError) {
              setState(() {
                _videoError = true;
              });
            }
          });
          setState(() {
            _videoController = vc;
            _videoIniciado = true;
          });
        } catch (_) {
          if (mounted) {
            setState(() {
              _videoError = true;
            });
          }
        }
      } else {
        _videoController?.play();
      }
    } else {
      _videoController?.pause();
      setState(() {
        _mostrandoVideo = false;
      });
      _arrancarTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneVideo = _videos.isNotEmpty;
    final tieneMultiplesImagenes = _imagenes.length > 1;
    final gifUrl = _gifUrl;

    Widget contenido;

    if (_mostrandoVideo) {
      if (gifUrl != null && !_videoError) {
        contenido = Container(
          color: Colors.white,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: CachedNetworkImage(
            imageUrl: gifUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (_, __, ___) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: FitColors.textMuted, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'Sin conexión para cargar la animación.',
                    style: TextStyle(color: FitColors.textMuted, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (_videoError) {
        contenido = Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 28),
              const SizedBox(height: 6),
              const Text(
                'No se pudo reproducir el video en este dispositivo.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _limpiarVideo();
                  _toggleVideo();
                },
                child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else if (_videoController == null || !_videoIniciado) {
        contenido = Container(
          color: Colors.black87,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white70),
        );
      } else {
        final vc = _videoController!;
        contenido = Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {
              if (vc.value.isPlaying) {
                vc.pause();
              } else {
                vc.play();
              }
              setState(() {});
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: vc.value.aspectRatio,
                    child: VideoPlayer(vc),
                  ),
                ),
                if (!vc.value.isPlaying)
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
              ],
            ),
          ),
        );
      }
    } else {
      // Modo Imágenes
      if (_imagenes.isEmpty) {
        final color = colorMusculo(widget.musculo);
        contenido = Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Container(
            width: widget.height * 0.8,
            height: widget.height * 0.8,
            decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(2)),
            child: Icon(iconoMusculo(widget.musculo), color: color, size: widget.height * 0.4),
          ),
        );
      } else if (_imagenes.length == 1) {
        contenido = Container(
          color: Colors.white,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: CachedNetworkImage(
            imageUrl: _imagenes.first,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => Center(
              child: Icon(iconoMusculo(widget.musculo), color: colorMusculo(widget.musculo), size: 48),
            ),
          ),
        );
      } else {
        // Múltiples imágenes con AnimatedSwitcher para la animación con transición FADE
        contenido = Container(
          color: Colors.white,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: CachedNetworkImage(
              key: ValueKey('${_imagenes[_indice]}-$_indice'),
              imageUrl: _imagenes[_indice],
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => Center(
                child: Icon(iconoMusculo(widget.musculo), color: colorMusculo(widget.musculo), size: 48),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      height: widget.height,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: (_mostrandoVideo && gifUrl == null) ? Colors.black : Colors.white,
        border: Border.all(color: FitColors.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: contenido),

          // Indicador de fase / fotograma si hay múltiples imágenes y estamos en modo fotos
          if (tieneMultiplesImagenes && !_mostrandoVideo)
            Positioned(
              bottom: 8,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.motion_photos_on_outlined, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      '${_indice + 1}/${_imagenes.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Botón para alternar video / fotos si el ejercicio tiene video
          if (tieneVideo)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: _mostrandoVideo ? FitColors.primary : Colors.black.withAlpha(190),
                borderRadius: BorderRadius.circular(2),
                child: InkWell(
                  onTap: _toggleVideo,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _mostrandoVideo ? Icons.photo_library_outlined : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _mostrandoVideo ? 'VER FOTOS' : 'VER VIDEO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Imagen pequeña de un ejercicio (guardada en el teléfono tras la primera
/// descarga). Sin imagen, muestra el ícono del grupo muscular.
class MiniaturaEjercicio extends StatelessWidget {
  const MiniaturaEjercicio({super.key, required this.musculo, this.imagen, this.size = 46});
  final String musculo;
  final String? imagen;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = colorMusculo(musculo);
    final icono = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(2)),
      child: Icon(iconoMusculo(musculo), color: color),
    );
    final url = imagen;
    if (url == null) return icono;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: size,
        height: size,
        color: Colors.white, // las imágenes de wger tienen fondo claro
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => icono,
        ),
      ),
    );
  }
}

/// Hoja con imágenes, video e instrucciones de un ejercicio de wger. Busca
/// por [wgerId]; si no lo hay (rutinas antiguas), por nombre.
Future<void> mostrarComoSeHace(
  BuildContext context, {
  required String nombre,
  int? wgerId,
  String musculo = '',
  String detalle = '',
}) {
  final ejercicio = wgerId != null ? Wger.porId(wgerId) : Wger.porNombre(nombre);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FitColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => FutureBuilder<EjercicioWger?>(
        future: ejercicio,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final e = snap.data;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(e?.nombre ?? nombre, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if ((e?.musculo ?? musculo).isNotEmpty) MusculoChip(e?.musculo ?? musculo),
                  Text(detalle.isNotEmpty ? detalle : (e?.equipoTexto ?? ''),
                      style: TextStyle(color: FitColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              if (e == null)
                Text('Este ejercicio no está en el catálogo de wger.', style: TextStyle(color: FitColors.textMuted))
              else ...[
                if (e.imagenes.isNotEmpty) _Carrusel(imagenes: e.imagenes),
                if (e.videos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _VideoEjercicio(videos: e.videos),
                ],
                const SizedBox(height: 18),
                Text('CÓMO SE HACE',
                    style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(e.descripcion, style: const TextStyle(height: 1.5)),
                if (e.evitarCon.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FitColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: FitColors.warning.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.healing_outlined, color: FitColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Puede cargar: ${e.evitarCon.map((l) => l.etiqueta.toLowerCase()).join(', ')}. '
                            'Si tienes molestias ahí, consúltalo antes.',
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '${Wger.credito}${e.autorImagen.isNotEmpty ? ' · Imagen: ${e.autorImagen}' : ''}',
                  style: TextStyle(color: FitColors.textMuted, fontSize: 11),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

class _Carrusel extends StatefulWidget {
  const _Carrusel({required this.imagenes});
  final List<String> imagenes;

  @override
  State<_Carrusel> createState() => _CarruselState();
}

class _CarruselState extends State<_Carrusel> {
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 240,
            color: Colors.white,
            child: PageView(
              onPageChanged: (i) => setState(() => _pagina = i),
              children: [
                for (final url in widget.imagenes)
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => const Center(
                      child: Text('Sin conexión para cargar la imagen', style: TextStyle(color: Colors.black54)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.imagenes.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.imagenes.length; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _pagina ? FitColors.primary : FitColors.surfaceHigh,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Video o animación de un ejercicio: se descarga y reproduce al tocar "Ver video".
class _VideoEjercicio extends StatefulWidget {
  const _VideoEjercicio({required this.videos});
  final List<String> videos;

  @override
  State<_VideoEjercicio> createState() => _VideoEjercicioState();
}

class _VideoEjercicioState extends State<_VideoEjercicio> {
  VideoPlayerController? _video;
  bool _mostrandoGif = false;
  bool _cargando = false;
  bool _error = false;

  String? get _gifUrl => ordenarVideosWger(widget.videos).where(esAnimacionGif).firstOrNull;

  Future<void> _iniciar() async {
    if (_gifUrl != null) {
      setState(() {
        _mostrandoGif = true;
        _error = false;
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final v = await _iniciarVideoCompatible(
        widget.videos,
        sigueMontado: () => mounted,
      );
      if (!mounted) {
        await v.dispose();
        return;
      }
      v.addListener(() {
        if (mounted && v.value.hasError && !_error) {
          setState(() => _error = true);
        }
      });
      setState(() {
        _video = v;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gifUrl = _gifUrl;
    if (_mostrandoGif && gifUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 240,
          color: Colors.white,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: CachedNetworkImage(
            imageUrl: gifUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sin conexión para cargar la animación.',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final v = _video;
    if (_error) {
      return Row(
        children: [
          Expanded(
            child: Text(
              'No se pudo reproducir el video en este dispositivo.',
              style: TextStyle(color: FitColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              _video?.dispose();
              _video = null;
              _iniciar();
            },
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (_cargando) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (v == null) {
      return OutlinedButton.icon(onPressed: _iniciar, icon: const Icon(Icons.play_circle_outline), label: const Text('Ver video'));
    }
    if (!v.value.isInitialized) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    return GestureDetector(
      onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/ejercicio_wger.dart';
import '../services/wger.dart';
import '../theme.dart';
import 'fitness.dart';

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
      decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(14)),
      child: Icon(iconoMusculo(musculo), color: color),
    );
    final url = imagen;
    if (url == null) return icono;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
                      style: const TextStyle(color: FitColors.textMuted, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              if (e == null)
                const Text('Este ejercicio no está en el catálogo de wger.', style: TextStyle(color: FitColors.textMuted))
              else ...[
                if (e.imagenes.isNotEmpty) _Carrusel(imagenes: e.imagenes),
                if (e.videos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _VideoEjercicio(url: e.videos.first),
                ],
                const SizedBox(height: 18),
                const Text('CÓMO SE HACE',
                    style: TextStyle(color: FitColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(e.descripcion, style: const TextStyle(height: 1.5)),
                if (e.evitarCon.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FitColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FitColors.warning.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.healing_outlined, color: FitColors.warning, size: 20),
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
                  style: const TextStyle(color: FitColors.textMuted, fontSize: 11),
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
          borderRadius: BorderRadius.circular(18),
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

/// Video de wger: se descarga y reproduce solo al tocar "Ver video".
class _VideoEjercicio extends StatefulWidget {
  const _VideoEjercicio({required this.url});
  final String url;

  @override
  State<_VideoEjercicio> createState() => _VideoEjercicioState();
}

class _VideoEjercicioState extends State<_VideoEjercicio> {
  VideoPlayerController? _video;
  bool _error = false;

  Future<void> _iniciar() async {
    final v = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    setState(() => _video = v);
    try {
      await v.initialize();
      await v.setLooping(true);
      await v.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    if (_error) {
      return const Text('No se pudo cargar el video (¿sin conexión?).', style: TextStyle(color: FitColors.textMuted));
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
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(aspectRatio: v.value.aspectRatio, child: VideoPlayer(v)),
      ),
    );
  }
}

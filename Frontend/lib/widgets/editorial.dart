import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Piezas de la dirección "deportiva editorial": movimiento seco y corto
/// (barrido, golpe, barra que se llena) y la diagonal roja de los bloques.
/// Si el sistema pide reducir el movimiento, todo aparece sin animar.

bool sinMovimiento(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Base de las entradas: arranca una sola vez tras [retraso].
abstract class _Entrada extends StatefulWidget {
  const _Entrada({super.key, required this.child, this.retraso = Duration.zero});
  final Widget child;
  final Duration retraso;
  Duration get duracion;
  Curve get curva;
  Widget construir(double t, Widget child);

  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duracion);
  bool _iniciado = false;
  Timer? _espera;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    if (sinMovimiento(context)) {
      _c.value = 1;
    } else {
      _espera = Timer(widget.retraso, _c.forward);
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => widget.construir(widget.curva.transform(_c.value), child!),
      );
}

/// Aparece barriendo de izquierda a derecha, sin mover lo que tiene al lado.
/// Se oculta solo al pintar (no con un recorte), así un toque durante la
/// entrada no se pierde.
class Barrido extends _Entrada {
  const Barrido({super.key, required super.child, super.retraso});
  @override
  Duration get duracion => const Duration(milliseconds: 450);
  @override
  Curve get curva => const Cubic(0.7, 0, 0.2, 1);
  @override
  Widget construir(double t, Widget child) {
    if (t >= 1) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        stops: [t, t],
      ).createShader(rect),
      child: child,
    );
  }
}

/// Entra un poco más grande y "golpea" al asentarse: para las cifras grandes.
class Golpe extends _Entrada {
  const Golpe({super.key, required super.child, super.retraso});
  @override
  Duration get duracion => const Duration(milliseconds: 350);
  @override
  Curve get curva => const Cubic(0.2, 0.9, 0.3, 1.2);
  @override
  Widget construir(double t, Widget child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 1.25 - 0.25 * t, alignment: Alignment.centerLeft, child: child),
      );
}

/// Barra recta que se llena hasta [valor] (0 a 1) al aparecer.
class BarraLlenado extends StatelessWidget {
  const BarraLlenado({super.key, required this.valor, this.color, this.fondo, this.alto = 8});
  final double valor;
  final Color? color;
  final Color? fondo;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final destino = valor.clamp(0.0, 1.0);
    return Container(
      height: alto,
      color: fondo ?? FitColors.line,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: sinMovimiento(context) ? destino : 0, end: destino),
        duration: const Duration(milliseconds: 700),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: ColoredBox(color: color ?? FitColors.ink),
        ),
      ),
    );
  }
}

/// Franja diagonal roja para el fondo de un bloque (colocar en un Stack).
class DiagonalRoja extends StatelessWidget {
  const DiagonalRoja({super.key, this.ancho = 170, this.color, this.opacidad = 1});
  final double ancho;
  final Color? color;
  final double opacidad;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacidad,
        child: ClipPath(
          clipper: _Diagonal(),
          child: SizedBox(width: ancho, child: ColoredBox(color: color ?? FitColors.accent)),
        ),
      );
}

class _Diagonal extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * 0.4, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width * 0.6, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  bool shouldReclip(_Diagonal old) => false;
}

/// Etiqueta en mayúsculas con espaciado amplio ("HOY TOCA", "SERIE").
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.color, this.size = 11});
  final String texto;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(texto.toUpperCase(), style: estiloEtiqueta(color: color ?? FitColors.textMuted, size: size));
}

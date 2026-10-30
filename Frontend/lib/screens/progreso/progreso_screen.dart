import 'package:flutter/material.dart';

import '../../models/sesion.dart';
import '../../services/historial.dart';
import '../../theme.dart';
import '../../widgets/fitness.dart';

/// Progreso a partir del historial: racha, entrenamientos por semana y la
/// evolución del peso por ejercicio, más la lista de entrenamientos.
class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key, required this.espacio});
  final String espacio;

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  List<SesionEntrenamiento>? _sesiones;
  String? _ejercicio;

  @override
  void initState() {
    super.initState();
    Historial.cargar(widget.espacio).then((s) {
      if (!mounted) return;
      final conPeso = Historial.ejerciciosConPeso(s);
      setState(() {
        _sesiones = s;
        _ejercicio = conPeso.isEmpty ? null : conPeso.first;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final sesiones = _sesiones;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi progreso')),
      body: sesiones == null
          ? const Center(child: CircularProgressIndicator())
          : sesiones.isEmpty
              ? const VacioMensaje(
                  icon: Icons.insights,
                  texto: 'Todavía no registras entrenamientos.\n'
                      'Abre una rutina, marca tus series y toca "Terminar entrenamiento".',
                )
              : _contenido(sesiones),
    );
  }

  Widget _contenido(List<SesionEntrenamiento> sesiones) {
    final ahora = DateTime.now();
    final delMes = sesiones.where((s) => s.fecha.year == ahora.year && s.fecha.month == ahora.month).toList();
    final racha = Historial.rachaSemanas(sesiones);
    final ejercicios = Historial.ejerciciosConPeso(sesiones);
    final recientes = sesiones.reversed.take(15).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            _Indicador(valor: '$racha', etiqueta: racha == 1 ? 'semana seguida' : 'semanas seguidas', icono: Icons.local_fire_department),
            const SizedBox(width: 8),
            _Indicador(valor: '${delMes.length}', etiqueta: 'este mes', icono: Icons.calendar_month_outlined),
            const SizedBox(width: 8),
            _Indicador(valor: '${sesiones.length}', etiqueta: 'en total', icono: Icons.fitness_center),
          ],
        ),
        const SizedBox(height: 20),
        const _Titulo('Entrenamientos por semana'),
        _Tarjeta(child: BarrasSemanales(datos: Historial.porSemana(sesiones))),
        const SizedBox(height: 20),
        const _Titulo('Peso por ejercicio'),
        _Tarjeta(
          child: ejercicios.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Anota el peso que usas en tus series: con dos entrenamientos de un mismo ejercicio verás su evolución aquí.',
                    style: TextStyle(color: FitColors.textMuted, height: 1.4),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButton<String>(
                      value: _ejercicio,
                      isExpanded: true,
                      dropdownColor: FitColors.surfaceHigh,
                      underline: const SizedBox.shrink(),
                      items: [for (final e in ejercicios) DropdownMenuItem(value: e, child: Text(e))],
                      onChanged: (v) => setState(() => _ejercicio = v),
                    ),
                    const SizedBox(height: 8),
                    LineaPeso(key: ValueKey(_ejercicio), datos: Historial.evolucionPeso(sesiones, _ejercicio!)),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        const _Titulo('Últimos entrenamientos'),
        for (final s in recientes) _FilaSesion(sesion: s),
      ],
    );
  }
}

String _fecha(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _kg(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}

class _Indicador extends StatelessWidget {
  const _Indicador({required this.valor, required this.etiqueta, required this.icono});
  final String valor;
  final String etiqueta;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Icon(icono, color: FitColors.primary, size: 20),
              const SizedBox(height: 6),
              Text(valor, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              Text(etiqueta,
                  textAlign: TextAlign.center, style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );
}

/// Barras de entrenamientos por semana. Una sola serie (sin leyenda: el
/// título la nombra), barras finas con extremo redondeado de 4 px apoyadas en
/// la base y 2 px de separación, cuadrícula apagada. Tocar una barra muestra
/// su valor; por defecto se rotula la semana actual.
class BarrasSemanales extends StatefulWidget {
  const BarrasSemanales({super.key, required this.datos});
  final List<(DateTime, int)> datos;

  @override
  State<BarrasSemanales> createState() => _BarrasSemanalesState();
}

class _BarrasSemanalesState extends State<BarrasSemanales> {
  late int _sel = widget.datos.length - 1;

  @override
  Widget build(BuildContext context) {
    final datos = widget.datos;
    final maximo = datos.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
    final tope = maximo <= 4 ? 4 : ((maximo + 1) ~/ 2) * 2;
    final (semana, cantidad) = datos[_sel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$cantidad ${cantidad == 1 ? 'entrenamiento' : 'entrenamientos'} · semana del ${_fecha(semana)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Eje Y apagado: 0, mitad y tope.
              SizedBox(
                width: 22,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final v in [tope, tope ~/ 2, 0])
                      Text('$v', style: const TextStyle(color: FitColors.textMuted, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [for (var i = 0; i < 3; i++) Container(height: 1, color: Colors.white.withAlpha(18))],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < datos.length; i++)
                          Expanded(
                            child: Semantics(
                              label: 'Semana del ${_fecha(datos[i].$1)}: ${datos[i].$2} entrenamientos',
                              button: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _sel = i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1), // 2 px entre barras
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: datos[i].$2 / tope,
                                      widthFactor: 0.62,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: i == _sel ? FitColors.chart : FitColors.chart.withAlpha(140),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 28),
            for (var i = 0; i < datos.length; i++)
              Expanded(
                child: Text(
                  i.isEven || i == datos.length - 1 ? _fecha(datos[i].$1) : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == _sel ? Colors.white : FitColors.textMuted,
                    fontSize: 10,
                    fontWeight: i == _sel ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Línea del peso máximo por sesión de un ejercicio: trazo de 2 px y
/// marcadores de 8 px. Tocar cerca de un punto lo selecciona y muestra su
/// valor; por defecto se rotula el último.
class LineaPeso extends StatefulWidget {
  const LineaPeso({super.key, required this.datos});
  final List<(DateTime, double)> datos;

  @override
  State<LineaPeso> createState() => _LineaPesoState();
}

class _LineaPesoState extends State<LineaPeso> {
  late int _sel = widget.datos.length - 1;

  @override
  Widget build(BuildContext context) {
    final datos = widget.datos;
    final (fecha, peso) = datos[_sel];
    final primero = datos.first.$2;
    final cambio = datos.last.$2 - primero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_kg(peso)} kg · ${_fecha(fecha)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(
          cambio == 0
              ? 'Sin cambios desde el primer registro'
              : '${cambio > 0 ? '+' : ''}${_kg(cambio)} kg desde el primer registro',
          style: const TextStyle(color: FitColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              onTapDown: (d) {
                final n = datos.length;
                final paso = n == 1 ? 0.0 : (c.maxWidth - 40) / (n - 1);
                final i = paso == 0 ? 0 : ((d.localPosition.dx - 32) / paso).round().clamp(0, n - 1);
                setState(() => _sel = i);
              },
              child: CustomPaint(
                size: Size(c.maxWidth, 150),
                painter: _PintorLinea(datos.map((d) => d.$2).toList(), _sel),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PintorLinea extends CustomPainter {
  _PintorLinea(this.valores, this.sel);
  final List<double> valores;
  final int sel;

  static const _izq = 32.0;
  static const _der = 8.0;
  static const _arriba = 10.0;
  static const _abajo = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = valores.reduce((a, b) => a < b ? a : b);
    final maxV = valores.reduce((a, b) => a > b ? a : b);
    final margen = (maxV - minV) == 0 ? (maxV == 0 ? 1 : maxV * 0.1) : (maxV - minV) * 0.15;
    final lo = (minV - margen).clamp(0, double.infinity).toDouble();
    final hi = maxV + margen;
    final ancho = size.width - _izq - _der;
    final alto = size.height - _arriba - _abajo;

    Offset punto(int i) => Offset(
          _izq + (valores.length == 1 ? ancho / 2 : ancho * i / (valores.length - 1)),
          _arriba + alto * (1 - (valores[i] - lo) / (hi - lo)),
        );

    // Cuadrícula y etiquetas del eje, apagadas.
    final grilla = Paint()
      ..color = Colors.white.withAlpha(18)
      ..strokeWidth = 1;
    for (var k = 0; k <= 2; k++) {
      final y = _arriba + alto * k / 2;
      canvas.drawLine(Offset(_izq, y), Offset(size.width - _der, y), grilla);
      final valor = hi - (hi - lo) * k / 2;
      final tp = TextPainter(
        text: TextSpan(text: _kg(valor), style: const TextStyle(color: FitColors.textMuted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_izq - tp.width - 6, y - tp.height / 2));
    }

    final linea = Paint()
      ..color = FitColors.chart
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final camino = Path()..moveTo(punto(0).dx, punto(0).dy);
    for (var i = 1; i < valores.length; i++) {
      camino.lineTo(punto(i).dx, punto(i).dy);
    }
    canvas.drawPath(camino, linea);

    // Marcadores de 8 px con anillo del color de la superficie; el
    // seleccionado, más grande y con guía vertical.
    for (var i = 0; i < valores.length; i++) {
      final p = punto(i);
      if (i == sel) {
        canvas.drawLine(Offset(p.dx, _arriba), Offset(p.dx, size.height - _abajo),
            Paint()..color = Colors.white.withAlpha(40)..strokeWidth = 1);
      }
      canvas.drawCircle(p, i == sel ? 6 : 4, Paint()..color = FitColors.surface);
      canvas.drawCircle(p, i == sel ? 5 : 4, Paint()..color = FitColors.chart);
    }
  }

  @override
  bool shouldRepaint(_PintorLinea old) => old.sel != sel || old.valores != valores;
}

class _FilaSesion extends StatelessWidget {
  const _FilaSesion({required this.sesion});
  final SesionEntrenamiento sesion;

  @override
  Widget build(BuildContext context) {
    final s = sesion;
    final musculos = s.ejercicios.where((e) => e.seriesHechas > 0).map((e) => e.musculo).where((m) => m.isNotEmpty).toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: FitColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Column(
              children: [
                Text('${s.fecha.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                Text(const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][s.fecha.month - 1],
                    style: const TextStyle(color: FitColors.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.rutinaNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${s.seriesHechas}/${s.seriesPlan} series · ${s.duracion.inMinutes} min'
                    '${s.volumenKg > 0 ? ' · ${_kg(s.volumenKg)} kg' : ''}',
                    style: const TextStyle(color: FitColors.textMuted, fontSize: 13),
                  ),
                  if (musculos.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [for (final m in musculos) MusculoChip(m)]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

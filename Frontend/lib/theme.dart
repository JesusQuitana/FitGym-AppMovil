import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colores de un tema (claro u oscuro) de la dirección "deportiva editorial":
/// carbón y papel, un único acento rojo y bloques sólidos.
class PaletaFit {
  const PaletaFit({
    required this.brillo,
    required this.fondo,
    required this.superficie,
    required this.superficieAlta,
    required this.tinta,
    required this.textoSuave,
    required this.linea,
    required this.acento,
    required this.primario,
    required this.sobrePrimario,
    required this.grafico,
    required this.ok,
    required this.warning,
    required this.danger,
    required this.vip,
    required this.premium,
    required this.regular,
    required this.bloque,
    required this.bloqueLinea,
    required this.sobreBloqueSuave,
    required this.barra,
    required this.barraSuave,
  });

  final Brightness brillo;
  final Color fondo;
  final Color superficie;
  final Color superficieAlta;

  /// Texto principal (y el relleno de los botones principales).
  final Color tinta;
  final Color textoSuave;
  final Color linea;

  /// Rojo de la marca para rellenos grandes: es el mismo en los dos temas.
  final Color acento;

  /// Rojo legible como texto o ícono sobre el fondo del tema.
  final Color primario;
  final Color sobrePrimario;

  /// Marcas de los gráficos de progreso (una sola serie).
  final Color grafico;

  final Color ok;
  final Color warning;
  final Color danger;
  final Color vip;
  final Color premium;
  final Color regular;

  /// Bloque destacado ("Hoy toca"): carbón en claro, gris carbón en oscuro.
  final Color bloque;
  final Color bloqueLinea;
  final Color sobreBloqueSuave;

  /// Barra de navegación inferior: carbón en los dos temas.
  final Color barra;
  final Color barraSuave;
}

/// Colores de la app según el tema activo. [actual] lo actualiza la app al
/// cambiar de tema (ver `main.dart`), así que estos valores no son
/// constantes: no se pueden usar dentro de expresiones `const`.
class FitColors {
  static const temaClaro = PaletaFit(
    brillo: Brightness.light,
    fondo: Color(0xFFF5F5F0),
    superficie: Color(0xFFFFFFFF),
    superficieAlta: Color(0xFFEBEBE4),
    tinta: Color(0xFF111111),
    textoSuave: Color(0xFF6B6B66),
    linea: Color(0xFFDADAD3),
    acento: Color(0xFFFF3B2F),
    primario: Color(0xFFD42A1E),
    sobrePrimario: Color(0xFFFFFFFF),
    grafico: Color(0xFFD42A1E),
    ok: Color(0xFF1E7A3E),
    warning: Color(0xFFA35A00),
    danger: Color(0xFFB3261E),
    vip: Color(0xFF8A5A00),
    premium: Color(0xFF5B3FD6),
    regular: Color(0xFF0E7C72),
    bloque: Color(0xFF111111),
    bloqueLinea: Color(0xFF111111),
    sobreBloqueSuave: Color(0xFFBDBDB5),
    barra: Color(0xFF111111),
    barraSuave: Color(0xFF9E9E96),
  );

  static const temaOscuro = PaletaFit(
    brillo: Brightness.dark,
    fondo: Color(0xFF121212),
    superficie: Color(0xFF1C1C1C),
    superficieAlta: Color(0xFF262626),
    tinta: Color(0xFFF5F5F0),
    textoSuave: Color(0xFFA3A39B),
    linea: Color(0xFF2E2E2B),
    acento: Color(0xFFFF3B2F),
    primario: Color(0xFFFF3B2F),
    sobrePrimario: Color(0xFF111111),
    grafico: Color(0xFFFF3B2F),
    ok: Color(0xFF4CC37A),
    warning: Color(0xFFFFA62B),
    danger: Color(0xFFFF6B61),
    vip: Color(0xFFFFC23D),
    premium: Color(0xFFA08BFF),
    regular: Color(0xFF2EC4B6),
    bloque: Color(0xFF1E1E1E),
    bloqueLinea: Color(0xFF2E2E2B),
    sobreBloqueSuave: Color(0xFFA3A39B),
    barra: Color(0xFF0A0A0A),
    barraSuave: Color(0xFF8A8A82),
  );

  static PaletaFit actual = temaOscuro;

  static bool get oscuro => actual.brillo == Brightness.dark;

  /// Papel y carbón fijos: el pase, el texto sobre el rojo y sobre el bloque.
  static const papel = Color(0xFFF5F5F0);
  static const carbon = Color(0xFF111111);

  static Color get primary => actual.primario;
  static Color get onPrimary => actual.sobrePrimario;
  static Color get accent => actual.acento;
  static Color get chart => actual.grafico;
  static Color get background => actual.fondo;
  static Color get surface => actual.superficie;
  static Color get surfaceHigh => actual.superficieAlta;
  static Color get ink => actual.tinta;
  static Color get textMuted => actual.textoSuave;
  static Color get line => actual.linea;
  static Color get block => actual.bloque;
  static Color get blockLine => actual.bloqueLinea;
  static Color get onBlockMuted => actual.sobreBloqueSuave;
  static Color get bar => actual.barra;
  static Color get barMuted => actual.barraSuave;

  static Color get vip => actual.vip;
  static Color get premium => actual.premium;
  static Color get regular => actual.regular;

  static Color get ok => actual.ok;
  static Color get warning => actual.warning;
  static Color get danger => actual.danger;
}

/// Tipografía de títulos y cifras: condensada, gruesa y en itálica.
const fuenteTitulos = 'BarlowCondensed';

TextStyle estiloCifra(double size, {Color? color, FontWeight weight = FontWeight.w900}) => TextStyle(
      fontFamily: fuenteTitulos,
      fontWeight: weight,
      fontStyle: FontStyle.italic,
      fontSize: size,
      height: 0.9,
      color: color,
    );

/// Etiqueta pequeña en mayúsculas con espaciado amplio.
TextStyle estiloEtiqueta({Color? color, double size = 11}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      color: color,
    );

ThemeData buildFitTheme(PaletaFit p) {
  final oscuro = p.brillo == Brightness.dark;
  const cuadrado = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2)));
  final scheme = ColorScheme(
    brightness: p.brillo,
    primary: p.tinta,
    onPrimary: p.fondo,
    secondary: p.acento,
    onSecondary: FitColors.carbon,
    secondaryContainer: p.tinta,
    onSecondaryContainer: p.fondo,
    tertiary: p.primario,
    onTertiary: p.sobrePrimario,
    error: p.danger,
    onError: oscuro ? FitColors.carbon : Colors.white,
    surface: p.superficie,
    onSurface: p.tinta,
    onSurfaceVariant: p.textoSuave,
    surfaceContainerLowest: p.fondo,
    surfaceContainerLow: p.superficie,
    surfaceContainer: p.superficie,
    surfaceContainerHigh: p.superficie,
    surfaceContainerHighest: p.superficieAlta,
    outline: p.tinta,
    outlineVariant: p.linea,
    inverseSurface: p.tinta,
    onInverseSurface: p.fondo,
  );

  final base = ThemeData(useMaterial3: true, brightness: p.brillo, colorScheme: scheme);
  final titulos = TextStyle(fontFamily: fuenteTitulos, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: p.tinta);
  final textTheme = base.textTheme.copyWith(
    displayLarge: base.textTheme.displayLarge?.merge(titulos),
    displayMedium: base.textTheme.displayMedium?.merge(titulos),
    displaySmall: base.textTheme.displaySmall?.merge(titulos),
    headlineLarge: base.textTheme.headlineLarge?.merge(titulos),
    headlineMedium: base.textTheme.headlineMedium?.merge(titulos),
    headlineSmall: base.textTheme.headlineSmall?.merge(titulos),
    titleLarge: base.textTheme.titleLarge?.merge(titulos).copyWith(fontSize: 26),
  ).apply(bodyColor: p.tinta, displayColor: p.tinta);

  const etiquetaBoton = TextStyle(
    fontFamily: fuenteTitulos,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    fontSize: 20,
    letterSpacing: 0.5,
  );

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: p.fondo,
    canvasColor: p.fondo,
    dividerColor: p.linea,
    dividerTheme: DividerThemeData(color: p.linea, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.fondo,
      foregroundColor: p.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(color: p.superficie, elevation: 0, margin: EdgeInsets.zero, shape: cuadrado),
    dialogTheme: DialogThemeData(backgroundColor: p.superficie, shape: cuadrado),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.superficie,
      modalBackgroundColor: p.superficie,
      shape: cuadrado,
      showDragHandle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.tinta,
        foregroundColor: p.fondo,
        minimumSize: const Size(64, 52),
        shape: cuadrado,
        textStyle: etiquetaBoton,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.tinta,
        foregroundColor: p.fondo,
        elevation: 0,
        minimumSize: const Size(64, 52),
        shape: cuadrado,
        textStyle: etiquetaBoton,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.tinta,
        side: BorderSide(color: p.tinta, width: 2),
        minimumSize: const Size(64, 52),
        shape: cuadrado,
        textStyle: etiquetaBoton,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.tinta, shape: cuadrado),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.acento,
      foregroundColor: FitColors.carbon,
      shape: cuadrado,
      elevation: 0,
      extendedTextStyle: etiquetaBoton,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: cuadrado,
        side: BorderSide(color: p.tinta, width: 2),
        selectedBackgroundColor: p.tinta,
        selectedForegroundColor: p.fondo,
        foregroundColor: p.tinta,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: cuadrado,
      side: BorderSide(color: p.linea),
      backgroundColor: p.superficie,
      selectedColor: p.tinta,
      checkmarkColor: p.fondo,
      labelStyle: TextStyle(color: p.tinta, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: p.fondo, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.superficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: p.linea)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: p.linea)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: BorderSide(color: p.tinta, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.barra,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.acento,
      indicatorShape: cuadrado,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? FitColors.carbon : p.barraSuave),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w700,
          color: s.contains(WidgetState.selected) ? FitColors.papel : p.barraSuave,
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.acento, linearTrackColor: p.linea),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? FitColors.carbon : p.textoSuave),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.acento : p.linea),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.acento, thumbColor: p.acento, inactiveTrackColor: p.linea),
    listTileTheme: ListTileThemeData(iconColor: p.textoSuave, shape: cuadrado),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.tinta,
      contentTextStyle: TextStyle(color: p.fondo),
      actionTextColor: p.acento,
      shape: cuadrado,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static const EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 16.0; // Increased for modern look
  static const double lg = 24.0;
  static const double xl = 32.0;
}

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

extension TextStyleExtensions on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get normal => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
  TextStyle withColor(Color color) => copyWith(color: color);
  TextStyle withSize(double size) => copyWith(fontSize: size);
}

// =============================================================================
// COLORS
// =============================================================================

class AppColors {
  // Brand Colors
  static const orangeVibrant = Color(0xFFff781f);
  static const orangeDark = Color(0xFFdc5800);
  
  // Dark Mode Backgrounds
  static const darkBackground = Color(0xFF201e1e);
  static const darkSurface = Color(0xFF2D2B2B); // Slightly lighter than background
  static const darkSurfaceHighlight = Color(0xFF3A3838);

  // Light Mode Backgrounds
  static const lightBackground = Color(0xFFffffff);
  static const lightSurface = Color(0xFFF7F9FA); 
  static const lightSurfaceHighlight = Color(0xFFF0F2F5);
}

class LightModeColors {
  static const primary = AppColors.orangeVibrant;
  static const onPrimary = Colors.white;
  static const primaryContainer = Color(0xFFFFDBC8);
  static const onPrimaryContainer = AppColors.orangeDark;

  static const secondary = AppColors.orangeDark;
  static const onSecondary = Colors.white;
  static const secondaryContainer = Color(0xFFFFE5D6);
  static const onSecondaryContainer = Color(0xFF451B00);

  static const tertiary = Color(0xFF384E77); // A complementary blue/slate
  static const onTertiary = Colors.white;

  static const error = Color(0xFFBA1A1A);
  static const onError = Colors.white;

  static const background = AppColors.lightBackground;
  static const onBackground = Color(0xFF1A1C1E);
  
  static const surface = AppColors.lightBackground;
  static const onSurface = Color(0xFF1A1C1E);
  
  static const surfaceContainerHighest = Color(0xFFE0E2E5);
  static const outline = Color(0xFF74777F);
}

class DarkModeColors {
  static const primary = AppColors.orangeVibrant;
  static const onPrimary = Color(0xFF201e1e); // Dark text on vibrant orange
  static const primaryContainer = AppColors.orangeDark;
  static const onPrimaryContainer = Colors.white;

  static const secondary = Color(0xFFFFB784);
  static const onSecondary = Color(0xFF4C1D00);
  static const secondaryContainer = AppColors.orangeDark;
  static const onSecondaryContainer = Colors.white;

  static const tertiary = Color(0xFFA0C9FF);
  static const onTertiary = Color(0xFF00325B);

  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);

  static const background = AppColors.darkBackground;
  static const onBackground = Color(0xFFE2E2E2);
  
  static const surface = AppColors.darkSurface;
  static const onSurface = Color(0xFFE2E2E2);

  static const surfaceContainerHighest = AppColors.darkSurfaceHighlight;
  static const outline = Color(0xFF8E9099);
}

// =============================================================================
// THEMES
// =============================================================================

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: LightModeColors.primary,
    onPrimary: LightModeColors.onPrimary,
    primaryContainer: LightModeColors.primaryContainer,
    onPrimaryContainer: LightModeColors.onPrimaryContainer,
    secondary: LightModeColors.secondary,
    onSecondary: LightModeColors.onSecondary,
    secondaryContainer: LightModeColors.secondaryContainer,
    onSecondaryContainer: LightModeColors.onSecondaryContainer,
    tertiary: LightModeColors.tertiary,
    onTertiary: LightModeColors.onTertiary,
    error: LightModeColors.error,
    onError: LightModeColors.onError,
    surface: LightModeColors.surface,
    onSurface: LightModeColors.onSurface,
    surfaceContainerHighest: LightModeColors.surfaceContainerHighest,
    outline: LightModeColors.outline,
  ),
  scaffoldBackgroundColor: LightModeColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFF1A1C1E),
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.light),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: LightModeColors.primary,
      foregroundColor: LightModeColors.onPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFFAFAFA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: LightModeColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.all(16),
  ),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: DarkModeColors.primary,
    onPrimary: DarkModeColors.onPrimary,
    primaryContainer: DarkModeColors.primaryContainer,
    onPrimaryContainer: DarkModeColors.onPrimaryContainer,
    secondary: DarkModeColors.secondary,
    onSecondary: DarkModeColors.onSecondary,
    secondaryContainer: DarkModeColors.secondaryContainer,
    onSecondaryContainer: DarkModeColors.onSecondaryContainer,
    tertiary: DarkModeColors.tertiary,
    onTertiary: DarkModeColors.onTertiary,
    error: DarkModeColors.error,
    onError: DarkModeColors.onError,
    surface: DarkModeColors.surface,
    onSurface: DarkModeColors.onSurface,
    surfaceContainerHighest: DarkModeColors.surfaceContainerHighest,
    outline: DarkModeColors.outline,
  ),
  scaffoldBackgroundColor: DarkModeColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Color(0xFFE2E2E2),
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: DarkModeColors.surface,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
    ),
  ),
  textTheme: _buildTextTheme(Brightness.dark),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DarkModeColors.primary,
      foregroundColor: DarkModeColors.onPrimary,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DarkModeColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: DarkModeColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.all(16),
  ),
);

TextTheme _buildTextTheme(Brightness brightness) {
  final textColor = brightness == Brightness.light 
      ? const Color(0xFF1A1C1E) 
      : const Color(0xFFE2E2E2);

  // Use Poppins for Headings/Display
  final displayFont = GoogleFonts.poppins;
  // Use Inter for Body
  final bodyFont = GoogleFonts.inter;

  return TextTheme(
    displayLarge: displayFont(fontSize: 57, fontWeight: FontWeight.w400, color: textColor),
    displayMedium: displayFont(fontSize: 45, fontWeight: FontWeight.w400, color: textColor),
    displaySmall: displayFont(fontSize: 36, fontWeight: FontWeight.w400, color: textColor),
    
    headlineLarge: displayFont(fontSize: 32, fontWeight: FontWeight.w600, color: textColor),
    headlineMedium: displayFont(fontSize: 28, fontWeight: FontWeight.w600, color: textColor),
    headlineSmall: displayFont(fontSize: 24, fontWeight: FontWeight.w600, color: textColor),
    
    titleLarge: displayFont(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
    titleMedium: displayFont(fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
    titleSmall: displayFont(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
    
    labelLarge: bodyFont(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
    labelMedium: bodyFont(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
    labelSmall: bodyFont(fontSize: 11, fontWeight: FontWeight.w500, color: textColor),
    
    bodyLarge: bodyFont(fontSize: 16, fontWeight: FontWeight.w400, color: textColor),
    bodyMedium: bodyFont(fontSize: 14, fontWeight: FontWeight.w400, color: textColor),
    bodySmall: bodyFont(fontSize: 12, fontWeight: FontWeight.w400, color: textColor),
  );
}

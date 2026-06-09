import 'dart:io';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Neon teal from the PeerBeat icon — the default seed when no album art drives
/// the theme (or dynamic theming is off).
const Color kDefaultSeed = Color(0xFF2BD9C6);

/// The PeerBeat "Expressive" Material 3 theme: album-art-forward, bold display
/// type, generously rounded surfaces, tonal navigation. [seed] is the album-art
/// accent when dynamic theming is on, else [kDefaultSeed].
ThemeData peerBeatTheme(Brightness brightness, {Color seed = kDefaultSeed}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
  );

  final tt = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  );

  return base.copyWith(
    textTheme: tt,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      scrolledUnderElevation: 3,
      titleTextStyle: tt.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      elevation: 2,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

/// Compute a stable accent color from an album-art file for dynamic theming.
/// Best-effort: returns null if there's no art or decoding fails. Caller must
/// invoke this only on track changes (never on the position tick).
Future<Color?> accentFromArt(String? artPath) async {
  if (artPath == null || artPath.isEmpty) return null;
  final file = File(artPath);
  if (!await file.exists()) return null;
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      FileImage(file),
      maximumColorCount: 12,
      size: const Size(120, 120), // downscale: fast + plenty for a seed
    );
    return palette.vibrantColor?.color ??
        palette.dominantColor?.color ??
        palette.mutedColor?.color;
  } catch (_) {
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_library/quran_library.dart';

/// Primary Quran experience for Dhker.
///
/// The legacy QCF reader remains in main.dart as a fallback/reference;
/// this screen promotes the maintained Quran Library reader without
/// deleting the existing reader implementation.
class QuranLibraryPreviewScreen extends StatelessWidget {
  const QuranLibraryPreviewScreen({super.key});

  static const _mushafGreen = Color(0xFF1C2B12);
  static const _paper = Color(0xFFF5EEDC);
  static const _ink = Color(0xFF211F18);
  static const _sage = Color(0xFF477A5D);
  static const _gold = Color(0xFFC6A76A);

  @override
  Widget build(BuildContext context) {
    final libraryTheme = ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _sage,
        onPrimary: Colors.white,
        secondary: _gold,
        onSecondary: _ink,
        surface: _paper,
        onSurface: _ink,
      ),
      scaffoldBackgroundColor: _mushafGreen,
      appBarTheme: const AppBarTheme(
        backgroundColor: _mushafGreen,
        foregroundColor: _paper,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: GoogleFonts.amiriTextTheme(
        ThemeData.light(useMaterial3: false).textTheme,
      ).apply(bodyColor: _ink, displayColor: _ink),
    );

    return Theme(
      data: libraryTheme,
      child: Builder(
        builder: (libraryContext) => QuranLibraryScreen(
          parentContext: libraryContext,
          withPageView: true,
          useDefaultAppBar: true,
          isShowAudioSlider: true,
          showAyahBookmarkedIcon: true,
          isDark: false,
          appLanguageCode: 'ar',
          backgroundColor: _mushafGreen,
          textColor: _ink,
          ayahSelectedBackgroundColor: const Color(0x55477A5D),
          ayahIconColor: _gold,
        ),
      ),
    );
  }
}

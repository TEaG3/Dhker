import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';

/// Separate reader route for evaluating the Medina Mushaf renderer.
/// The existing Quran reader remains available as the default.
class QuranLibraryPreviewScreen extends StatelessWidget {
  const QuranLibraryPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTheme = Theme.of(context);
    final libraryTheme = (isDark
            ? ThemeData.dark(useMaterial3: false)
            : ThemeData.light(useMaterial3: false))
        .copyWith(
          colorScheme: currentTheme.colorScheme,
          textTheme: currentTheme.textTheme,
        );

    return Theme(
      data: libraryTheme,
      child: QuranLibraryScreen(
        parentContext: context,
        isDark: isDark,
        appLanguageCode: 'ar',
      ),
    );
  }
}

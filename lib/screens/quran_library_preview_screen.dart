import 'package:flutter/material.dart';
import 'package:quran_library/quran_library.dart';

/// Isolated preview route for evaluating quran_library without replacing
/// the existing qcf_quran_lite reader.
class QuranLibraryPreviewScreen extends StatelessWidget {
  const QuranLibraryPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final libraryTheme = ThemeData.from(Theme.of(context), useMaterial3: false);

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

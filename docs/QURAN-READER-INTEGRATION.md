# Quran reader integration — ذِكر

## Current implementation

- The primary Quran tab now opens `quran_library` (MIT package code) using its Madinah Mushaf/Hafs rendering, page view, Arabic interface, ayah selection, bookmarks, search/index, tafsir and audio surfaces.
- `QuranLibrary.init()` is called before `runApp` in `lib/main.dart`.
- Android `MainActivity` already extends `AudioServiceActivity`, which is the package requirement for system/lock-screen audio controls.
- The former `qcf_quran_lite` reader remains in `main.dart`; it has not been deleted or overwritten and can be retained as a fallback while the new reader is verified.
- The reader is styled with a deep olive surround, warm paper palette, sage selection colour and gold controls. The package's Quran page renderer is used for the actual Quran text and page layout.

## Content architecture

1. Mushaf rendering and Quran text: use the package's QCF/Hafs resources and preserve the Quran text exactly. Do not manually edit or reconstruct Quran text.
2. Search, surah/juz index, bookmarks and tafsir: use the package's built-in data/controllers. Download optional tafsir/font resources on demand and disclose storage/network needs.
3. Recitation audio: use the package's reciter/audio player and per-surah download manager. Keep audio as user-selected downloads; do not bundle a complete recitation corpus in the APK.
4. Website: keep the website independent from the Android Flutter app. It may stream Quran audio from the AlQuran Cloud CDN and continue to cache already-opened Quran text pages in IndexedDB; browser offline audio is not promised.
5. App distribution: the website download button remains separate and points to the Android Releases page.

## Verification still required

- GitHub Actions must resolve dependencies, run `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` and build the release APK.
- Install the generated APK on a physical Android device and verify page navigation, search, bookmarks, tafsir download, reciter selection, audio playback, per-surah download and playback after airplane mode.
- Confirm each QCF font/resource's upstream QUL/KFGQPC terms before redistribution. The package's code is MIT, but the package documentation explicitly says QCF fonts and QUL resources have separate terms.

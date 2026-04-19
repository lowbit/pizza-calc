# Pizzazz - Pizza Dough Calculator

A Flutter app for calculating pizza dough ingredients with precision. Supports multiple pizza styles, fermentation modes, and step-by-step instructions with timing.

## Pizza Types

- **Neapolitan** — 60% hydration, 250g balls, Tipo 00 flour
- **New York** — 64% hydration, 300g balls, bread flour
- **Sicilian/Detroit** — 74% hydration, 800g pan, bread flour
- **Roman Teglia** — 80% hydration, 800g tray, Tipo 00 flour

## Features

- Same day (room temp) and cold ferment (fridge, 1–5 days) modes
- iOS time picker for same day — calculates fermentation and yeast automatically
- Poolish pre-ferment calculator
- Fresh, instant/dry, and poolish yeast options
- Time-aware step-by-step instructions with freezing tips
- Wakelock for flour-covered hands

## Build

```bash
# Install dependencies
flutter pub get

# Run
flutter run

# Release APK (arm64 only, newer phones)
flutter build apk --release --target-platform android-arm64

# Release APK (all architectures)
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Icons & Splash

```bash
dart run flutter_launcher_icons:main
dart run flutter_native_splash:create
```

---

Made by Rijad Spahic

# 🍕 Pizzazz - Professional Pizza Calculator

A modern, iOS-style Flutter app for calculating pizza dough ingredients with precision and style. Features multiple pizza types, rise time options, poolish calculator, and detailed step-by-step instructions.

## ✨ Features

### 🎯 **Pizza Types Supported**
- **Neapolitan** (60% hydration, traditional Italian style)
- **New York** (64% hydration, sugar & olive oil)
- **Sicilian/Detroit** (74% hydration, high oil content)
- **Roman Teglia** (70% hydration, crispy Roman style)

### 🧮 **Advanced Calculations**
- **Baker's Percentage System** - Professional ingredient ratios
- **Rise Time Options** - Same day vs overnight (auto-adjusts yeast)
- **Poolish Calculator** - Pre-ferment calculations with elegant modal
- **Dynamic Ingredients** - Flour type and percentages per pizza style
- **Precise Measurements** - Optimized for any number of doughballs

### 📱 **Modern UI/UX**
- **iOS-Style Interface** - Cupertino widgets with dark theme
- **Touch-Friendly Controls** - Steppers, sliders, pickers (no text inputs)
- **Smooth Animations** - Collapsible sections and haptic feedback
- **Professional Polish** - Custom app icon and splash screen
- **Easter Eggs** - Hidden Hawaiian pizza toast and developer credit

### 📋 **Step-by-Step Instructions**
- **Collapsible Guides** - Detailed instructions for each pizza style
- **Same Day & Overnight** - Different processes for each rise time
- **Traditional Techniques** - Authentic pizza-making methods
- **Timing Guidelines** - Proper fermentation and preparation times

## 🚀 Getting Started

### **Prerequisites**
- Flutter SDK (3.0+)
- Android Studio or VS Code
- Android device/emulator or iOS simulator

### **Installation**
```bash
# Clone the repository
git clone <your-repo-url>
cd pizza_calc

# Install dependencies
flutter pub get

# Generate app icons and splash screen (if needed)
dart run flutter_launcher_icons:main
dart run flutter_native_splash:create

# Run the app
flutter run
```

## 🔧 Building Release APK

### **For ARM64 Devices (Most Android Phones)**
```bash
flutter build apk --target-platform android-arm64 --release
```

### **For x64 Devices (Emulators/Intel)**
```bash
flutter build apk --target-platform android-x64 --release
```

### **Universal APK (All Architectures)**
```bash
flutter build apk --release
```

**Output Location**: `build/app/outputs/flutter-apk/app-release.apk`

## 📁 Project Structure

```
lib/
├── main.dart                    # Main app entry point
├── components/
│   ├── steps_display.dart       # Collapsible pizza instructions
│   └── poolish_calculator.dart  # Poolish modal calculator
└── widgets/
    ├── stepper_button.dart      # Custom increment/decrement buttons
    └── picker_input.dart        # Number picker with steppers

assets/
├── icon/
│   └── app_icon.png            # App icon (1024x1024)
└── splash/
    └── splash_logo.png         # Splash screen logo (512x512)
```

## 🎨 Customization

### **App Name**
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<application android:label="Your App Name">
```

### **App Icon & Splash Screen**
1. Replace images in `assets/icon/` and `assets/splash/`
2. Run generation commands:
```bash
dart run flutter_launcher_icons:main
dart run flutter_native_splash:create
```

### **Pizza Types**
Add new pizza types in `main.dart` by extending the `PizzaType` class with custom hydration and ingredient percentages.

## 🛠️ Dependencies

### **Core**
- `flutter` - UI framework
- `cupertino_icons` - iOS-style icons

### **Development**
- `flutter_launcher_icons` - App icon generation
- `flutter_native_splash` - Splash screen generation
- `flutter_lints` - Code quality

## 📱 Supported Platforms

- ✅ **Android** (ARM64, x64, ARM32)
- ✅ **Web** (with app icon support)
- ✅ **Windows** (with app icon support)
- 🔄 **iOS** (ready, requires Xcode setup)

## 🎯 Technical Highlights

- **State Management** - Pure Flutter StatefulWidget approach
- **Responsive Design** - Adapts to different screen sizes
- **Performance** - Optimized calculations and smooth animations
- **Accessibility** - Touch-friendly controls and clear typography
- **Professional Polish** - Custom branding and consistent theming

## 🍕 About

**Pizzazz** was created for pizza enthusiasts who want precise, professional dough calculations with a beautiful, modern interface. Whether you're making Neapolitan at home or Detroit-style for a crowd, Pizzazz handles the math so you can focus on the craft.

## 📄 License

This project is open source. Feel free to use, modify, and distribute.

---

**Made with ❤️ for pizza lovers everywhere** 🍕✨

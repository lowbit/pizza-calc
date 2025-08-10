# 📱 App Icon & Splash Screen Setup Guide

## 🎨 What You Need to Create

### **1. App Icon (`assets/icon/app_icon.png`)**
- **Size**: 1024x1024 pixels
- **Format**: PNG with transparent background
- **Design**: Pizza-themed icon (e.g., pizza slice, chef hat, calculator with pizza)
- **Style**: Clean, modern, recognizable at small sizes

### **2. Splash Screen Logo (`assets/splash/splash_logo.png`)**
- **Size**: 512x512 pixels (or smaller, will be centered)
- **Format**: PNG with transparent background
- **Design**: Your logo/branding for the launch screen
- **Style**: Simple, clean design that works on black background

## 🚀 Setup Steps

### **Step 1: Create Your Images**
1. Design your app icon (1024x1024 px)
2. Design your splash screen logo (512x512 px)
3. Save both as PNG files with transparent backgrounds
4. Place them in the correct directories:
   - `assets/icon/app_icon.png`
   - `assets/splash/splash_logo.png`

### **Step 2: Generate Icons & Splash Screen**
Run these commands in your project directory:

```bash
# Install dependencies
flutter pub get

# Generate app icons for all platforms
flutter pub run flutter_launcher_icons:main

# Generate splash screens for all platforms
flutter pub run flutter_native_splash:create
```

### **Step 3: Clean & Rebuild**
```bash
# Clean the project
flutter clean

# Get dependencies again
flutter pub get

# Build and test
flutter run
```

## 🎯 Design Recommendations

### **App Icon Ideas:**
- 🍕 Pizza slice with calculator elements
- 📱 Phone with pizza emoji overlay
- ⚖️ Scale/balance with pizza ingredients
- 👨‍🍳 Chef hat with pizza slice
- 🧮 Calculator with pizza theme

### **Color Scheme:**
- **Background**: Dark (#1C1C1C) to match app theme
- **Accent**: iOS blue (#007AFF) for consistency
- **Pizza colors**: Traditional red, white, green, or golden crust tones

### **Splash Screen:**
- **Background**: Black (#000000) to match app
- **Logo**: Centered, simple design
- **Duration**: Brief, professional appearance

## 📁 File Structure After Setup
```
pizza_calc/
├── assets/
│   ├── icon/
│   │   └── app_icon.png (1024x1024)
│   └── splash/
│       └── splash_logo.png (512x512)
├── android/app/src/main/res/ (auto-generated icons)
├── ios/Runner/Assets.xcassets/ (auto-generated icons)
└── web/icons/ (auto-generated icons)
```

## ✅ What This Setup Provides

### **App Icon:**
- **iOS**: All required sizes (20x20 to 1024x1024)
- **Android**: All density variants (mdpi to xxxhdpi)
- **Web**: Favicon and PWA icons
- **Windows**: Desktop app icon

### **Splash Screen:**
- **iOS**: Native launch screen
- **Android**: Including Android 12+ splash API
- **Web**: Loading screen
- **Dark mode**: Consistent with app theme

## 🔧 Troubleshooting

### **Common Issues:**
- **File not found**: Ensure PNG files are in correct directories
- **Build errors**: Run `flutter clean` and `flutter pub get`
- **Icon not updating**: Uninstall and reinstall the app

### **Testing:**
- **iOS Simulator**: Check app icon in home screen
- **Android Emulator**: Verify icon in app drawer
- **Splash screen**: Watch launch animation when opening app

---

**Ready to make your pizza calculator look professional! 🍕✨**

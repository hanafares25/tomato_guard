# 🍅 TomatoGuard

**Offline AI for tomato leaf disease screening — built for the World Bank × Hack-Nation Small AI for Development Hackathon.**

TomatoGuard is a lightweight AI-powered tool designed to help smallholder farmers identify possible tomato leaf diseases using a photo. The application runs the computer-vision model **locally on the user's device**, making the core screening feature usable without an internet connection.

The project was developed during the **Small AI for Development Hackathon**, organized by **Hack-Nation in collaboration with the World Bank**, with a focus on practical AI solutions for agriculture in low-connectivity environments.

## 🌱 The Problem

Smallholder farmers may face:

- Limited access to agricultural extension officers
- Delays in identifying crop problems
- Poor or unreliable internet connectivity
- Language and literacy barriers
- Difficulty knowing when a visible leaf symptom requires further attention

A farmer may have a smartphone available but not have reliable access to an agricultural expert.

## 💡 Our Solution

**Take a picture. Get an answer.**

TomatoGuard uses a lightweight computer-vision model to analyze a tomato leaf and provide a **screening result** with a suggested next step.

```text
📷 Take a photo
      ↓
🍅 Tomato leaf check
      ↓
🤖 AI screening
      ↓
🩺 Possible problem 
      ↓
🔊 Egyptian Arabic voice guidance
```

The project uses MobileNetV3-Small, selected for its lightweight architecture and suitability for on-device inference.

**The model is trained on the tomato subset of the PlantVillage dataset, covering 10 classes:**

- Healthy
- Bacterial Spot
- Early Blight
- Late Blight
- Leaf Mold
- Mosaic Virus
- Septoria Leaf Spot
- Spider Mites
- Target Spot
- Yellow Leaf Curl Virus

## 📱 Build and install the Android app

Install Flutter and the Android SDK, then run the following commands from the repository root:

```powershell
flutter pub get
flutter build apk --release
```

The universal release APK is created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

To install it on a connected Android device, enable **Developer options** and
**USB debugging**, connect the device, and run:

```powershell
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

You can also copy the APK to the phone and open it with a file manager. Android
may ask you to allow **Install unknown apps** for that file manager or browser.

### Smaller APKs by device architecture

For smaller downloads, build architecture-specific APKs:

```powershell
flutter build apk --release --split-per-abi
```

The output files are placed in `build/app/outputs/flutter-apk/`. Use
`arm64-v8a` for most modern Android phones. Use the universal
`app-release.apk` if you are unsure which architecture the device uses.

### Google Play distribution

For Google Play, build an Android App Bundle instead of an APK:

```powershell
flutter build appbundle --release
```

The bundle is created at:

```text
build/app/outputs/bundle/release/app-release.aab
```

For public release, configure a production Android signing key and keep it
outside the repository. Do not commit keystores or passwords.

## 🧪 Run tests

```powershell
flutter analyze
flutter test
```

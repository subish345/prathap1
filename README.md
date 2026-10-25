# DrivePlus Flutter + Python backend

This package rebuilds the original Java Android interface as a Flutter/Dart app and retains the existing FastAPI + SQLite backend.

## What's included

- Flutter UI: login/register, home, vehicle list/add/remove, service reminders, trip fuel-cost calculator, Google Maps links, emergency information, profile and API URL settings.
- Python FastAPI backend and SQLite schema.
- Existing DrivePlus logo.

## Requirements

- Flutter SDK (stable) and Dart
- Android Studio with Android SDK, or a connected Android phone with USB debugging
- Python 3.10+ recommended

## 1. Create Android platform files (first time only)

The source package omits generated Gradle/build files so Flutter can generate them for the Flutter version installed on your computer.

In VS Code, open the extracted `driveplus_flutter` folder. Open Terminal and run:

```bash
flutter doctor
flutter create --platforms=android .
```

If Flutter asks to overwrite files, keep `lib/main.dart`, `pubspec.yaml`, and `assets/driveplus_logo.png` from this package. The command normally generates the Android platform without replacing those app files.

Open `android/app/src/main/AndroidManifest.xml` and ensure the `<manifest>` has this permission and the `<application>` has `android:usesCleartextTraffic="true"` for local HTTP development:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Example application tag:

```xml
<application android:label="DrivePlus" android:usesCleartextTraffic="true" ...>
```

For production deployment, use HTTPS and remove the cleartext allowance.

## 2. Install Flutter packages

From the project root:

```bash
flutter pub get
```

## 3. Start the Python backend

Open a second terminal in the `backend` folder.

**Windows PowerShell:**

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

If PowerShell blocks activation, use Command Prompt instead:

```bat
py -m venv .venv
.venv\Scripts\activate.bat
python -m pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Test the API at `http://127.0.0.1:8000/docs` on your computer.

## 4. Run on Android

Start an emulator in Android Studio, or connect an Android phone with USB debugging enabled. In a terminal at the Flutter project root:

```bash
flutter devices
flutter run
```

Keep the backend terminal running while using the app.

### Backend URL

- **Android emulator:** `http://10.0.2.2:8000` (default in the app; this special address points to the development computer).
- **Physical Android phone:** both devices must be on the same Wi-Fi network. In Profile, change Python API address to `http://YOUR_COMPUTER_LAN_IP:8000`, for example `http://192.168.1.20:8000`. Allow Python through Windows Firewall if prompted.
- **Deployed backend:** use your server's HTTPS URL.

## 5. Build an APK

```bash
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`.

## Important limitations

- This is a functional starter implementation, not a store-ready production release. The backend's token scheme is explicitly a starter/demo token and should be replaced with robust signed-token/OAuth authentication before public deployment.
- Account registration validates email format but does not send an email or OTP.
- SOS records a demo request only; it does not contact emergency services. For a real emergency in India, call 112.
- Google Maps opens route/search links externally. It does not embed live map tiles or automatically calculate distance in this version; enter route distance to calculate fuel cost.
- Reminder records are saved in the backend, but scheduled push notifications have not been configured.
- Vehicle photo selection/editing and live GPS permissions are not yet implemented in this Flutter conversion.
# prathap1
# prathap1

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

Open a terminal in the `backend` folder:

```bash
# Easy way (auto-detects and displays your Wi-Fi IP address):
python run_server.py
```

Or manually with uvicorn:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

> **Important**: The backend MUST listen on `0.0.0.0` (not just `127.0.0.1`), so devices on your Wi-Fi network can reach it.

## 4. Run on Android Device

### Why did "Backend not found" happen when removing the USB cable?
- Over USB, `flutter run` runs a **temporary debug session** and forwards requests via ADB.
- `127.0.0.1` on your phone points to the **phone itself**, where no backend is running.
- As soon as you unplug the USB cable, the ADB tunnel closes.

### How to run wirelessly on a physical phone:
1. Ensure your **computer and phone are connected to the same Wi-Fi network**.
2. Run `python backend/run_server.py` in your computer terminal. Note the Wi-Fi IP displayed (e.g. `http://192.168.1.39:8000`).
3. Open the DrivePlus app on your phone.
4. On the login screen, tap the **Server / IP** banner at the top or the settings icon.
5. Enter your computer's Wi-Fi IP (e.g. `http://192.168.1.39:8000`) and tap **"Test Connection"**.
6. Once it says "Connected! Backend is reachable", tap **"Save & Apply"** and sign in.

## 5. Build, Install Standalone & Share the Application

If you use `flutter run`, it is only a temporary debug session. To permanently install the app on your phone so it doesn't need the computer, or to share the app with others:

### Step 1: Build the Release APK
From the project root:
```bash
flutter build apk --release
```

### Step 2: Locate the APK File
The complete, standalone APK is created at:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Step 3: Share the Application
- **Send the APK**: You can send `app-release.apk` to any Android phone via WhatsApp, Telegram, Google Drive, Quick Share, or USB.
- **Install**: On the Android phone, tap the APK file and select "Install" (enable "Install from unknown sources" if prompted).

### Step 4: Connecting the Shared App to the Backend
- **On the same Wi-Fi**: Anyone on your Wi-Fi can enter your PC's IP (`http://192.168.1.39:8000`) in the app's Server Settings.
- **Over the Internet / Mobile Data**:
  - Run a free tunnel like ngrok on your computer:
    ```bash
    ngrok http 8000
    ```
  - Copy the HTTPS URL provided by ngrok (e.g. `https://xxxx.ngrok-free.app`).
  - Enter that URL into the DrivePlus app's Server Settings on any phone anywhere!

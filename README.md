🖥️ PMT Display Pro — Fire TV Digital Signage Client 
(finishing STAGE 1, Ready for stage 2)

Enterprise-grade signage client powered by Flutter + GitHub JSON backend
✨ Overview

PMT Display Pro is a lightweight, high-reliability digital signage client designed for Fire TV / Firestick devices.
It enables businesses to display menus, promotions, ads, and dynamic content on any TV using a simple remote-managed system.

This version (MVP 0.1) is fully functional, stable, and suitable for commercial deployment.

🚀 Key Features
🔹 Zero-configuration Device Setup

Each Firestick generates a numeric Device ID (0000-0000) automatically on first launch.
No typing required — users simply register this code in the PMT content system.

🔹 Playlist & Single Image Modes

Display one fixed image or multiple images rotated on a schedule.

🔹 Remote Content Control

Images & playlists are defined via small JSON files hosted on GitHub Pages.

🔹 Offline Operation (Store-grade reliability)

If the device loses internet:

Uses last known good config stored locally

Keeps displaying content without interruptions

Shows offline status in debug overlay

🔹 Auto Refresh

Device periodically refreshes its configuration to update content.

🔹 Debug Overlay (for installers)

Toggleable overlay showing:

Device ID

Current mode

Offline/online state

Rotation timing

Config URL

Last error

🔹 Automatic rotation timer

Smooth transitions between playlist items.

🧱 System Architecture
+------------------------------+
|     GitHub Pages Backend     |
|------------------------------|
| /screens/<ID>/<ID>.json      |
| /screens/<Folder>/images/... |
+--------------+---------------+
               |
               | HTTPS (pull)
               v
+------------------------------+
|     Fire TV Signage App      |
|------------------------------|
| - Device ID generation       |
| - JSON fetch + validation    |
| - Offline cache              |
| - Image playlist engine      |
| - Debug overlay              |
+------------------------------+

📂 JSON Configuration Format
Example (Playlist Mode)
{
  "mode": "playlist",
  "rotation_seconds": 10,
  "refresh_seconds": 300,
  "images": [
    "https://luisprz.github.io/pmt-signage/screens/gala-deli/CateringJPG.jpg",
    "https://luisprz.github.io/pmt-signage/screens/gala-deli/ElGalaLogoJPG.jpg",
    "https://luisprz.github.io/pmt-signage/screens/gala-deli/SantaSpanishJPG.jpg"
  ]
}

Example (Single Image Mode)
{
  "mode": "single",
  "refresh_seconds": 300,
  "image_url": "https://luisprz.github.io/pmt-signage/screens/store1/menu.jpg"
}

🎯 How Device IDs Work

Device IDs are always numeric (e.g., 4821-9304)

Generated only when internet is available

App verifies that the ID does not already exist on GitHub

Prevents collisions between businesses

JSON folder must match the device ID exactly:

/screens/<DEVICE_ID>/<DEVICE_ID>.json


If ID is unassigned, the app shows:

Waiting for assignment

🛠️ Development & Deployment

This project uses:

Flutter

ADB (Android Debug Bridge)

GitHub Pages

SharedPreferences (for offline persistence)

🚀 Automated Deployment (.BAT Script)

A Windows automation script is included to streamline installation onto Fire TV devices.

The script performs:

flutter clean

flutter pub get

flutter build apk --release

Connect to Firestick over ADB

Uninstall previous version

Install new APK

Auto-launch the app

⚙ Configuration Variables (in the .BAT)

These must be updated depending on your workstation setup:

set PROJECT_DIR=C:\Users\maste\Documents\PMT\Software\pmt_display_client_pro
set ADB_DIR=C:\Users\maste\AppData\Local\Android\Sdk\platform-tools
set APP_ID=com.example.pmt_display_client_pro
set FIRE_IP=192.168.137.242
set APK_PATH=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk

Modify when:
Change	Update in .BAT
New project folder	PROJECT_DIR
New Fire TV IP	FIRE_IP
Package name changes	APP_ID
New Android installation	ADB_DIR
Custom APK output location	APK_PATH
🧪 Testing Instructions
1️⃣ Build the project
flutter build apk --release

2️⃣ Install to device
adb install -r build/app/outputs/flutter-apk/app-release.apk

3️⃣ View logs (optional)
adb logcat | findstr PMT

4️⃣ Force refresh configuration

Restart the app or wait for refresh_seconds.

🧭 Project Roadmap
Phase 1 — DONE ✔

MVP Firestick Client
GitHub JSON Backend
Playlist Support
Offline Mode
Device ID system

Phase 2 — Coming Next

📱 PMT Admin App (Flutter)
Upload images from phone
Assign screens to clients

Phase 3

🌐 Supabase backend (no GitHub dependency)
Authentication + multi-tenant system

Phase 4

🎞️ Video playback support
Transitions, effects, animations

Phase 5

📊 PMT Dashboard SaaS
Subscription billing
User permissions
Analytics per screen

🏢 Branding Notes (PMT)

App name: ProMultiTech Display PRO

Launch banner (Fire TV): coming in next version

Package ID can be customized later for the Store release

PMT logos and assets included in /assets/

🤝 License & Ownership

This project is proprietary software developed for:

ProMultiTech (PMT)

New York, USA
"Technology with Precision and Purpose"

Distribution or copying without permission is prohibited.

💬 Support

For support, installation help or onboarding:

📧 support@promultitech.com

🌐 https://promultitech.com
 (placeholder)

🎉 Final Note

This MVP is the foundation of a full SaaS product:

Scalable

Reliable

Simple for clients

Powerful for PMT as a managed service

@echo off
title PMT Display PRO - SIMPLE Build & Deploy

REM ========= CONFIG =========
set PROJECT_DIR=C:\Users\maste\Documents\PMT\Software\pmt_display_client_pro
set FLUTTER_CMD=C:\Users\maste\Documents\flutter\bin\flutter.bat
set ADB_DIR=C:\Users\maste\AppData\Local\Android\Sdk\platform-tools
set APP_ID=com.example.pmt_display_client_pro
set FIRE_IP=192.168.137.108
set APK_PATH=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk
REM ==========================

echo ===============================
echo  PMT DISPLAY PRO - SIMPLE TOOL
echo ===============================
echo Project: %PROJECT_DIR%
echo Fire TV: %FIRE_IP%
echo App ID:  %APP_ID%
echo APK:     %APK_PATH%
echo.

cd /d "%PROJECT_DIR%"

echo [1] flutter clean
call "%FLUTTER_CMD%" clean
echo [1] DONE
echo.

echo [2] flutter pub get
call "%FLUTTER_CMD%" pub get
IF %ERRORLEVEL% NEQ 0 (
    echo *** ERROR: flutter pub get failed
    pause
    exit /b 1
)
echo [2] DONE
echo.

echo [3] flutter build apk --release
call "%FLUTTER_CMD%" build apk --release
IF %ERRORLEVEL% NEQ 0 (
    echo *** ERROR: flutter build apk failed
    pause
    exit /b 1
)
echo [3] DONE
echo.

IF NOT EXIST "%APK_PATH%" (
    echo *** ERROR: APK not found:
    echo     %APK_PATH%
    pause
    exit /b 1
)

cd /d "%ADB_DIR%"

echo [4] adb connect %FIRE_IP%
.\adb connect %FIRE_IP%:5555
echo.
.\adb devices
echo [4] DONE
echo.

echo [5] adb uninstall %APP_ID%
.\adb uninstall %APP_ID%  >NUL 2>&1
echo [5] DONE
echo.

echo [6] adb install -r APK
.\adb install -r "%APK_PATH%"
IF %ERRORLEVEL% NEQ 0 (
    echo *** ERROR: adb install failed
    pause
    exit /b 1
)
echo [6] DONE
echo.

echo [7] Launching app...
.\adb shell monkey -p %APP_ID% -c android.intent.category.LAUNCHER 1
echo [7] DONE
echo.

echo ===============================
echo   PROCESS COMPLETED 💙
echo ===============================
pause

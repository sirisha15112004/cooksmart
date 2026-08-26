@echo off
title Launch CookSmart Web App
cd /d "%~dp0"
echo Cleaning lingering dart processes...
taskkill /F /IM dart.exe >nul 2>&1
echo Launching CookSmart on Chrome...
flutter run -d chrome
pause

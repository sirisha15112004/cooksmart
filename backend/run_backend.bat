@echo off
title CookSmart Backend Server
cd /d "%~dp0"
echo Starting CookSmart Backend on port 5000...
python app.py
pause

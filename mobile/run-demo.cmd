@echo off
rem Chay app voi backend that tren server demo DigitalOcean.
rem Them tham so flutter run phia sau, vi du: run-demo -d chrome
cd /d "%~dp0"
call flutter pub get || exit /b 1
call flutter run --dart-define-from-file=env/demo-server.json %*

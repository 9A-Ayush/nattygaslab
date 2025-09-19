@echo off
echo ========================================
echo  NattyGas Lab - Web Deployment Script
echo ========================================
echo.

echo Building Flutter web app...
flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter build failed!
    pause
    exit /b 1
)

echo ✅ Flutter build completed successfully!
echo.

echo Deploying to Firebase Hosting...
firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Firebase deployment failed!
    pause
    exit /b 1
)

echo.
echo ✅ Deployment completed successfully!
echo 🌐 Your app is now live at: https://nattygaslab.web.app
echo.
pause
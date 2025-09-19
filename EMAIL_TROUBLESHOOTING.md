# Email Service Troubleshooting Guide

## 🔍 Debugging Steps

### 1. **Test the Email Service**
I've added a **Test Email Service** option in the Users Management screen:

1. Open the app
2. Go to Users Management
3. Click the menu button (⋮) in the top right
4. Select "Test Email Service"
5. Enter a test email and name
6. Click "Test Email Service"

This will show you detailed debug information about what's happening.

### 2. **Common Issues & Solutions**

#### ❌ **API Not Reachable**
**Symptoms**: Connection timeout, network errors
**Solutions**:
- Check if Render service is running: https://nattygaslab-email-api.onrender.com/api/health
- Verify internet connection on device
- Check if device allows HTTP requests (for debug mode)

#### ❌ **SMTP Configuration Issues**
**Symptoms**: API responds but email not sent
**Solutions**:
- Verify Gmail app password is correct
- Check if 2FA is enabled on Gmail account
- Ensure "Less secure app access" is configured properly

#### ❌ **Email Goes to Spam**
**Symptoms**: Email sent successfully but not received
**Solutions**:
- Check spam/junk folder
- Add sender email to contacts
- Verify SPF/DKIM records (for production)

#### ❌ **Debug vs Release Mode Issues**
**Symptoms**: Works in debug but not in release
**Solutions**:
- Check network security config
- Verify HTTPS certificates
- Test with debug APK first

### 3. **Manual API Testing**

You can test the API directly using PowerShell:

```powershell
# Test API health
Invoke-WebRequest -Uri "https://nattygaslab-email-api.onrender.com/api/health" -Method GET

# Test email sending
$body = @{
    to = "your-email@example.com"
    subject = "Test Welcome Email"
    type = "welcome"
    userData = @{
        userName = "Test User"
        email = "your-email@example.com"
        password = "temp123"
        role = "user"
    }
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://nattygaslab-email-api.onrender.com/api/send-email" -Method POST -Body $body -ContentType "application/json"
```

### 4. **Check Render Logs**

1. Go to your Render dashboard
2. Select your email service
3. Check the "Logs" tab for any errors
4. Look for email sending attempts and SMTP errors

### 5. **Environment Variables Check**

Ensure these are set correctly in your Render service:

```env
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_SECURE=false
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
NODE_ENV=production
BASE_URL=https://nattygaslab-email-api.onrender.com
```

### 6. **Debug Output**

When creating users, check the Flutter debug console for messages like:

```
✅ Welcome email sent successfully to user@example.com
❌ Failed to send welcome email: [error details]
```

## 🚀 Quick Fixes

### Fix 1: Restart Render Service
Sometimes the service needs a restart:
1. Go to Render dashboard
2. Select your service
3. Click "Manual Deploy" or restart

### Fix 2: Update Gmail App Password
1. Go to Google Account settings
2. Security → 2-Step Verification → App passwords
3. Generate new password
4. Update in Render environment variables

### Fix 3: Test with Debug APK
Use the debug APK (`app-debug.apk`) which has more detailed logging:
```bash
flutter build apk --debug
```

## 📧 Test Email Addresses

For testing, use these email addresses:
- Your personal email
- A test Gmail account
- Temporary email services (for initial testing)

## 🔧 Advanced Debugging

If the basic tests don't work, check:

1. **Network connectivity** from the app
2. **CORS settings** in the backend
3. **SSL/TLS certificates** for HTTPS
4. **Firewall rules** blocking outbound requests
5. **Device security policies** preventing network access

---

**Need more help?** Check the debug output from the "Test Email Service" feature in the app!
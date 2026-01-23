# Google Sign-In Debugging Guide

## What I've Done For You

✅ **Added comprehensive debug logging** to `sign_in_screen.dart`:
- Debug function prints Google Sign-In configuration on app startup
- Enhanced error messages with specific web platform guidance
- Prints troubleshooting steps directly to console if errors occur

✅ **Created a template in web/index.html** with placeholder for Client ID:
```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com">
```

✅ **Created this debugging guide** with step-by-step instructions

## How to Debug Now

### Step 1: Check Console Output

When you run the app and navigate to the Sign-In screen, open the console:
- **On Web**: Press `F12` → Go to Console tab
- **On Android**: Use Android Studio logcat or `flutter logs`

You should see:
```
=== Google Sign-In Configuration Debug ===
Platform: TargetPlatform.android (or TargetPlatform.windows, TargetPlatform.web)
Is Web: false (or true if on web)
Google Sign-In Scopes: [email, profile]
Google Sign-In initialized: true
=========================================
```

### Step 2: Get Your Web Client ID

Follow these exact steps:

1. **Open Firebase Console**: https://console.firebase.google.com/
2. **Select Project**: `mandaue-foam-ar-1`
3. **Click Settings ⚙️** (top-left area)
4. **Click "Project Settings"**
5. **Look for "Your Apps"** section
6. **Find "Google Cloud Console"** button or link
7. **It will open Google Cloud Console** - click **APIs & Services** in left sidebar
8. **Click "Credentials"**
9. **Look for "OAuth 2.0 Client IDs"** section
10. **Find the entry with Type = "Web application"**
11. **Copy the Client ID** - it looks like:
    ```
    245668040106-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.apps.googleusercontent.com
    ```

### Step 3: Update web/index.html

Once you have the Client ID:

1. **Open** `web/index.html`
2. **Find the line** with `google-signin-client_id`
3. **Replace** `YOUR_WEB_CLIENT_ID_HERE` with your actual Client ID
4. **Save the file**

**Before:**
```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com">
```

**After:**
```html
<meta name="google-signin-client_id" content="245668040106-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.apps.googleusercontent.com">
```

### Step 4: Test the App

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on web
flutter run -d web

# OR run on Android
flutter run -d android
```

## Error Messages and Solutions

### Error: "ClientID not set"

**Cause**: The `<meta name="google-signin-client_id">` tag is missing or has wrong value

**Solution**: 
1. Verify web/index.html has the correct Client ID
2. Check that Client ID format is: `XXXXX.apps.googleusercontent.com`
3. Copy-paste directly from Google Cloud Console to avoid typos

### Error: "One or more client IDs not registered"

**Cause**: The Client ID is not properly registered in Google Cloud

**Solution**:
1. Go to Google Cloud Console → APIs & Services → Credentials
2. Make sure OAuth 2.0 consent screen is configured
3. Verify the Web Client ID exists
4. If not, create a new one

### Error: "origin_mismatch"

**Cause**: Your app's origin is not registered in Google Cloud

**Solution**:
1. Go to Google Cloud Console → APIs & Services → Credentials
2. Click on the Web Client ID
3. Under "Authorized JavaScript origins" add:
   - `http://localhost:7357` (for local testing)
   - `http://localhost:8080` (alternative port)
   - `https://yourdomain.com` (for production)
4. Click Save

### Error: "Plugin not found" on Android

**Cause**: Plugin not properly installed

**Solution**:
```bash
flutter clean
flutter pub get
flutter pub upgrade google_sign_in_android
```

## Verification Checklist

- [ ] Downloaded Flutter packages: `flutter pub get`
- [ ] google_sign_in package installed: `flutter pub list | grep google_sign_in`
- [ ] google-services.json present in `android/app/google-services.json`
- [ ] web/index.html has `<meta name="google-signin-client_id">` tag with valid Client ID
- [ ] Client ID format is `XXXXX.apps.googleusercontent.com`
- [ ] Firebase project is "mandaue-foam-ar-1"
- [ ] Used Google Cloud Console (not Firebase Console) to get Client ID
- [ ] For Android: Added SHA-1 fingerprint to Firebase Console

## Testing on Different Platforms

### Web Platform (http://localhost:7357)

1. Run: `flutter run -d web`
2. Click "Continue with Google"
3. Should see Google Sign-In popup
4. Check browser console (F12) for any errors

### Android Platform

1. Run: `flutter run -d android`
2. Click "Continue with Google"
3. Should see Android Google Sign-In dialog
4. Check Flutter logs: `flutter logs`

## If Still Having Issues

Check these files in order:

1. **web/index.html** - Does it have the Client ID meta tag?
2. **Console output** - Does it show "Is Web: true"?
3. **Browser console (F12)** - Are there JavaScript errors?
4. **Google Cloud Console** - Is the Web Client ID created?
5. **Google Cloud Credentials** - Is "http://localhost:7357" authorized?

## My Configuration for Reference

Your Firebase Project:
- **Project ID**: mandaue-foam-ar-1
- **Project Number**: 245668040106
- **Android Package**: com.example.ar_3d_viewer

Code Changes I Made:
- ✅ Added `import 'package:flutter/foundation.dart';` for kIsWeb detection
- ✅ Added `_debugPrintGoogleSignInConfig()` method to print config on startup
- ✅ Enhanced error catching with specific web platform debugging
- ✅ Added placeholder meta tag to web/index.html with instructions
- ✅ Error messages now suggest specific fixes for common issues

## Quick Copy-Paste Template

Once you have your Client ID from Google Cloud Console, use this:

```html
<meta name="google-signin-client_id" content="PUT_YOUR_CLIENT_ID_HERE.apps.googleusercontent.com">
```

Replace `PUT_YOUR_CLIENT_ID_HERE` with the actual ID (e.g., `245668040106-abc123xyz...`)

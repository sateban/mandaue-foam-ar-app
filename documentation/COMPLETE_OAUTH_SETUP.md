# Complete Android + Web Google Sign-In Configuration

## Current Status

### ✅ Fixed
- `google-services.json` - Added OAuth client structure (needs your Client ID)
- `AndroidManifest.xml` - Added `android:debuggable="true"`
- `web/index.html` - Has OAuth meta tag placeholder (needs your Web Client ID)
- `sign_in_screen.dart` - Debug logging ready

### ⏭️ You Need To Do

#### For Android
1. Get Android OAuth Client ID from Google Cloud Console
2. Update `android/app/google-services.json` with the Client ID

#### For Web
1. Get Web OAuth Client ID from Google Cloud Console
2. Update `web/index.html` with the Client ID

---

## Android Setup (Error 10 - Sign-In Failed)

### Why Error 10 Happens
The `google-services.json` has an empty `oauth_client` array. Google's OAuth validation fails because the Client ID isn't registered with your app's credentials.

### How to Fix

**Step 1: Get Android Client ID**
```
1. Go to: https://console.cloud.google.com/
2. Select: mandaue-foam-ar-1
3. APIs & Services → Credentials
4. Find: Android OAuth 2.0 Client ID
5. Copy: The Client ID
```

**Step 2: Update google-services.json**
```json
"oauth_client": [
  {
    "client_id": "245668040106-YOUR_ID_HERE.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.example.ar_3d_viewer",
      "certificate_hash": "e598f1d260fde4f895d67e0d3b453de9f38f2ab5c"
    }
  }
]
```

**Step 3: Rebuild**
```bash
flutter clean
flutter pub get
flutter run -d android
```

### Your Android Config
- Package: `com.example.ar_3d_viewer`
- SHA-1: `E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C`
- Certificate Hash: `e598f1d260fde4f895d67e0d3b453de9f38f2ab5c`

---

## Web Setup

### Why It Needs Configuration
Web platform requires OAuth Client ID in a meta tag in `web/index.html` for Google Sign-In to work.

### How to Fix

**Step 1: Get Web Client ID**
```
1. Go to: https://console.cloud.google.com/
2. Select: mandaue-foam-ar-1
3. APIs & Services → Credentials
4. Find: Web OAuth 2.0 Client ID
5. Copy: The Client ID
```

**Step 2: Update web/index.html**
```html
<meta name="google-signin-client_id" content="245668040106-YOUR_ID_HERE.apps.googleusercontent.com">
```

**Step 3: Test**
```bash
flutter clean
flutter pub get
flutter run -d web
```

---

## Files Modified Summary

### ✅ Already Done

**File: `android/app/google-services.json`**
```json
"oauth_client": [
  {
    "client_id": "245668040106-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.example.ar_3d_viewer",
      "certificate_hash": "e598f1d260fde4f895d67e0d3b453de9f38f2ab5c"
    }
  }
]
```

**File: `android/app/src/main/AndroidManifest.xml`**
```xml
<application
    android:label="ar_3d_viewer"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:debuggable="true"
    android:usesCleartextTraffic="true">
```

### ⏭️ You Need To Update

**File: `android/app/google-services.json`**
- Replace: `245668040106-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- With: Your actual Android Client ID

**File: `web/index.html`**
- Replace: `YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com`
- With: Your actual Web Client ID

---

## Getting Client IDs from Google Cloud Console

### Finding the Console
1. Go to: https://console.firebase.google.com/
2. Select: mandaue-foam-ar-1
3. Click: ⚙️ Settings
4. Click: "Google Cloud Console" or go directly to: https://console.cloud.google.com/

### Finding Credentials
1. In Google Cloud Console, left sidebar: **APIs & Services**
2. Click: **Credentials**
3. Look for: **OAuth 2.0 Client IDs**

### Two Types You Need

**Type 1: Android**
- Platform: Android
- Package: com.example.ar_3d_viewer
- SHA-1: E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C
- Copy: Client ID

**Type 2: Web application**
- Platform: Web
- Authorized origins: http://localhost:7357
- Copy: Client ID

---

## Quick Reference

### Android Client ID
Location in google-services.json:
```json
"client": [
  {
    ...
    "oauth_client": [
      {
        "client_id": "← PUT ANDROID CLIENT ID HERE"
      }
    ]
  }
]
```

### Web Client ID
Location in web/index.html:
```html
<meta name="google-signin-client_id" content="← PUT WEB CLIENT ID HERE">
```

---

## Testing Checklist

### After Updating Android Config
- [ ] Run `flutter clean && flutter pub get`
- [ ] Run `flutter run -d android`
- [ ] Click "Continue with Google"
- [ ] Android Google Sign-In dialog appears
- [ ] Can authenticate successfully
- [ ] No "Error 10" message

### After Updating Web Config
- [ ] Run `flutter clean && flutter pub get`
- [ ] Run `flutter run -d web`
- [ ] Browser opens at http://localhost:7357
- [ ] Open console (F12)
- [ ] See configuration debug output
- [ ] Click "Continue with Google"
- [ ] Google Sign-In popup appears
- [ ] Can authenticate successfully

---

## Your Project Information

```
Firebase Project: mandaue-foam-ar-1
Project Number: 245668040106
Android Package: com.example.ar_3d_viewer
Android SHA-1: E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C
Database URL: https://mandaue-foam-ar-1-default-rtdb.firebaseio.com
```

---

## Documentation Files

- **ANDROID_QUICK_FIX.md** - Quick steps for Android error
- **ANDROID_OAUTH_FIX.md** - Detailed Android setup
- **QUICK_START_OAUTH.md** - Original web setup
- **WEB_OAUTH_SETUP.md** - Detailed web setup

---

## Next Steps

1. ✅ Read this guide
2. ⏭️ Get Android Client ID from Google Cloud Console
3. ⏭️ Update android/app/google-services.json
4. ⏭️ Get Web Client ID from Google Cloud Console  
5. ⏭️ Update web/index.html
6. ⏭️ Rebuild and test both platforms

Estimated time: 20-30 minutes

---

## Still Having Issues?

**Android Error 10**: Check that Client ID in google-services.json is not the placeholder
**Web Auth Failed**: Check that Client ID in web/index.html is present and correct
**Still errors**: See DEBUG_GOOGLE_SIGNIN.md

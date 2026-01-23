# Android Google Sign-In Configuration Fix

## Error You're Seeing
```
platformexception(sign_in_failed, com.google.android.gms.common.api.k: 10: null, null)
```

**Error Code 10 = OAuth Client ID Configuration Issue**

## Root Cause

The `google-services.json` has an **empty `oauth_client` array**. Google's OAuth validation fails because:
1. Package name: `com.example.ar_3d_viewer`
2. SHA-1 fingerprint: Must match exactly
3. OAuth Client ID: Must be registered with these credentials

## Solution

### Step 1: Get Your Android OAuth Client ID from Google Cloud Console

1. Go to: https://console.cloud.google.com/
2. Select Project: `mandaue-foam-ar-1`
3. Navigate: **APIs & Services** → **Credentials**
4. Look for: **OAuth 2.0 Client IDs** section
5. Find: Entry with `Type = "Android"` and `Package = "com.example.ar_3d_viewer"`
6. It should show:
   - **Client ID**: `245668040106-[random].apps.googleusercontent.com`
   - **Package Name**: `com.example.ar_3d_viewer`
   - **SHA-1**: `E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C`

### Step 2: Copy the Client ID

Your Android OAuth Client ID should look like:
```
245668040106-a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6.apps.googleusercontent.com
```

### Step 3: Update google-services.json

1. Open: `android/app/google-services.json`
2. Find the `oauth_client` array (currently empty: `[]`)
3. Replace it with:

```json
"oauth_client": [
  {
    "client_id": "YOUR_ANDROID_CLIENT_ID_HERE.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.example.ar_3d_viewer",
      "certificate_hash": "e598f1d260fde4f895d67e0d3b453de9f38f2ab5c"
    }
  }
]
```

**Replace `YOUR_ANDROID_CLIENT_ID_HERE` with your actual Client ID**

### Step 4: If Android Client ID Doesn't Exist in Google Cloud

Create one:

1. In Google Cloud Console → Credentials
2. Click: **+ Create Credentials**
3. Choose: **OAuth client ID**
4. Select: **Android**
5. Fill in:
   - **Package name**: `com.example.ar_3d_viewer`
   - **SHA-1 certificate fingerprint**: `E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C`
6. Click: **Create**
7. Copy the generated Client ID
8. Update `android/app/google-services.json` with it

### Step 5: Rebuild and Test

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Rebuild APK
flutter build apk --release

# Or run directly on device
flutter run -d android
```

## Your Configuration

```
Project: mandaue-foam-ar-1
Package: com.example.ar_3d_viewer
SHA-1: E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C
```

## Current State of Files

### ✅ Already Updated:
1. **AndroidManifest.xml** - Added `android:debuggable="true"`
2. **google-services.json** - Added oauth_client placeholder

### ⏭️ You Need To Do:
1. Get Android Client ID from Google Cloud Console
2. Update `google-services.json` with the actual Client ID
3. Rebuild the app

## What Changed

### Before:
```json
"oauth_client": []
```

### After (with your Client ID):
```json
"oauth_client": [
  {
    "client_id": "YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.example.ar_3d_viewer",
      "certificate_hash": "e598f1d260fde4f895d67e0d3b453de9f38f2ab5c"
    }
  }
]
```

## Verification Steps

1. Check google-services.json has your Client ID
2. Run: `flutter clean && flutter pub get`
3. Run: `flutter run -d android`
4. Click "Continue with Google"
5. Google Sign-In dialog should appear
6. No "10" error

## If Still Having Issues

**Check**:
- [ ] Client ID is from Google Cloud Console (not Firebase Console)
- [ ] SHA-1 matches exactly: `E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C`
- [ ] Package name matches: `com.example.ar_3d_viewer`
- [ ] Client ID format: `XXXXX.apps.googleusercontent.com`
- [ ] AndroidManifest.xml has `android:debuggable="true"`
- [ ] `flutter clean` was run
- [ ] App was rebuilt

## Error Codes Reference

| Code | Meaning | Fix |
|------|---------|-----|
| 10 | Invalid client ID | Get correct OAuth Client ID from Google Cloud |
| 12501 | User cancelled sign-in | Normal - user clicked cancel |
| 12502 | No internet connection | Check network |
| 12500 | Internal error | Rebuild app after updating config |

## Files Modified

1. ✅ `android/app/google-services.json` - Added oauth_client structure
2. ✅ `android/app/src/main/AndroidManifest.xml` - Added android:debuggable="true"

## Next Steps

1. Get Android Client ID from Google Cloud Console
2. Update the Client ID in google-services.json
3. Run `flutter clean && flutter pub get`
4. Run `flutter run -d android` to test
5. Google Sign-In should now work!

# 🔧 Android Sign-In Error 10 - Quick Fix

## The Problem
```
Error: platformexception(sign_in_failed, com.google.android.gms.common.api.k: 10)
```

**Error 10 = Android OAuth Client ID not properly configured**

## The Solution (3 Steps - 5 Minutes)

### Step 1: Get Android Client ID

Go to: https://console.cloud.google.com/
1. Select Project: **mandaue-foam-ar-1**
2. Left Sidebar: **APIs & Services** → **Credentials**
3. Find: **Android OAuth 2.0 Client ID**
4. Copy: The Client ID (looks like: `245668040106-abc123xyz.apps.googleusercontent.com`)

**If not found**: Create it
- Click: **+ Create Credentials**
- Choose: **OAuth client ID** → **Android**
- Package: `com.example.ar_3d_viewer`
- SHA-1: `E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C`
- Click: **Create**
- Copy: The generated Client ID

### Step 2: Update android/app/google-services.json

1. Open: `android/app/google-services.json`
2. Find line with: `"oauth_client": [`
3. Replace `245668040106-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` with your actual Client ID
4. Save

**Example**:
```json
"oauth_client": [
  {
    "client_id": "245668040106-abc123def456xyz789.apps.googleusercontent.com",
    "client_type": 1,
    "android_info": {
      "package_name": "com.example.ar_3d_viewer",
      "certificate_hash": "e598f1d260fde4f895d67e0d3b453de9f38f2ab5c"
    }
  }
]
```

### Step 3: Rebuild & Test

```bash
flutter clean
flutter pub get
flutter run -d android
```

Click "Continue with Google" → Should work now! ✅

---

## What I Already Fixed

✅ **google-services.json** - Added oauth_client structure
✅ **AndroidManifest.xml** - Added `android:debuggable="true"`

## What You Need to Do

⏭️ **Replace placeholder Client ID with your actual one from Google Cloud Console**

---

## Reference Info

Your App:
- Package: `com.example.ar_3d_viewer`
- SHA-1: `E5:98:F1:D2:60:FD:E4:F8:95:D6:7E:0D:3B:45:31:E9:38:F2:AB:5C`
- Project: `mandaue-foam-ar-1`
- Number: `245668040106`

Your Certificate Hash (lowercase, no colons):
- `e598f1d260fde4f895d67e0d3b453de9f38f2ab5c`

---

## ⚡ TL;DR

1. Go to Google Cloud Console → Credentials
2. Find/Create Android OAuth Client ID
3. Copy it
4. Replace in `android/app/google-services.json`
5. Run `flutter clean && flutter run -d android`
6. Done! ✅

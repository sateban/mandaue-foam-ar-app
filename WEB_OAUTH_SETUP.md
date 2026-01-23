# Google Sign-In Web Platform Configuration Guide

## Current Issue
The web platform is throwing an error:
```
Assertion failed: 
'ClientID not set. Either set it on a <meta name="google-signin-client_id" content="CLIENT_ID" /> tag, 
or pass clientId when initializing GoogleSignIn'
```

## Why This Happens
Your Firebase project has Android configuration in `google-services.json`, but the web platform needs separate OAuth credentials from Google Cloud Console.

## Solution Steps

### Step 1: Get Your Web Client ID from Firebase Console

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select Project**: `mandaue-foam-ar-1`
3. **Navigate to Google Cloud Console**:
   - Click the **Settings ⚙️** icon (top-left corner)
   - Click **Project Settings**
   - Click the **"Google Cloud Console"** link (it's a button in the main area)
   
4. **In Google Cloud Console**:
   - Go to **APIs & Services** → **Credentials** (left sidebar)
   - Look for **OAuth 2.0 Client IDs**
   - Find the one with type **"Web application"**
   - If it doesn't exist, you may need to create one:
     - Click **+ Create Credentials** → **OAuth client ID**
     - Choose **Web application**
     - Add `http://localhost:7357` to **Authorized JavaScript origins** (for local testing)
     - Add `https://yourdomain.com` if you have a production domain
     - Click Create
   
5. **Copy the Client ID** - It looks like:
   ```
   1234567890-abcdefghijk.apps.googleusercontent.com
   ```

### Step 2: Add Client ID to web/index.html

Once you have the Client ID, open `web/index.html` and add this meta tag in the `<head>` section:

```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com" />
```

**Example**: If your Client ID is `245668040106-a1b2c3d4e5f6g7h8i9j0k.apps.googleusercontent.com`, add:

```html
<meta name="google-signin-client_id" content="245668040106-a1b2c3d4e5f6g7h8i9j0k.apps.googleusercontent.com" />
```

### Step 3: Update Android Configuration (Optional but Recommended)

For Android to work properly, also add the **SHA-1 fingerprint**:

1. **Get your debug SHA-1**:
   ```bash
   cd android
   .\gradlew signingReport
   ```

2. **In Firebase Console**:
   - Go to **Project Settings** → **Your Apps** → Select Android app
   - Scroll to **SHA certificate fingerprints**
   - Click **Add fingerprint**
   - Paste the SHA-1 value from the signing report

### Step 4: Test

1. **Restart the app**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test on web**: Click "Continue with Google" - you should see the Google Sign-In popup
3. **Test on Android**: Click "Continue with Google" - you should see the Android Google Sign-In dialog

## Troubleshooting

| Error | Solution |
|-------|----------|
| `ClientID not set` | Add the meta tag to `web/index.html` with correct Client ID |
| `One or more client IDs not registered` | Make sure Client ID is registered for "Web application" in Google Cloud |
| `origin_mismatch` | Add `http://localhost:7357` to Authorized JavaScript origins in Google Cloud Console |
| `MissingPluginException` on Android | Make sure google-services.json is in `android/app/` |

## File Locations to Update

1. ✅ `web/index.html` - Add meta tag (REQUIRED for web)
2. ⚠️ `android/app/google-services.json` - Already present, Firebase will update automatically
3. ✅ `lib/screens/auth/sign_in_screen.dart` - Already configured (no changes needed)

## Quick Reference: Your Firebase Project

- **Project ID**: mandaue-foam-ar-1
- **Project Number**: 245668040106
- **Android Package**: com.example.ar_3d_viewer
- **API Key**: AIzaSyCXZTOX70xysOb3Cz_zlpSzFc-CiHenUPA

## Still Having Issues?

1. Check that google-signin plugin is installed: `flutter pub list | grep google_sign_in`
2. Clear Flutter cache: `flutter clean && flutter pub get`
3. Check browser console (F12) for detailed error messages on web
4. Verify internet connection for OAuth server communication

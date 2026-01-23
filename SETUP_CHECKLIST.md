# Google Sign-In Setup Checklist

Use this checklist to track your progress through the Google Sign-In web configuration.

## Phase 1: Preparation ✅ (Already Done for You)

- [x] Added debug import: `import 'package:flutter/foundation.dart';`
- [x] Created debug function: `_debugPrintGoogleSignInConfig()`
- [x] Enhanced error handling with web-specific debugging
- [x] Added google-signin-client_id meta tag template to web/index.html
- [x] Created comprehensive documentation files

## Phase 2: Get Web Client ID (⬜ You Need to Do This)

### Step 1: Navigate to Google Cloud Console
- [ ] Open: https://console.firebase.google.com/
- [ ] Select project: **mandaue-foam-ar-1**
- [ ] Click ⚙️ **Settings** (gear icon, top-left)
- [ ] Click **Project Settings**

### Step 2: Open Google Cloud Console
- [ ] Look for **"Google Cloud Console"** button or link
- [ ] Click it to open Google Cloud Console
- [ ] You should now be in Google Cloud console

### Step 3: Find Web Client ID
- [ ] Left sidebar: Click **APIs & Services**
- [ ] Click **Credentials**
- [ ] Look for **OAuth 2.0 Client IDs** section
- [ ] Find entry with **Type = "Web application"**

### Step 4: Copy Client ID
- [ ] You should see a Client ID that looks like:
  ```
  245668040106-a1b2c3d4e5f6g7h8i9j0k.apps.googleusercontent.com
  ```
- [ ] **Copy this entire value** (Ctrl+C)
- [ ] Save it somewhere safe (notepad, etc.)

### If Web Client ID Doesn't Exist
- [ ] Click **+ Create Credentials**
- [ ] Choose **OAuth client ID**
- [ ] Select **Web application**
- [ ] Add to **Authorized JavaScript origins**:
  - [ ] `http://localhost:7357`
  - [ ] `http://localhost:8080`
  - [ ] `https://yourdomain.com` (if you have production domain)
- [ ] Click **Create**
- [ ] Copy the newly created Client ID

## Phase 3: Update web/index.html (⬜ You Need to Do This)

### Step 1: Open the File
- [ ] Open `web/index.html` in VS Code
- [ ] Find the line: `<meta name="google-signin-client_id"`

### Step 2: Update the Content
- [ ] You'll see:
  ```html
  <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com">
  ```
- [ ] Replace `YOUR_WEB_CLIENT_ID_HERE` with your copied Client ID
- [ ] Example after update:
  ```html
  <meta name="google-signin-client_id" content="245668040106-a1b2c3d4e5f6g7h8i9j0k.apps.googleusercontent.com">
  ```
- [ ] **Save the file** (Ctrl+S)

### Verification
- [ ] Client ID starts with number (e.g., `245668040106`)
- [ ] Client ID ends with `.apps.googleusercontent.com`
- [ ] No `YOUR_WEB_CLIENT_ID_HERE` text remains
- [ ] File is saved

## Phase 4: Test Configuration (⬜ You Need to Do This)

### Clean and Build
- [ ] Open Terminal in VS Code (Ctrl+`)
- [ ] Run: `flutter clean`
- [ ] Wait for completion
- [ ] Run: `flutter pub get`
- [ ] Wait for completion

### Start the App
- [ ] Run: `flutter run -d web`
- [ ] Wait for app to load in browser
- [ ] Browser should open at `http://localhost:7357`

### Check Debug Output
- [ ] Open Browser Console (Press **F12**)
- [ ] Go to **Console** tab
- [ ] You should see:
  ```
  === Google Sign-In Configuration Debug ===
  Platform: TargetPlatform.web
  Is Web: true
  Google Sign-In Scopes: [email, profile]
  Google Sign-In initialized: true
  ⚠️  WEB PLATFORM DETECTED
  Make sure your web/index.html contains:
  <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com" />
  =========================================
  ```
- [ ] Debug output confirms configuration is correct

## Phase 5: Test Google Sign-In (⬜ You Need to Do This)

### Test Button Click
- [ ] Look for "Continue with Google" button on login screen
- [ ] Click the button
- [ ] A Google Sign-In popup should appear
- [ ] Do **NOT** see error about "ClientID not set"

### Complete Authentication
- [ ] In popup, enter your Google account email
- [ ] Enter password
- [ ] Click Sign In
- [ ] Grant permissions if prompted

### Verify Success
- [ ] After successful sign-in, app should navigate to home screen
- [ ] Browser console should NOT show any errors
- [ ] You should be logged in

## Phase 6: Test on Android (⬜ Optional but Recommended)

### Get SHA-1 Fingerprint
- [ ] Open Terminal
- [ ] Run: `cd android`
- [ ] Run: `.\gradlew signingReport`
- [ ] Look for line with `SHA-1:` value
- [ ] Copy the SHA-1 value

### Add to Firebase
- [ ] Go to Firebase Console: https://console.firebase.google.com/
- [ ] Select project: mandaue-foam-ar-1
- [ ] Go to Project Settings → Your Apps
- [ ] Click Android app
- [ ] Scroll to **SHA certificate fingerprints**
- [ ] Click **Add fingerprint**
- [ ] Paste the SHA-1 value
- [ ] Click **Save**

### Test on Android
- [ ] Run: `flutter run -d android`
- [ ] Click "Continue with Google"
- [ ] Android Sign-In dialog should appear
- [ ] Complete authentication
- [ ] Should navigate to home screen

## Troubleshooting: If Something Goes Wrong

### Error: "ClientID not set"
- [ ] Check web/index.html has correct Client ID
- [ ] Verify format: `XXXXX.apps.googleusercontent.com`
- [ ] Make sure you replaced `YOUR_WEB_CLIENT_ID_HERE`
- [ ] No typos in Client ID
- [ ] Restart browser (Ctrl+Shift+R for hard refresh)

### Error: "One or more client IDs not registered"
- [ ] Go to Google Cloud Console
- [ ] Check that Web Client ID exists
- [ ] Verify Client ID in web/index.html matches exactly
- [ ] Try creating new Web Client ID if one doesn't exist

### Error: "origin_mismatch"
- [ ] Go to Google Cloud Console → Credentials
- [ ] Click on Web Client ID
- [ ] Under **Authorized JavaScript origins**, add:
  - `http://localhost:7357`
  - `http://localhost:8080`
- [ ] Click Save
- [ ] Restart browser

### Error: "Plugin not found" on Android
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter pub upgrade google_sign_in_android`
- [ ] Run: `flutter run -d android` again

### App compiles but Google Sign-In doesn't work
- [ ] Check browser console (F12) for JavaScript errors
- [ ] Make sure internet connection is working
- [ ] Try in incognito/private browsing mode
- [ ] Clear browser cache (Shift+Delete in browser console)

## Documentation Files Reference

| File | Purpose |
|------|---------|
| `QUICK_START_OAUTH.md` | Quick 4-step guide |
| `WEB_OAUTH_SETUP.md` | Complete setup guide |
| `DEBUG_GOOGLE_SIGNIN.md` | Detailed debugging |
| `GOOGLE_SIGNIN_DEBUG_SUMMARY.md` | Implementation details |
| `VISUAL_DEBUG_FLOW.md` | Visual flow diagrams |
| `SETUP_CHECKLIST.md` | This file |

## Quick Reference: Your Project Details

```
Firebase Project: mandaue-foam-ar-1
Project Number: 245668040106
Android Package: com.example.ar_3d_viewer
Database URL: https://mandaue-foam-ar-1-default-rtdb.firebaseio.com
```

## Success Criteria

✅ All items in Phase 1: Preparation - COMPLETE
✅ All items in Phase 2: Get Web Client ID - COMPLETE
✅ All items in Phase 3: Update web/index.html - COMPLETE
✅ All items in Phase 4: Test Configuration - COMPLETE
✅ All items in Phase 5: Test Google Sign-In - COMPLETE
✅ (Optional) All items in Phase 6: Test on Android - COMPLETE

= **Google Sign-In is working on all platforms!**

## Estimated Time Required

- Getting Client ID: 5-10 minutes
- Updating web/index.html: 2-3 minutes
- Testing: 5-10 minutes
- **Total: 15-25 minutes**

## Need Help?

1. Check the browser console (F12) - usually has helpful error messages
2. Check `DEBUG_GOOGLE_SIGNIN.md` - has solutions for common errors
3. Check `VISUAL_DEBUG_FLOW.md` - visual diagrams of the process
4. Verify Client ID format: `XXXXX.apps.googleusercontent.com`
5. Make sure file is saved after editing web/index.html

---

**Last Updated**: When setup code was added to your project
**Next Steps**: Follow the checklist starting from Phase 2!

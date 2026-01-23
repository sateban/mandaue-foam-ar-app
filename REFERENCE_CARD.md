# Reference Card: Google Sign-In Web Configuration

## The Error You're Getting
```
Assertion Error: ClientID not set
```

## The Fix (3 Steps)

### Step 1: Get Client ID
```
1. https://console.firebase.google.com/
2. Select: mandaue-foam-ar-1
3. Settings ⚙️ → Google Cloud Console
4. APIs & Services → Credentials
5. Find Web application Client ID
6. Copy it (format: XXXXX.apps.googleusercontent.com)
```

### Step 2: Update web/index.html
```
Find: <meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID_HERE...
Replace: YOUR_WEB_CLIENT_ID_HERE
With: Your copied Client ID
Save file
```

### Step 3: Test
```bash
flutter clean
flutter pub get
flutter run -d web
```

## Expected Output

### In Browser Console (F12)
```
=== Google Sign-In Configuration Debug ===
Platform: TargetPlatform.web
Is Web: true
Google Sign-In Scopes: [email, profile]
Google Sign-In initialized: true
⚠️  WEB PLATFORM DETECTED
=========================================
```

### After Clicking "Continue with Google"
- ✅ Google Sign-In popup appears
- ✅ Enter credentials
- ✅ Authenticated & navigated to home

## If You See Error

| Error | Fix |
|-------|-----|
| ClientID not set | Check web/index.html has Client ID |
| origin_mismatch | Add `http://localhost:7357` to Google Cloud Console |
| Plugin not found | Run `flutter clean && flutter pub get` |

## File Locations

- **To edit**: `web/index.html` (line ~32)
- **To check**: `lib/screens/auth/sign_in_screen.dart` (has debug code)
- **To read**: 
  - `QUICK_START_OAUTH.md` (fast)
  - `SETUP_CHECKLIST.md` (detailed)
  - `DEBUG_GOOGLE_SIGNIN.md` (troubleshooting)

## Your Project Details

```
Firebase: mandaue-foam-ar-1
Number: 245668040106
Android: com.example.ar_3d_viewer
URL: mandaue-foam-ar-1-default-rtdb.firebaseio.com
```

## Client ID Format
```
✅ Correct:   245668040106-abc123xyz.apps.googleusercontent.com
❌ Wrong:     YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com
❌ Wrong:     abc123xyz.apps.googleusercontent.com (missing number prefix)
```

## Commands to Know
```bash
# Test on web
flutter run -d web

# Clean project
flutter clean

# Get dependencies
flutter pub get

# Check errors
flutter analyze
```

## Browser Console (F12)
- **To open**: Press `F12`
- **Go to**: Console tab
- **Look for**: Debug output or error messages
- **Clear cache**: Ctrl+Shift+Delete

## Success Criteria
- [ ] Browser shows configuration debug output
- [ ] Click "Continue with Google" - popup appears
- [ ] Can sign in with Google account
- [ ] Redirected to home screen
- [ ] No errors in console

## Time Breakdown
- Getting Client ID: 5 min
- Updating web/index.html: 1 min
- Running flutter clean: 2 min
- Testing: 5 min
- **Total: ~15 minutes**

## Need More Help?
- Fast: Read `QUICK_START_OAUTH.md`
- Detailed: Read `SETUP_CHECKLIST.md`
- Troubleshooting: Read `DEBUG_GOOGLE_SIGNIN.md`
- Visual: Read `VISUAL_DEBUG_FLOW.md`

---

**Print this card and keep it handy while configuring Google Sign-In!**

Key takeaway: You need your Web Client ID in web/index.html for Google Sign-In to work on web platform.

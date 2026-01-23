# Visual Debugging Flow

## Current Error Flow (What Happens Now)

```
User clicks "Continue with Google"
         ↓
GoogleSignIn.signIn() is called
         ↓
(Web Platform) Checks for Client ID
         ↓
Client ID NOT found in web/index.html
         ↓
🔴 ASSERTION ERROR: "ClientID not set"
         ↓
Console prints troubleshooting steps
         ↓
SnackBar shows helpful error message
```

## Fixed Flow (What Should Happen)

```
User starts app
         ↓
initState() runs → _debugPrintGoogleSignInConfig()
         ↓
Console prints: "=== Google Sign-In Configuration Debug ==="
Console prints: Platform & configuration details
         ↓
User clicks "Continue with Google"
         ↓
GoogleSignIn.signIn() checks for Client ID in web/index.html
         ↓
✅ Client ID FOUND
         ↓
Google Sign-In popup appears
         ↓
User authenticates with Google
         ↓
Firebase credential created
         ↓
✅ Sign in successful
         ↓
Navigate to home screen
```

## What You Need to Do

```
1. GET CLIENT ID
   ┌─ Firebase Console
   │  ├─ mandaue-foam-ar-1 project
   │  ├─ ⚙️ Settings
   │  └─ Google Cloud Console
   └─ Google Cloud Console
      ├─ APIs & Services
      ├─ Credentials
      └─ Web Application Client ID
      
2. UPDATE FILE
   └─ web/index.html
      └─ Replace: YOUR_WEB_CLIENT_ID_HERE
         With: 245668040106-abc123...apps.googleusercontent.com
         
3. TEST
   └─ flutter run -d web
      └─ Browser Console (F12) shows debug output
         └─ Google Sign-In popup appears on button click
```

## Configuration Hierarchy

```
Firebase Console (mandaue-foam-ar-1)
    ↓
    ├─ Android Config (google-services.json) ✅
    │  └─ Downloaded & placed in android/app/
    │
    └─ Web Config (needs web Client ID)
       └─ Must be added manually to web/index.html
```

## Debug Information Location

```
Application Console Output
    ├─ Browser Console (F12) - for web platform ⭐
    ├─ Android Logcat - for Android platform
    ├─ Xcode Console - for iOS platform
    └─ Output messages print:
       ├─ Startup: Configuration info
       └─ On Error: Troubleshooting steps
```

## File Structure for OAuth

```
web/
├─ index.html ⭐ NEEDS: <meta name="google-signin-client_id" ...>
├─ manifest.json
├─ favicon.png
└─ icons/

android/
├─ app/
│  ├─ google-services.json ✅ Android config present
│  └─ src/
└─ ...

lib/
├─ screens/
│  ├─ auth/
│  │  └─ sign_in_screen.dart ✅ Debug code added
│  └─ ...
└─ ...
```

## Error Detection Flow

```
catch (e) {
    if (kIsWeb && kDebugMode) {
        // Web platform in debug mode
        Print detailed error info
        Print troubleshooting steps
    }
    
    if (e.toString().contains('ClientID')) {
        // Show specific message
        errorMessage = "Add google-signin-client_id meta tag"
    } else if (e.toString().contains('origin_mismatch')) {
        // Show different message
        errorMessage = "Add http://localhost:7357 to Google Cloud"
    } else {
        errorMessage = "Generic Google Sign-In error"
    }
    
    Show SnackBar with errorMessage
}
```

## Console Output Timeline

```
[App Startup]
=== Google Sign-In Configuration Debug ===
Platform: TargetPlatform.web
Is Web: true
Google Sign-In Scopes: [email, profile]
Google Sign-In initialized: true
⚠️  WEB PLATFORM DETECTED
Make sure your web/index.html contains:
<meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com" />
=========================================

[User clicks Google Sign-In Button]
[If error occurs]
=== Google Sign-In Error (Web Platform) ===
Error Type: Exception
Error Message: [Full error details]
[Troubleshooting steps printed here]
==========================================
```

## Success Indicators

✅ Browser console shows configuration debug output on startup
✅ No assertion errors after clicking "Continue with Google"
✅ Google Sign-In popup appears after button click
✅ Can authenticate with Google account
✅ Redirected to home screen after successful sign-in

## Quick Decision Tree

```
Error says "ClientID not set"?
├─ YES → Go to Firebase Console, get Web Client ID, update web/index.html
└─ NO → Check browser console (F12) for detailed error message

Client ID format correct?
├─ YES (XXXXX.apps.googleusercontent.com) → Test again
└─ NO → Copy directly from Google Cloud Console

Still not working?
├─ Check http://localhost:7357 is authorized in Google Cloud
├─ Run: flutter clean && flutter pub get
└─ Restart browser and try again
```

## Files I Created for Your Reference

```
QUICK_START_OAUTH.md .................. Quick 4-step guide
WEB_OAUTH_SETUP.md ................... Detailed setup documentation
DEBUG_GOOGLE_SIGNIN.md ............... Comprehensive debugging guide
GOOGLE_SIGNIN_DEBUG_SUMMARY.md ....... Implementation details
VISUAL_DEBUG_FLOW.md ................. This file
```

All guides are in your project root directory for easy reference!

# Quick Start: Getting Your Google Sign-In Web Client ID

## The Problem
Your app shows: `Assertion Error: ClientID not set`

This means the web platform can't find the OAuth Client ID.

## The Solution in 4 Steps

### 1. Go to Google Cloud Console
```
https://console.firebase.google.com/
→ Select: mandaue-foam-ar-1
→ Click ⚙️ Settings
→ Click "Google Cloud Console" link
```

### 2. Find Your Web Client ID
```
Google Cloud Console
→ Left Sidebar: APIs & Services
→ Click: Credentials
→ Look for: OAuth 2.0 Client IDs
→ Type: Web application
→ Copy the Client ID (looks like: 245668040106-abc123xyz.apps.googleusercontent.com)
```

### 3. Update web/index.html
Replace this line:
```html
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID_HERE.apps.googleusercontent.com">
```

With your actual Client ID:
```html
<meta name="google-signin-client_id" content="245668040106-a1b2c3d4e5f6g7h8i9j0k.apps.googleusercontent.com">
```

### 4. Test
```bash
flutter clean
flutter pub get
flutter run -d web
```

## If Web Client ID Doesn't Exist

In Google Cloud Console → Credentials:
1. Click **+ Create Credentials**
2. Choose **OAuth client ID**
3. Select **Web application**
4. Add to **Authorized JavaScript origins**:
   - `http://localhost:7357`
   - `http://localhost:8080`
   - `https://yourdomain.com` (if you have one)
5. Click **Create**

## What I Already Did For You

✅ Added debugging code to sign_in_screen.dart
✅ Added google-signin-client_id meta tag placeholder to web/index.html
✅ Enhanced error messages with troubleshooting steps
✅ Console now prints configuration status on startup

## Files Modified

- `lib/screens/auth/sign_in_screen.dart` - Added debug function & error handling
- `web/index.html` - Added google-signin-client_id meta tag placeholder
- `WEB_OAUTH_SETUP.md` - Complete setup guide
- `DEBUG_GOOGLE_SIGNIN.md` - Detailed debugging guide

## Your Project Info
- **Firebase Project**: mandaue-foam-ar-1
- **Project Number**: 245668040106
- **Android Package**: com.example.ar_3d_viewer

That's it! Just get the Client ID and update web/index.html.

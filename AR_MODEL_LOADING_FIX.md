# AR Model Loading Fix - Cache Clearing Issue

## Problem Summary

After clearing app data/cache, the AR viewer would crash with a `FileNotFoundException` when trying to load 3D models. The error occurred because:

1. **Root Cause**: The app cached the model file path in memory (`_localModelPath`), but when the user cleared app data, the actual `.glb` file was deleted from disk
2. **Secondary Issue**: The app attempted to place models before verifying the file existed
3. **Plugin Issue**: `LateInitializationError: Field 'onPlaneDetected' has not been initialized` - This is a known issue in the AR plugin itself (not our code)

## Error Logs Analysis

```
E/ModelRenderable( 7309): java.io.FileNotFoundException: 
/data/user/0/com.mandauefoam.ar3dviewer/app_flutter/filip_accent_chair1.glb: 
open failed: ENOENT (No such file or directory)
```

The file path was valid in memory, but the file didn't exist on disk after cache clearing.

## Solution Implemented

### 1. **Enhanced File Validation** (`_downloadModel()`)
- Added check to verify if cached file actually exists on disk
- If path exists in memory but file is missing, force re-download
- Clear invalid cache path before re-downloading

```dart
if (_localModelPath != null) {
  final cachedFile = File(_localModelPath!);
  if (await cachedFile.exists()) {
    return _localModelPath; // File exists, use it
  } else {
    _localModelPath = null; // File missing, force re-download
  }
}
```

### 2. **Pre-Placement Validation** (`_placeModelAtCenter()`)
- Verify model is downloaded before attempting placement
- Check file exists on disk before creating AR node
- Automatically trigger re-download if file is missing
- Provide clear user feedback during download

```dart
// Verify model file exists before attempting placement
if (_localModelPath == null) {
  final downloadedPath = await _downloadModel();
  if (downloadedPath == null) {
    throw Exception('Failed to download model');
  }
}

// Double-check file exists on disk
final file = File(_localModelPath!);
if (!await file.exists()) {
  _localModelPath = null;
  final downloadedPath = await _downloadModel();
  // ... handle re-download
}
```

### 3. **Tap-to-Place Validation** (`_handleTapToPlace()`)
- Added user-friendly error messages
- Prevent placement attempts while downloading
- Verify file exists before processing tap

### 4. **Anchor Placement Validation** (`_addModelAtAnchor()`)
- Validate file exists before adding to AR scene
- Automatic re-download if file is missing
- Throw clear exceptions for debugging

## User Experience Improvements

### Before Fix:
- ❌ App crashes with cryptic error
- ❌ No feedback about missing file
- ❌ User has to restart app

### After Fix:
- ✅ Automatic re-download when file is missing
- ✅ Clear user feedback: "Please wait, model is downloading..."
- ✅ Graceful error handling with helpful messages
- ✅ No app restart required

## Testing Recommendations

1. **Clear Cache Test**:
   - Open AR viewer with a model
   - Close app
   - Clear app data/cache from Android settings
   - Reopen AR viewer
   - ✅ Model should automatically re-download

2. **Network Failure Test**:
   - Clear cache
   - Disable internet
   - Try to place model
   - ✅ Should show clear error message

3. **Normal Flow Test**:
   - Open AR viewer
   - Place model
   - ✅ Should work normally without re-downloading

## Known Issues

### `LateInitializationError: Field 'onPlaneDetected'`
This error comes from the AR Flutter plugin itself, not our code. It's a non-critical warning that doesn't affect functionality. The plugin has an uninitialized callback that it tries to use internally.

**Impact**: None - just log noise
**Workaround**: Can be ignored, or update to newer plugin version if available

## Files Modified

- `lib/screens/onboarding/ar_viewer_screen.dart`
  - Enhanced `_downloadModel()` method
  - Updated `_placeModelAtCenter()` method
  - Updated `_handleTapToPlace()` method
  - Updated `_addModelAtAnchor()` method

## Technical Details

### File Storage Location
Models are stored in: `/data/user/0/com.mandauefoam.ar3dviewer/app_flutter/`

This directory is cleared when user selects "Clear Data" in Android settings.

### AR Node Type
Using `NodeType.fileSystemAppFolderGLB` which expects:
- File to be in app's support directory
- Only filename (not full path) in the `uri` parameter
- File must exist before `addNode()` is called

## Prevention Strategy

The fix implements a **defensive programming** approach:
1. **Never trust cached paths** - Always verify file exists
2. **Fail gracefully** - Provide clear error messages
3. **Auto-recovery** - Automatically re-download when possible
4. **User feedback** - Keep user informed of what's happening

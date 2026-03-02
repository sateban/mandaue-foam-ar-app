import 'package:flutter/material.dart';

class ColorUtils {
  static Map<String, String> _dynamicColorMap = {};

  static const Map<String, String> _defaultColorMap = {
    "Brown": "#8B4513",
    "Black": "#000000",
    "White": "#FFFFFF",
    "Gray": "#808080",
    "Beige": "#F5F5DC",
    "Natural": "#E8D8B0",
    "Dark Walnut": "#5D3A1A",
    "Oak": "#C19A6B",
    "Bronze": "#CD7F32",
    "Silver": "#C0C0C0",
    "Teal": "#008080",
    "Cyan": "#00FFFF",
    "Slate": "#708090",
    "Olive": "#808000",
    "Blue": "#1E3A8A",
    "Light Gray": "#D3D3D3",
    "Walnut": "#6c533c",
    "Maple": "#D6A77A",
  };

  static void updateColorMap(Map<String, String> newMap) {
    print('📦 ColorUtils: Updating dynamic map with ${newMap.length} entries');
    _dynamicColorMap = Map<String, String>.from(newMap);
    if (_dynamicColorMap.containsKey('Blue')) {
      print(
        '📦 ColorUtils: Firebase Blue Value -> ${_dynamicColorMap['Blue']}',
      );
    }
  }

  static Color getColorFromHex(String hexColor) {
    var hex = hexColor.toUpperCase().replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse(hex, radix: 16));
  }

  static Color getColorFromName(String colorName) {
    final sanitizedName = colorName.trim();
    print(
      '🔍 ColorUtils: Resolving for "$sanitizedName" (Dynamic size: ${_dynamicColorMap.length})',
    );

    // 1. Try exact match in dynamic map
    String? hex = _dynamicColorMap[sanitizedName];
    if (hex != null) print('🔍 ColorUtils: Exact dynamic match found -> $hex');

    // 2. Try exact match in default map
    if (hex == null) {
      hex = _defaultColorMap[sanitizedName];
      if (hex != null)
        print('🔍 ColorUtils: Exact default match found -> $hex');
    }

    // 3. Try case-insensitive lookup
    if (hex == null) {
      for (var entry in _dynamicColorMap.entries) {
        if (entry.key.toLowerCase() == sanitizedName.toLowerCase()) {
          hex = entry.value;
          print(
            '🔍 ColorUtils: Case-insensitive dynamic match found: ${entry.key} -> $hex',
          );
          break;
        }
      }
      if (hex == null) {
        for (var entry in _defaultColorMap.entries) {
          if (entry.key.toLowerCase() == sanitizedName.toLowerCase()) {
            hex = entry.value;
            print(
              '🔍 ColorUtils: Case-insensitive default match found: ${entry.key} -> $hex',
            );
            break;
          }
        }
      }
    }

    // 4. Try partial match
    if (hex == null) {
      for (var entry in _dynamicColorMap.entries) {
        if (sanitizedName.toLowerCase().contains(entry.key.toLowerCase())) {
          hex = entry.value;
          print(
            '🔍 ColorUtils: Partial dynamic match found: ${entry.key} -> $hex',
          );
          break;
        }
      }
      if (hex == null) {
        for (var entry in _defaultColorMap.entries) {
          if (sanitizedName.toLowerCase().contains(entry.key.toLowerCase())) {
            hex = entry.value;
            print(
              '🔍 ColorUtils: Partial default match found: ${entry.key} -> $hex',
            );
            break;
          }
        }
      }
    }

    if (hex != null) {
      return getColorFromHex(hex);
    }

    print('⚠️ ColorUtils: No mapping found for "$colorName", using Gray');
    return Colors.grey;
  }

  /// Determines if a color is light or dark to set appropriate text/icon color
  static Color getContrastColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

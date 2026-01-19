import 'package:flutter/material.dart';

class ShopShellScope extends InheritedWidget {
  const ShopShellScope({
    required this.setTab,
    required super.child,
    super.key,
  });

  final void Function(int index) setTab;

  static ShopShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShopShellScope>();
  }

  @override
  bool updateShouldNotify(ShopShellScope oldWidget) => false;
}


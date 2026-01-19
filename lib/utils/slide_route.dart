import 'package:flutter/material.dart';

Route<T> slideRoute<T>(
  Widget page, {
  Offset begin = const Offset(1.0, 0.0),
  Duration duration = const Duration(milliseconds: 300),
}) {
  // Shared slide + fade transition to keep navigation consistent
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideTween = Tween<Offset>(begin: begin, end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic));

      return SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
    transitionDuration: duration,
    reverseTransitionDuration: duration,
  );
}

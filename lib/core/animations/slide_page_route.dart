import 'package:flutter/material.dart';

class SlidePageRoute extends PageRouteBuilder {
  final Widget page;

  SlidePageRoute({required this.page})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // slide from right
            const end = Offset.zero;

            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.easeOutCubic));

            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}
import 'package:flutter/material.dart';

class SlidePageRoute extends PageRouteBuilder {
  final Widget page;
  final bool fromRight;

  SlidePageRoute({
    required this.page,
    this.fromRight = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {

            final beginOffset = fromRight
                ? const Offset(1.0, 0.0)
                : const Offset(-1.0, 0.0);

            const end = Offset.zero;

            final tween = Tween(
              begin: beginOffset,
              end: end,
            ).chain(
              CurveTween(curve: Curves.easeOutCubic),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
}
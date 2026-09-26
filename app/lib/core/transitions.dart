import 'package:flutter/material.dart';

/// Bharari's signature page transition: a soft upward drift + fade + scale,
/// replacing Flutter's default slide so every navigation feels distinct and
/// intentional rather than templated. Used everywhere instead of MaterialPageRoute.
class BharariRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  BharariRoute({required this.builder})
      : super(
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
            final outCurved = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
                  child: SlideTransition(
                    position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.03, 0)).animate(outCurved),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
}

/// A distinct "reveal" transition for moments that deserve their own beat —
/// currently the quiz-to-results handoff: the old screen holds and fades while
/// results rises and scales in, like a curtain opening on the outcome.
class BharariRevealRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;
  BharariRevealRoute({required this.builder})
      : super(
          transitionDuration: const Duration(milliseconds: 520),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: animation, curve: const Interval(0, 0.6))),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Push helper: `push(context, (_) => SomeScreen())` instead of
/// `Navigator.push(context, MaterialPageRoute(builder: (_) => SomeScreen()))`.
Future<T?> push<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.push<T>(context, BharariRoute<T>(builder: builder));

Future<T?> pushReplacement<T, TO>(BuildContext context, WidgetBuilder builder) =>
    Navigator.pushReplacement<T, TO>(context, BharariRoute<T>(builder: builder));

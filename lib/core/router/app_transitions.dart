import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions used throughout Témoignages.
///
/// Usage — inside a GoRoute builder:
///   pageBuilder: (context, state) => AppTransitions.slideUp(
///     state: state,
///     child: const MyScreen(),
///   )
abstract final class AppTransitions {
  // ── Horizontal slide (default push — feels native on Android) ───────────
  static CustomTransitionPage<void> slideRight({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondary, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // ── Slide up from bottom (modals, sheets, publish flow) ─────────────────
  static CustomTransitionPage<void> slideUp({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondary, child) {
        final tween = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutQuart));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // ── Fade (splash → onboarding, tab switching) ───────────────────────────
  static CustomTransitionPage<void> fade({
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondary, child) {
        return FadeTransition(
          opacity: animation.drive(
            CurveTween(curve: Curves.easeIn),
          ),
          child: child,
        );
      },
    );
  }

  // ── Fade + Scale (detail cards, testimony reveal) ───────────────────────
  static CustomTransitionPage<void> fadeScale({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ── No transition (tab root replacement — keeps perception of same level)
  static NoTransitionPage<void> none({
    required GoRouterState state,
    required Widget child,
  }) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }
}

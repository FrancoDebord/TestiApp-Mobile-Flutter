import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 72,
              color: Color(0xFF184797),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.errorNotFoundTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.errorNotFoundBody,
              style: const TextStyle(color: Color(0xFF667085)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go('/home'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF184797),
              ),
              child: Text(context.l10n.errorBackHome),
            ),
          ],
        ),
      ),
    );
  }
}

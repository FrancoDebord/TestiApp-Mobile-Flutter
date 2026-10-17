// lib/features/testimony/screens/shorts_tab_screen.dart
//
// Tab wrapper for the Shorts feed.
// Pulls all VideoTestimony from the global feed and passes them to ShortsScreen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../home/models/testimony_model.dart';
import '../../home/providers/home_providers.dart';
import 'shorts_screen.dart';
import '../../../l10n/app_localizations.dart';

class ShortsTabScreen extends ConsumerWidget {
  const ShortsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref
        .watch(feedNotifierProvider)
        .whereType<VideoTestimony>()
        // Vidéos YouTube : lecteur YouTube (hors défilement des Shorts) ;
        // vidéos en traitement ou en échec : rien à lire.
        .where((v) => !v.isYouTube && v.isReady)
        .toList();

    if (videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded,
                  size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              Text(
                context.l10n.shortsEmptyTitle,
                style: TextStyle(
                  color: Colors.white54,
                  fontFamily: AppFonts.family,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.shortsEmptyBody,
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: AppFonts.family,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ShortsScreen(testimonies: videos);
  }
}

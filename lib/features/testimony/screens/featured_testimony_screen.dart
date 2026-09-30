import 'package:flutter/material.dart';

import 'testimony_detail_screen.dart';

/// Témoignage « À la une » : même page de lecture que le détail d'un
/// témoignage (maquette, écran 8).
class FeaturedTestimonyScreen extends StatelessWidget {
  const FeaturedTestimonyScreen({required this.testimonyId, super.key});
  final String testimonyId;

  @override
  Widget build(BuildContext context) =>
      TestimonyDetailScreen(testimonyId: testimonyId);
}

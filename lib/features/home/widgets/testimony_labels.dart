// lib/features/home/widgets/testimony_labels.dart
//
// Labels de confiance d'un témoignage (carte du fil, page détail) :
// « À la une » (badges contient "featured", mise à la une manuelle) et
// « Témoignage approuvé » (badges contient "verified", label attribué par un
// administrateur), « Conversion » (témoignage de conversion). Rien quand le témoignage n'en a aucun.
// Le statut de modération (publié) n'est jamais affiché ici.

import 'package:flutter/material.dart';

import '../../../shared/widgets/approval_badges.dart';
import '../../conversion/widgets/conversion_widgets.dart' show ConversionLabel;
import '../models/testimony_model.dart';

class TestimonyLabels extends StatelessWidget {
  const TestimonyLabels({required this.testimony, this.compact = false, this.padding = EdgeInsets.zero, super.key});

  final Testimony testimony;
  final bool compact;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final featured = testimony.isFeaturedBadge;
    final approved = testimony.hasApprovedLabel;
    final conversion = testimony.isConversion;
    if (!featured && !approved && !conversion) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          // Témoignage de conversion (docs serveur fonctionnalites/temoignage-de-conversion.md).
          if (conversion) ConversionLabel(compact: compact),
          if (featured) FeaturedLabel(compact: compact),
          if (approved) TestimonyApprovedLabel(compact: compact),
        ],
      ),
    );
  }
}

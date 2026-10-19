import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart' show AppFonts;
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../models/event_models.dart';

// ── Dates (tables françaises écrites à la main, intl pour l'anglais) ────────

const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.']; // i18n-ignore
const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', // i18n-ignore
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.', // i18n-ignore
];

bool get _fr => L10n.languageCode == 'fr';

/// Mois abrégé : « oct. » / « Oct ».
String _month(int m) => _fr ? _months[m - 1] : formatDatePattern(DateTime(2000, m), 'MMM');

String _hm(DateTime d) => _fr
    ? '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
    : formatTime(d);

/// « sam. 12 oct. 2026 » / « Sat 12 Oct 2026 ».
String formatEventDay(DateTime d) => _fr
    ? '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}'
    : formatDatePattern(d, 'EEE d MMM y');

/// Période lisible :
/// - même jour : « sam. 12 oct. 2026 · 18:00 – 21:00 » ;
/// - plusieurs jours : « 12 → 14 oct. 2026 » (ou mois / années différents).
String formatEventRange(DateTime? start, DateTime? end) {
  if (start == null) return L10n.current.eventsDateTbd;
  if (end == null) return '${formatEventDay(start)} · ${_hm(start)}';
  final sameDay =
      start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) return '${formatEventDay(start)} · ${_hm(start)} – ${_hm(end)}';
  if (start.year == end.year && start.month == end.month) {
    return '${start.day} → ${end.day} ${_month(end.month)} ${end.year}';
  }
  if (start.year == end.year) {
    return '${start.day} ${_month(start.month)} → ${end.day} ${_month(end.month)} ${end.year}';
  }
  return '${start.day} ${_month(start.month)} ${start.year} → '
      '${end.day} ${_month(end.month)} ${end.year}';
}

/// 950 · 1,2 k · 12 k · 1,5 M
String compactCount(int n) {
  if (n < 1000) return '$n';
  if (!_fr) return formatCompactNumber(n);
  if (n < 1000000) {
    return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0).replaceAll('.', ',')} k';
  }
  return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
}

/// Icône du type d'événement.
IconData eventTypeIcon(EventType t) => eventTypeIconFor(t.icon);

/// Icônes proposées aux administrateurs (mêmes clés que le serveur).
const kEventTypeIcons = <String, IconData>{
  'bullhorn': Icons.campaign_rounded,
  'microphone': Icons.mic_external_on_rounded,
  'chalkboard': Icons.co_present_rounded,
  'campground': Icons.cabin_rounded,
  'route': Icons.route_rounded,
  'music': Icons.music_note_rounded,
  'dove': Icons.self_improvement_rounded,
  'calendar': Icons.event_rounded,
  'church': Icons.church_rounded,
  'users': Icons.groups_rounded,
  'hands': Icons.volunteer_activism_rounded,
  'star': Icons.star_rounded,
  'book': Icons.menu_book_rounded,
  'heart': Icons.favorite_rounded,
  'globe': Icons.public_rounded,
  'cross': Icons.add_rounded,
  'fire': Icons.local_fire_department_rounded,
  'child': Icons.child_care_rounded,
  'graduation': Icons.school_rounded,
};

IconData eventTypeIconFor(String key) => kEventTypeIcons[key] ?? Icons.event_rounded;

// ── Pastilles ────────────────────────────────────────────────────────────────

/// État : À venir (bleu), En cours (orange), Terminé (gris), Annulé (rouge), Brouillon.
class EventPhaseBadge extends StatelessWidget {
  const EventPhaseBadge({required this.event, this.onImage = false, super.key});

  final ChristianEvent event;

  /// Posée sur une image : fond plein.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = event.isCancelled
        ? (AppColors.danger, Colors.white)
        : event.isDraft
            ? (const Color(0xFF475467), Colors.white)
            : event.dateTbd
            ? (_postponedColor, Colors.white)
            : switch (event.phase) {
                EventPhase.ongoing => (AppColors.secondary, Colors.white),
                EventPhase.past => (const Color(0xFF667085), Colors.white),
                EventPhase.upcoming => onImage
                    ? (AppColors.primary, Colors.white)
                    : (AppColors.primarySoft, AppColors.primary),
              };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        event.phaseLabel,
        style: TextStyle(
          color: fg,
          fontFamily: AppFonts.family,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// « EN DIRECT » quand le direct de l'événement est à l'antenne.
class EventLiveBadge extends StatelessWidget {
  const EventLiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            context.l10n.eventsLiveBadge,
            style: TextStyle(
              color: Colors.white,
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image de couverture ──────────────────────────────────────────────────────

/// Image de l'événement, ou fond aux couleurs de la marque avec l'icône du type.
class EventCoverImage extends StatelessWidget {
  const EventCoverImage({required this.event, this.url, super.key});

  final ChristianEvent event;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(eventTypeIcon(event.type), size: 48, color: Colors.white.withAlpha(120)),
    );
    final u = url ?? event.coverUrl;
    if (u == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

/// Carrousel des images de couverture (glisser, points), avec un calque optionnel.
class EventCoverCarousel extends StatefulWidget {
  const EventCoverCarousel({required this.event, this.overlay, super.key});

  final ChristianEvent event;
  final Widget? overlay;

  @override
  State<EventCoverCarousel> createState() => _EventCoverCarouselState();
}

class _EventCoverCarouselState extends State<EventCoverCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.event.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.length <= 1)
          EventCoverImage(event: widget.event)
        else
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => EventCoverImage(event: widget.event, url: images[i].url),
          ),
        ?widget.overlay,
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Semantics(
              label: context.l10n.eventsImageOf(_index + 1, images.length),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? Colors.white : Colors.white.withAlpha(120),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Cartes ───────────────────────────────────────────────────────────────────

/// Carte d'un événement dans une liste.
class EventCard extends StatelessWidget {
  const EventCard({required this.event, required this.onTap, super.key});

  final ChristianEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventCoverImage(event: e),
                    Positioned(
                      left: 10,
                      top: 10,
                      right: 66,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          EventPhaseBadge(event: e, onImage: true),
                          if (e.isLiveNow) const EventLiveBadge(),
                          ...EventFlagBadge.forEvent(e),
                        ],
                      ),
                    ),
                    // Date en vignette (jour + mois).
                    if (e.startsAt != null && !e.dateTbd)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: _DateTile(date: e.startsAt!),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(eventTypeIcon(e.type), size: 14, color: AppColors.secondary),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            e.type.label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.secondaryDark,
                              fontFamily: AppFonts.family,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w800,
                        fontSize: 16.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoLine(icon: Icons.schedule_rounded, text: eventScheduleText(e)),
                    if (e.isPostponed && e.originalStartsAt != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 21, top: 2),
                        child: EventOriginalDate(event: e),
                      ),
                    if (e.place != null) ...[
                      const SizedBox(height: 4),
                      _InfoLine(icon: Icons.place_outlined, text: e.place!),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  e.organizer.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontFamily: AppFonts.family,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (e.organizer.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                              ],
                            ],
                          ),
                        ),
                        if (e.goingCount > 0) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: context.l10n.eventsParticipantCount(e.goingCount),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.groups_rounded, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  compactCount(e.goingCount),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontFamily: AppFonts.family,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petite carte horizontale (bandeau « Événements à venir » de l'accueil).
class EventMiniCard extends StatelessWidget {
  const EventMiniCard({required this.event, required this.onTap, super.key});

  final ChristianEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return SizedBox(
      width: 230,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EventCoverImage(event: e),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: e.isLiveNow
                            ? const EventLiveBadge()
                            : EventPhaseBadge(event: e, onImage: true),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontFamily: AppFonts.family,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.dateTbd
                            ? context.l10n.eventsDateTbc
                            : e.startsAt == null ? context.l10n.eventsDateTbd : formatEventDay(e.startsAt!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontFamily: AppFonts.family,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Report, non confirmé, masqué ─────────────────────────────────────────────

const _postponedColor = Color(0xFFB54708); // orange foncé (contraste AA sur blanc)
const _unconfirmedColor = Color(0xFFB42318);

/// Période affichée d'un événement : « Date à confirmer » s'il est reporté sans date.
String eventScheduleText(ChristianEvent e) =>
    e.dateTbd ? L10n.current.eventsDateTbc : formatEventRange(e.startsAt, e.endsAt);

/// Petite pastille d'information (Reporté, Non confirmé, Masqué).
class EventFlagBadge extends StatelessWidget {
  const EventFlagBadge({required this.label, required this.color, this.icon, super.key});

  final String label;
  final Color color;
  final IconData? icon;

  /// Pastilles complémentaires de l'état : « Reporté » (avec nouvelle date),
  /// « Non confirmé », « Masqué » (gestionnaires et modérateurs).
  static List<Widget> forEvent(ChristianEvent e) => [
        if (e.isPostponed && !e.dateTbd && !e.isCancelled)
          EventFlagBadge(label: L10n.current.eventsFlagPostponed, color: _postponedColor, icon: Icons.event_repeat_rounded),
        if (e.isUnconfirmed)
          EventFlagBadge(label: L10n.current.eventsFlagUnconfirmed, color: _unconfirmedColor, icon: Icons.help_outline_rounded),
        if (e.isHidden)
          EventFlagBadge(label: L10n.current.eventsFlagHidden, color: const Color(0xFF475467), icon: Icons.visibility_off_outlined),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: AppFonts.family,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ancienne date d'un événement reporté, barrée (« 12 oct. 2026 »).
class EventOriginalDate extends StatelessWidget {
  const EventOriginalDate({required this.event, this.fontSize = 12, super.key});

  final ChristianEvent event;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final d = event.originalStartsAt;
    if (!event.isPostponed || d == null) return const SizedBox.shrink();
    return Semantics(
      label: context.l10n.eventsOriginalDate(formatEventRange(d, event.originalEndsAt)),
      excludeSemantics: true,
      child: Text(
        formatEventRange(d, event.originalEndsAt),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontFamily: AppFonts.family,
          fontSize: fontSize,
          decoration: TextDecoration.lineThrough,
        ),
      ),
    );
  }
}

// ── Ligne compacte ───────────────────────────────────────────────────────────

/// Ligne compacte d'un événement (affichage « Liste ») : vignette date, titre,
/// lieu / ville, organisateur, pastilles d'état.
class EventCompactTile extends StatelessWidget {
  const EventCompactTile({required this.event, required this.onTap, super.key});

  final ChristianEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final place = [e.location, e.city].whereType<String>().join(', ');
    final flags = EventFlagBadge.forEvent(e);
    final showPhase = e.isCancelled || e.isDraft || e.dateTbd || e.phase != EventPhase.upcoming;
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: eventScheduleText(e),
                excludeSemantics: true,
                child: e.dateTbd || e.startsAt == null
                    ? Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.event_repeat_rounded, color: _postponedColor, size: 22),
                      )
                    : _DateTile(date: e.startsAt!, flat: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [if (place.isNotEmpty) place, e.organizer.displayName].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: AppFonts.family,
                        fontSize: 12.5,
                      ),
                    ),
                    if (showPhase || flags.isNotEmpty || e.isLiveNow) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (e.isLiveNow) const EventLiveBadge(),
                          if (showPhase) EventPhaseBadge(event: e),
                          ...flags,
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, this.flat = false});
  final DateTime date;

  /// Sans ombre, avec bordure (ligne compacte).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: flat ? Border.all(color: AppColors.border) : null,
        boxShadow: flat ? null : const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(
              color: AppColors.primary,
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              height: 1.1,
            ),
          ),
          Text(
            _month(date.month).replaceAll('.', '').toUpperCase(),
            style: const TextStyle(
              color: AppColors.secondaryDark,
              fontFamily: AppFonts.family,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFamily: AppFonts.family,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// Événements passés : liste paginée (recherche, type), chaque carte ouvre
// l'événement sur ses témoignages pour les revivre.
// Backend : docs/fonctionnalites/evenements.md (GET events?scope=past).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../widgets/event_widgets.dart' show eventTypeIcon;
import '../widgets/past_events_widgets.dart';

class PastEventsScreen extends ConsumerStatefulWidget {
  const PastEventsScreen({super.key});

  @override
  ConsumerState<PastEventsScreen> createState() => _PastEventsScreenState();
}

class _PastEventsScreenState extends ConsumerState<PastEventsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _query;
  EventType? _type;

  EventListKey get _key => (scope: EventScope.past, type: _type, query: _query);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = v.trim();
      setState(() => _query = q.isEmpty ? null : q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(eventListProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(l10n.pastEventsScreenTitle,
            style: AppTextStyles.h4.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(eventListProvider(_key)),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 500) {
              ref.read(eventListProvider(_key).notifier).loadMore();
            }
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 40),
            children: [
              Text(l10n.pastEventsIntro,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.pastEventsSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(l10n.pastEventsAllTypes),
                        selected: _type == null,
                        onSelected: (_) => setState(() => _type = null),
                      ),
                    ),
                    for (final t in EventType.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(eventTypeIcon(t), size: 16),
                          label: Text(t.label),
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = _type == t ? null : t),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...switch (async) {
                AsyncValue(:final value?) when value.items.isEmpty => [
                    _Message(icon: Icons.history_rounded, text: l10n.eventsEmptyPast),
                  ],
                AsyncValue(:final value?) => [
                    for (final e in value.items) ...[
                      PastEventCard(event: e, imageHeight: 150),
                      const SizedBox(height: 12),
                    ],
                    if (value.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                AsyncValue(:final error?) => [
                    _Message(
                      icon: Icons.wifi_off_rounded,
                      text: error is EventFailure ? error.message : l10n.commonError,
                      onRetry: () => ref.invalidate(eventListProvider(_key)),
                    ),
                  ],
                _ => const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}

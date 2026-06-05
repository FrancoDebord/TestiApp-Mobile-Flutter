import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/explore_providers.dart';

/// Animated search bar that expands from an icon hint to a full text field.
///
/// Widget tree:
/// AnimatedContainer (height: 48, rounded, border)
///   └─ Row
///       ├─ Icon (search, grey)
///       ├─ SizedBox
///       ├─ Expanded → TextField (no decoration borders)
///       ├─ [if text] IconButton (clear)
///       └─ IconButton (mic)
class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();

    _focus.addListener(() {
      ref.read(searchBarActiveProvider.notifier).update(_focus.hasFocus);
    });

    _ctrl.addListener(() {
      ref.read(searchQueryProvider.notifier).update(_ctrl.text);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    ref.read(searchQueryProvider.notifier).update('');
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focus.hasFocus ? AppColors.primary : AppColors.border,
          width: _focus.hasFocus ? 1.5 : 1,
        ),
        boxShadow: _focus.hasFocus
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            color: _focus.hasFocus
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Rechercher un témoignage…',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  // Navigation to search results is handled by the parent
                }
              },
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textSecondary,
              onPressed: _clear,
              tooltip: 'Effacer',
              padding: const EdgeInsets.symmetric(horizontal: 8),
              constraints: const BoxConstraints(),
            ),
          IconButton(
            icon: const Icon(Icons.mic_none_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () {
              // TODO: wire voice search
            },
            tooltip: 'Recherche vocale',
            padding: const EdgeInsets.symmetric(horizontal: 12),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

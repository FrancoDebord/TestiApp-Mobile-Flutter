// Types de témoignages d'un profil (administrateurs) : pour chaque type, suivre
// le réglage de la plateforme, l'autoriser ou l'interdire pour ce compte.
// Backend : docs/fonctionnalites/types-de-temoignages.md
//   GET · PUT /admin/users/{id}/publishing
//   → { global: { text: bool, … }, overrides: { text: bool|null, … }, allowed: [...] }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';

/// Types gérés, dans l'ordre d'affichage.
const kTestimonyTypes = ['text', 'audio', 'video', 'youtube']; // i18n-ignore : codes du serveur

String testimonyTypeLabel(String type) => switch (type) {
      'text' => L10n.current.adminSettingsTypeText,
      'audio' => L10n.current.adminSettingsTypeAudio,
      'video' => L10n.current.adminSettingsTypeVideo,
      _ => L10n.current.adminSettingsTypeYoutube,
    };

/// Réglages de publication d'un compte.
class UserPublishing {
  const UserPublishing({required this.global, required this.overrides, required this.allowed});

  factory UserPublishing.fromJson(Map<String, dynamic> m) {
    Map<String, dynamic> map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
    final g = map(m['global']);
    final o = map(m['overrides']);
    return UserPublishing(
      global: {for (final t in kTestimonyTypes) t: g[t] != false},
      overrides: {for (final t in kTestimonyTypes) t: o[t] is bool ? o[t] as bool : null},
      allowed: {for (final t in (m['allowed'] is List ? m['allowed'] as List : const [])) '$t'},
    );
  }

  final Map<String, bool> global;

  /// null : suit la plateforme ; true / false : exception pour ce profil.
  final Map<String, bool?> overrides;
  final Set<String> allowed;
}

Future<void> showUserPublishingSheet(BuildContext context, {required String userId, required String userName}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _UserPublishingSheet(userId: userId, userName: userName),
    );

class _UserPublishingSheet extends ConsumerStatefulWidget {
  const _UserPublishingSheet({required this.userId, required this.userName});
  final String userId;
  final String userName;

  @override
  ConsumerState<_UserPublishingSheet> createState() => _UserPublishingSheetState();
}

class _UserPublishingSheetState extends ConsumerState<_UserPublishingSheet> {
  UserPublishing? _data;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiServiceProvider).get<dynamic>(AppConstants.adminUserPublishing(widget.userId));
      if (!mounted) return;
      setState(() => _data = UserPublishing.fromJson(Map<String, dynamic>.from(res.data as Map)));
    } on LaravelApiException catch (e) {
      if (mounted) setState(() => _error = e.displayMessage);
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.adminSettingsSaveFailed);
    }
  }

  Future<void> _set(String type, bool? value) async {
    final before = _data;
    if (before == null || _saving) return;
    setState(() {
      _saving = true;
      _data = UserPublishing(
        global: before.global,
        overrides: {...before.overrides, type: value},
        allowed: before.allowed,
      );
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final res = await ref
          .read(apiServiceProvider)
          .put<dynamic>(AppConstants.adminUserPublishing(widget.userId), data: {type: value});
      if (mounted) setState(() => _data = UserPublishing.fromJson(Map<String, dynamic>.from(res.data as Map)));
    } on LaravelApiException catch (e) {
      if (mounted) setState(() => _data = before);
      messenger?.showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(e.displayMessage)));
    } catch (_) {
      if (mounted) setState(() => _data = before);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = _data;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.adminUserPublishingTitle, style: AppTextStyles.h4),
            const SizedBox(height: 2),
            Text(l10n.adminUserPublishingSubtitle(widget.userName), style: AppTextStyles.bodySmall),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.danger))
            else if (d == null)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else
              for (final type in kTestimonyTypes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(testimonyTypeLabel(type),
                                style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Icon(
                            d.allowed.contains(type) ? Icons.check_circle_rounded : Icons.block_rounded,
                            size: 16,
                            color: d.allowed.contains(type) ? AppColors.success : AppColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            d.allowed.contains(type) ? l10n.adminUserPublishingAllowed : l10n.adminUserPublishingBlocked,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: 0,
                            label: Text(
                              d.global[type]! ? l10n.adminUserPublishingDefaultOn : l10n.adminUserPublishingDefaultOff,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ButtonSegment(value: 1, label: Text(l10n.adminUserPublishingAllow)),
                          ButtonSegment(value: 2, label: Text(l10n.adminUserPublishingDeny)),
                        ],
                        selected: {switch (d.overrides[type]) { null => 0, true => 1, false => 2 }},
                        onSelectionChanged: _saving
                            ? null
                            : (v) => _set(type, switch (v.first) { 1 => true, 2 => false, _ => null }),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

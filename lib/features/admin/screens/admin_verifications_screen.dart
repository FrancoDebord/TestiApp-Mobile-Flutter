// lib/features/admin/screens/admin_verifications_screen.dart
//
// Administration → « Vérification des comptes » : demandes de badge
// « Compte vérifié » des comptes personnels (approuver, refuser avec motif,
// retirer). Les pièces justificatives sont téléchargées avec le jeton
// administrateur (jamais d'URL publique). Les PDF s'ouvrent sur le site.
// Voir docs/fonctionnalites/verification-des-comptes.md (dépôt Laravel).

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';

// ── Modèles ───────────────────────────────────────────────────────────────────

class AdminVerificationRequest {
  const AdminVerificationRequest({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.fullName,
    required this.roleLabel,
    required this.church,
    this.createdAt,
    this.reviewNote,
    this.documentCount = 0,
    this.userId,
    this.userName,
    this.userEmail,
    this.userIsVerified = false,
    this.links = const [],
    this.message,
    this.documents = const [],
  });

  final String id;
  final String status;
  final String statusLabel;
  final String fullName;
  final String roleLabel;
  final String church;
  final DateTime? createdAt;
  final String? reviewNote;
  final int documentCount;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final bool userIsVerified;
  final List<String> links;
  final String? message;
  final List<AdminVerificationDocument> documents;

  bool get isPending => status == 'pending';

  factory AdminVerificationRequest.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? Map<String, dynamic>.from(j['user'] as Map) : const <String, dynamic>{};
    return AdminVerificationRequest(
      id: '${j['id'] ?? ''}',
      status: '${j['status'] ?? ''}',
      statusLabel: '${j['statusLabel'] ?? j['status'] ?? ''}',
      fullName: '${j['fullName'] ?? ''}',
      roleLabel: '${j['roleLabel'] ?? ''}',
      church: '${j['church'] ?? ''}',
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}'),
      reviewNote: j['reviewNote'] as String?,
      documentCount: (j['documentCount'] as num?)?.toInt() ?? 0,
      userId: user['id'] as String?,
      userName: user['displayName'] as String?,
      userEmail: user['email'] as String?,
      userIsVerified: user['isVerified'] == true,
      links: (j['links'] as List? ?? const []).whereType<String>().toList(),
      message: j['message'] as String?,
      documents: (j['documents'] as List? ?? const [])
          .whereType<Map>()
          .map((d) => AdminVerificationDocument.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }
}

class AdminVerificationDocument {
  const AdminVerificationDocument({required this.index, String? name, required this.isImage})
      : _name = name;
  final int index;
  final String? _name;
  final bool isImage;

  /// Nom de la pièce, ou « Pièce » (dans la langue affichée) s'il est absent.
  String get name => _name ?? L10n.current.adminDocumentFallback;

  factory AdminVerificationDocument.fromJson(Map<String, dynamic> j) => AdminVerificationDocument(
        index: (j['index'] as num?)?.toInt() ?? 0,
        name: j['name'] == null ? null : '${j['name']}',
        isImage: j['isImage'] == true,
      );
}

// ── Providers ─────────────────────────────────────────────────────────────────

final adminVerificationsProvider =
    FutureProvider.autoDispose.family<(List<AdminVerificationRequest>, int), String>((ref, status) async {
  final res = await ref.watch(apiServiceProvider).get<dynamic>(
    AppConstants.adminVerificationRequests,
    query: {'status': status, 'per_page': 50},
  );
  final data = Map<String, dynamic>.from(res.data as Map);
  final items = (data['items'] as List? ?? const [])
      .whereType<Map>()
      .map((m) => AdminVerificationRequest.fromJson(Map<String, dynamic>.from(m)))
      .toList();
  return (items, (data['pendingCount'] as num?)?.toInt() ?? 0);
});

final adminVerificationProvider =
    FutureProvider.autoDispose.family<AdminVerificationRequest, String>((ref, id) async {
  final res = await ref.watch(apiServiceProvider).get<dynamic>(AppConstants.adminVerificationRequest(id));
  return AdminVerificationRequest.fromJson(Map<String, dynamic>.from(res.data as Map));
});

/// Pièce justificative (octets) téléchargée avec le jeton administrateur.
final adminVerificationDocumentProvider =
    FutureProvider.autoDispose.family<Uint8List, (String, int)>((ref, key) async {
  final res = await ref.watch(apiServiceProvider).rawDio.get<List<int>>(
        AppConstants.adminVerificationDocument(key.$1, key.$2),
        options: Options(responseType: ResponseType.bytes),
      );
  return Uint8List.fromList(res.data ?? const []);
});

// ── Liste ─────────────────────────────────────────────────────────────────────

class AdminVerificationsScreen extends StatelessWidget {
  const AdminVerificationsScreen({super.key});

  static List<(String, String)> get _tabs => [
        ('pending', L10n.current.adminVerifTabPending),
        ('approved', L10n.current.adminVerifTabApproved),
        ('rejected', L10n.current.adminVerifTabRejected),
        ('revoked', L10n.current.adminVerifTabRevoked),
      ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(context.l10n.adminAccountVerification),
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in _tabs) Tab(text: t.$2)],
          ),
        ),
        body: TabBarView(children: [for (final t in _tabs) _RequestList(status: t.$1)]),
      ),
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminVerificationsProvider(status));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminVerificationsProvider(status).future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(e is LaravelApiException ? e.message : context.l10n.adminLoadFailed, textAlign: TextAlign.center),
          ),
        ]),
        data: (result) {
          final items = result.$1;
          if (items.isEmpty) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Text(context.l10n.adminNoRequests, textAlign: TextAlign.center),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screen),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final r = items[i];
              return Material(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
                child: ListTile(
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                  title: Text(r.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(context.l10n.adminVerifRequestSubtitle(r.roleLabel, r.church, r.documentCount),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => AdminVerificationDetailScreen(requestId: r.id),
                    ));
                    ref.invalidate(adminVerificationsProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Détail ────────────────────────────────────────────────────────────────────

class AdminVerificationDetailScreen extends ConsumerStatefulWidget {
  const AdminVerificationDetailScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<AdminVerificationDetailScreen> createState() => _AdminVerificationDetailScreenState();
}

class _AdminVerificationDetailScreenState extends ConsumerState<AdminVerificationDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      ref.invalidate(adminVerificationProvider(widget.requestId));
    } on LaravelApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.displayMessage)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.adminActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askReason(String title, String confirm) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 255,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(labelText: context.l10n.adminReasonLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().length >= 3) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: Text(confirm),
          ),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminVerificationProvider(widget.requestId));
    final api = ref.read(apiServiceProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.adminVerifRequestTitle),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e is LaravelApiException ? e.message : context.l10n.adminLoadFailed)),
        data: (r) => ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            _info(l10n.adminVerifStatus, r.statusLabel),
            _info(l10n.adminVerifFullName, r.fullName),
            _info(l10n.adminVerifRole, r.roleLabel),
            _info(l10n.adminVerifChurch, r.church),
            if (r.userName != null) _info(l10n.adminVerifAccount, '${r.userName}${r.userEmail != null ? '\n${r.userEmail}' : ''}'),
            if (r.links.isNotEmpty) _info(l10n.adminVerifLinks, r.links.join('\n')),
            if (r.message?.isNotEmpty ?? false) _info(l10n.adminVerifMessage, r.message!),
            if (r.reviewNote?.isNotEmpty ?? false) _info(l10n.adminVerifReason, r.reviewNote!),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.adminVerifDocuments,
                style: const TextStyle(fontFamily: AppFonts.family, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: AppSpacing.sm),
            if (r.documents.isEmpty) Text(l10n.adminVerifNoDocuments),
            for (final d in r.documents) _DocumentPreview(requestId: r.id, document: d),
            const SizedBox(height: AppSpacing.xl),
            if (r.isPending)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton(
                    label: l10n.adminApprove,
                    leadingIcon: Icons.verified_rounded,
                    isLoading: _busy,
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () => api.post<dynamic>(AppConstants.adminVerificationApprove(r.id)),
                              l10n.adminVerifApprovedSnack,
                            ),
                  ),
                  AppButton(
                    label: l10n.adminReject,
                    variant: AppButtonVariant.danger,
                    leadingIcon: Icons.close_rounded,
                    onPressed: _busy
                        ? null
                        : () async {
                            final reason = await _askReason(l10n.adminRejectRequest, l10n.adminReject);
                            if (reason == null) return;
                            await _run(
                              () => api.post<dynamic>(AppConstants.adminVerificationReject(r.id), data: {'reason': reason}),
                              l10n.adminVerifRejectedSnack,
                            );
                          },
                  ),
                ],
              )
            else if (r.status == 'approved' && r.userIsVerified && r.userId != null)
              AppButton(
                label: l10n.adminRevokeVerification,
                variant: AppButtonVariant.danger,
                leadingIcon: Icons.block_rounded,
                onPressed: _busy
                    ? null
                    : () async {
                        final reason = await _askReason(l10n.adminRevokeVerification, l10n.commonRemove);
                        if (reason == null) return;
                        await _run(
                          () => api.post<dynamic>(AppConstants.adminRevokeVerification(r.userId!), data: {'reason': reason}),
                          l10n.adminVerifRevokedSnack,
                        );
                      },
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontFamily: AppFonts.family, fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            SelectableText(value, style: const TextStyle(fontFamily: AppFonts.family, fontSize: 14)),
          ],
        ),
      );
}

class _DocumentPreview extends ConsumerWidget {
  const _DocumentPreview({required this.requestId, required this.document});
  final String requestId;
  final AdminVerificationDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = Text(document.name,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppFonts.family, fontSize: 12));
    if (!document.isImage) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined),
          title: title,
          subtitle: Text(context.l10n.adminVerifPdfHint),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => launchUrl(
            Uri.parse('${AppConstants.webBaseUrl}/admin/verifications/$requestId'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      );
    }
    final bytes = ref.watch(adminVerificationDocumentProvider((requestId, document.index)));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              color: AppColors.border,
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 360),
              child: bytes.when(
                loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                error: (_, _) => SizedBox(height: 120, child: Center(child: Text(context.l10n.adminVerifDocumentUnavailable))),
                data: (b) => Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
          ),
          const SizedBox(height: 4),
          title,
        ],
      ),
    );
  }
}

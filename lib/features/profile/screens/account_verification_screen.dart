// lib/features/profile/screens/account_verification_screen.dart
//
// Profil → « Faire vérifier mon compte » : demande du badge « Compte vérifié »
// pour un compte personnel (pasteur, chantre, personnalité publique…), avec
// pièces justificatives privées. Les organisations sont vérifiées à partir de
// leur profil. Voir docs/fonctionnalites/verification-des-comptes.md (Laravel).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../features/auth/providers/auth_notifier.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/account_verification.dart';
import '../providers/account_verification_provider.dart';

class AccountVerificationScreen extends ConsumerWidget {
  const AccountVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(accountVerificationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.profileVerifTitle,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        top: false,
        child: user?.isOrganization ?? false
            ? _Message(
                icon: Icons.apartment_rounded,
                title: context.l10n.profileVerifOrgTitle,
                text: context.l10n.profileVerifOrgBody,
              )
            : async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _Message(
                  icon: Icons.cloud_off_rounded,
                  title: context.l10n.profileVerifLoadFailedTitle,
                  text: e is LaravelApiException ? e.message : context.l10n.profileVerifLoadFailedBody,
                  action: AppButton(
                    label: context.l10n.commonRetry,
                    variant: AppButtonVariant.outline,
                    onPressed: () => ref.invalidate(accountVerificationProvider),
                  ),
                ),
                data: (state) => _VerificationBody(state: state, user: user),
              ),
      ),
    );
  }
}

class _VerificationBody extends StatelessWidget {
  const _VerificationBody({required this.state, required this.user});
  final AccountVerificationState state;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VerificationStatusCard(state: state),
          const SizedBox(height: AppSpacing.lg),
          if (state.canRequest)
            VerificationRequestForm(state: state, initialName: user?.displayName ?? '')
          else if (state.status == AccountVerificationStatus.pending && state.request != null)
            _RequestSummary(request: state.request!),
        ],
      ),
    );
  }
}

/// Bandeau d'état : vérifié, en attente, refusé / retiré (motif), ou explication.
class VerificationStatusCard extends StatelessWidget {
  const VerificationStatusCard({super.key, required this.state});
  final AccountVerificationState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, color, bg, title, text) = switch (state.status) {
      AccountVerificationStatus.verified => (
          Icons.verified_rounded,
          AppColors.success,
          AppColors.successSoft,
          l10n.profileVerifVerifiedTitle,
          l10n.profileVerifVerifiedBody,
        ),
      AccountVerificationStatus.pending => (
          Icons.hourglass_top_rounded,
          AppColors.sunText,
          AppColors.sunSoft,
          l10n.profileVerifUnderReview,
          l10n.profileVerifPendingBody,
        ),
      AccountVerificationStatus.rejected || AccountVerificationStatus.revoked => (
          Icons.gpp_bad_rounded,
          AppColors.danger,
          AppColors.dangerSoft,
          state.status == AccountVerificationStatus.revoked ? l10n.profileVerifRevokedTitle : l10n.profileVerifRefusedTitle,
          [
            if (state.reason?.trim().isNotEmpty ?? false) l10n.profileVerifReason(state.reason!.trim()),
            if (state.canRequest)
              l10n.profileVerifCanRequestAgain
            else if (state.blockReason != null)
              state.blockReason!,
          ].join('\n'),
        ),
      AccountVerificationStatus.none => (
          Icons.verified_outlined,
          AppColors.primary,
          AppColors.primarySoft,
          l10n.profileVerifRequestTitle,
          l10n.profileVerifRequestBody,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.cardRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: AppFonts.family,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(text,
                      style: const TextStyle(
                          fontFamily: AppFonts.family,
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request});
  final AccountVerificationRequest request;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontFamily: AppFonts.family, fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontFamily: AppFonts.family, fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.profileVerifYourRequest,
              style: const TextStyle(
                  fontFamily: AppFonts.family, fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          row(context.l10n.profileVerifSummaryFullName, request.fullName),
          row(context.l10n.profileVerifSummaryRole, request.roleLabel),
          row(context.l10n.profileVerifSummaryChurch, request.church),
          row(context.l10n.profileVerifSummaryDocuments,
              context.l10n.profileVerifDocumentsPrivateCount(request.documentCount)),
        ],
      ),
    );
  }
}

/// Formulaire de demande (nom, fonction, église, liens, pièces, message).
class VerificationRequestForm extends ConsumerStatefulWidget {
  const VerificationRequestForm({
    super.key,
    required this.state,
    this.initialName = '',
    this.initialDocuments = const [],
  });
  final AccountVerificationState state;
  final String initialName;

  /// Pièces déjà choisies (tests : le sélecteur de fichiers n'est pas disponible).
  @visibleForTesting
  final List<VerificationDocument> initialDocuments;

  @override
  ConsumerState<VerificationRequestForm> createState() => _VerificationRequestFormState();
}

class _VerificationRequestFormState extends ConsumerState<VerificationRequestForm> {
  late final _nameCtrl = TextEditingController(text: widget.state.request?.fullName ?? widget.initialName);
  late final _churchCtrl = TextEditingController(text: widget.state.request?.church ?? '');
  late final _roleOtherCtrl = TextEditingController(text: widget.state.request?.roleOther ?? '');
  final _messageCtrl = TextEditingController();
  late final List<TextEditingController> _linkCtrls = [
    for (final l in (widget.state.request?.links ?? const <String>[]).take(widget.state.maxLinks))
      TextEditingController(text: l),
  ];
  late String? _role = widget.state.request?.role;
  late final List<VerificationDocument> _documents = [...widget.initialDocuments];
  Map<String, String> _errors = const {};
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (_linkCtrls.isEmpty) _linkCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _churchCtrl.dispose();
    _roleOtherCtrl.dispose();
    _messageCtrl.dispose();
    for (final c in _linkCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  bool get _documentsFull => _documents.length >= widget.state.maxDocuments;

  void _addDocument(VerificationDocument doc) {
    final reason = verificationDocumentRejection(doc, maxKb: widget.state.maxDocumentKb);
    if (reason != null) {
      _snack(reason);
      return;
    }
    if (_documentsFull) {
      _snack(context.l10n.profileVerifDocMax(widget.state.maxDocuments));
      return;
    }
    setState(() {
      _documents.add(doc);
      _errors = Map.of(_errors)..remove('documents');
    });
  }

  Future<void> _takePhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 85);
    if (img == null || !mounted) return;
    final size = await img.length();
    final name = img.name.contains('.') ? img.name : '${img.name}.jpg';
    _addDocument(VerificationDocument(
      name: name,
      size: size,
      path: kIsWeb ? null : img.path,
      bytes: kIsWeb ? await img.readAsBytes() : null,
    ));
  }

  Future<void> _pickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: kVerificationDocumentExtensions,
    );
    if (f == null || !mounted) return;
    if (!kIsWeb && f.path == null) return;
    final bytes = kIsWeb ? await f.readAsBytes() : null;
    if (!mounted) return;
    _addDocument(VerificationDocument(name: f.name, size: f.size, path: kIsWeb ? null : f.path, bytes: bytes));
  }

  Future<void> _submit() async {
    final links = _linkCtrls.map((c) => c.text).toList();
    final errors = validateVerificationForm(
      fullName: _nameCtrl.text,
      role: _role,
      roleOther: _roleOtherCtrl.text,
      church: _churchCtrl.text,
      links: links,
      documents: _documents,
      maxDocuments: widget.state.maxDocuments,
    );
    setState(() {
      _errors = errors;
      _error = errors.isEmpty ? null : context.l10n.profileVerifFixFields;
    });
    if (errors.isNotEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(accountVerificationRepositoryProvider).submit(
            fullName: _nameCtrl.text,
            role: _role!,
            roleOther: _roleOtherCtrl.text,
            church: _churchCtrl.text,
            links: links,
            message: _messageCtrl.text,
            documents: _documents,
          );
    } on LaravelApiException catch (e) {
      if (!mounted) return;
      final fieldErrors = <String, String>{};
      e.errors?.forEach((key, value) {
        final msg = value is List && value.isNotEmpty ? '${value.first}' : '$value';
        fieldErrors[key.startsWith('documents.') ? 'documents' : key] = msg;
      });
      setState(() {
        _sending = false;
        _errors = fieldErrors;
        _error = fieldErrors.isEmpty ? e.message : context.l10n.profileVerifFixFields;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = context.l10n.profileVerifSendFailed;
      });
      return;
    }
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user != null) {
      await ref
          .read(authStateProvider.notifier)
          .updateCurrentUser(user.copyWith(verificationStatus: VerificationStatus.pending));
    }
    if (!mounted) return;
    setState(() => _sending = false);
    _snack(context.l10n.profileVerifSent);
    ref.invalidate(accountVerificationProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = context.l10n;
    const sectionStyle = TextStyle(
        fontFamily: AppFonts.family, fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary);
    const hintStyle =
        TextStyle(fontFamily: AppFonts.family, fontSize: 12, height: 1.4, color: AppColors.textSecondary);
    const errorStyle = TextStyle(fontFamily: AppFonts.family, fontSize: 12, height: 1.4, color: AppColors.danger);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppShadows.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: l10n.profileVerifFullNameLabel,
            helperText: l10n.profileVerifFullNameHelper,
            controller: _nameCtrl,
            errorText: _errors['full_name'],
            maxLength: 150,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.profileVerifRoleLabel, style: sectionStyle),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final r in state.roles)
                ChoiceChip(
                  key: ValueKey('role-${r.value}'),
                  label: Text(r.label),
                  selected: _role == r.value,
                  onSelected: (_) => setState(() {
                    _role = r.value;
                    _errors = Map.of(_errors)..remove('role');
                  }),
                ),
            ],
          ),
          if (_errors['role'] != null) ...[
            const SizedBox(height: 4),
            Text(_errors['role']!, style: errorStyle),
          ],
          if (_role == 'other') ...[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: l10n.profileVerifRoleOtherLabel,
              controller: _roleOtherCtrl,
              errorText: _errors['role_other'],
              maxLength: 100,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.profileVerifChurchLabel,
            hint: l10n.profileVerifChurchHint,
            controller: _churchCtrl,
            errorText: _errors['church'],
            maxLength: 150,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.profileVerifLinksLabel, style: sectionStyle),
          const SizedBox(height: 2),
          Text(l10n.profileVerifLinksHint, style: hintStyle),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _linkCtrls.length; i++) ...[
            AppTextField(
              hint: 'https://',
              controller: _linkCtrls[i],
              keyboardType: TextInputType.url,
              errorText: _errors['links.$i'],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_linkCtrls.length < state.maxLinks)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _linkCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: Text(l10n.profileVerifAddLink),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.profileVerifDocumentsLabel, style: sectionStyle),
          const SizedBox(height: 2),
          Text(
            l10n.profileVerifDocumentsHint(state.maxDocumentKb ~/ 1024, state.maxDocuments),
            style: hintStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _documents.length; i++)
            _DocumentTile(
              key: ValueKey('doc-$i-${_documents[i].name}'),
              document: _documents[i],
              onRemove: _sending ? null : () => setState(() => _documents.removeAt(i)),
            ),
          if (!_documentsFull)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (!kIsWeb)
                  OutlinedButton.icon(
                    onPressed: _sending ? null : _takePhoto,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(l10n.profileVerifTakePhoto),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('pick-document'),
                  onPressed: _sending ? null : _pickFile,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(l10n.profileVerifPickFile),
                ),
              ],
            ),
          if (_errors['documents'] != null) ...[
            const SizedBox(height: 4),
            Text(_errors['documents']!, style: errorStyle),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.profileVerifDocumentsPrivate,
                  style: hintStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.profileVerifMessageLabel,
            hint: l10n.profileVerifMessageHint,
            controller: _messageCtrl,
            maxLines: 4,
            minLines: 2,
            maxLength: 1000,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, key: const ValueKey('verification-error'), style: errorStyle.copyWith(fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            key: const ValueKey('verification-submit'),
            label: l10n.profileVerifSubmit,
            size: AppButtonSize.large,
            fullWidth: true,
            isLoading: _sending,
            onPressed: _sending ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({super.key, required this.document, this.onRemove});
  final VerificationDocument document;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final kb = (document.size / 1024).ceil();
    final size = kb >= 1024
        ? context.l10n.profileFileSizeMb((kb / 1024).toStringAsFixed(1))
        : context.l10n.profileFileSizeKb(kb);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(document.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
              color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppFonts.family, fontSize: 13, color: AppColors.textPrimary)),
                Text(size,
                    style: const TextStyle(fontFamily: AppFonts.family, fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonRemove,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppFonts.family, fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppFonts.family, fontSize: 13, height: 1.45, color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

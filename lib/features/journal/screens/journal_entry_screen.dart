import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers/categories_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/audio_player_service.dart';
import '../../../shared/utils/rich_text_utils.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/journal_offline_controller.dart';
import '../data/journal_repository.dart';
import '../models/journal_entry.dart';
import 'journal_screen.dart' show journalDayLabel, journalTypeIcon;

/// Lire une entrée du carnet privé ; la partager, la ranger ou la supprimer.
class JournalEntryScreen extends ConsumerStatefulWidget {
  const JournalEntryScreen({required this.entryId, this.initialEntry, super.key});

  final String entryId;

  /// Entrée déjà chargée par la liste du carnet : affichée immédiatement,
  /// sans dépendre de `GET /testimonies/{id}`.
  final JournalEntry? initialEntry;

  @override
  ConsumerState<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends ConsumerState<JournalEntryScreen> {
  late JournalEntry? _entry = widget.initialEntry;
  String? _error;
  bool _busy = false;

  /// Audio / vidéo présent sur le téléphone (copie hors ligne).
  File? _localMedia;

  @override
  void initState() {
    super.initState();
    unawaited(_findLocalMedia());
    unawaited(_load());
  }

  /// Rafraîchit l'entrée depuis le serveur. Si elle vient de la liste, un
  /// échec est sans conséquence : on garde ce qui est déjà affiché. Sans
  /// connexion, on la cherche dans la copie du téléphone.
  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final e = await ref.read(journalRepositoryProvider).show(widget.entryId);
      if (mounted) setState(() => _entry = e);
    } on JournalFailure catch (e) {
      if (_entry == null && e.statusCode == 0) await _loadFromPhone();
      if (mounted && _entry == null) setState(() => _error = e.message);
    }
    unawaited(_findLocalMedia());
  }

  Future<void> _loadFromPhone() async {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null || !kJournalOfflineSupported) return;
    final local = await ref.read(journalOfflineStoreProvider).readEntries(uid);
    final found = local.where((e) => e.id == widget.entryId).firstOrNull;
    if (found != null && mounted) setState(() => _entry = found);
  }

  Future<void> _findLocalMedia() async {
    final uid = ref.read(currentUserProvider)?.id;
    final entry = _entry;
    if (uid == null || entry == null || !kJournalOfflineSupported) return;
    final file = await ref.read(journalOfflineStoreProvider).localMedia(uid, entry);
    if (mounted && file?.path != _localMedia?.path) setState(() => _localMedia = file);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.danger : null,
      content: Text(msg),
    ));
  }

  Future<void> _run(Future<JournalEntry> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _entry = updated);
      ref.read(journalRefreshProvider.notifier).bump();
      _snack(success);
    } on JournalFailure catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(JournalEntry entry) async {
    final category = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _ShareSheet(initialCategory: entry.category),
    );
    if (category == null || !mounted) return;
    await _run(
      () => ref.read(journalRepositoryProvider).share(entry.id, category: category),
      'Témoignage partagé : il sera visible après validation par un modérateur.',
    );
  }

  Future<void> _moveBack(JournalEntry entry) async {
    await _run(
      () => ref.read(journalRepositoryProvider).moveToJournal(entry.id),
      'Rangé dans votre carnet privé 🔒',
    );
  }

  Future<void> _delete(JournalEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce témoignage ?'),
        content: const Text('Il sera définitivement effacé de votre carnet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(journalRepositoryProvider).delete(entry.id);
      if (!mounted) return;
      ref.read(journalRefreshProvider.notifier).bump();
      _snack('Témoignage supprimé.');
      context.canPop() ? context.pop() : context.go('/journal');
    } on JournalFailure catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon carnet'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (entry != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _delete(entry);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                    title: Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: entry == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(onPressed: _load, child: const Text('Réessayer')),
                        ],
                      ),
                    ),
            )
          : _buildEntry(entry),
      bottomNavigationBar: entry == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: entry.isPrivate
                    ? FilledButton.icon(
                        onPressed: _busy ? null : () => _share(entry),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.campaign_rounded),
                        label: const Text('Partager ce témoignage'),
                      )
                    : OutlinedButton.icon(
                        onPressed: _busy ? null : () => _moveBack(entry),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        icon: const Icon(Icons.lock_outline_rounded),
                        label: const Text('Ne plus partager · ranger dans mon carnet'),
                      ),
              ),
            ),
    );
  }

  Widget _buildEntry(JournalEntry entry) {
    final categories = ref.watch(categoriesListProvider);
    final categoryName = categories
        .where((c) => c.slug == entry.category)
        .map((c) => c.name)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _StatusChip(entry: entry),
        const SizedBox(height: 12),
        Text(entry.title, style: AppTextStyles.h3),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Meta(icon: journalTypeIcon(entry.type), text: entry.type.label),
            if (entry.createdAt != null)
              _Meta(icon: Icons.event_rounded, text: journalDayLabel(entry.createdAt!)),
            if (categoryName != null && entry.category != 'autre')
              _Meta(icon: Icons.label_outline_rounded, text: categoryName),
          ],
        ),
        const SizedBox(height: 18),

        if (entry.type == JournalEntryType.video && entry.mediaUrl != null)
          // Copie du téléphone si elle existe (lecture sans connexion).
          _JournalVideo(
            key: ValueKey(_localMedia?.path ?? entry.mediaUrl),
            url: entry.mediaUrl!,
            file: _localMedia,
          )
        else if (entry.type == JournalEntryType.audio && entry.mediaUrl != null)
          _JournalAudio(
            url: _localMedia?.path ?? entry.mediaUrl!,
            durationSeconds: entry.durationSeconds,
          )
        else if (entry.coverUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(imageUrl: entry.coverUrl!, fit: BoxFit.cover),
          ),
        if (_localMedia != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.offline_pin_rounded, size: 15, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Disponible hors ligne sur ce téléphone',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              ],
            ),
          ),
        if (entry.mediaUrl != null || entry.coverUrl != null) const SizedBox(height: 18),

        if (entry.body.trim().isNotEmpty)
          buildRichBody(entry.body, AppTextStyles.bodyLarge),

        if ((entry.bibleVerse ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              [entry.bibleVerse!, if ((entry.verseReference ?? '').isNotEmpty) '— ${entry.verseReference}']
                  .join('\n'),
              style: AppTextStyles.verseQuote,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Morceaux d'écran ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.entry});
  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = entry.isPrivate
        ? (Icons.lock_rounded, 'Privé · visible par vous seul', AppColors.primary)
        : entry.isPendingReview
            ? (Icons.hourglass_top_rounded, 'Partagé · en attente de validation', AppColors.secondary)
            : (Icons.public_rounded, 'Partagé', AppColors.success);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Lecteur audio simple, branché sur le lecteur global de l'app.
class _JournalAudio extends ConsumerWidget {
  const _JournalAudio({required this.url, required this.durationSeconds});
  final String url;
  final int durationSeconds;

  static String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final isThis = player.url == url;
    final playing = isThis && player.isPlaying;
    final total = isThis && player.duration > Duration.zero
        ? player.duration
        : Duration(seconds: durationSeconds);

    // Échec de lecture (fichier introuvable sur le serveur, réseau…).
    if (isThis && player.error != null && !player.isPlaying) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            const Expanded(
              child: Text("Impossible de lire l'enregistrement audio."),
            ),
            TextButton(
              onPressed: () async {
                await notifier.stop(); // oublie l'échec, puis nouvel essai
                await notifier.play(url);
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: () => playing ? notifier.pause() : notifier.play(url),
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: isThis && player.isLoading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
          ),
          Expanded(
            child: Slider(
              value: isThis ? player.progress.clamp(0.0, 1.0) : 0,
              onChanged: isThis ? (v) => notifier.seekToFraction(v) : null,
              activeColor: AppColors.primary,
            ),
          ),
          Text(
            '${_fmt(isThis ? player.position : Duration.zero)} / ${_fmt(total)}',
            style: AppTextStyles.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Lecteur vidéo simple (sans commentaires ni suggestions : c'est privé).
class _JournalVideo extends StatefulWidget {
  const _JournalVideo({required this.url, this.file, super.key});
  final String url;

  /// Fichier sur le téléphone (copie hors ligne), prioritaire sur [url].
  final File? file;

  @override
  State<_JournalVideo> createState() => _JournalVideoState();
}

class _JournalVideoState extends State<_JournalVideo> {
  late final VideoPlayerController _video =
      widget.file != null
          ? VideoPlayerController.file(widget.file!)
          : VideoPlayerController.networkUrl(Uri.parse(widget.url));
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _video.initialize().then((_) {
      if (!mounted) return;
      setState(() => _chewie = ChewieController(
            videoPlayerController: _video,
            aspectRatio: _video.value.aspectRatio,
            autoPlay: false,
          ));
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: _chewie != null ? _video.value.aspectRatio : 9 / 16,
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: _failed
              ? const Text('Impossible de lire la vidéo.',
                  style: TextStyle(color: Colors.white70))
              : _chewie == null
                  ? const CircularProgressIndicator(color: Colors.white70)
                  : Chewie(controller: _chewie!),
        ),
      ),
    );
  }
}

/// Partage : catégorie + confirmation d'authenticité. Renvoie la catégorie.
class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.initialCategory});
  final String initialCategory;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  String? _category;
  bool _consent = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final valid = categories.any((c) => c.slug == _category);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partager ce témoignage', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Il quittera votre carnet privé et sera relu par un modérateur '
              'avant d\'être visible par tous. Vous pourrez toujours le reprendre.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: valid ? _category : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.slug, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('Je certifie que ce témoignage est réel'),
              subtitle: const Text('Les faits sont authentiques et vécus personnellement.'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _consent && valid ? () => Navigator.pop(context, _category) : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Partager'),
            ),
          ],
        ),
      ),
    );
  }
}

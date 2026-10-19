import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../../../core/media/youtube.dart' show extractYouTubeId;
import '../../../core/providers/categories_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../../events/data/events_repository.dart';
import '../../events/models/event_models.dart';
import '../data/live_repository.dart';
import '../models/ip_camera_config.dart';
import '../models/live_models.dart';
import '../widgets/ip_camera_form.dart';
import 'live_studio_screen.dart';

enum _CheckState { pending, ok, warning, failed }

class _Check {
  /// Message déjà rédigé (erreur renvoyée par le serveur, nom de réseau).
  const _Check(this.state, String message)
      : _message = message,
        _text = null,
        needsSettings = false;

  /// Message traduit au moment de l'affichage (suit un changement de langue).
  const _Check.l10n(this.state, String Function(AppLocalizations l) text,
      {this.needsSettings = false})
      : _text = text,
        _message = null;

  final _CheckState state;
  final String? _message;
  final String Function(AppLocalizations l)? _text;

  String message(AppLocalizations l10n) => _message ?? _text!(l10n);

  /// Autorisation refusée définitivement : à accorder dans les réglages.
  final bool needsSettings;
}

/// Préparer un direct (modérateurs / administrateurs) : vérifications,
/// aperçu caméra, titre et options, puis ouverture du studio.
///
/// [eventId] : direct d'un événement, que son organisateur (organisation
/// vérifiée) peut lancer sans être modérateur (docs serveur
/// fonctionnalites/evenements.md).
class LiveSetupScreen extends ConsumerStatefulWidget {
  const LiveSetupScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<LiveSetupScreen> createState() => _LiveSetupScreenState();
}

class _LiveSetupScreenState extends ConsumerState<LiveSetupScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  /// Lien du direct YouTube (source youtube).
  final _youtubeUrl = TextEditingController();

  /// Réponse de GET /lives : LiveKit configuré, directs YouTube possibles (null : pas encore lu).
  ({bool liveKit, bool youtube})? _services;
  /// Caméra IP (mode url) : adresse composée par [IpCameraForm] et réglage
  /// structuré (mémorisé sans mot de passe après la création du direct).
  String _cameraUrl = '';
  IpCameraConfig? _ipCamera;
  String? _category;
  bool _commentsEnabled = true;

  /// Événement diffusé (chargé depuis [LiveSetupScreen.eventId]).
  ChristianEvent? _event;

  /// Caméra utilisée : appareil, caméra IP / encodeur (RTMP) ou adresse de flux.
  LiveSource _source = LiveSource.browser;

  _Check _rights = _Check.l10n(_CheckState.pending, (l) => l.liveCheckPending);
  _Check _service = _Check.l10n(_CheckState.pending, (l) => l.liveCheckPending);
  _Check _network = _Check.l10n(_CheckState.pending, (l) => l.liveCheckPending);
  _Check _camera = _Check.l10n(_CheckState.pending, (l) => l.liveCheckPending);
  _Check _micro = _Check.l10n(_CheckState.pending, (l) => l.liveCheckPending);

  lk.LocalVideoTrack? _preview;
  lk.CameraPosition _position = lk.CameraPosition.front;

  /// true une fois l'aperçu confié au studio (qui le publie et le libère).
  bool _handedOff = false;
  bool _submitting = false;

  /// Caméra externe : caméra et micro de l'appareil ne sont pas vérifiés.
  bool get _allOk => [
        _rights,
        _service,
        _network,
        if (!_source.isExternal) ...[_camera, _micro],
      ].every((c) => c.state == _CheckState.ok || c.state == _CheckState.warning);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_runChecks());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour des réglages système après avoir autorisé caméra / micro.
    if (state == AppLifecycleState.resumed &&
        !_source.isExternal &&
        (_camera.state == _CheckState.failed ||
            _micro.state == _CheckState.failed)) {
      unawaited(_checkDevices());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _title.dispose();
    _description.dispose();
    _youtubeUrl.dispose();
    if (!_handedOff) unawaited(_preview?.stop());
    super.dispose();
  }

  // ── Vérifications ───────────────────────────────────────────────────────

  Future<void> _runChecks() async {
    final user = ref.read(currentUserProvider);
    final eventId = widget.eventId;
    if (eventId != null) {
      // Direct d'un événement : le titre reprend celui de l'événement.
      try {
        final e = await ref.read(eventsRepositoryProvider).show(eventId);
        if (!mounted) return;
        setState(() {
          _event = e;
          if (_title.text.isEmpty) _title.text = e.title;
          _rights = e.canManage
              ? _Check.l10n(_CheckState.ok, (l) => l.liveCheckEventOrganizer)
              : _Check.l10n(_CheckState.failed, (l) => l.liveCheckEventOrganizerOnly);
        });
      } on EventFailure catch (e) {
        if (mounted) setState(() => _rights = _Check(_CheckState.failed, e.message));
      }
    } else {
      setState(() => _rights = user?.canModerate == true
          ? _Check.l10n(_CheckState.ok, (l) => l.liveCheckModeratorAccount)
          : _Check.l10n(_CheckState.failed, (l) => l.liveCheckModeratorsOnly));
    }

    await Future.wait([
      _checkService(),
      _checkNetwork(),
      if (!_source.isExternal) _checkDevices(),
    ]);
  }

  /// Changement de caméra : libère la caméra de l'appareil pour une caméra
  /// externe, la rouvre (avec les autorisations) pour l'appareil.
  Future<void> _selectSource(LiveSource source) async {
    if (source == _source) return;
    setState(() => _source = source);
    _applyService();
    if (source.isExternal) {
      final preview = _preview;
      setState(() => _preview = null);
      await preview?.stop();
    } else {
      await _checkDevices();
    }
  }

  Future<void> _checkService() async {
    try {
      final index = await ref.read(liveRepositoryProvider).index();
      if (!mounted) return;
      _services = (liveKit: index.configured, youtube: index.youtubeEnabled);
      // Pas de LiveKit sur ce serveur : le lien YouTube est la seule possibilité.
      if (!index.configured && index.youtubeEnabled && !_source.isYoutube) {
        await _selectSource(LiveSource.youtube);
      }
      _applyService();
    } on LiveFailure catch (e) {
      if (mounted) setState(() => _service = _Check(_CheckState.failed, e.message));
    }
  }

  /// Service vidéo selon la source : LiveKit, ou YouTube (pas de LiveKit).
  void _applyService() {
    final s = _services;
    if (s == null || !mounted) return;
    setState(() => _service = _source.isYoutube
        ? (s.youtube
            ? _Check.l10n(_CheckState.ok, (l) => l.liveCheckYoutubeOk)
            : _Check.l10n(_CheckState.failed, (l) => l.liveCheckServiceMissing))
        : (s.liveKit
            ? _Check.l10n(_CheckState.ok, (l) => l.liveCheckServiceOk)
            : _Check.l10n(_CheckState.failed, (l) => l.liveCheckServiceMissing)));
  }

  Future<void> _checkNetwork() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        _network = const _Check(_CheckState.ok, 'Wi-Fi'); // i18n-ignore
      } else if (results.contains(ConnectivityResult.mobile)) {
        _network = _Check.l10n(_CheckState.warning, (l) => l.liveCheckMobileData);
      } else if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        _network = _Check.l10n(_CheckState.failed, (l) => l.liveCheckNoInternet);
      } else {
        _network = _Check.l10n(_CheckState.ok, (l) => l.liveCheckConnected);
      }
    });
  }

  Future<void> _checkDevices() async {
    final statuses =
        await [Permission.camera, Permission.microphone].request();
    if (!mounted || _source.isExternal) return;

    _Check describe(PermissionStatus? s, {required bool mic}) => switch (s) {
          PermissionStatus.granted ||
          PermissionStatus.limited =>
            _Check.l10n(_CheckState.ok,
                (l) => mic ? l.liveCheckMicGranted : l.liveCheckCameraGranted),
          PermissionStatus.permanentlyDenied => _Check.l10n(_CheckState.failed,
              (l) => mic ? l.liveCheckMicDeniedForever : l.liveCheckCameraDeniedForever,
              needsSettings: true),
          PermissionStatus.restricted => _Check.l10n(_CheckState.failed,
              (l) => mic ? l.liveCheckMicRestricted : l.liveCheckCameraRestricted),
          _ => _Check.l10n(_CheckState.failed,
              (l) => mic ? l.liveCheckMicDenied : l.liveCheckCameraDenied),
        };

    setState(() {
      _camera = describe(statuses[Permission.camera], mic: false);
      _micro = describe(statuses[Permission.microphone], mic: true);
    });

    if (_camera.state == _CheckState.ok && _preview == null) {
      await _openPreview();
    }
  }

  Future<void> _openPreview() async {
    try {
      final track = await lk.LocalVideoTrack.createCameraTrack(
        lk.CameraCaptureOptions(cameraPosition: _position),
      );
      if (!mounted) {
        await track.stop();
        return;
      }
      setState(() => _preview = track);
    } catch (e) {
      if (mounted) {
        setState(() => _camera = _Check.l10n(_CheckState.failed, (l) => l.liveCheckCameraBusy));
      }
    }
  }

  Future<void> _switchCamera() async {
    final next = _position == lk.CameraPosition.front
        ? lk.CameraPosition.back
        : lk.CameraPosition.front;
    try {
      await _preview?.setCameraPosition(next);
      setState(() => _position = next);
    } catch (_) {}
  }

  Future<void> _fixCheck(_Check c) async {
    if (c.state != _CheckState.failed) return;
    if (identical(c, _camera) || identical(c, _micro)) {
      final permanently = c.needsSettings;
      if (permanently) {
        await openAppSettings();
      } else {
        await _checkDevices();
      }
    } else if (identical(c, _network)) {
      await _checkNetwork();
    } else if (identical(c, _service)) {
      await _checkService();
    }
  }

  // ── Lancement ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || !_allOk || _submitting) return;
    setState(() => _submitting = true);
    final repo = ref.read(liveRepositoryProvider);
    try {
      final (live, creds) = await repo.start(
        title: _title.text.trim(),
        description: _description.text.trim(),
        categorySlug: _category,
        commentsEnabled: _commentsEnabled,
        source: _source,
        cameraUrl: _source == LiveSource.url ? _cameraUrl : null,
        youtubeUrl: _source.isYoutube ? _youtubeUrl.text.trim() : null,
        eventId: widget.eventId,
      );
      if (_source == LiveSource.url && _ipCamera != null) {
        unawaited(IpCameraForm.remember(ref, _ipCamera!));
      }
      if (!mounted) return;
      if (creds == null || live.source.isYoutube) {
        // Direct YouTube : à l'antenne dès sa création, ouvert dans la vue YouTube.
        context.pushReplacement('/lives/${live.id}');
        return;
      }
      _openStudio(LiveStudioArgs(
        live: live,
        credentials: creds,
        // Caméra externe : l'aperçu local n'est pas publié.
        previewTrack: _source.isExternal ? null : _preview,
        cameraPosition: _position,
      ));
    } on LiveFailure catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.liveId != null) {
        await _offerResume(e.liveId!, e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating, content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Un direct est déjà en cours (409) : proposer de le reprendre.
  Future<void> _offerResume(String liveId, String message) async {
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.liveAlreadyRunningTitle),
        content: Text(context.l10n.liveAlreadyRunningBody(message)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.commonCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.liveResume)),
        ],
      ),
    );
    if (resume != true || !mounted) return;
    _openStudio(LiveStudioArgs.resume(
      liveId,
      previewTrack: _source.isExternal ? null : _preview,
      cameraPosition: _position,
    ));
  }

  void _openStudio(LiveStudioArgs args) {
    _handedOff = args.previewTrack != null;
    context.pushReplacement('/lives/${args.liveId}/studio', extra: args);
  }

  // ── Interface ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesListProvider);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.livesGoLive),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (_event != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: l10n.liveEventLiveLabel),
                          TextSpan(
                            text: _event!.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(l10n.liveCameraUsed, style: AppTextStyles.h4),
            const SizedBox(height: 4),
            RadioGroup<LiveSource>(
              groupValue: _source,
              onChanged: (v) {
                if (v != null) unawaited(_selectSource(v));
              },
              child: Column(
                children: [
                  RadioListTile<LiveSource>(
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.browser,
                    title: Text(l10n.liveSourceDevice),
                  ),
                  RadioListTile<LiveSource>(
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.rtmp,
                    title: Text(l10n.liveSourceRtmp),
                    subtitle: Text(l10n.liveSourceRtmpHint),
                  ),
                  RadioListTile<LiveSource>(
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.url,
                    title: Text(l10n.liveSourceUrl),
                    subtitle: Text(l10n.liveSourceUrlHint),
                  ),
                  RadioListTile<LiveSource>(
                    key: const ValueKey('live-source-youtube'),
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.youtube,
                    title: Text(l10n.liveSourceYoutube),
                    subtitle: Text(l10n.liveSourceYoutubeHint),
                  ),
                ],
              ),
            ),
            if (_source == LiveSource.url) ...[
              const SizedBox(height: 8),
              IpCameraForm(
                onChanged: (url, config) {
                  _cameraUrl = url;
                  _ipCamera = config;
                },
              ),
            ],
            const SizedBox(height: 12),
            if (_source.isYoutube) ...[
              TextFormField(
                key: const ValueKey('live-youtube-url'),
                controller: _youtubeUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.liveYoutubeUrlLabel,
                  hintText: 'https://www.youtube.com/live/…', // i18n-ignore
                  prefixIcon: const Icon(Icons.smart_display_outlined),
                ),
                validator: (v) => extractYouTubeId(v ?? '') != null ? null : l10n.liveYoutubeUrlInvalid,
              ),
              const SizedBox(height: 12),
              const _YoutubeHelp(),
            ] else if (_source.isExternal)
              _ExternalCameraHelp(source: _source)
            else
              _PreviewBox(
                track: _preview,
                position: _position,
                onSwitch: _preview == null ? null : _switchCamera,
              ),
            const SizedBox(height: 16),
            Text(l10n.liveChecks, style: AppTextStyles.h4),
            const SizedBox(height: 8),
            _CheckTile(icon: Icons.verified_user_outlined, label: l10n.liveCheckRights, check: _rights),
            _CheckTile(icon: Icons.cloud_outlined, label: l10n.liveCheckService, check: _service, onTap: () => _fixCheck(_service)),
            _CheckTile(icon: Icons.network_check_rounded, label: l10n.liveCheckNetwork, check: _network, onTap: () => _fixCheck(_network)),
            if (!_source.isExternal) ...[
              _CheckTile(icon: Icons.videocam_outlined, label: l10n.liveCheckCamera, check: _camera, onTap: () => _fixCheck(_camera)),
              _CheckTile(icon: Icons.mic_none_rounded, label: l10n.liveCheckMic, check: _micro, onTap: () => _fixCheck(_micro)),
            ],
            const SizedBox(height: 20),
            Text(l10n.liveYourLive, style: AppTextStyles.h4),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.liveTitleLabel,
                hintText: l10n.liveTitleHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.liveTitleRequired
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              maxLength: 1000,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.liveDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.liveCategoryLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String>(value: null, child: Text(l10n.liveCategoryNone)),
                for (final c in categories)
                  DropdownMenuItem(value: c.slug, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _commentsEnabled,
              onChanged: (v) => setState(() => _commentsEnabled = v),
              title: Text(l10n.liveAllowComments),
              subtitle: Text(l10n.liveAllowCommentsHint),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _allOk && !_submitting ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sensors_rounded),
              label: Text(l10n.liveOpenStudio),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.liveInvisibleUntilOnAir,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mode d'emploi d'un direct YouTube (pas de LiveKit).
class _YoutubeHelp extends StatelessWidget {
  const _YoutubeHelp();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [l10n.liveYoutubeStep1, l10n.liveYoutubeStep2, l10n.liveYoutubeStep3];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_display_rounded, color: Color(0xFFE11D48)),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.liveYoutubeHelpTitle, style: AppTextStyles.h4)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${i + 1}. ${steps[i]}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.5)),
            ),
        ],
      ),
    );
  }
}

/// Mode d'emploi à la place de l'aperçu quand la caméra est externe.
class _ExternalCameraHelp extends StatelessWidget {
  const _ExternalCameraHelp({required this.source});

  final LiveSource source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = source == LiveSource.rtmp
        ? [l10n.liveRtmpStep1, l10n.liveRtmpStep2, l10n.liveRtmpStep3]
        : [l10n.liveUrlStep1, l10n.liveUrlStep2, l10n.liveUrlStep3];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_input_antenna_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.liveConnectIpCamera, style: AppTextStyles.h4)),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${i + 1}. ${steps[i]}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.5)),
            ),
          const SizedBox(height: 6),
          Text(
            l10n.liveExternalCameraNote,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.track, required this.position, this.onSwitch});

  final lk.LocalVideoTrack? track;
  final lk.CameraPosition position;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF120A1F)),
            if (track != null)
              lk.VideoTrackRenderer(
                track!,
                fit: lk.VideoViewFit.cover,
                mirrorMode: position == lk.CameraPosition.front
                    ? lk.VideoViewMirrorMode.mirror
                    : lk.VideoViewMirrorMode.off,
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
                    const SizedBox(height: 8),
                    Text(context.l10n.liveCameraPreview,
                        style: const TextStyle(color: Colors.white54, fontFamily: 'Plus Jakarta Sans')),
                  ],
                ),
              ),
            if (onSwitch != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: IconButton.filled(
                  onPressed: onSwitch,
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  tooltip: context.l10n.liveSwitchCamera,
                  icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.icon, required this.label, required this.check, this.onTap});

  final IconData icon;
  final String label;
  final _Check check;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (statusIcon, color) = switch (check.state) {
      _CheckState.pending => (Icons.hourglass_empty_rounded, AppColors.textSecondary),
      _CheckState.ok => (Icons.check_circle_rounded, AppColors.success),
      _CheckState.warning => (Icons.warning_amber_rounded, AppColors.secondary),
      _CheckState.failed => (Icons.cancel_rounded, AppColors.danger),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: check.state == _CheckState.failed ? onTap : null,
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(check.message(context.l10n)),
      trailing: check.state == _CheckState.pending
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(statusIcon, color: color),
    );
  }
}

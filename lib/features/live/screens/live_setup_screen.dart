import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

import '../../../core/providers/categories_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/live_repository.dart';
import '../models/live_models.dart';
import 'live_studio_screen.dart';

enum _CheckState { pending, ok, warning, failed }

class _Check {
  const _Check(this.state, this.message);
  final _CheckState state;
  final String message;
}

/// Préparer un direct (modérateurs / administrateurs) : vérifications,
/// aperçu caméra, titre et options, puis ouverture du studio.
class LiveSetupScreen extends ConsumerStatefulWidget {
  const LiveSetupScreen({super.key});

  @override
  ConsumerState<LiveSetupScreen> createState() => _LiveSetupScreenState();
}

class _LiveSetupScreenState extends ConsumerState<LiveSetupScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _cameraUrl = TextEditingController();
  String? _category;
  bool _commentsEnabled = true;

  /// Caméra utilisée : appareil, caméra IP / encodeur (RTMP) ou adresse de flux.
  LiveSource _source = LiveSource.browser;

  _Check _rights = const _Check(_CheckState.pending, 'Vérification…');
  _Check _service = const _Check(_CheckState.pending, 'Vérification…');
  _Check _network = const _Check(_CheckState.pending, 'Vérification…');
  _Check _camera = const _Check(_CheckState.pending, 'Vérification…');
  _Check _micro = const _Check(_CheckState.pending, 'Vérification…');

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
    _cameraUrl.dispose();
    if (!_handedOff) unawaited(_preview?.stop());
    super.dispose();
  }

  // ── Vérifications ───────────────────────────────────────────────────────

  Future<void> _runChecks() async {
    final user = ref.read(currentUserProvider);
    setState(() => _rights = user?.canModerate == true
        ? const _Check(_CheckState.ok, 'Compte modérateur ou administrateur')
        : const _Check(_CheckState.failed,
            'Seuls les modérateurs et administrateurs peuvent diffuser.'));

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
      setState(() => _service = index.configured
          ? const _Check(_CheckState.ok, 'Service vidéo disponible')
          : const _Check(_CheckState.failed,
              "Le service vidéo n'est pas encore configuré sur le serveur."));
    } on LiveFailure catch (e) {
      if (mounted) setState(() => _service = _Check(_CheckState.failed, e.message));
    }
  }

  Future<void> _checkNetwork() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        _network = const _Check(_CheckState.ok, 'Wi-Fi');
      } else if (results.contains(ConnectivityResult.mobile)) {
        _network = const _Check(_CheckState.warning,
            'Données mobiles : la vidéo consomme environ 1 Go par heure.');
      } else if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        _network = const _Check(_CheckState.failed, 'Aucune connexion Internet.');
      } else {
        _network = const _Check(_CheckState.ok, 'Connecté');
      }
    });
  }

  Future<void> _checkDevices() async {
    final statuses =
        await [Permission.camera, Permission.microphone].request();
    if (!mounted || _source.isExternal) return;

    _Check describe(PermissionStatus? s, String what) => switch (s) {
          PermissionStatus.granted ||
          PermissionStatus.limited =>
            _Check(_CheckState.ok, '$what autorisé${what == 'Micro' ? '' : 'e'}'),
          PermissionStatus.permanentlyDenied => _Check(_CheckState.failed,
              '$what refusé${what == 'Micro' ? '' : 'e'} : autorisez-l${what == 'Micro' ? 'e' : 'a'} dans les réglages.'),
          PermissionStatus.restricted => _Check(
              _CheckState.failed, '$what bloqué${what == 'Micro' ? '' : 'e'} sur cet appareil.'),
          _ => _Check(_CheckState.failed,
              '$what refusé${what == 'Micro' ? '' : 'e'}. Appuyez pour réessayer.'),
        };

    setState(() {
      _camera = describe(statuses[Permission.camera], 'Caméra');
      _micro = describe(statuses[Permission.microphone], 'Micro');
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
        setState(() => _camera = const _Check(_CheckState.failed,
            "Impossible d'ouvrir la caméra (déjà utilisée par une autre application ?)."));
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
      final permanently = c.message.contains('réglages');
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
        cameraUrl: _source == LiveSource.url ? _cameraUrl.text : null,
      );
      if (!mounted) return;
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
        title: const Text('Direct déjà en cours'),
        content: Text('$message\n\nVoulez-vous reprendre ce direct ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reprendre')),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lancer un direct'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text('Caméra utilisée', style: AppTextStyles.h4),
            const SizedBox(height: 4),
            RadioGroup<LiveSource>(
              groupValue: _source,
              onChanged: (v) {
                if (v != null) unawaited(_selectSource(v));
              },
              child: const Column(
                children: [
                  RadioListTile<LiveSource>(
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.browser,
                    title: Text('Caméra de cet appareil'),
                  ),
                  RadioListTile<LiveSource>(
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.rtmp,
                    title: Text('Caméra IP ou encodeur (RTMP)'),
                    subtitle: Text("Conseillé : le studio donne une adresse et une clé à saisir dans la caméra ou le logiciel (OBS…)."),
                  ),
                  RadioListTile<LiveSource>(
                    contentPadding: EdgeInsets.zero,
                    value: LiveSource.url,
                    title: Text('Adresse du flux de la caméra'),
                    subtitle: Text('Le service vidéo lit lui-même un flux joignable depuis Internet.'),
                  ),
                ],
              ),
            ),
            if (_source == LiveSource.url) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _cameraUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Adresse du flux *',
                  hintText: 'rtsp://, rtmp://, https:// ou srt://',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return "Indiquez l'adresse du flux de la caméra.";
                  if (!liveCameraUrlPattern.hasMatch(value)) {
                    return 'Adresse non reconnue : elle doit commencer par rtsp://, rtmp://, http(s):// ou srt://.';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),
            if (_source.isExternal)
              _ExternalCameraHelp(source: _source)
            else
              _PreviewBox(
                track: _preview,
                position: _position,
                onSwitch: _preview == null ? null : _switchCamera,
              ),
            const SizedBox(height: 16),
            Text('Vérifications', style: AppTextStyles.h4),
            const SizedBox(height: 8),
            _CheckTile(icon: Icons.verified_user_outlined, label: 'Droits', check: _rights),
            _CheckTile(icon: Icons.cloud_outlined, label: 'Service vidéo', check: _service, onTap: () => _fixCheck(_service)),
            _CheckTile(icon: Icons.network_check_rounded, label: 'Réseau', check: _network, onTap: () => _fixCheck(_network)),
            if (!_source.isExternal) ...[
              _CheckTile(icon: Icons.videocam_outlined, label: 'Caméra', check: _camera, onTap: () => _fixCheck(_camera)),
              _CheckTile(icon: Icons.mic_none_rounded, label: 'Micro', check: _micro, onTap: () => _fixCheck(_micro)),
            ],
            const SizedBox(height: 20),
            Text('Votre direct', style: AppTextStyles.h4),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Titre *',
                hintText: 'Ex. : Comment Dieu m\'a relevé',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Merci de donner un titre au direct.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              maxLength: 1000,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Présentation (facultatif)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Catégorie (facultatif)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Aucune')),
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
              title: const Text('Autoriser les commentaires'),
              subtitle: const Text('Vous pourrez masquer un commentaire ou exclure une personne.'),
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
              label: const Text('Ouvrir le studio'),
            ),
            const SizedBox(height: 8),
            Text(
              'Le direct reste invisible du public tant que vous n\'êtes pas passé à l\'antenne.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
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
    final steps = source == LiveSource.rtmp
        ? const [
            "Ouvrez le studio : il affiche l'adresse du serveur et la clé de diffusion.",
            'Saisissez-les dans la caméra, OBS, vMix ou votre encodeur, puis lancez la diffusion.',
            "Quand l'image apparaît dans le studio, appuyez sur « Passer à l'antenne ».",
          ]
        : const [
            "Le service vidéo se connecte à l'adresse indiquée (elle doit être joignable depuis Internet).",
            "Vérifiez l'aperçu dans le studio.",
            "Appuyez sur « Passer à l'antenne » : le direct ne démarre jamais tout seul.",
          ];
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
              Expanded(child: Text('Brancher une caméra IP', style: AppTextStyles.h4)),
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
            "Caméra et micro de ce téléphone ne sont pas utilisés. Réglages conseillés : 720p, 2 à 4 Mbit/s, image clé toutes les 2 secondes, son AAC.",
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
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
                    SizedBox(height: 8),
                    Text('Aperçu de la caméra',
                        style: TextStyle(color: Colors.white54, fontFamily: 'Plus Jakarta Sans')),
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
                  tooltip: 'Changer de caméra',
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
      subtitle: Text(check.message),
      trailing: check.state == _CheckState.pending
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(statusIcon, color: color),
    );
  }
}

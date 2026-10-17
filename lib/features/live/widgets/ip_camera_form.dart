// Formulaire de connexion à une caméra IP (direct en mode « Adresse du flux »).
// Compose l'adresse envoyée dans `camera_url` ; mode « Adresse complète » pour
// coller une adresse. Doc backend : docs/fonctionnalites/lives-camera-ip.md

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_service.dart' show secureStorageProvider;
import '../models/ip_camera_config.dart';
import '../models/live_models.dart' show liveCameraUrlPattern;

/// Clé du dernier réglage mémorisé (sans mot de passe).
const ipCameraStorageKey = 'live_ip_camera_last';

class IpCameraForm extends ConsumerStatefulWidget {
  const IpCameraForm({super.key, required this.onChanged});

  /// Adresse à envoyer (`camera_url`) et réglage structuré (null en mode
  /// « Adresse complète » si l'adresse n'est pas lisible).
  final void Function(String url, IpCameraConfig? config) onChanged;

  /// Mémorise le réglage sur l'appareil, sans mot de passe ni phrase secrète.
  static Future<void> remember(WidgetRef ref, IpCameraConfig config) async {
    try {
      await ref
          .read(secureStorageProvider)
          .write(key: ipCameraStorageKey, value: jsonEncode(config.toStorage()));
    } catch (_) {}
  }

  @override
  ConsumerState<IpCameraForm> createState() => _IpCameraFormState();
}

class _IpCameraFormState extends ConsumerState<IpCameraForm> {
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _path = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _streamId = TextEditingController();
  final _passphrase = TextEditingController();
  final _url = TextEditingController();

  IpCameraProtocol _protocol = IpCameraProtocol.rtsp;
  IpCameraPreset _preset = IpCameraPreset.other;
  IpCameraStream _stream = IpCameraStream.main;
  bool _advanced = false;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    _port.text = '${_protocol.defaultPort}';
    for (final c in [_host, _port, _path, _username, _password, _streamId, _passphrase, _url]) {
      c.addListener(_notify);
    }
    unawaited(_restore());
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _path, _username, _password, _streamId, _passphrase, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final raw = await ref.read(secureStorageProvider).read(key: ipCameraStorageKey);
      if (raw == null || !mounted || _host.text.isNotEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) _fill(IpCameraConfig.fromStorage(decoded.cast<String, Object?>()));
    } catch (_) {}
  }

  IpCameraConfig get _config => IpCameraConfig(
        protocol: _protocol,
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()),
        path: _path.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        streamId: _streamId.text.trim(),
        passphrase: _passphrase.text,
        presetId: _preset.id,
        stream: _stream,
      );

  void _fill(IpCameraConfig c) {
    setState(() {
      _protocol = c.protocol;
      _preset = c.preset;
      _stream = c.stream;
    });
    _host.text = c.host;
    _port.text = '${c.effectivePort}';
    _path.text = c.path;
    _username.text = c.username;
    _password.text = c.password;
    _streamId.text = c.streamId;
    _passphrase.text = c.passphrase;
  }

  void _notify() {
    if (!mounted) return;
    if (_advanced) {
      final url = _url.text.trim();
      widget.onChanged(url, IpCameraConfig.parse(url));
    } else {
      final c = _config;
      widget.onChanged(c.toUrl(), c);
    }
    setState(() {}); // aperçu, avertissement
  }

  void _selectPreset(IpCameraPreset p) {
    _fill(_config.applyPreset(p));
  }

  void _selectStream(IpCameraStream s) {
    _fill(_config.applyPreset(_preset, stream: s));
  }

  void _selectProtocol(IpCameraProtocol p) {
    final current = int.tryParse(_port.text.trim());
    // Port laissé à la valeur par défaut : suit le nouveau protocole.
    if (current == null || current == _protocol.defaultPort) {
      _port.text = '${p.defaultPort}';
    }
    setState(() => _protocol = p);
    _notify();
  }

  void _toggleAdvanced(bool advanced) {
    if (advanced == _advanced) return;
    if (advanced) {
      _url.text = _host.text.trim().isEmpty ? '' : _config.toUrl();
    } else if (_url.text.trim().isNotEmpty) {
      final parsed = IpCameraConfig.parse(_url.text);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(context.l10n.liveCamUnreadableUrl),
        ));
      } else {
        _fill(parsed);
      }
    }
    setState(() => _advanced = advanced);
    _notify();
  }

  InputDecoration _decoration(String label, {String? hint, String? helper, Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  Widget _eye() => IconButton(
        tooltip: _showSecret ? context.l10n.liveCamHide : context.l10n.liveCamShow,
        icon: Icon(_showSecret ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _showSecret = !_showSecret),
      );

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final host = _advanced ? (IpCameraConfig.parse(_url.text)?.host ?? '') : config.host;
    final private = IpCameraConfig.isPrivateHost(host);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, icon: const Icon(Icons.tune_rounded), label: Text(context.l10n.liveCamModeForm)),
            ButtonSegment(value: true, icon: const Icon(Icons.link_rounded), label: Text(context.l10n.liveCamModeFullUrl)),
          ],
          selected: {_advanced},
          onSelectionChanged: (s) => _toggleAdvanced(s.first),
        ),
        const SizedBox(height: 12),
        if (_advanced) ..._advancedFields() else ..._formFields(config),
        if (private) ...[
          const SizedBox(height: 10),
          _Notice(
            color: AppColors.warningSoft,
            iconColor: AppColors.warning,
            icon: Icons.warning_amber_rounded,
            text: context.l10n.liveCamPrivateHost(host),
          ),
        ],
        const SizedBox(height: 10),
        _Notice(
          color: AppColors.primarySoft,
          iconColor: AppColors.primary,
          icon: Icons.public_rounded,
          text: context.l10n.liveCamReachableNotice,
        ),
      ],
    );
  }

  List<Widget> _advancedFields() => [
        TextFormField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          obscureText: !_showSecret,
          maxLength: IpCameraConfig.maxLength,
          decoration: _decoration(
            context.l10n.liveCamStreamUrlLabel,
            hint: context.l10n.liveCamStreamUrlHint,
            helper: context.l10n.liveCamStreamUrlHelper,
            suffix: _eye(),
          ),
          validator: (v) {
            final value = v?.trim() ?? '';
            if (value.isEmpty) return context.l10n.liveCamStreamUrlRequired;
            if (!liveCameraUrlPattern.hasMatch(value)) {
              return context.l10n.liveCamStreamUrlInvalid;
            }
            return null;
          },
        ),
      ];

  List<Widget> _formFields(IpCameraConfig config) => [
        DropdownButtonFormField<String>(
          initialValue: _preset.id,
          key: ValueKey('preset-${_preset.id}'),
          isExpanded: true,
          decoration: _decoration(context.l10n.liveCamModel),
          items: [
            for (final p in IpCameraPreset.all)
              DropdownMenuItem(value: p.id, child: Text(p.label)),
          ],
          onChanged: (id) => _selectPreset(IpCameraPreset.byId(id)),
        ),
        if (_preset.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(_preset.hint!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
        if (_preset.hasSubStream) ...[
          const SizedBox(height: 10),
          SegmentedButton<IpCameraStream>(
            segments: [
              ButtonSegment(value: IpCameraStream.main, label: Text(context.l10n.liveCamMainStream)),
              ButtonSegment(value: IpCameraStream.sub, label: Text(context.l10n.liveCamSubStream)),
            ],
            selected: {_stream},
            onSelectionChanged: (s) => _selectStream(s.first),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<IpCameraProtocol>(
          initialValue: _protocol,
          key: ValueKey('protocol-${_protocol.scheme}'),
          isExpanded: true,
          decoration: _decoration(context.l10n.liveCamProtocol),
          items: [
            for (final p in IpCameraProtocol.values)
              DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          onChanged: (p) {
            if (p != null) _selectProtocol(p);
          },
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _host,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: _decoration(context.l10n.liveCamHostLabel, hint: context.l10n.liveCamHostHint),
                validator: (v) => IpCameraConfig.validateHost(v ?? ''),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: TextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _decoration(context.l10n.liveCamPort),
                validator: (v) => IpCameraConfig.validatePort(v ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _path,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: _decoration(
            _protocol.isSrt ? context.l10n.liveCamPathParams : context.l10n.liveCamPath,
            hint: '/stream1', // i18n-ignore
          ),
          validator: (v) => IpCameraConfig.validatePath(v ?? ''),
        ),
        const SizedBox(height: 12),
        if (_protocol.isSrt) ...[
          TextFormField(
            controller: _streamId,
            autocorrect: false,
            enableSuggestions: false,
            decoration: _decoration(context.l10n.liveCamStreamId),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passphrase,
            autocorrect: false,
            enableSuggestions: false,
            obscureText: !_showSecret,
            decoration: _decoration(context.l10n.liveCamPassphrase,
                helper: context.l10n.liveCamPassphraseHelper, suffix: _eye()),
            validator: (v) => IpCameraConfig.validatePassphrase(v ?? ''),
          ),
        ] else ...[
          TextFormField(
            controller: _username,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.username],
            decoration: _decoration(context.l10n.liveCamUsername, hint: 'admin'), // i18n-ignore
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            autocorrect: false,
            enableSuggestions: false,
            obscureText: !_showSecret,
            autofillHints: const [AutofillHints.password],
            decoration: _decoration(context.l10n.authPasswordLabel, suffix: _eye()),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.liveCamComposedUrl,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              SelectableText(
                config.host.isEmpty ? '—' : config.maskedUrl(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
          ),
        ),
      ];
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.text,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, height: 1.4)),
            ),
          ],
        ),
      );
}

// Paramètres › Localisation : « Utiliser ma position pour personnaliser mes fils »
// (consentement explicite, désactivable), « Mettre à jour ma position », « Ma ville »
// et « Supprimer ma position » (effacement immédiat). Doc serveur : docs/fonctionnalites/localisation.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_tokens.dart';
import '../../services/api_service.dart' show LaravelApiException;
import '../events/widgets/event_location_widgets.dart' show LocationFailure;
import 'location_providers.dart';
import 'user_location.dart';

class LocationSettingsScreen extends ConsumerStatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  ConsumerState<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends ConsumerState<LocationSettingsScreen> {
  final _city = TextEditingController();
  bool _busy = false;
  bool _cityLoaded = false;

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } on LocationFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: e.canOpenSettings
              ? SnackBarAction(
                  label: 'Réglages',
                  onPressed: Geolocator.openAppSettings,
                )
              : null,
        ),
      );
    } on LaravelApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Action impossible pour le moment. Réessayez.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  UserLocationNotifier get _notifier => ref.read(userLocationProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userLocationProvider);
    final s = async.value ?? const UserLocationSettings();
    if (!_cityLoaded && async.hasValue) {
      _city.text = s.homeCity ?? '';
      _cityLoaded = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Localisation',
          style: AppTextStyles.h4.copyWith(fontSize: 18),
        ),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: async.isLoading && !async.hasValue
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xxxl,
              ),
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                _Card(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: s.useGps,
                      onChanged: _busy
                          ? null
                          : (v) => _run(
                              v ? _notifier.enableAndLocate : _notifier.disable,
                              done: v
                                  ? 'Position enregistrée.'
                                  : 'Position effacée.',
                            ),
                      title: Text(
                        'Utiliser ma position pour personnaliser mes fils',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Les témoignages, prières et événements proches de vous d’abord. '
                        'Position arrondie (environ 1 km), jamais montrée aux autres.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.describe(),
                            key: const Key('location-describe'),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                _notifier.enableAndLocate,
                                done: 'Position mise à jour.',
                              ),
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('Mettre à jour ma position'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Card(
                  children: [
                    Text(
                      'Ma ville (sans position)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Utilisée quand la position est désactivée ; le pays est celui de votre profil.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _city,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Ex. Cotonou',
                        counterText: '',
                      ),
                      onSubmitted: (v) => _run(
                        () => _notifier.setHomeCity(v),
                        done: 'Ville enregistrée.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                () => _notifier.setHomeCity(_city.text),
                                done: 'Ville enregistrée.',
                              ),
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _notifier.erase();
                            _city.clear();
                          }, done: 'Votre position a été supprimée.'),
                    icon: const Icon(Icons.location_off_outlined, size: 18),
                    label: const Text('Supprimer ma position'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

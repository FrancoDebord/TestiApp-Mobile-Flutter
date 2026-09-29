import '../../../core/data/countries.dart';
import '../../../shared/widgets/country_picker.dart';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_notifier.dart'
    show currentUserProvider;
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/profile_cover.dart';
import '../models/profile_models.dart';
import '../providers/profile_provider.dart';

// Pays : liste partagée avec le site (lib/core/data/countries.dart).

// Canonical stored gender values (language-neutral keys)
const _kGenderValues = ['Homme', 'Femme', 'Autre'];

const _kSuggestedTitles = [
  'Pasteur', 'Évangéliste', 'Ancien', 'Diacre', 'Missionnaire',
  'Étudiant en théologie', 'Fidèle', 'Coordinateur de jeunesse',
  'Responsable de cellule', 'Autre',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _customTitleCtrl;

  // ── Organisation (comptes AccountType.organization uniquement) ────────────
  late final TextEditingController _orgNameCtrl;
  late final TextEditingController _orgCityCtrl;
  late final TextEditingController _orgWebsiteCtrl;
  OrganizationType? _orgType;
  bool _isOrg = false;

  String? _gender;
  String? _country;
  /// Indicatif du téléphone : suit le pays, reste modifiable.
  Country? _phoneDial;
  String? _selectedTitle;
  String? _avatarPath;
  bool _isLoading   = false;
  bool _initialized = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _customTitleCtrl.dispose();
    if (_initialized) {
      _orgNameCtrl.dispose();
      _orgCityCtrl.dispose();
      _orgWebsiteCtrl.dispose();
    }
    super.dispose();
  }

  void _initFrom(ProfileExtras e) {
    if (_initialized) return;
    _initialized = true;
    _firstCtrl       = TextEditingController(text: e.firstName);
    _lastCtrl        = TextEditingController(text: e.lastName);
    final me = ref.read(currentUserProvider);
    _phoneDial = countryByCode(me?.phoneCountry) ??
        countryByCode(e.phoneCountry) ??
        countryByName(me?.country) ??
        countryByName(e.country);
    _phoneCtrl       = TextEditingController(
        text: PhoneNumberField.nationalPart(
            (me?.phone.isNotEmpty ?? false) ? me!.phone : e.phone, _phoneDial));
    _emailCtrl       = TextEditingController(text: e.email);
    _bioCtrl         = TextEditingController(text: e.bio);
    _customTitleCtrl = TextEditingController(
        text: _kSuggestedTitles.contains(e.title) ? '' : e.title);
    _gender        = e.gender.isNotEmpty ? e.gender : null;
    _country       = e.country.isNotEmpty ? e.country : null;
    _avatarPath    = e.avatarPath;
    _selectedTitle = _kSuggestedTitles.contains(e.title) ? e.title : null;

    final user = ref.read(currentUserProvider);
    _isOrg          = user?.isOrganization ?? false;
    _orgNameCtrl    = TextEditingController(
        text: user?.organizationName ?? (_isOrg ? user!.displayName : ''));
    _orgCityCtrl    = TextEditingController(text: user?.organizationCity ?? '');
    _orgWebsiteCtrl =
        TextEditingController(text: user?.organizationWebsite ?? '');
    _orgType        = user?.organizationType;
  }

  static String? _normalizeWebsite(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    return v.contains('://') ? v : 'https://$v';
  }

  static bool _isValidWebsite(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return true; // optionnel
    final uri = Uri.tryParse(v.contains('://') ? v : 'https://$v');
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.') &&
        !v.contains(' ');
  }

  /// Champs organisation à inclure dans le PUT /users/me du profil.
  OrganizationProfileUpdate _organizationUpdate() {
    final city = _orgCityCtrl.text.trim();
    return OrganizationProfileUpdate(
      name:    _orgNameCtrl.text.trim(),
      type:    _orgType,
      city:    city.isEmpty ? null : city,
      website: _normalizeWebsite(_orgWebsiteCtrl.text),
    );
  }

  // ── Picker photo ──────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF1FC),
                  child: Icon(Icons.photo_library_rounded,
                      color: AppColors.primary)),
              title: Text(l10n.editGallery,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEAF1FC),
                  child: Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary)),
              title: Text(l10n.editCamera,
                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans')),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (file != null && mounted) {
      setState(() => _avatarPath = file.path);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_isOrg) {
      if (_orgNameCtrl.text.trim().length < 2) {
        _snack("Veuillez saisir le nom de l'organisation");
        return;
      }
      if (_orgType == null) {
        _snack("Veuillez choisir le type d'organisation");
        return;
      }
      if (_orgCityCtrl.text.trim().isEmpty) {
        _snack('Veuillez saisir la ville');
        return;
      }
      if (!_isValidWebsite(_orgWebsiteCtrl.text)) {
        _snack('Adresse du site web invalide');
        return;
      }
    }
    // Organisation : le nom affiché est le nom de l'organisation.
    final first = _isOrg ? _orgNameCtrl.text.trim() : _firstCtrl.text.trim();
    if (first.isEmpty) {
      _snack(l10n.editFirstRequired);
      return;
    }

    final title = _selectedTitle == 'Autre' || _selectedTitle == null
        ? _customTitleCtrl.text.trim()
        : _selectedTitle!;

    final phoneVerified = ref.read(currentUserProvider)?.isPhoneVerified ?? false;
    if (!phoneVerified) {
      final phoneError = PhoneNumberField.check(_phoneDial, _phoneCtrl.text, required: _isOrg);
      if (phoneError != null) {
        _snack(phoneError);
        return;
      }
    }

    setState(() => _isLoading = true);

    final extras = ProfileExtras(
      firstName:  first,
      lastName:   _isOrg ? '' : _lastCtrl.text.trim(),
      gender:     _isOrg ? '' : (_gender ?? ''),
      phone:      _phoneCtrl.text.trim(),
      phoneCountry: _phoneDial?.code ?? '',
      email:      _emailCtrl.text.trim(),
      country:    _country  ?? '',
      bio:        _bioCtrl.text.trim(),
      title:      title,
      avatarPath: _avatarPath,
    );

    final synced = await ref.read(profileExtrasProvider.notifier).save(
          extras,
          organization: _isOrg ? _organizationUpdate() : null,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!synced) {
      // Rester sur l'écran : l'utilisateur peut réessayer.
      _snack("Les informations de l'organisation n'ont pas pu être "
          'enregistrées sur le serveur. Vérifiez votre connexion et '
          'réessayez.');
      return;
    }
    _snack(l10n.editSaved, success: true);
    Navigator.of(context).pop();
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
        backgroundColor:
            success ? AppColors.primary : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extrasAsync = ref.watch(profileExtrasProvider);

    return extrasAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (extras) {
        _initFrom(extras);
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.profileEdit,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.textPrimary,
            )),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.border,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(l10n.detailSave,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.primary,
                      )),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Photo de couverture (envoi immédiat) ──────────────────────
            // docs/fonctionnalites/photo-de-couverture.md
            _CoverPicker(coverUrl: ref.watch(currentUserProvider)?.coverUrl),
            const SizedBox(height: 20),

            // ── Avatar ──────────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      backgroundImage: _avatarPath != null
                          ? (kIsWeb
                              ? NetworkImage(_avatarPath!) as ImageProvider
                              : FileImage(File(_avatarPath!)))
                          : null,
                      child: _avatarPath == null
                          ? Icon(
                              _isOrg
                                  ? Icons.church_rounded
                                  : Icons.person_rounded,
                              size: 52, color: AppColors.primary)
                          : null,
                    ),
                    Positioned(
                      bottom: 2, right: 2,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                  _isOrg ? 'Logo · touchez pour modifier' : l10n.editTapToChange,
                  style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 28),

            // ── Organisation ────────────────────────────────────────────
            if (_isOrg) ...[
              const _SectionTitle('Organisation'),
              const SizedBox(height: 12),
              _Field(
                label: "Nom de l'organisation *",
                controller: _orgNameCtrl,
                hint: 'Église de la Grâce',
                prefixIcon: Icons.church_outlined,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              const _Label('Type *'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OrganizationType.values.map((t) {
                  final selected = t == _orgType;
                  return ChoiceChip(
                    label: Text(t.label,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        )),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onSelected: (_) => setState(() => _orgType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Ville *',
                controller: _orgCityCtrl,
                hint: 'Cotonou',
                prefixIcon: Icons.location_city_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              _Field(
                label: 'Site web (optionnel)',
                controller: _orgWebsiteCtrl,
                hint: 'www.exemple.org',
                keyboardType: TextInputType.url,
                prefixIcon: Icons.language_rounded,
              ),
              const SizedBox(height: 28),
            ],

            // ── Identity ────────────────────────────────────────────────
            if (!_isOrg) ...[
            _SectionTitle(l10n.editIdentity),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    label: '${l10n.authFirstNameLabel} *',
                    controller: _firstCtrl,
                    hint: 'Marie',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: l10n.authLastNameLabel,
                    controller: _lastCtrl,
                    hint: 'Dupont',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Title ────────────────────────────────────────────────────
            _Label(l10n.editTitleOptional),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kSuggestedTitles.map((t) {
                final selected = t == _selectedTitle;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedTitle = selected ? null : t;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_selectedTitle == 'Autre' || _selectedTitle == null) ...[
              const SizedBox(height: 10),
              _Field(
                label: _selectedTitle == 'Autre'
                    ? l10n.editSpecifyTitle
                    : l10n.editCustomTitle,
                controller: _customTitleCtrl,
                hint: 'Ex. : Responsable worship, Coordinatrice femmes…',
              ),
            ],
            const SizedBox(height: 16),

            // ── Gender ──────────────────────────────────────────────────
            _Label(l10n.editGender),
            const SizedBox(height: 8),
            _GenderSelector(
              selected: _gender,
              onChanged: (g) => setState(() => _gender = g),
            ),

            const SizedBox(height: 28),
            ],

            // ── Contact ─────────────────────────────────────────────────
            _SectionTitle(l10n.editContact),
            const SizedBox(height: 12),
            if (ref.watch(currentUserProvider)?.isPhoneVerified ?? false)
              _VerifiedPhone(phone: ref.watch(currentUserProvider)!.phone)
            else
              PhoneNumberField(
                dial: _phoneDial,
                onDialChanged: (c) => setState(() => _phoneDial = c),
                controller: _phoneCtrl,
                required: _isOrg,
                requiredNote: _isOrg ? null : '(facultatif)',
              ),
            const SizedBox(height: 16),
            _Field(
              label: 'Email',
              controller: _emailCtrl,
              hint: 'marie@exemple.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),

            const SizedBox(height: 28),

            // ── Location ─────────────────────────────────────────────────
            _SectionTitle(l10n.editLocation),
            const SizedBox(height: 12),
            CountryPickerField(
              label: l10n.authCountryLabel,
              initialValue: countryByName(_country),
              required: false,
              onChanged: (c) => setState(() {
                _country = c?.name;
                if (c != null) _phoneDial = c;
              }),
            ),

            const SizedBox(height: 28),

            // ── Bio ──────────────────────────────────────────────────────
            _SectionTitle(l10n.editBio),
            const SizedBox(height: 12),
            _Field(
              label: l10n.editAboutOptional,
              controller: _bioCtrl,
              hint: l10n.editBioHint,
              maxLines: 4,
              maxLength: 200,
            ),

            const SizedBox(height: 32),

            // ── Save button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        l10n.editSaveProfile,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Bandeau « Photo de couverture » : aperçu, touche pour changer ou retirer.
class _CoverPicker extends ConsumerWidget {
  const _CoverPicker({required this.coverUrl});
  final String? coverUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCover = coverUrl != null;
    return Semantics(
      button: true,
      label: hasCover ? 'Modifier la photo de couverture' : 'Ajouter une photo de couverture',
      child: Material(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showProfileCoverSheet(context, ref, hasCover: hasCover),
          child: AspectRatio(
            aspectRatio: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfileCoverImage(url: coverUrl),
                Align(
                  alignment: hasCover ? Alignment.bottomRight : Alignment.center,
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: hasCover ? Colors.black.withAlpha(150) : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 16, color: hasCover ? Colors.white : AppColors.primary),
                        const SizedBox(width: 6),
                        Text(hasCover ? 'Modifier la couverture' : 'Ajouter une photo de couverture',
                            style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hasCover ? Colors.white : AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 14,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14,
                fontFamily: 'Plus Jakarta Sans'),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: AppColors.textSecondary)
                : null,
            filled: true,
            fillColor: AppColors.surface,
            counterStyle: const TextStyle(
                fontFamily: 'Plus Jakarta Sans', fontSize: 11,
                color: AppColors.textSecondary),
            contentPadding: EdgeInsets.symmetric(
              horizontal: prefixIcon != null ? 0 : 14,
              vertical: maxLines > 1 ? 12 : 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.genderMale, l10n.genderFemale, l10n.genderOther];

    return Row(
      children: List.generate(_kGenderValues.length, (i) {
        final value = _kGenderValues[i];
        final label = labels[i];
        final isSelected = value == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: i < _kGenderValues.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(isSelected ? null : value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Numéro confirmé par SMS : il sert à la connexion par téléphone, il ne se modifie pas ici.
class _VerifiedPhone extends StatelessWidget {
  const _VerifiedPhone({required this.phone});
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Téléphone'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.phone_outlined, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(phone, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
            const SizedBox(width: 4),
            const Text('Vérifié par SMS', style: TextStyle(fontSize: 12, color: AppColors.success)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Ce numéro sert à vous connecter : il ne se modifie pas ici.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

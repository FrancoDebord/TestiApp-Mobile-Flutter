// Choix du pays et du téléphone (indicatif + numéro), avec recherche et drapeaux.
// Liste : lib/core/data/countries.dart (identique au site). Backend : docs/fonctionnalites/telephone.md

import 'package:flutter/material.dart';

import '../../core/data/countries.dart';

const _kBorder = Color(0xFFE4E7EC);
const _kFocus = Color(0xFF184797);
const _kHint = Color(0xFF98A2B3);
const _kText = Color(0xFF263238);
const _kError = Color(0xFFD92D20);

InputDecoration countryFieldDecoration({IconData? prefix, String? hint, String? errorText}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    prefixIcon: prefix == null ? null : Icon(prefix, color: _kHint, size: 20),
    hintText: hint,
    hintStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', color: Color(0xFFD0D5DD), fontSize: 15),
    errorText: errorText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: border(_kBorder),
    enabledBorder: border(_kBorder),
    focusedBorder: border(_kFocus, 1.8),
    errorBorder: border(_kError),
    focusedErrorBorder: border(_kError, 1.8),
    errorStyle: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (note != null)
              TextSpan(text: ' $note', style: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFF667085))),
          ],
        ),
        style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w500, fontSize: 13, color: _kText),
      ),
    );
  }
}

// ── Liste avec recherche ─────────────────────────────────────────────────────

/// Ouvre la liste des pays. [withDial] : affiche et cherche aussi les indicatifs.
Future<Country?> showCountryPicker(
  BuildContext context, {
  bool withDial = false,
  String? selectedCode,
}) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (context) => _CountrySheet(withDial: withDial, selectedCode: selectedCode),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.withDial, this.selectedCode});
  final bool withDial;
  final String? selectedCode;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(_query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: countryFieldDecoration(
                  prefix: Icons.search_rounded,
                  hint: widget.withDial ? 'Rechercher un pays ou un indicatif' : 'Rechercher un pays',
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        widget.withDial ? 'Aucun pays ni indicatif ne correspond.' : 'Aucun pays ne correspond à votre recherche.',
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        final selected = c.code == widget.selectedCode;
                        return ListTile(
                          leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                          title: Text(c.name,
                              style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                          trailing: widget.withDial
                              ? Text(c.dialLabel, style: const TextStyle(color: Color(0xFF667085)))
                              : (selected ? const Icon(Icons.check_rounded, color: _kFocus) : null),
                          selected: selected,
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Champ « Pays » ───────────────────────────────────────────────────────────

/// Champ de formulaire : drapeau + nom du pays ; ouvre la liste avec recherche.
class CountryPickerField extends FormField<Country> {
  CountryPickerField({
    super.key,
    super.initialValue,
    required ValueChanged<Country?> onChanged,
    bool required = true,
    super.enabled = true,
    String label = 'Pays',
  }) : super(
          validator: (v) => required && v == null ? 'Veuillez sélectionner votre pays' : null,
          builder: (field) {
            final value = field.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(label),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: !enabled
                      ? null
                      : () async {
                          final picked = await showCountryPicker(field.context, selectedCode: value?.code);
                          if (picked == null) return;
                          field.didChange(picked);
                          onChanged(picked);
                        },
                  child: InputDecorator(
                    isEmpty: value == null,
                    decoration: countryFieldDecoration(
                      prefix: value == null ? Icons.public_rounded : null,
                      hint: 'Sélectionnez votre pays',
                      errorText: field.errorText,
                    ).copyWith(
                      prefix: value == null
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Text(value.flag, style: const TextStyle(fontSize: 20)),
                            ),
                      suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kHint),
                    ),
                    child: value == null
                        ? null
                        : Text(value.name, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, color: _kText)),
                  ),
                ),
              ],
            );
          },
        );
}

// ── Champ « Téléphone » ──────────────────────────────────────────────────────

/// Indicatif (drapeau + « +229 », liste avec recherche) puis numéro national.
/// L'indicatif est fourni par le parent (il suit le pays choisi).
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.dial,
    required this.onDialChanged,
    required this.controller,
    this.required = false,
    this.requiredNote,
    this.enabled = true,
  });

  final Country? dial;
  final ValueChanged<Country> onDialChanged;
  final TextEditingController controller;

  /// Obligatoire (organisation).
  final bool required;

  /// Mention à côté du libellé, ex. « (obligatoire pour une organisation) ».
  final String? requiredNote;
  final bool enabled;

  /// Contrôle simple avant envoi (le serveur vérifie le format exact) ; null si correct.
  static String? check(Country? dial, String? value, {required bool required}) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return required ? 'Le numéro de téléphone est obligatoire.' : null;
    if (dial == null) return 'Choisissez l\'indicatif du pays.';
    if (RegExp(r'[^0-9 .\-()+/]').hasMatch(text)) return 'Numéro de téléphone invalide.';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4 || digits.length > 15) return 'Numéro de téléphone invalide.';
    return null;
  }

  /// Partie nationale d'un numéro enregistré au format international (+229…).
  static String nationalPart(String phone, Country? dial) {
    final p = phone.trim();
    if (dial != null && p.startsWith(dial.dialLabel)) return p.substring(dial.dialLabel.length).trim();
    return p;
  }

  String? _validate(String? v) => check(dial, v, required: required);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(required ? 'Téléphone *' : 'Téléphone', note: requiredNote),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: !enabled
                    ? null
                    : () async {
                        final picked = await showCountryPicker(context, withDial: true, selectedCode: dial?.code);
                        if (picked != null) onDialChanged(picked);
                      },
                child: InputDecorator(
                  decoration: countryFieldDecoration().copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kHint, size: 20),
                    suffixIconConstraints: const BoxConstraints(minWidth: 28),
                  ),
                  child: Semantics(
                    label: 'Indicatif du pays',
                    value: dial?.dialLabel,
                    child: Text(
                      dial == null ? 'Indicatif' : '${dial!.flag} ${dial!.dialLabel}',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, color: dial == null ? _kHint : _kText),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                textInputAction: TextInputAction.next,
                maxLength: 30,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                validator: _validate,
                style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 15, color: _kText),
                decoration: countryFieldDecoration(hint: 'Numéro'),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Sert uniquement à vérifier votre compte : il n\'est jamais affiché publiquement.',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, color: Color(0xFF667085)),
          ),
        ),
      ],
    );
  }
}

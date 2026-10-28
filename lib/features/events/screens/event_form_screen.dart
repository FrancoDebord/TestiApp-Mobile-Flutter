import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_tokens.dart';
import '../../offline/outbox_controller.dart';
import '../../auth/providers/auth_notifier.dart' show currentUserProvider;
import '../data/events_repository.dart';
import '../models/event_models.dart';
import '../providers/events_providers.dart';
import '../providers/event_types_providers.dart' show eventTypesProvider;
import '../widgets/event_location_widgets.dart';
import '../widgets/event_widgets.dart';
import '../../../core/media/youtube.dart' show extractYouTubeId;
import '../../../l10n/app_localizations.dart';

/// Création ([eventId] null) ou modification d'un événement :
/// infos, dates, lieu, invités principaux, images du carrousel, publication.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({this.eventId, super.key});

  final String? eventId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  static const _maxImages = 6;
  static const _maxGuests = 10;

  final _formKey = GlobalKey<FormState>();
  EventDraft _draft = EventDraft();

  /// Événement en cours de modification (images déjà en ligne).
  ChristianEvent? _event;

  /// Images choisies, envoyées après l'enregistrement (création ; modification
  /// faite hors connexion).
  final List<XFile> _pending = [];

  /// Modification hors connexion : images retirées / mise en premier, en attente d'envoi.
  final Set<String> _removedImageIds = {};
  String? _firstImageId;

  /// Images en ligne telles qu'elles seront après l'envoi des actions en attente.
  List<EventImage> get _existingImages {
    final list = [for (final i in _event?.images ?? const <EventImage>[]) if (!_removedImageIds.contains(i.id)) i];
    final first = list.where((i) => i.id == _firstImageId).firstOrNull;
    return first == null ? list : [first, ...list.where((i) => i != first)];
  }

  /// Une clé stable par ligne d'invité (alignée sur `_draft.guests`).
  final List<Key> _guestKeys = [];

  /// Aligne `_guestKeys` sur le nombre d'invités (brouillon rechargé) et renvoie ce nombre.
  int _syncGuestKeys(int count) {
    while (_guestKeys.length < count) {
      _guestKeys.add(UniqueKey());
    }
    if (_guestKeys.length > count) _guestKeys.removeRange(count, _guestKeys.length);
    return count;
  }

  bool _loading = false;
  bool _saving = false;
  bool _imageBusy = false;
  String? _progress;
  String? _loadError;

  bool get _isEdit => widget.eventId != null;

  /// Statut enregistré de l'événement modifié (« Reporté » n'est proposé que s'il l'est déjà).
  EventStatus? get _initialStatus => _event?.status;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final id = widget.eventId!;
      // Hors connexion : copie gardée sur le téléphone (événement que je gère).
      final e = await ref
          .read(eventsRepositoryProvider)
          .show(id, offlineKey: eventOfflineKey(ref.read(currentUserProvider)?.id, id));
      if (!mounted) return;
      // Modification déjà faite hors connexion, pas encore envoyée : on la reprend.
      final queued = ref
          .read(outboxProvider)
          .items
          .where((i) => i.dedupeKey == eventEditKey(id) && !i.isFailed)
          .lastOrNull
          ?.payload
          .request
          ?.body;
      setState(() {
        _event = e;
        _draft = queued != null ? EventDraft.fromJson(queued) : EventDraft.fromEvent(e);
        _loading = false;
      });
    } on EventFailure catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.message;
          _loading = false;
        });
      }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  // ── Dates ──────────────────────────────────────────────────────────────────

  Future<DateTime?> _pickDateTime(DateTime? initial, {DateTime? notBefore}) async {
    final now = DateTime.now();
    final base = initial ?? notBefore ?? now.add(const Duration(days: 7));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _isEdit ? DateTime(now.year - 2) : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Images ─────────────────────────────────────────────────────────────────

  int get _imageCount => _existingImages.length + _pending.length;

  Future<void> _addImages() async {
    final left = _maxImages - _imageCount;
    if (left <= 0) {
      _snack(context.l10n.eventsFormMaxImages);
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1920,
      imageQuality: 85,
      limit: left > 1 ? left : null,
    );
    if (picked.isEmpty || !mounted) return;
    final files = picked.take(left).toList();
    if (!_isEdit) {
      setState(() => _pending.addAll(files));
      return;
    }
    // Modification : envoi immédiat.
    setState(() => _imageBusy = true);
    final repo = ref.read(eventsRepositoryProvider);
    for (var i = 0; i < files.length; i++) {
      try {
        final e = await repo.addImage(_event!.id, files[i]);
        if (mounted) setState(() => _event = e);
      } on EventFailure catch (err) {
        // Hors connexion : les images partiront avec l'enregistrement (file d'envoi).
        if (err.offline && !kIsWeb) {
          if (mounted) setState(() => _pending.addAll(files.skip(i)));
        } else {
          _snack(err.message);
        }
        break;
      }
    }
    if (mounted) setState(() => _imageBusy = false);
  }

  Future<void> _imageAction(EventImage img, String action) async {
    setState(() => _imageBusy = true);
    final repo = ref.read(eventsRepositoryProvider);
    final id = _event!.id;
    final cover = action == 'cover';
    try {
      // Hors connexion : l'action attend le réseau, l'aperçu change tout de suite.
      final e = await ref.read(outboxProvider.notifier).sendOrQueue(
            () => cover ? repo.makeCover(id, img.id) : repo.removeImage(id, img.id),
            () => OutboxDraft(
              kind: OutboxKind.event,
              label: _draft.title,
              targetId: id,
              request: cover
                  ? OutboxRequest('POST', AppConstants.eventImageCover(id, img.id))
                  : OutboxRequest('DELETE', AppConstants.eventImage(id, img.id)),
            ),
          );
      if (mounted) {
        setState(() {
          if (e != null) {
            _event = e;
          } else if (cover) {
            _firstImageId = img.id;
          } else {
            _removedImageIds.add(img.id);
          }
        });
      }
    } on EventFailure catch (err) {
      _snack(err.message);
    }
    if (mounted) setState(() => _imageBusy = false);
  }

  // ── Enregistrement ─────────────────────────────────────────────────────────

  /// Images à rattacher à un événement existant, gardées dans la file d'envoi.
  Future<void> _queueImages(String eventId, List<XFile> files) async {
    await ref.read(outboxProvider.notifier).enqueue(OutboxDraft(
      kind: OutboxKind.event,
      label: _draft.title,
      targetId: eventId,
      after: [
        for (final f in files)
          OutboxFile(path: AppConstants.eventImages(eventId), file: f.path, field: 'image'),
      ],
    ));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_draft.startsAt == null || _draft.endsAt == null) {
      _snack(context.l10n.eventsFormDatesRequired);
      return;
    }
    if (_draft.endsAt!.isBefore(_draft.startsAt!)) {
      _snack(context.l10n.eventsEndAfterStart);
      return;
    }
    setState(() {
      _saving = true;
      _progress = null;
    });
    final repo = ref.read(eventsRepositoryProvider);
    if (!_isEdit) _draft.organizationId = ref.read(_organizerChoice);
    try {
      // Nouvel événement sans réseau : gardé sur le téléphone avec ses images,
      // créé au retour de la connexion.
      final outbox = ref.read(outboxProvider.notifier);
      final saved = _isEdit
          // Modification sans réseau : la dernière version part au retour de la connexion.
          ? await outbox.sendOrQueue(
              () => repo.update(_event!.id, _draft),
              () => OutboxDraft(
                kind: OutboxKind.event,
                label: _draft.title,
                targetId: _event!.id,
                dedupeKey: eventEditKey(_event!.id),
                request: OutboxRequest('PUT', AppConstants.eventById(_event!.id), body: _draft.toJson()),
              ),
            )
          : await outbox.sendOrQueue(
                () => repo.create(_draft),
                () => OutboxDraft(
                  kind: OutboxKind.event,
                  label: _draft.title,
                  localId: newLocalId(),
                  request: OutboxRequest('POST', AppConstants.events, body: _draft.toJson()),
                  after: [
                    for (final f in _pending)
                      OutboxFile(path: AppConstants.eventImages('{id}'), file: f.path, field: 'image'),
                  ],
                ),
              );
      if (saved == null) {
        // Modification : les images ajoutées partent dans une action à part
        // (une nouvelle modification ne les remplace pas).
        if (_isEdit && _pending.isNotEmpty) await _queueImages(_event!.id, _pending);
        if (!mounted) return;
        showQueuedSnack(context);
        context.pop();
        return;
      }
      var event = saved;

      // Création : images envoyées une par une (un échec n'annule pas l'événement).
      var failed = 0;
      var queued = false;
      for (var i = 0; i < _pending.length; i++) {
        if (mounted) setState(() => _progress = L10n.current.eventsFormUploadingImages(i + 1, _pending.length));
        try {
          event = await repo.addImage(event.id, _pending[i]);
        } on EventFailure catch (err) {
          // Coupure pendant l'envoi : les images restantes attendent le réseau.
          if (err.offline && !kIsWeb) {
            await _queueImages(event.id, _pending.sublist(i));
            queued = true;
            break;
          }
          failed++;
        }
      }
      if (queued && mounted) showQueuedSnack(context);

      ref.invalidate(eventListProvider);
      ref.invalidate(upcomingEventsProvider);
      ref.invalidate(eventDetailProvider(event.id));
      if (!mounted) return;
      _snack(failed > 0
          ? context.l10n.eventsFormImagesFailed(failed)
          : _isEdit
              ? context.l10n.eventsFormUpdated
              : context.l10n.eventsFormCreated);
      if (_isEdit) {
        context.pop();
      } else {
        context.pushReplacement('/events/${event.id}');
      }
    } on EventFailure catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Types d'événements gérés par les administrateurs (recharge à l'arrivée de la liste).
    ref.watch(eventTypesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? context.l10n.eventsFormEditTitle : context.l10n.eventsFormNewTitle),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: Text(context.l10n.commonRetry)),
                    ],
                  ),
                )
              : _form(),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 12),
                child: FilledButton(
                  onPressed: _saving || _imageBusy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  child: _saving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            const SizedBox(width: 10),
                            Text(_progress ?? context.l10n.eventsFormSaving),
                          ],
                        )
                      : Text(_isEdit
                          ? context.l10n.eventsFormSaveChanges
                          : _draft.status == EventStatus.draft
                              ? context.l10n.eventsFormSaveDraft
                              : context.l10n.eventsFormPublish),
                ),
              ),
            ),
    );
  }

  Widget _form() {
    final l10n = context.l10n;
    final d = _draft;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 24),
        children: [
          // ── Images ────────────────────────────────────────────────────────
          _Section(
            title: l10n.eventsFormCoverImages,
            subtitle: l10n.eventsFormCoverImagesHelp,
            child: _ImagesEditor(
              existing: _existingImages,
              pending: _pending,
              busy: _imageBusy,
              canAdd: _imageCount < _maxImages,
              onAdd: _addImages,
              onRemovePending: (f) => setState(() => _pending.remove(f)),
              onExisting: _imageAction,
            ),
          ),

          // ── Au nom de qui (gestionnaire de plusieurs organisations) ─────
          if (!_isEdit) const _OrganizerPicker(),

          // ── Informations ─────────────────────────────────────────────────
          _Section(
            title: l10n.eventsFormInfo,
            child: Column(
              children: [
                TextFormField(
                  initialValue: d.title,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.eventsFormTitleLabel, hintText: l10n.eventsFormTitleHint),
                  validator: (v) => (v ?? '').trim().isEmpty ? l10n.eventsFormTitleRequired : null,
                  onChanged: (v) => d.title = v,
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<EventType>(
                  initialValue: d.type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.eventsFormTypeLabel),
                  items: [
                    for (final t in [
                      ...EventType.values,
                      if (!EventType.values.contains(d.type)) d.type,
                    ])
                      DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(eventTypeIcon(t), size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Flexible(child: Text(t.label, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (t) => setState(() => d.type = t ?? d.type),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: d.description,
                  minLines: 4,
                  maxLines: 12,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.eventsFormDescription,
                    hintText: l10n.eventsFormDescriptionHint,
                    alignLabelWithHint: true,
                  ),
                  onChanged: (v) => d.description = v,
                ),
              ],
            ),
          ),

          // ── Dates ────────────────────────────────────────────────────────
          _Section(
            title: l10n.eventsFormDates,
            child: Column(
              children: [
                _DateField(
                  label: l10n.eventsFormStart,
                  value: d.startsAt,
                  onTap: () async {
                    final v = await _pickDateTime(d.startsAt);
                    if (v == null) return;
                    setState(() {
                      d.startsAt = v;
                      // Fin proposée : 3 h plus tard, si absente ou antérieure.
                      if (d.endsAt == null || d.endsAt!.isBefore(v)) {
                        d.endsAt = v.add(const Duration(hours: 3));
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                _DateField(
                  label: l10n.eventsFormEnd,
                  value: d.endsAt,
                  onTap: () async {
                    final v = await _pickDateTime(d.endsAt, notBefore: d.startsAt);
                    if (v != null) setState(() => d.endsAt = v);
                  },
                ),
              ],
            ),
          ),

          // ── Lieu ─────────────────────────────────────────────────────────
          _Section(
            title: l10n.eventsPlace,
            child: Column(
              children: [
                TextFormField(
                  initialValue: d.location,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.eventsPlace,
                    hintText: l10n.eventsFormPlaceHint,
                    prefixIcon: const Icon(Icons.place_outlined),
                  ),
                  onChanged: (v) => d.location = v,
                ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: d.address,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.eventsFormAddress,
                    hintText: l10n.eventsFormAddressHint,
                    prefixIcon: const Icon(Icons.signpost_outlined),
                  ),
                  onChanged: (v) => d.address = v,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: d.city,
                        maxLength: 100,
                        decoration: InputDecoration(labelText: l10n.eventsFormCity),
                        onChanged: (v) => d.city = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        initialValue: d.country,
                        maxLength: 100,
                        decoration: InputDecoration(labelText: l10n.eventsFormCountry),
                        onChanged: (v) => d.country = v,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Position sur la carte (repère GPS facultatif) ────────────────
          _Section(
            title: l10n.eventsFormMapPosition,
            subtitle: l10n.eventsFormMapPositionHelp,
            child: EventMapPicker(
              key: ValueKey('map-${_event?.id}'),
              latitude: d.latitude,
              longitude: d.longitude,
              onChanged: (lat, lng) {
                d.latitude = lat;
                d.longitude = lng;
              },
              addressQuery: () => [d.address, d.location, d.city, d.country]
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .join(', '),
            ),
          ),

          // ── Direct YouTube (lien facultatif ; pas de direct dans l'application) ──
          _Section(
            title: l10n.eventsFormYoutubeLive,
            subtitle: l10n.eventsFormYoutubeLiveHelp,
            child: TextFormField(
              initialValue: d.youtubeLiveUrl,
              maxLength: 300,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.eventsFormYoutubeLiveLabel,
                hintText: 'https://www.youtube.com/live/…', // i18n-ignore
                prefixIcon: const Icon(Icons.smart_display_outlined),
              ),
              validator: (v) => (v ?? '').trim().isEmpty || extractYouTubeId(v) != null
                  ? null
                  : l10n.eventsFormYoutubeLiveInvalid,
              onChanged: (v) => d.youtubeLiveUrl = v,
            ),
          ),

          // ── Invités ──────────────────────────────────────────────────────
          _Section(
            title: l10n.eventsFormGuests,
            subtitle: l10n.eventsFormGuestsHelp,
            child: Column(
              children: [
                for (var i = 0; i < _syncGuestKeys(d.guests.length); i++)
                  _GuestRow(
                    key: _guestKeys[i],
                    guest: d.guests[i],
                    onChanged: (g) => d.guests[i] = g,
                    onRemove: () => setState(() {
                      d.guests.removeAt(i);
                      _guestKeys.removeAt(i);
                    }),
                  ),
                if (d.guests.length < _maxGuests)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        d.guests.add(const EventGuest(name: ''));
                        _guestKeys.add(UniqueKey());
                      }),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(l10n.eventsFormAddGuest),
                    ),
                  ),
              ],
            ),
          ),

          // ── Publication ──────────────────────────────────────────────────
          _Section(
            title: l10n.eventsFormPublication,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<EventStatus>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: EventStatus.draft, icon: const Icon(Icons.edit_note_rounded), label: Text(l10n.eventsStatusDraft)),
                    ButtonSegment(
                        value: EventStatus.published, icon: const Icon(Icons.public_rounded), label: Text(l10n.eventsStatusPublished)),
                    // Reporté (date à confirmer) : seulement s'il l'est déjà ; changer la date le reprogramme.
                    if (_isEdit && _initialStatus == EventStatus.postponed)
                      ButtonSegment(
                          value: EventStatus.postponed, icon: const Icon(Icons.event_repeat_rounded), label: Text(l10n.eventsFlagPostponed)),
                    if (_isEdit)
                      ButtonSegment(
                          value: EventStatus.cancelled, icon: const Icon(Icons.cancel_outlined), label: Text(l10n.eventsStatusCancelled)),
                  ],
                  selected: {d.status},
                  onSelectionChanged: (s) => setState(() => d.status = s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (d.status) {
                    EventStatus.draft => l10n.eventsFormDraftHelp,
                    EventStatus.published => l10n.eventsFormPublishedHelp,
                    EventStatus.cancelled => l10n.eventsFormCancelledHelp,
                    EventStatus.postponed => l10n.eventsFormPostponedHelp,
                  },
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: d.commentsEnabled,
                  onChanged: (v) => setState(() => d.commentsEnabled = v),
                  title: Text(l10n.eventsFormCommentsOpen),
                  subtitle: Text(l10n.eventsFormCommentsOpenHelp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Morceaux du formulaire ───────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_rounded),
          suffixIcon: const Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(
          v == null
              ? context.l10n.eventsFormPickDateTime
              : '${formatEventDay(v)} · ${formatTime(v)}',
          style: TextStyle(color: v == null ? AppColors.textSecondary : AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({required this.guest, required this.onChanged, required this.onRemove, super.key});

  final EventGuest guest;
  final ValueChanged<EventGuest> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    var current = guest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: TextFormField(
              initialValue: guest.name,
              decoration: InputDecoration(labelText: context.l10n.eventsFormGuestName, isDense: true),
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => onChanged(current = EventGuest(name: v, role: current.role)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextFormField(
              initialValue: guest.role,
              decoration: InputDecoration(labelText: context.l10n.eventsFormGuestRole, hintText: context.l10n.eventsFormGuestRoleHint, isDense: true),
              onChanged: (v) => onChanged(current = EventGuest(name: current.name, role: v)),
            ),
          ),
          IconButton(
            tooltip: context.l10n.eventsFormRemoveGuest,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ImagesEditor extends StatelessWidget {
  const _ImagesEditor({
    required this.existing,
    required this.pending,
    required this.busy,
    required this.canAdd,
    required this.onAdd,
    required this.onRemovePending,
    required this.onExisting,
  });

  final List<EventImage> existing;
  final List<XFile> pending;
  final bool busy;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<XFile> onRemovePending;
  final void Function(EventImage image, String action) onExisting;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (var i = 0; i < existing.length; i++)
        _Thumb(
          image: CachedNetworkImage(imageUrl: existing[i].url, fit: BoxFit.cover),
          first: i == 0,
          menu: PopupMenuButton<String>(
            tooltip: context.l10n.eventsFormOptions,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
            onSelected: (a) => onExisting(existing[i], a),
            itemBuilder: (_) => [
              if (i != 0) PopupMenuItem(value: 'cover', child: Text(context.l10n.eventsFormMakeFirst)),
              PopupMenuItem(value: 'remove', child: Text(context.l10n.commonRemove)),
            ],
          ),
        ),
      for (var i = 0; i < pending.length; i++)
        _Thumb(
          image: kIsWeb
              ? Image.network(pending[i].path, fit: BoxFit.cover)
              : _FileImage(key: ObjectKey(pending[i]), file: pending[i]),
          first: existing.isEmpty && i == 0,
          menu: IconButton(
            tooltip: context.l10n.commonRemove,
            onPressed: () => onRemovePending(pending[i]),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
          ),
        ),
      if (canAdd)
        InkWell(
          onTap: busy ? null : onAdd,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(70)),
            ),
            child: Center(
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  // Réduit plutôt que de déborder (petit écran, texte agrandi).
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                            const SizedBox(height: 4),
                            Text(context.l10n.commonAdd,
                                style: const TextStyle(
                                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.25,
      children: tiles,
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.first, required this.menu});

  final Widget image;
  final bool first;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x88000000), Colors.transparent],
              ),
            ),
          ),
          Positioned(top: -4, right: -4, child: menu),
          if (first)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(5)),
                child: Text(context.l10n.eventsFormThumbnail,
                    style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aperçu d'une image locale (mobile) sans dépendre de dart:io.
class _FileImage extends StatefulWidget {
  const _FileImage({required this.file, super.key});
  final XFile file;

  @override
  State<_FileImage> createState() => _FileImageState();
}

class _FileImageState extends State<_FileImage> {
  late final _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _bytes,
      builder: (_, snap) => snap.hasData
          ? Image.memory(snap.data!, fit: BoxFit.cover)
          : const ColoredBox(color: AppColors.primarySoft),
    );
  }
}

// ── Organisateur (création au nom d'une organisation gérée) ─────────────────

class _OrganizerChoice extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final _organizerChoice =
    NotifierProvider.autoDispose<_OrganizerChoice, String?>(_OrganizerChoice.new);

/// Sélecteur affiché seulement si la personne peut créer pour plusieurs comptes
/// (elle-même et / ou des organisations vérifiées qu'elle gère).
class _OrganizerPicker extends ConsumerWidget {
  const _OrganizerPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creators = ref.watch(eventCreatorsProvider).value ?? const <EventPerson>[];
    if (creators.isEmpty) return const SizedBox.shrink();
    final selected = ref.watch(_organizerChoice) ?? creators.first.id;
    if (ref.read(_organizerChoice) == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(_organizerChoice.notifier).set(creators.first.id));
    }
    return _Section(
      title: context.l10n.eventsOrganizer,
      subtitle: creators.length > 1
          ? context.l10n.eventsFormOnBehalfOf
          : context.l10n.eventsFormPublishedAs,
      child: creators.length == 1
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apartment_rounded, color: AppColors.primary),
              title: Text(creators.first.displayName),
            )
          : DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.eventsOrganizer),
              items: [
                for (final c in creators)
                  DropdownMenuItem(value: c.id, child: Text(c.displayName, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => ref.read(_organizerChoice.notifier).set(v),
            ),
    );
  }
}

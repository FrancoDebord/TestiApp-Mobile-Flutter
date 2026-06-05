// lib/shared/models/publish_draft_model.dart — Dart pur, sans génération de code.

import 'testimony_model.dart';

class PublishDraftModel {
  const PublishDraftModel({
    this.title = '',
    this.category,
    this.content = '',
    this.type = TestimonyType.text,
    this.mediaPath,
    this.coverPath,
    this.verse = '',
    this.verseReference = '',
    this.visibility = TestimonyVisibility.public,
    this.status = TestimonyStatus.draft,
    this.tags = const [],
  });

  final String              title;
  final TestimonyCategory?  category;
  final String              content;
  final TestimonyType       type;
  final String?             mediaPath;
  final String?             coverPath;
  final String              verse;
  final String              verseReference;
  final TestimonyVisibility visibility;
  final TestimonyStatus     status;
  final List<String>        tags;

  bool get isReadyToSubmit =>
      title.trim().isNotEmpty &&
      content.trim().isNotEmpty &&
      category != null;

  bool get hasMedia => mediaPath != null && mediaPath!.isNotEmpty;
  bool get hasCover => coverPath != null && coverPath!.isNotEmpty;

  PublishDraftModel copyWith({
    String? title, TestimonyCategory? category, String? content,
    TestimonyType? type, String? mediaPath, String? coverPath,
    String? verse, String? verseReference, TestimonyVisibility? visibility,
    TestimonyStatus? status, List<String>? tags,
  }) => PublishDraftModel(
    title:          title          ?? this.title,
    category:       category       ?? this.category,
    content:        content        ?? this.content,
    type:           type           ?? this.type,
    mediaPath:      mediaPath      ?? this.mediaPath,
    coverPath:      coverPath      ?? this.coverPath,
    verse:          verse          ?? this.verse,
    verseReference: verseReference ?? this.verseReference,
    visibility:     visibility     ?? this.visibility,
    status:         status         ?? this.status,
    tags:           tags           ?? this.tags,
  );

  Map<String, dynamic> toJson() => {
    'title': title, 'content': content,
    'type': type.toJson(),
    if (category != null) 'category': category!.toJson(),
    if (mediaPath != null) 'media_path': mediaPath,
    if (coverPath != null) 'cover_path': coverPath,
    'verse': verse, 'verse_reference': verseReference,
    'visibility': visibility.toJson(), 'status': status.toJson(),
    'tags': tags,
  };
}

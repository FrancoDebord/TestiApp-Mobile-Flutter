// Photo de couverture du profil : image du bandeau et feuille « Photo de couverture ».
// Backend : POST/DELETE /users/me/cover — docs/fonctionnalites/photo-de-couverture.md

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../services/api_service.dart' show LaravelApiException;

/// Image de couverture qui remplit son parent ; rien (le fond reste visible)
/// si [url] est absent ou si l'image ne se charge pas.
class ProfileCoverImage extends StatelessWidget {
  const ProfileCoverImage({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const SizedBox.shrink();
    return Image.network(
      u,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

enum _CoverAction { gallery, camera, remove }

/// Choisir, prendre ou retirer la photo de couverture de son profil.
/// Envoi immédiat ; retourne `true` si la couverture a changé.
Future<bool> showProfileCoverSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool hasCover,
}) async {
  final action = await showModalBottomSheet<_CoverAction>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text('Photo de couverture',
                style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Format large conseillé (1500 × 500 pixels).',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: const Text('Choisir dans la galerie', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
            onTap: () => Navigator.pop(sheet, _CoverAction.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: const Text('Prendre une photo', style: TextStyle(fontFamily: 'Plus Jakarta Sans')),
            onTap: () => Navigator.pop(sheet, _CoverAction.camera),
          ),
          if (hasCover)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Retirer la couverture',
                  style: TextStyle(fontFamily: 'Plus Jakarta Sans', color: AppColors.danger)),
              onTap: () => Navigator.pop(sheet, _CoverAction.remove),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  void snack(String msg, {bool error = false}) => messenger.showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 13)),
        backgroundColor: error ? AppColors.danger : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));

  final notifier = ref.read(profileExtrasProvider.notifier);
  try {
    if (action == _CoverAction.remove) {
      await notifier.removeCover();
      snack('Photo de couverture retirée');
      return true;
    }
    final file = await ImagePicker().pickImage(
      source: action == _CoverAction.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file == null) return false;
    await notifier.uploadCover(file.path);
    snack('Photo de couverture mise à jour');
    return true;
  } on LaravelApiException catch (e) {
    snack(e.fieldError('cover') ?? "La photo de couverture n'a pas pu être enregistrée.", error: true);
  } catch (_) {
    snack("La photo de couverture n'a pas pu être enregistrée. Vérifiez votre connexion.", error: true);
  }
  return false;
}

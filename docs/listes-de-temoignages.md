# Listes de témoignages (application)

> Ajouté le 2026-10-30. Règles et routes du serveur : `docs/fonctionnalites/listes-de-temoignages.md`
> dans TestiApp-Backend-Laravel. Cette page décrit ce que fait l'application.

Comme les playlists YouTube : un compte regroupe ses propres témoignages qui parlent d'une même
chose. Mettre un témoignage dans une liste est facultatif. Pendant la lecture d'un témoignage qui
fait partie d'une liste, l'application montre la liste et enchaîne sur le suivant.

## Code

| Fichier | Rôle |
|---|---|
| `lib/features/playlists/models/playlist_models.dart` | `Playlist`, `PlaylistItem`, `PlaylistContext` (champ `playlist` de `GET /testimonies/{id}`), `playlistNextToAutoplay` |
| `lib/features/playlists/data/playlist_api.dart` | `PlaylistApi` : toutes les routes, erreurs `PlaylistFailure` (403, 404, 422, hors connexion) |
| `lib/features/playlists/providers/playlist_providers.dart` | `myPlaylistsProvider`, `userPlaylistsProvider`, `playlistProvider`, `playlistContextProvider`, `playlistAutoplayProvider`, `refreshPlaylists` |
| `lib/features/playlists/playlist_navigation.dart` | `openPlaylistItem` : vidéo → lecteur vidéo, audio → lecteur audio, écrit → page du témoignage, toujours avec la liste |
| `lib/features/playlists/widgets/` | Panneau du lecteur, bandeau « À suivre », carte, feuille « Ajouter à une liste », dialogue de création / modification, section du profil |
| `lib/features/playlists/screens/` | « Mes listes » (`/mes-listes`) et page d'une liste (`/listes/{id}`, aussi lien partagé) |
| `Testimony.playlist` | Liste en cours lue avec le témoignage (null hors liste) |

## Comportement

| Endroit | Ce qui se passe |
|---|---|
| Publier, étape 3 | Bloc « Liste de témoignages » : une de mes listes ou le titre d'une nouvelle liste (prioritaire). Envoi de `playlist_id` ou `playlist_title` avec `POST /testimonies` et `POST /videos/upload-init`. Masqué pour le carnet privé. Erreur 422 `errors.playlist_id` sous le champ. Choix gardé dans le brouillon. |
| Détail, lecteur vidéo, lecteur audio | Panneau sous le lecteur : titre (ouvre la liste), « auteur · 2 sur 5 », Précédent / Suivant, interrupteur « Lecture auto de la liste » (pas pour un écrit), témoignages avec celui en cours en surbrillance. La liste vient de `GET /testimonies/{id}?list=` ; sans `?list=`, le serveur choisit. |
| Fin d'une vidéo ou d'un audio | Si la liste a un suivant et que l'interrupteur est actif : bandeau « À suivre » 5 s (Annuler, Lire maintenant), puis le suivant remplace la page. Interrupteur coupé : arrêt. Fin de liste : comportement habituel (recommandations, répétition). « Répéter ce témoignage » reste prioritaire. |
| Témoignage écrit | Bouton « Suivant » du panneau seulement (pas d'enchaînement après la lecture vocale). |
| Réglage | `playlist_autoplay` dans SharedPreferences, activé par défaut, séparé de la lecture auto ordinaire (Paramètres). |
| Mes listes | Menu du profil et menu latéral. Création, ouverture d'une liste ; dans la liste : Modifier, Supprimer (confirmation), ordre par glisser-déposer (`PUT` avec `testimonyIds`), Retirer (confirmation), ajout d'un de mes témoignages (hors carnet privé). |
| Ajouter à une liste | Page de son témoignage et menu de « Mes publications » : une de ses listes ou « Nouvelle liste » (`POST /playlists` avec `testimonyIds`). |
| Profil d'un compte | Section « Listes » (`GET /users/{id}/playlists`), masquée s'il n'y en a aucune. |
| Page d'une liste | Tout lire (premier témoignage avec la liste), Partager (`shareUrl`). |

## Lecteur audio et liste

En mode liste, le lecteur audio n'enchaîne pas sur les audios du fil : `AudioPlayerNotifier.stopAtTrackEnd`
arrête la piste et incrémente `completedTracks`, l'écran affiche alors le bandeau. Chaque nouvelle
file a une `session` : quand un lecteur est remplacé par le suivant de la liste, il n'arrête que sa
propre lecture (`stopSession`).

## Limites connues

- La liste en cours est lue par une requête `GET /testimonies/{id}` de plus à l'ouverture du
  détail et des lecteurs (le serveur compte une vue par personne toutes les 30 minutes).
- Le mode immersif du détail et les Shorts n'affichent pas le panneau.
- Lien `https://<domaine>/listes/{id}` : `/listes/` dans l'intent-filter autoVerify
  d'`AndroidManifest.xml` ; le serveur déclare `/listes/*` dans apple-app-site-association (iOS,
  entitlement `applinks:` existant, liens profonds Flutter actifs par défaut). Le routeur ouvre
  `PlaylistScreen` sur `/listes/:id`, accessible sans compte.

Tests : `test/playlists_test.dart`.

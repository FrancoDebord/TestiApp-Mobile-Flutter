# Backend : qualités média & comptes organisation

> **Implémenté le 2026-09-28** dans TestiApp-Backend-Laravel. La référence à
> jour se trouve dans `docs/fonctionnalites/qualites-media.md` et
> `docs/fonctionnalites/comptes-organisation.md` du backend. Ce document garde
> le contrat d'échange attendu par l'app.

Contrat entre l'app et **TestiApp-Backend-Laravel**. Sans ces champs, l'app
fonctionne quand même : elle lit le fichier original et n'affiche pas de badge
vérifié.

---

## 1. Qualités vidéo / audio (MP4 multi-qualités)

### Ce que l'app attend

Chaque témoignage audio ou vidéo (`TestimonyResource`) peut renvoyer un champ
`renditions`. L'app accepte aussi `mediaRenditions` et `media_renditions`.
`mediaUrl` reste l'original et sert de secours.

```json
{
  "type": "video",
  "mediaUrl": "https://…/storage/media/videos/abc.mp4",
  "renditions": [
    { "quality": "240p", "height": 240, "bitrate": 400,  "url": "https://…/abc_240p.mp4" },
    { "quality": "360p", "height": 360, "bitrate": 800,  "url": "https://…/abc_360p.mp4" },
    { "quality": "720p", "height": 720, "bitrate": 2500, "url": "https://…/abc_720p.mp4" }
  ]
}
```

Audio : même format, sans `height`, avec `bitrate` en kbps (32, 64, 128).
L'app accepte aussi une forme courte : `{ "360p": "url", "720p": "url" }` ou
`{ "64k": "url" }`. Les URLs relatives (`/storage/...`) sont acceptées.

### Choix de la qualité dans l'app (mode « Auto »)

| Réseau          | Normal        | Économiseur de données |
|-----------------|---------------|------------------------|
| Wi-Fi           | ≤ 720p / max  | ≤ 480p / 64 kbps       |
| Données mobiles | ≤ 360p / 64k  | 144p (la plus basse) / 32 kbps |

L'app lit la version la plus haute qui ne dépasse pas ce plafond. Si aucune ne
convient, elle lit la plus basse. L'utilisateur peut aussi choisir une qualité
manuellement.

### Implémentation suggérée

1. Installer ffmpeg sur le serveur. Ajouter `pbmedia/laravel-ffmpeg` ou appeler
   `ffmpeg` avec `Symfony\Process`.
2. Ajouter une migration `media_renditions` : `id`, `media_file_id` (FK),
   `quality` (string), `height` (nullable int), `bitrate_kbps` (int), `path`,
   `url`, `size_bytes`. Ou, plus simple, une colonne JSON `renditions` sur
   `testimonies`.
3. Créer un job `TranscodeMediaJob implements ShouldQueue`, lancé depuis
   `MediaController::upload()` pour les types video/audio. La file est déjà
   `database` : lancer `php artisan queue:work` sur le serveur.
   - Vidéo : 240p, 360p, 480p, 720p (seulement celles ≤ la hauteur source), H.264 + AAC, `-movflags +faststart` (lecture progressive)
     ```
     ffmpeg -i in.mp4 -vf scale=-2:360 -c:v libx264 -preset veryfast -crf 28 \
            -maxrate 800k -bufsize 1600k -c:a aac -b:a 96k -movflags +faststart out_360p.mp4
     ```
   - Audio : AAC/M4A à 32, 64 et 128 kbps
     ```
     ffmpeg -i in.m4a -vn -c:a aac -b:a 64k out_64k.m4a
     ```
   - Profiter du job pour calculer `duration_sec` (ffprobe). Aujourd'hui il est
     toujours à 0.
4. Ajouter `renditions` dans `TestimonyResource`.

---

## 2. Comptes organisation

### Inscription — `POST /api/v1/auth/register`

L'app envoie en plus :

| Champ                  | Valeurs                                                     |
|------------------------|-------------------------------------------------------------|
| `account_type`         | `individual` \| `organization`                              |
| `organization_name`    | requis si organisation (aussi envoyé dans `display_name`)   |
| `organization_type`    | `church`, `ministry`, `association`, `ngo`, `media`, `other`|
| `organization_city`    | requis si organisation                                      |
| `organization_website` | optionnel, URL                                              |

Pour une organisation, l'app envoie le nom de l'organisation dans `name`,
`display_name` et `first_name`, et `last_name` vide. `last_name` ne doit donc
pas être obligatoire.

Validation suggérée (`RegisterRequest`) :
`account_type` → `in:individual,organization` ; les champs `organization_*`
→ `required_if:account_type,organization`, sauf `organization_website`
(`nullable|url`).

### Données utilisateur — `UserResource`

Ajouter : `account_type`, `organization_name`, `organization_type`,
`organization_city`, `organization_website`, `is_verified` (bool) et
`verification_status` (`pending` | `verified` | `rejected`).

Dans l'auteur d'un témoignage (`user` de `TestimonyResource`), au minimum
`account_type` et `is_verified`, pour afficher le badge.

### Base de données

Migration sur `users` :
- `account_type` string(20), défaut `individual`
- `organization_name`, `organization_type`, `organization_city`, `organization_website` : nullable
- `verification_status` string(20), nullable, `pending` à l'inscription d'une organisation
- `verified_at` timestamp, nullable
- `verified_by` uuid, nullable

`is_verified` = `verification_status === 'verified'`.

### Admin (panel Blade + API)

- Liste des utilisateurs : filtre « Organisations en attente ».
- Fiche utilisateur : boutons **Vérifier** et **Refuser** (met à jour
  `verification_status`, `verified_at`, `verified_by`), avec une notification
  push à l'organisation.
- API : `POST /admin/users/{id}/verify` et `POST /admin/users/{id}/reject-verification`.

Mise à jour du profil (`PUT /users/me`) : accepter les mêmes champs
`organization_*`. Modifier le nom d'une organisation vérifiée devrait la
remettre en `pending`.

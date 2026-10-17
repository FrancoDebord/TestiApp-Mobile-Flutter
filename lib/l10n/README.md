# Traductions (français / anglais)

L'application est traduite avec `flutter_localizations` et des fichiers ARB.

| Fichier | Rôle |
|---|---|
| `lib/l10n/arb/app_fr.arb` | Textes français, **modèle** : chaque clé y est définie, avec ses `@métadonnées` |
| `lib/l10n/arb/app_en.arb` | Traductions anglaises (mêmes clés) |
| `lib/l10n/gen/` | Code Dart **généré** par `flutter gen-l10n` (ne pas modifier à la main) |
| `lib/l10n/app_localizations.dart` | Point d'entrée : `context.l10n`, `L10n.current`, choix de la langue |
| `lib/l10n/formatters.dart` | Dates, heures et nombres selon la langue |
| `l10n.yaml` | Configuration de la génération |

## Ajouter ou modifier un texte

1. Ajouter la clé dans `app_fr.arb` **et** `app_en.arb` (clé `lowerCamelCase`, préfixée par la fonctionnalité : `eventsCancelTitle`, `liveEndConfirm`…).
2. Lancer `flutter gen-l10n` (fait aussi automatiquement par `flutter run` / `flutter build`).
3. Utiliser le texte :
   - dans un widget : `Text(context.l10n.eventsCancelTitle)` ;
   - hors widget (modèle, enum, service, provider) : `L10n.current.eventsCancelTitle`.
     Ne jamais mettre la valeur dans une constante ou un champ `static final` : elle ne suivrait pas un changement de langue. Utiliser un getter.

### Paramètres et pluriels (syntaxe ICU)

```json
"eventsAttendees": "{count, plural, =0{Aucun participant} =1{1 participant} other{{count} participants}}",
"@eventsAttendees": {"placeholders": {"count": {"type": "int"}}},
"liveHostedBy": "Animé par {name}",
"@liveHostedBy": {"placeholders": {"name": {"type": "String"}}}
```

Les métadonnées `@clé` ne vont que dans `app_fr.arb`. Les apostrophes s'écrivent telles quelles (`l'application`).

## Dates et nombres

Toujours passer par `lib/l10n/formatters.dart` : `formatDate`, `formatDateLong`, `formatDayMonth`, `formatTime`, `formatDateTime`, `formatTimeAgo`, `formatNumber`, `formatCompactNumber`, `formatBytes`, `formatPercent`. Ne pas écrire de noms de mois ni de « il y a » à la main.

## Langue

- Paramètres › Langue : **Langue du système** (par défaut), Français ou English.
- La langue affichée part dans l'en-tête `Accept-Language` de chaque requête (`fr-BJ,fr;q=0.9`) et au serveur via `PUT /me { locale }` (repli sur `PUT /users/me` tant que `/me` n'existe pas).

## Chaînes oubliées

```
dart run tool/find_hardcoded_strings.dart              # liste tout lib/
dart run tool/find_hardcoded_strings.dart lib/features/live
dart run tool/find_hardcoded_strings.dart --count      # total par fichier
```

Une chaîne volontairement non traduite (nom propre, marque, référence biblique, valeur envoyée au serveur) se marque avec `// i18n-ignore` en fin de ligne ; une table de données bilingue avec `// i18n-ignore-file`.

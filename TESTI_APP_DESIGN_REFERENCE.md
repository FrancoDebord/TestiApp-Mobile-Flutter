# TÉMOIGNAGES — COMPLETE DESIGN & ARCHITECTURE REFERENCE

**Version 1.0 — Production Reference**
**Last updated: 2026-05-30**
**Audience: Flutter development team**

---

## TABLE OF CONTENTS

0. Executive Summary
1. User Flows & Information Architecture
2. Design System
3. Navigation Architecture
4. Screen Specifications
5. Flutter Technical Architecture
6. Reusable Widget Library
7. Data Models & Services
8. Implementation Roadmap
9. UX Recommendations & Best Practices
10. Accessibility & Inclusive Design

---

---

## 0. EXECUTIVE SUMMARY

### Product Vision

Témoignages is a faith-based mobile platform designed to give every believer a voice. The app allows users across the French-speaking Christian world to share, discover, and engage with personal testimonies of healing, deliverance, conversion, and divine intervention. Unlike generic social platforms, Témoignages is intentional in its purpose: every design and technical decision prioritizes spiritual depth, community trust, and authentic storytelling over engagement metrics or virality. The product serves three distinct actors — visitors who browse anonymously, authenticated believers who publish and interact, and moderators who safeguard content integrity — and their flows are designed to be frictionless, respectful, and mutually reinforcing.

### Design Philosophy

The visual language of Témoignages draws from the lexicon of sacred spaces: deep purple-blacks reminiscent of an illuminated night sky, gold accents echoing manuscript illuminations, and generous white space that invites contemplation rather than consumption. The design system is not a generic Material or Cupertino theme applied to a faith topic — it is an independently authored, spiritually intentional system where every color token, typography scale, and motion curve has been chosen to reinforce reverence, warmth, and trust. The typography trio (Poppins for clarity, Inter for readability, Playfair Display Italic for scripture) mirrors the three registers of worship: proclamation, conversation, and devotion. Micro-animations are celebratory rather than distracting, rewarding genuine acts of community (publishing, reacting, praying) with brief, joyful responses.

### Technical Approach

The Flutter implementation follows a layered, feature-first architecture built on Riverpod 2 for state management, GoRouter for declarative navigation with role-based guards, Freezed for immutable, code-generated data models, and Dio with interceptors for resilient API communication. The project is organized around vertical feature slices (`auth`, `testimony`, `moderation`, `admin`, `profile`, `notifications`) each containing its own screens, providers, models, and widgets, with horizontal shared infrastructure (`core/`, `shared/`) for design tokens, routing, networking, and reusable components. This architecture supports parallel team development — a developer can own the entire `moderation` feature without touching `auth` — and the strict separation of concerns ensures that the eventual addition of features (live prayer, groups, Bible reading plans) can be grafted onto the existing structure without refactoring.

---

---

## 1. USER FLOWS & INFORMATION ARCHITECTURE

### 1.1 Visitor (Unauthenticated) Entry Flow

```
[App Launch]
      |
[Splash Screen — 2.5s]
  Logo + tagline "Partagez votre foi"
  Primary #6B21A8 background, animated logo
      |
[First Launch Check] — Hive local store
      |
      ├── First time? YES ──→ [Onboarding Flow]
      |
      └── Returning visitor? NO ──→ [Auth Gate Screen]
```

**Onboarding (3 slides — swipeable + skip button)**

```
[Slide 1: Témoignez]
  Illustration: person sharing
  Heading (Poppins SemiBold): "Partagez votre témoignage"
  Body (Inter): "Inspirez des milliers de croyants à travers le monde"
  Progress dots: ● ○ ○
      |
[Slide 2: Découvrez]
  Illustration: feed with categories
  Heading: "Découvrez des miracles"
  Body: "Guérison, délivrance, conversion... Dieu agit encore"
  Progress dots: ○ ● ○
      |
[Slide 3: Communauté]
  Illustration: community hands
  Heading: "Rejoignez la communauté"
  Body: "Priez, encouragez, et grandissez ensemble"
  Progress dots: ○ ○ ●
      |
      ├── [S'inscrire] ──→ [Registration Screen]
      └── [Parcourir sans compte] ──→ [Home Feed — Mode Visiteur]
```

**Auth Gate Screen**

```
[Auth Gate Screen]
  Logo (small)
  Heading: "Bienvenue sur Témoignages"
      |
      ├── [S'inscrire] ──→ [Registration Flow]
      ├── [Se connecter] ──→ [Login Flow]
      └── [Continuer sans compte] ──→ [Home Feed — Mode Visiteur]
```

---

### 1.2 Authentication Flows

**Registration**

```
[Registration Screen]
  Prénom + Nom | Email | Mot de passe (+ confirm)
  Pays (dropdown) | Église/Communauté (optional)
  [ ] Accepter les CGU
      |
      ├── [Créer mon compte]
      |       ↓
      |   [Email Verification Sent Screen]
      |       ↓ (link clicked in email)
      |   [Account Verified] ──→ [Home Feed — Utilisateur]
      |
      └── [Déjà un compte?] ──→ [Login Screen]
```

**Login**

```
[Login Screen]
  Email | Mot de passe
  [Mot de passe oublié?] ──→ [Forgot Password Screen]
                                    ↓
                              Enter email → Reset email sent
                                    ↓
                              [New Password Screen] ──→ [Login Screen]
      |
      ├── [Se connecter]
      |       ├── Success ──→ [Home Feed — Utilisateur]
      |       └── Fail ──→ [Inline error] (retry or forgot password)
      |
      ├── [Continuer avec Google] ──→ [Google OAuth] ──→ [Home Feed]
      └── [Pas encore de compte?] ──→ [Registration Screen]
```

---

### 1.3 Visitor Browse Mode

```
[Home Feed — Mode Visiteur]
  Sticky banner: "Connectez-vous pour interagir"
  Bottom Navigation: Accueil | Explorer | Publier | Notifications | Profil
      |
      ├── [Feed Card] ──→ [Testimony Detail — Read Only]
      |       ├── Tap reaction ──→ [Modal: S'inscrire | Se connecter | Annuler]
      |       ├── Tap commenter ──→ [Same modal]
      |       └── Tap partager ──→ [Native Share Sheet — ALLOWED]
      |
      ├── [Explorer Tab] ──→ [Search & Categories — Read Only]
      ├── [Publier Tab] ──→ [Prompt: "Connectez-vous pour publier"]
      ├── [Notifications Tab] ──→ [Prompt: "Connectez-vous"]
      └── [Profil Tab] ──→ [Auth Gate Screen]
```

---

### 1.4 Authenticated User — Home Feed

```
[Home Feed — Utilisateur Connecté]
  Header: Logo + Search icon + Notification bell (badge count)
  Greeting: "Bonjour, [Prénom]"
  Verse du jour card (Playfair Italic)
  Category filter chips: Tous | Guérison | Délivrance | ...
  Vertical feed: Testimony cards (infinite scroll)
      |
      ├── [Verse card] ──→ [Full Verse Modal] ──→ [Share]
      ├── [Category chip] ──→ [Filtered Feed]
      ├── [Testimony Card] ──→ [Testimony Detail Screen]
      └── [Notification bell] ──→ [Notifications Screen]
```

---

### 1.5 Testimony Detail Flows

**Text Testimony**
```
[Testimony Detail — Texte]
  Header: back | share | more options (⋮)
  ⋮ menu: Signaler | Partager | (own) Modifier | Supprimer
  ─────────────────────────────────
  Author section: Avatar → [Public Profile] | Name | Church | Follow toggle
  Category badge + Date
  Title (Poppins SemiBold large)
  Bible verse (Playfair Italic, gold #F59E0B left border)
  Full testimony text (collapsible if > 500 words)
  Tags: #Guérison #Miracle
  ─────────────────────────────────
  [Reaction Bar]: Amen 🙌 | Prier 🙏 | Touché ❤️ (toggle, optimistic update)
  [Action Bar]: Commenter | Partager | Sauvegarder
  ─────────────────────────────────
  [Comments Section]
    Comment list + reply threads (collapsed by default)
    [Comment Input Bar — sticky bottom]: avatar | field | send | @ mention | emoji
```

**Audio Testimony**
```
[Testimony Detail — Audio]
  (Same header, author, category, title, verse)
  ─────────────────────────────────
  [Audio Player Card]
    Waveform visualization (animated during playback)
    Duration: 0:00 / 12:34
    [▶ Play/Pause] [⏮ Rewind 15s] [⏭ Forward 15s]
    [Speed: 1x → 1.25x → 1.5x → 2x]
    [Download for offline]
  Transcript (collapsible, if provided)
  (Same reaction bar, action bar, comments)
```

**Video Testimony**
```
[Testimony Detail — Vidéo]
  [Video Player — 16:9 ratio]
    Thumbnail → tap to play
    Full-screen toggle (landscape)
    Progress bar + duration
    [Play/Pause] [Mute] [Quality: Auto/360p/720p]
  (Same metadata, verse, reaction bar, action bar, comments)
```

---

### 1.6 Publication Flows

```
[Publier Tab]
      ↓
[Publish Type Chooser]
  [Texte] | [Audio] | [Vidéo]
```

**Text Publication (2 steps)**

```
Step 1: Content
  Title (max 100) | Category (required) | Bible verse (optional → Bible Search Modal)
  Rich Text Editor (Bold | Italic | Quote | List | Verse-style)
  Tags (max 5) | Auto-save "Brouillon sauvegardé"
      ↓
Step 2: Privacy & Submit
  Visibility: Public | Communauté
  Allow comments: [Toggle] | Allow sharing: [Toggle]
  Preview card
  [Soumettre pour révision]
      ↓
[Confirmation] — checkmark animation + "En cours de révision"
  [Voir mes témoignages] | [Retour à l'accueil]
```

**Audio Publication (2 steps)**

```
Step 1: Record or Upload
  [Record tab]: mic permission → waveform visualizer → Record/Pause/Stop → Preview
    Max duration: 15:00
  [Upload tab]: file picker (MP3, M4A, WAV ≤ 50MB) → preview player
      ↓
Step 2: Metadata
  Title | Category | Bible verse | Transcript (optional) | Tags | Visibility | Comments
  [Soumettre] → [Upload progress] → [Confirmation]
```

**Video Publication (2 steps)**

```
Step 1: Record or Upload
  [Record tab]: camera permission → preview → Record/Stop → preview clip
    Max duration: 10 minutes
  [Upload tab]: gallery picker (MP4, MOV ≤ 500MB) → thumbnail preview
      ↓
Step 2: Thumbnail & Metadata
  Thumbnail (auto-extracted or from gallery)
  Title | Category | Bible verse | Tags | Visibility
  [Soumettre] → [Upload progress with MB indicator] → [Confirmation]
```

---

### 1.7 Profile & Settings Flow

```
[Profil Tab]
  Profile Header: Cover | Avatar | Name | Church + City + Country | Bio | Stats row
  [Modifier le profil] ──→ [Edit Profile Screen]
      Edit: Avatar | Cover | Nom | Bio | Église | Ville | Pays
      [Sauvegarder] → success toast
  ─────────────────────────────────
  Tabs: Mes témoignages | Sauvegardés | Aimés
    Mes témoignages: filter Tous | En révision | Publiés | Rejetés
      Swipe left → Delete | Edit options
  ─────────────────────────────────
  [Settings ⚙]
    Compte: Email | Mot de passe | Supprimer le compte
    Notifications: per-type push toggles
    Confidentialité: Profil public/privé
    Langue: Français | English
    Thème: Clair | Sombre | Système
    À propos: Version | CGU | Politique de confidentialité
    [Se déconnecter] (Danger #EF4444)
```

---

### 1.8 Moderator Flow

```
[Login] ──→ [Role: Modérateur detected]
      ↓
[Modération Tab — Dashboard]
  Stats: En attente | Approuvés (today) | Rejetés (today) | Signalements
  Filter tabs: En attente | Approuvés | Rejetés | Signalements
  Submission Queue (oldest first)
    Card: Author | Type badge | Category | Title preview | Submitted time
    [Examiner →]
      ↓
[Review Screen]
  Author Info: Avatar | Name | Church | Account age | Previous submissions
  Full content preview: text / audio player / video player
  Moderation Checklist (internal)
  ─────────────────────────────────
  [✅ APPROUVER]
    Confirm → Status: Publié → Author notified → Return to queue
  [✏️ DEMANDER UNE MODIFICATION]
    Reason checkboxes + free text (max 500) → Status: modification demandée
    → Author notified with feedback → Return to queue
  [❌ REJETER]
    Required reason (radio) + internal note → Status: Rejeté
    → Author notified with sanitized reason → Return to queue
```

**Reports Flow**

```
[Modération Tab → Signalements]
  Report card: testimony title | report count | category | [Examiner]
      ↓
[Report Review Screen]
  Full testimony + report details (anonymized)
  [Ignorer] | [Retirer temporairement] | [Rejeter] | [Bannir auteur → escalate Admin]
```

---

### 1.9 Notification Flow

```
[Notifications Screen]
  Filter: Tous | Réactions | Commentaires | Abonnements | Système
  Grouped by: Aujourd'hui | Cette semaine | Plus tôt
  ─────────────────────────────────
  Types:
    🙌 Amen reaction ──→ Testimony Detail
    💬 Comment ──→ Testimony Detail + scroll to comment
    🙏 Prière ──→ Testimony Detail
    👤 New follower ──→ Public Profile
    ✅ Approved ──→ Testimony Detail
    ❌ Rejeté ──→ Rejection Detail Screen
    ✏️ Modification demandée ──→ Edit Testimony
    📢 System ──→ Web view / info modal
```

---

### 1.10 Key User Journeys

**Journey 1 — First-time Visitor Discovers and Registers**

| Step | Screen | Action |
|---|---|---|
| 1 | Splash Screen | App launches, 2.5s animated logo |
| 2–3 | Onboarding (3 slides) | Swipe through all slides |
| 4 | Home Feed (visitor) | Browses testimonies read-only |
| 5 | Testimony Detail | Reads full testimony |
| 6 | Reaction gate | Taps Amen → modal appears |
| 7 | Registration | Fills form, accepts CGU |
| 8 | Email Verification | Opens link in email |
| 9 | Home Feed (authenticated) | Account verified, reacts with haptic |

**Journey 2 — Believer Publishes a Text Testimony**

| Step | Action |
|---|---|
| 1–2 | Taps Publier → selects Texte |
| 3–7 | Fills title, category, Bible verse, body, tags |
| 8–9 | Confirms privacy settings |
| 10–11 | Submits → confirmation screen |
| 12–13 | Receives push notification → testimony live |

**Journey 3 — User Engages with an Audio Testimony**

| Step | Action |
|---|---|
| 1–3 | Filters by Délivrance → opens audio card |
| 4–8 | Plays audio, adjusts speed, skips forward |
| 9–12 | Reacts (Prier), comments, shares via WhatsApp |
| 13–14 | Bookmarks, follows author |

**Journey 4 — Moderator Processes the Review Queue**

| Step | Action |
|---|---|
| 1–4 | Opens app → sees badge → opens dashboard → examines oldest item |
| 5–10 | Reads content, checks list → approves → success toast |
| 11–14 | Reviews audio → requests modification with note |
| 15–17 | Reviews third (promotional) → rejects → queue empty |

**Journey 5 — User Receives Rejection, Corrects, and Resubmits**

| Step | Action |
|---|---|
| 1–4 | Receives rejection push notification → reads reason and note |
| 5–9 | Edits testimony, adds verse and detail |
| 10–14 | Resubmits → moderator approves → receives approval notification |
| 15 | First reaction arrives |

---

### 1.11 Full Information Architecture

```
TÉMOIGNAGES APP
│
├── L0: Entry Points
│   ├── Splash Screen
│   ├── Onboarding (3 slides)
│   └── Auth Gate
│       ├── Login Screen
│       │   └── Forgot Password → Reset Password Screen
│       └── Registration Screen
│           └── Email Verification Screen
│
├── L1: Main Navigation (Bottom Bar)
│   │
│   ├── [1] ACCUEIL
│   │   ├── Feed principal (infinite scroll)
│   │   │   └── Category filter chips
│   │   ├── Verse du Jour card → Full Verse Modal
│   │   └── Testimony Card → L2: Testimony Detail
│   │
│   ├── [2] EXPLORER
│   │   ├── Search Bar → Search Results
│   │   ├── Categories Grid → Category Feed
│   │   ├── Trending Section
│   │   └── Recent / New
│   │
│   ├── [3] PUBLIER
│   │   ├── Publish Type Chooser
│   │   ├── Publish Text Flow (2 steps)
│   │   │   └── Bible Search Modal
│   │   ├── Publish Audio Flow (2 steps)
│   │   ├── Publish Video Flow (2 steps)
│   │   └── Submission Confirmation
│   │
│   ├── [4] NOTIFICATIONS
│   │   ├── Notification List (filtered)
│   │   └── Notification Detail → deep link
│   │
│   └── [5] PROFIL
│       ├── Profile Header
│       ├── Tabs: Mes Témoignages | Sauvegardés | Aimés
│       ├── Edit Profile Screen
│       └── Settings Screen
│           ├── Compte (email / password / delete)
│           ├── Notifications
│           ├── Confidentialité
│           ├── Langue
│           ├── Thème
│           └── À propos (CGU / Privacy Policy)
│
├── L2: Testimony Detail
│   ├── Detail — Texte
│   ├── Detail — Audio (+ Audio Player)
│   └── Detail — Vidéo (+ Video Player + Fullscreen)
│
├── L3: Public Profile
│   ├── Profile Header (follow/unfollow)
│   ├── Testimonies tab
│   └── About tab
│
├── L4: Rejection Detail Screen
│   └── Edit & Resubmit → Publish Flow
│
└── L5: Modération (Modérateur / Administrateur only)
    ├── Moderation Dashboard
    │   ├── Queue: En attente → Review Screen
    │   │   ├── Approve flow
    │   │   ├── Request edit flow
    │   │   └── Reject flow
    │   ├── Queue: Signalements → Report Review Screen
    │   └── History log
    └── Admin Panel (Administrateur only)
        ├── User Management (ban / suspend / promote)
        ├── Moderator Management
        ├── Category Management
        ├── Announcement System
        └── Analytics Dashboard
```

---

### 1.12 Screen Inventory

| Screen | Access | Navigation Trigger |
|---|---|---|
| Splash | All | App launch |
| Onboarding (×3) | All — first launch | Auto |
| Auth Gate | Visitor | Onboarding / tab tap |
| Login | Visitor | Auth Gate |
| Registration | Visitor | Auth Gate / Login |
| Email Verification | Visitor | Registration |
| Forgot / Reset Password | Visitor | Login |
| Home Feed | All | Bottom nav |
| Category Feed | All | Home chips / Explorer |
| Search Screen | All | Explorer tab |
| Testimony Detail — Texte | All | Feed tap |
| Testimony Detail — Audio | All | Feed tap |
| Testimony Detail — Vidéo | All | Feed tap |
| Full Verse Modal | All | Home card tap |
| Comment Thread | Utilisateur+ | Detail screen |
| Report Modal | Utilisateur+ | Detail ⋮ menu |
| Public Profile | All | Author tap |
| Publish Type Chooser | Utilisateur+ | Bottom nav |
| Publish Text (×2 steps) | Utilisateur+ | Chooser |
| Publish Audio (×2 steps) | Utilisateur+ | Chooser |
| Publish Video (×2 steps) | Utilisateur+ | Chooser |
| Bible Search Modal | Utilisateur+ | Publish step 1 |
| Submission Confirmation | Utilisateur+ | Publish submit |
| Notifications | Utilisateur+ | Bottom nav / bell |
| Rejection Detail | Utilisateur+ | Notification tap |
| Profile | Utilisateur+ | Bottom nav |
| Edit Profile | Utilisateur+ | Profile |
| Settings | Utilisateur+ | Profile |
| Modération Dashboard | Modérateur+ | Bottom nav tab |
| Review Screen | Modérateur+ | Dashboard queue |
| Report Review Screen | Modérateur+ | Dashboard reports |
| Edit Request Modal | Modérateur+ | Review screen |
| Rejection Modal | Modérateur+ | Review screen |
| Admin Panel | Administrateur | Modération tab |

---

---

## 2. DESIGN SYSTEM

### 2.1 Color Tokens

#### Light & Dark Mode Reference

| Token | Light | Dark | Notes |
|---|---|---|---|
| **Backgrounds** | | | |
| `background-primary` | `#F8FAFC` | `#0A0612` | Main app background |
| `background-secondary` | `#F1F5F9` | `#12091E` | Section backgrounds, containers |
| `background-tertiary` | `#E2E8F0` | `#1A0F2E` | Inactive areas, subtle groupings |
| **Surfaces** | | | |
| `surface-primary` | `#FFFFFF` | `#1E1035` | Cards, sheets, inputs |
| `surface-elevated` | `#FFFFFF` | `#261545` | Modals, bottom sheets |
| `surface-overlay` | `rgba(0,0,0,0.40)` | `rgba(0,0,0,0.72)` | Scrim behind modals |
| **Text** | | | |
| `text-primary` | `#0F172A` | `#F1F5F9` | Main readable text |
| `text-secondary` | `#64748B` | `#94A3B8` | Supporting labels, metadata |
| `text-tertiary` | `#94A3B8` | `#64748B` | Placeholders, disabled labels |
| `text-disabled` | `#CBD5E1` | `#334155` | Fully disabled |
| `text-inverse` | `#FFFFFF` | `#0F172A` | Text on dark surfaces |
| `text-on-primary` | `#FFFFFF` | `#FFFFFF` | Text on purple buttons |
| `text-on-gold` | `#1C0A00` | `#1C0A00` | Text on gold backgrounds |
| **Borders** | | | |
| `border-subtle` | `#F1F5F9` | `#1E1035` | Hairline separators |
| `border-default` | `#E2E8F0` | `#2D1B4E` | Input/card borders |
| `border-strong` | `#CBD5E1` | `#4C1D95` | Focused inputs |
| **Interactive — Primary (Purple)** | | | |
| `interactive-primary` | `#6B21A8` | `#7C3AED` | Primary buttons, links |
| `interactive-primary-hover` | `#581C87` | `#8B5CF6` | Hover state |
| `interactive-primary-pressed` | `#4C1D95` | `#6D28D9` | Pressed state |
| `interactive-primary-subtle` | `#F3E8FF` | `#2E1065` | Selected chip background |
| **Interactive — Secondary (Gold)** | | | |
| `interactive-secondary` | `#F59E0B` | `#FBBF24` | CTA accents, featured |
| `interactive-secondary-hover` | `#D97706` | `#F59E0B` | Gold hover |
| `interactive-secondary-subtle` | `#FFFBEB` | `#1C1400` | Gold-tinted surface |
| **Semantic** | | | |
| `semantic-success` | `#22C55E` | `#4ADE80` | Approved, published |
| `semantic-success-subtle` | `#F0FDF4` | `#052E16` | Success background |
| `semantic-warning` | `#F59E0B` | `#FBBF24` | Pending, caution |
| `semantic-warning-subtle` | `#FFFBEB` | `#1C1400` | Warning background |
| `semantic-error` | `#EF4444` | `#F87171` | Errors, rejected |
| `semantic-error-subtle` | `#FEF2F2` | `#2D0000` | Error background |
| `semantic-info` | `#3B82F6` | `#60A5FA` | Informational |
| `semantic-info-subtle` | `#EFF6FF` | `#0C1A3D` | Info background |
| **Brand (Spiritual)** | | | |
| `spiritual-purple` | `#6B21A8` | `#7C3AED` | Brand identity |
| `spiritual-purple-light` | `#A855F7` | `#C084FC` | Gradients, highlights |
| `spiritual-purple-glow` | `rgba(107,33,168,0.18)` | `rgba(124,58,237,0.28)` | Focus rings |
| `spiritual-gold` | `#F59E0B` | `#FBBF24` | Secondary brand |
| `spiritual-gold-light` | `#FDE68A` | `#FEF08A` | Gold gradient ends |
| `spiritual-gradient-start` | `#6B21A8` | `#4C1D95` | Gradient from |
| `spiritual-gradient-end` | `#A855F7` | `#7C3AED` | Gradient to |

---

### 2.2 Typography Scale

**Font Families:**
- **Poppins** — Headings, display, nav labels (weights: 400, 500, 600, 700)
- **Inter** — Body text, UI labels, inputs (weights: 400, 500, 600)
- **Playfair Display** — Bible verses, pull-quotes (weights: 400 italic, 700 italic)

| Style | Family | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|---|
| `display-xl` | Poppins | 40px | 600 | 48px | -0.5px | Splash, hero |
| `display-lg` | Poppins | 32px | 600 | 40px | -0.3px | Onboarding headlines |
| `heading-1` | Poppins | 28px | 600 | 36px | -0.2px | Screen titles |
| `heading-2` | Poppins | 24px | 600 | 32px | -0.1px | Section headers |
| `heading-3` | Poppins | 20px | 600 | 28px | 0px | Card titles |
| `heading-4` | Poppins | 17px | 500 | 24px | 0px | Subsection labels |
| `body-lg` | Inter | 17px | 400 | 26px | 0px | Main testimony body |
| `body-md` | Inter | 15px | 400 | 23px | 0px | Standard body copy |
| `body-sm` | Inter | 13px | 400 | 20px | 0.1px | Descriptions |
| `caption` | Inter | 11px | 400 | 16px | 0.3px | Timestamps, counts |
| `label-lg` | Inter | 15px | 500 | 20px | 0.1px | Large button text |
| `label-md` | Inter | 13px | 500 | 18px | 0.2px | Small buttons, chips |
| `label-sm` | Inter | 11px | 600 | 16px | 0.4px | Badges, nav labels |
| `quote` | Playfair Display | 19px | 400i | 30px | 0.1px | Bible verses |
| `quote-lg` | Playfair Display | 22px | 700i | 34px | 0px | Featured scripture |

**Flutter TextStyle reference:**

```dart
// lib/core/theme/app_text_styles.dart

static const TextStyle displayXl = TextStyle(
  fontFamily: 'Poppins',
  fontSize: 40,
  fontWeight: FontWeight.w600,
  height: 1.2,
  letterSpacing: -0.5,
);

static const TextStyle bodyLg = TextStyle(
  fontFamily: 'Inter',
  fontSize: 17,
  fontWeight: FontWeight.w400,
  height: 1.53,
);

static const TextStyle quote = TextStyle(
  fontFamily: 'PlayfairDisplay',
  fontSize: 19,
  fontWeight: FontWeight.w400,
  fontStyle: FontStyle.italic,
  height: 1.58,
  letterSpacing: 0.1,
);
```

---

### 2.3 Spacing System

**Base unit: 4px.** All spacing is a multiple of 4.

| Token | px | Primary Use |
|---|---|---|
| `space-1` | 4px | Icon internal padding |
| `space-2` | 8px | Chip H padding, icon-label gap |
| `space-3` | 12px | Input V padding, list item gaps |
| `space-4` | 16px | Card padding, button H padding |
| `space-5` | 20px | Button V padding (L), avatar margins |
| `space-6` | 24px | Card padding, section content |
| `space-7` | 28px | Generous content separation |
| `space-8` | 32px | Section-to-section, modal padding |
| `space-10` | 40px | Screen top padding, hero margins |
| `space-11` | 44px | Min touch target height |
| `space-12` | 48px | Bottom bar height, large CTAs |
| `space-14` | 56px | FAB size, large avatar |
| `space-16` | 64px | Section breaks |
| `space-20` | 80px | Bottom nav safe area |
| `space-24` | 96px | Onboarding illustration area |

**Semantic aliases:**

| Alias | Token | Description |
|---|---|---|
| `padding-screen-h` | 24px | Horizontal page margin |
| `padding-screen-v` | 20px | Vertical page top/bottom |
| `padding-card` | 16px | Internal card padding |
| `padding-card-lg` | 24px | Large card padding |
| `gap-list-item` | 12px | Gap between list rows |
| `gap-inline` | 8px | Icon-to-label, chip-to-chip |
| `gap-section` | 32px | Between major screen sections |
| `min-touch-target` | 44px | Minimum tappable area (iOS HIG) |

---

### 2.4 Border Radius Tokens

| Token | Value | Usage |
|---|---|---|
| `radius-xs` | 4px | Badges, small chips, tooltips |
| `radius-sm` | 8px | Inputs, small buttons, chips |
| `radius-md` | 12px | Standard cards, dropdowns |
| `radius-lg` | 16px | Featured cards, media containers |
| `radius-xl` | 24px | Bottom sheets (top corners), large modals |
| `radius-2xl` | 32px | Onboarding cards, hero containers |
| `radius-full` | 9999px | Avatars, pills, FAB, status dots |

---

### 2.5 Shadow / Elevation Tokens

**Light mode:**

| Level | Shadow |
|---|---|
| `elevation-0` | none |
| `elevation-1` | `0 1px 3px rgba(15,23,42,0.06), 0 1px 2px rgba(15,23,42,0.04)` |
| `elevation-2` | `0 4px 8px rgba(15,23,42,0.08), 0 2px 4px rgba(15,23,42,0.04)` |
| `elevation-3` | `0 8px 16px rgba(15,23,42,0.10), 0 4px 8px rgba(15,23,42,0.06)` |
| `elevation-4` | `0 16px 32px rgba(15,23,42,0.12), 0 8px 16px rgba(15,23,42,0.08)` |
| `elevation-5` | `0 24px 48px rgba(15,23,42,0.16), 0 12px 24px rgba(15,23,42,0.10)` |

**Dark mode:**

| Level | Shadow |
|---|---|
| `elevation-1` | `0 1px 3px rgba(0,0,0,0.30), 0 1px 2px rgba(0,0,0,0.20)` |
| `elevation-2` | `0 4px 8px rgba(0,0,0,0.40), 0 2px 4px rgba(0,0,0,0.24)` |
| `elevation-3` | `0 8px 16px rgba(0,0,0,0.48), 0 4px 8px rgba(0,0,0,0.32)` |
| `elevation-4` | `0 16px 32px rgba(0,0,0,0.56), 0 8px 16px rgba(0,0,0,0.40)` |
| `elevation-5` | `0 24px 48px rgba(0,0,0,0.72), 0 12px 24px rgba(0,0,0,0.48)` |

**Brand glow (special):**

| Token | Light | Dark |
|---|---|---|
| `glow-spiritual` | `0 0 24px rgba(107,33,168,0.20)` | `0 0 32px rgba(124,58,237,0.36)` |
| `glow-gold` | `0 0 16px rgba(245,158,11,0.24)` | `0 0 24px rgba(251,191,36,0.32)` |

---

### 2.6 Icon Set (40 Icons — Lucide preferred)

**Navigation (8)**

| Token | Lucide Icon | Usage |
|---|---|---|
| `nav-home` | `Home` | Accueil tab |
| `nav-explore` | `Compass` | Explorer tab |
| `nav-publish` | `PlusCircle` | Publier tab (FAB-style) |
| `nav-notifications` | `Bell` | Notifications tab |
| `nav-profile` | `User` | Profil tab |
| `nav-back` | `ChevronLeft` | Back navigation |
| `nav-close` | `X` | Close modal |
| `nav-menu` | `Menu` | Hamburger / side menu |

**Actions (12)**

| Token | Lucide Icon | Usage |
|---|---|---|
| `action-share` | `Share2` | Share externally |
| `action-bookmark` | `Bookmark` | Save testimony |
| `action-bookmark-filled` | `BookmarkCheck` | Saved state |
| `action-like` | `Heart` | Encouragement reaction |
| `action-comment` | `MessageCircle` | Open comments |
| `action-pray` | `Flame` | Prier reaction |
| `action-report` | `Flag` | Report content |
| `action-edit` | `Pencil` | Edit |
| `action-delete` | `Trash2` | Delete |
| `action-filter` | `SlidersHorizontal` | Filter/sort |
| `action-search` | `Search` | Search trigger |
| `action-like-filled` | Custom filled Heart | Liked state |

**Categories (10)**

| Token | Lucide Icon | Category |
|---|---|---|
| `cat-healing` | `Stethoscope` | Guérison |
| `cat-deliverance` | `ShieldCheck` | Délivrance |
| `cat-conversion` | `Sparkles` | Conversion |
| `cat-marriage` | `Heart` (or custom Rings) | Mariage |
| `cat-family` | `Users` | Famille |
| `cat-finances` | `TrendingUp` | Finances |
| `cat-miracles` | `Zap` | Miracles |
| `cat-protection` | `Shield` | Protection divine |
| `cat-ministry` | `Mic` | Ministère |
| `cat-salvation` | `Sun` | Salut |

**Status & Roles (6)**

| Token | Lucide Icon | Usage |
|---|---|---|
| `status-verified` | `BadgeCheck` | Verified / approved |
| `status-pending` | `Clock` | Awaiting moderation |
| `status-rejected` | `XCircle` | Rejected content |
| `status-moderator` | `ShieldAlert` | Moderator badge |
| `status-admin` | `Crown` | Admin badge |
| `status-new` | `Sparkle` | New / unread |

**Media (4)**

| Token | Lucide Icon | Usage |
|---|---|---|
| `media-play` | `Play` | Play audio/video |
| `media-pause` | `Pause` | Pause playback |
| `media-mic` | `Mic2` | Audio type indicator |
| `media-video` | `Video` | Video type indicator |

---

### 2.7 Component Library Catalogue

#### Button

**Variants:** Type (`primary`, `secondary`, `ghost`, `danger`, `gold`) × Size (`S`, `M`, `L`) × State (`default`, `hover`, `pressed`, `disabled`, `loading`)

| Size | Height | H Padding | Font | Icon |
|---|---|---|---|---|
| S | 32px | 12px | `label-sm` | 14px |
| M | 44px | 20px | `label-md` | 16px |
| L | 52px | 24px | `label-lg` | 18px |

Shape: `radius-full`. Primary: `spiritual-purple` fill + white label. Gold: `spiritual-gold` fill + `text-on-gold`. Ghost: transparent + purple border. Danger: `semantic-error` fill. Loading: label replaced by 16px spinner matching label color.

---

#### Avatar

**Sizes:** `xs` (24px), `sm` (32px), `md` (40px), `lg` (56px), `xl` (80px)
**Types:** `image`, `initials`, `placeholder`

Circular (`radius-full`). Initials use purple gradient fill with white text. Verified badge: 16px `BadgeCheck` gold, bottom-right overlay on white circle.

---

#### Badge

**Types:** `count`, `label`, `dot`. **Semantics:** `default`, `success`, `warning`, `error`, `info`

Count badges: 18px min-width, 18px tall, `label-sm` white text. Dot badge: 8px solid circle. Positioned as stack overlay.

---

#### Chip / Tag

**Types:** `filter`, `category`, `status`, `input-tag`
**States:** `default`, `selected`, `disabled`

32px tall, `radius-full`. Default: `border-default` + `surface-primary` + `text-secondary`. Selected: `interactive-primary-subtle` fill + `interactive-primary` border + `text-primary`.

---

#### Testimony Cards

**Text card:** White surface, `radius-md`, `elevation-2`. Header: avatar + username + timestamp + overflow. Body: 3-line excerpt. Footer: CategoryChip + ReactionBar. Featured: 2px `spiritual-gold` top border + `glow-gold` shadow.

**Audio card:** Same base + mini AudioPlayer (waveform bar, play/pause, duration). `media-mic` badge on category chip.

**Video card:** Same base + 16:9 thumbnail (no H padding on media). Centered 48px circular white play overlay. Duration badge bottom-right.

---

#### InputField

**Types:** `text`, `email`, `password`, `number`, `multiline`
**States:** `default`, `focused`, `error`, `success`, `disabled`

48px tall, `radius-sm`. Default: `border-default` 1px. Focused: `interactive-primary` 2px + `spiritual-purple-glow` outer ring. Error: `semantic-error` border + red text below.

---

#### SearchBar

44px tall, `radius-full`. Filled: `background-secondary`, no border. Leading search icon. Trailing clear X when has-value. Focus animates to `interactive-primary` border.

---

#### BottomSheet

`surface-elevated` fill, `radius-xl` top corners, `elevation-4`. Handle: 4×32px `border-default` pill, 12px from top. Title `heading-3`. Safe area bottom padding respected.

---

#### Modal / Dialog

Centered overlay on scrim. `surface-elevated`, `radius-xl`, `elevation-5`, max-width 320px. Optional semantic icon (56px colored circle). Title `heading-3`, body `body-md`. Confirm destructive actions use `danger` button.

---

#### Toast / Snackbar

Pill: `radius-full`, 52px tall. Semantic-colored fill (subtle light / full-color dark). Appears 16px above nav bar, slide-up + fade-in. Auto-dismisses after 3s.

---

#### Skeleton Loader

Shimmer: linear left-to-right sweep, 1.5s loop. Light: base `background-secondary`, highlight `surface-primary`. Dark: `background-tertiary` / `surface-primary`. Text lines: `radius-full`. Image areas: `radius-md`.

---

#### AudioPlayer (Mini)

64px horizontal strip. Left: 40px circular play/pause (`interactive-primary`). Center: waveform bars (active `interactive-primary`, inactive `border-default`). Right: elapsed/total (`caption`). Docks above nav bar during playback.

---

#### AudioPlayer (Full)

Bottom sheet (75%). Large waveform (120px), time scrubber. Controls: skip-15s, play/pause (56px), skip+15s, speed chip (0.75x–2x). Background: `spiritual-gradient` at 8% opacity.

---

#### VideoPlayer

16:9, `radius-lg`. Custom controls overlay (fades 3s after interaction). Fullscreen via Hero animation. Buffering: `spinner-white` over semi-transparent scrim.

---

#### CategoryChip

36px tall, includes category icon (14px). Inactive: `background-secondary` + `text-secondary`. Active: `interactive-primary-subtle` + `interactive-primary` icon + `text-primary`. Horizontal scroll on Accueil, wrapping grid on Explorer.

---

#### ReactionBar

Each action: 20px icon + count (`caption`) + 36px touch target. Heart active: `semantic-error` + scale-bounce. Flame active: `spiritual-gold` + flicker. 40px minimum spacing between reactions.

---

#### CommentBubble

`surface-primary`, `radius-md`, `elevation-1`. Header: avatar xs + username + timestamp. Reply quotes parent in `background-secondary` with 4px `interactive-primary` left border. My-comment: right-aligned, `interactive-primary-subtle` fill.

---

#### NavigationBar

64px + safe area. Each tab: 20px icon + `label-sm`. Inactive: `text-tertiary`. Active: `interactive-primary`. Publier: 52px circular FAB-style, `glow-spiritual`, no label. Notification badge: `error` semantic. Active tab animates with `elastic` curve.

---

### 2.8 Animation & Motion Principles

**Duration Tokens**

| Token | Value | Usage |
|---|---|---|
| `duration-instant` | 80ms | Color swaps, checkbox |
| `duration-fast` | 150ms | Button press, icon swap |
| `duration-medium` | 250ms | Tab transitions, chip select |
| `duration-slow` | 380ms | Screen transitions, bottom sheet |
| `duration-extra-slow` | 500ms | Onboarding, splash, celebration |

**Easing Curves**

| Token | Cubic Bezier | Usage |
|---|---|---|
| `ease-linear` | `(0,0,1,1)` | Spinner, shimmer |
| `ease-standard` | `(0.4,0,0.2,1)` | General UI (Material standard) |
| `ease-decelerate` | `(0,0,0.2,1)` | Entering elements |
| `ease-accelerate` | `(0.4,0,1,1)` | Exiting elements |
| `ease-spring` | Spring(mass:1, stiffness:400, damping:28) | Toggle, reaction bounce |
| `ease-elastic` | Spring(mass:1, stiffness:280, damping:20) | FAB pop, active nav tab |

**5 Key Micro-Animations**

1. **Heart Reaction:** Scale 1.0 → 1.4 (spring, 150ms) + color → `semantic-error` (80ms) → settle 1.0 (250ms). First like: 3-particle burst fades 500ms. Count label slides up vertically.

2. **Publish Success:** Button → spinner (fast). Full-screen scrim + checkmark scales 0.5 → 1.0 (elastic, 380ms) → stays 800ms → testimony card slides from bottom with gold shimmer sweep (500ms).

3. **Navigation Tab Switch:** Indicator slides horizontally (standard, 250ms). Departing: → `text-tertiary` (fast). Arriving: scale 0.85 → 1.0 (elastic, 250ms) + → `interactive-primary`. Screen cross-fades (380ms).

4. **Bottom Sheet Open:** Scrim fades 0 → 40% (380ms, decelerate). Sheet translates from 100% below (380ms, decelerate). Content items stagger-fade 40ms apart. Dismiss: reverse (accelerate, 250ms).

5. **Audio Waveform Playback:** Bars fill left-to-right as playhead passes (`interactive-primary`). Ahead-of-playhead bars breathe ±2px height at 1.2s period, staggered by index×80ms. Play → Pause: 90-degree Y-flip (fast).

---

### 2.9 Dark Mode Strategy

**Core philosophy:** Purple-depth darkness, not charcoal grey. Backgrounds are deep purple-blacks (`#0A0612`, `#12091E`, `#1A0F2E`) to preserve spiritual brand identity. Primary purple brightens from `#6B21A8` to `#7C3AED` to maintain 4.5:1 contrast.

**Three-layer surface system (dark):**

| Layer | Token | Value | Purpose |
|---|---|---|---|
| Base | `background-primary` | `#0A0612` | App background |
| Raised | `surface-primary` | `#1E1035` | Cards, inputs |
| Floating | `surface-elevated` | `#261545` | Modals, sheets |

Each layer is 8–12% lighter in purple-hue saturation, creating perceived depth without losing brand identity.

**Key adjustments:**
- Semantic colors lighten 15–20 lightness points for dark background contrast
- `text-primary` uses `#F1F5F9` (cool white, not pure `#FFFFFF`) to reduce eye strain for devotional reading
- `glow-gold` intensifies from 24% to 32% opacity — gold on deep purple yields a sacred manuscript aesthetic
- Bottom nav bar uses `surface-primary` fill with no top border — elevation shadow alone creates separation (OLED-friendly)
- Skeleton shimmer: `#1E1035` base, `#261545` highlight — feels native, not grey-rectangle foreign objects
- `spiritual-purple-glow` increases from 18% to 28% opacity for focus ring visibility

**Accessibility in both modes:** All text targets minimum 4.5:1 contrast (WCAG AA). Large headings (18px+ bold) target 3:1 minimum. Color is never the sole state conveyor — all semantic states include icon, label, or pattern differentiation.

---

---

## 3. NAVIGATION ARCHITECTURE

### 3.1 Route Constants

```dart
// lib/core/router/app_routes.dart

abstract class AppRoutes {
  // Entry
  static const String splash        = 'splash';
  static const String onboarding    = 'onboarding';
  static const String authGate      = 'auth-gate';
  static const String login         = 'login';
  static const String register      = 'register';
  static const String forgotPassword = 'forgot-password';
  static const String verifyEmail   = 'verify-email';

  // Main shell
  static const String home          = 'home';
  static const String explorer      = 'explorer';
  static const String publish       = 'publish';
  static const String notifications = 'notifications';
  static const String profile       = 'profile';

  // Testimony
  static const String testimonyDetail = 'testimony-detail';
  static const String testimonyAudio  = 'testimony-audio';
  static const String testimonyVideo  = 'testimony-video';
  static const String publicProfile   = 'public-profile';
  static const String rejectionDetail = 'rejection-detail';

  // Publish flows
  static const String publishText   = 'publish-text';
  static const String publishAudio  = 'publish-audio';
  static const String publishVideo  = 'publish-video';
  static const String publishConfirm = 'publish-confirm';

  // Profile sub-screens
  static const String editProfile   = 'edit-profile';
  static const String settings      = 'settings';

  // Moderation
  static const String moderation    = 'moderation';
  static const String moderationDetail = 'moderation-detail';
  static const String reportReview  = 'report-review';

  // Admin
  static const String adminDashboard = 'admin-dashboard';
}

abstract class AppPaths {
  static const String splash        = '/';
  static const String onboarding    = '/onboarding';
  static const String authGate      = '/auth';
  static const String login         = '/auth/login';
  static const String register      = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyEmail   = '/auth/verify-email';

  static const String home          = '/home';
  static const String explorer      = '/home/explorer';
  static const String publish       = '/home/publish';
  static const String notifications = '/home/notifications';
  static const String profile       = '/home/profile';

  static const String testimonyDetail = '/testimony/:id';
  static const String publicProfile   = '/user/:userId';
  static const String rejectionDetail = '/rejection/:id';

  static const String publishText   = '/publish/text';
  static const String publishAudio  = '/publish/audio';
  static const String publishVideo  = '/publish/video';

  static const String editProfile   = '/profile/edit';
  static const String settings      = '/profile/settings';

  static const String moderation    = '/moderation';
  static const String moderationDetail = '/moderation/:id';
  static const String reportReview  = '/moderation/report/:id';

  static const String adminDashboard = '/admin';
}
```

---

### 3.2 GoRouter Configuration

```dart
// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppPaths.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        data: (s) => s is AuthStateAuthenticated,
        orElse: () => false,
      );
      final isLoading = authState.isLoading;
      final currentPath = state.matchedLocation;

      // Still loading — stay on splash
      if (isLoading) return AppPaths.splash;

      // Authenticated user trying to access auth screens
      final isAuthRoute = currentPath.startsWith('/auth');
      if (isAuthenticated && isAuthRoute) return AppPaths.home;

      // Protected routes requiring authentication
      final protectedPrefixes = [
        '/publish', '/profile/edit', '/profile/settings',
        '/moderation', '/admin',
      ];
      final isProtected = protectedPrefixes.any(
        (p) => currentPath.startsWith(p),
      );
      if (!isAuthenticated && isProtected) return AppPaths.authGate;

      // Role-based guards
      if (isAuthenticated) {
        final user = (authState.value as AuthStateAuthenticated).user;

        if (currentPath.startsWith('/moderation') &&
            !user.canModerate) return AppPaths.home;

        if (currentPath.startsWith('/admin') &&
            !user.isAdmin) return AppPaths.home;
      }

      return null;
    },

    routes: [
      // Entry
      GoRoute(
        path: AppPaths.splash,
        name: AppRoutes.splash,
        builder: (ctx, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppPaths.onboarding,
        name: AppRoutes.onboarding,
        builder: (ctx, state) => const OnboardingScreen(),
      ),

      // Auth
      GoRoute(
        path: AppPaths.authGate,
        name: AppRoutes.authGate,
        builder: (ctx, state) => const AuthGateScreen(),
        routes: [
          GoRoute(
            path: 'login',
            name: AppRoutes.login,
            builder: (ctx, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'register',
            name: AppRoutes.register,
            builder: (ctx, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: 'forgot-password',
            name: AppRoutes.forgotPassword,
            builder: (ctx, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: 'verify-email',
            name: AppRoutes.verifyEmail,
            builder: (ctx, state) => const VerifyEmailScreen(),
          ),
        ],
      ),

      // Main shell (bottom navigation)
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppPaths.home,
              name: AppRoutes.home,
              builder: (ctx, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppPaths.explorer,
              name: AppRoutes.explorer,
              builder: (ctx, state) => const ExplorerScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppPaths.publish,
              name: AppRoutes.publish,
              builder: (ctx, state) => const PublishChooserScreen(),
              routes: [
                GoRoute(
                  path: 'text',
                  name: AppRoutes.publishText,
                  builder: (ctx, state) => const PublishTextScreen(),
                ),
                GoRoute(
                  path: 'audio',
                  name: AppRoutes.publishAudio,
                  builder: (ctx, state) => const PublishAudioScreen(),
                ),
                GoRoute(
                  path: 'video',
                  name: AppRoutes.publishVideo,
                  builder: (ctx, state) => const PublishVideoScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppPaths.notifications,
              name: AppRoutes.notifications,
              builder: (ctx, state) => const NotificationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppPaths.profile,
              name: AppRoutes.profile,
              builder: (ctx, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  name: AppRoutes.editProfile,
                  builder: (ctx, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  name: AppRoutes.settings,
                  builder: (ctx, state) => const SettingsScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),

      // Testimony detail (accessible from any tab)
      GoRoute(
        path: '/testimony/:id',
        name: AppRoutes.testimonyDetail,
        builder: (ctx, state) => TestimonyDetailScreen(
          testimonyId: state.pathParameters['id']!,
          type: state.uri.queryParameters['type'] ?? 'text',
        ),
      ),
      GoRoute(
        path: '/user/:userId',
        name: AppRoutes.publicProfile,
        builder: (ctx, state) => PublicProfileScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/rejection/:id',
        name: AppRoutes.rejectionDetail,
        builder: (ctx, state) => RejectionDetailScreen(
          testimonyId: state.pathParameters['id']!,
        ),
      ),

      // Moderation
      GoRoute(
        path: AppPaths.moderation,
        name: AppRoutes.moderation,
        builder: (ctx, state) => const ModerationScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: AppRoutes.moderationDetail,
            builder: (ctx, state) => ModerationDetailScreen(
              itemId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'report/:id',
            name: AppRoutes.reportReview,
            builder: (ctx, state) => ReportReviewScreen(
              reportId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // Admin
      GoRoute(
        path: AppPaths.adminDashboard,
        name: AppRoutes.adminDashboard,
        builder: (ctx, state) => const AdminDashboardScreen(),
      ),
    ],

    errorBuilder: (ctx, state) => ErrorScreen(error: state.error),
  );
});
```

---

### 3.3 Deep Link Configuration

**`android/app/src/main/AndroidManifest.xml`**

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="temoignages.app"
        android:pathPrefix="/testimony" />
  <data android:scheme="https"
        android:host="temoignages.app"
        android:pathPrefix="/user" />
</intent-filter>
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="temoignages" />
</intent-filter>
```

**`ios/Runner/Info.plist`**

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>temoignages</string></array>
  </dict>
</array>
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:temoignages.app</string>
</array>
```

**Deep link map:**

| URL | Destination Screen |
|---|---|
| `https://temoignages.app/testimony/{id}` | `TestimonyDetailScreen(id)` |
| `https://temoignages.app/user/{userId}` | `PublicProfileScreen(userId)` |
| `temoignages://verify-email?token={token}` | `VerifyEmailScreen(token)` |
| `temoignages://reset-password?token={token}` | `ResetPasswordScreen(token)` |
| `temoignages://notification/{type}/{id}` | Context-dependent (see notification type map) |

---

---

## 4. SCREEN SPECIFICATIONS

### 4.1 Auth Screens

**File structure:**
```
lib/features/auth/
├── screens/
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── forgot_password_screen.dart
│   └── verify_email_screen.dart
└── widgets/
    └── auth_widgets.dart
```

**Shared Auth Widgets (`auth_widgets.dart`):**

| Widget | Description |
|---|---|
| `AuthWaveHeader` | Purple left→right gradient shell, top section of every auth screen |
| `AuthTextField` | Labelled `TextFormField` with prefix icon, show/hide toggle, all 4 border states |
| `AuthPrimaryButton` | Full-width `FilledButton` swapping label for `CircularProgressIndicator` when `isLoading` |
| `AuthErrorBanner` | Red inline banner for network / auth errors |
| `AuthOrDivider` | "ou continuer avec" row divider |
| `AuthSocialButton` | Outlined icon+label button for Google / Apple |

**Splash Screen:**
- `ConsumerStatefulWidget` — listens to `authProvider` via `ref.listen`, navigates once `AuthState` resolves
- Scale + fade entrance animation, three-dot pulsing indicator
- `_CrossCustomPainter` draws cross glyph using `CustomPaint`
- Minimum display 2.5s even if auth resolves faster

**Onboarding Screen:**
- `PageView.builder` with `BouncingScrollPhysics`
- Animated pill dot indicator (active pill elongates)
- Three `CustomPaint` illustrations using `dart:math` — raised hands, community hearts, open Bible + sun
- Skip button jumps directly to slide 3
- Last slide: `S'inscrire` (filled primary) + `Se connecter` (outlined) buttons

**Login Screen:**
- Screen-scoped `_loginLoadingProvider` / `_loginErrorProvider` (simple `StateProvider`)
- Password show/hide toggle via suffix icon
- Forgot-password right-aligned link below password field
- Google OAuth button with `AuthSocialButton`
- `GoRouter` redirect handles post-login navigation

**Register Screen:**
- `_AvatarPicker`: optional photo with gold camera badge overlay
- Two-column first/last name row
- `_CountryDropdown`: 55 countries, `initialValue` (not deprecated `value`)
- `_PasswordStrengthBar`: 4-segment indicator (score 0–4 based on length, symbols, case, numbers)
- `_TermsCheckbox`: purple `RichText` links to CGU and privacy policy

**Forgot Password Screen:**
- Two-state widget (`_InputBody` / `_SuccessBody`) driven by `_fpSentProvider`
- Email masking in success state (`j***@email.com`)
- `_EnvelopePainter` custom draws envelope + green checkmark
- Resend button returns to input state; transparent `AppBar` with back arrow

**Verify Email Screen:**
- Six individual `TextField` cells in `_OtpInputRow`
- Auto-advance on digit entry; backspace retreat via `KeyboardListener`
- Paste detection distributes digits across all 6 cells automatically
- 60s countdown timer via `dart:async Timer.periodic`
- Resend resets timer and clears all cells; confirm disabled until all 6 filled
- Sign-out link calls `authProvider.notifier.signOut()`

---

### 4.2 Home & Explorer Screens

**File structure:**
```
lib/features/home/
├── screens/
│   ├── home_screen.dart
│   └── explorer_screen.dart
└── widgets/
    ├── verse_of_day_card.dart
    ├── home_header.dart
    └── category_feed.dart
```

**Home Screen:**
- `NestedScrollView` with pinned `SliverAppBar`
- `Greeting` row: "Bonjour, [Prénom]" (Poppins SemiBold)
- `VerseOfDayCard`: `Playfair Display` italic, gold left border, share button → native share sheet
- `CategoryChipList` horizontal scroll — tap triggers filtered feed
- `TestimonyCard` list (infinite scroll via `ListView.builder` + pagination provider)
- Skeleton loading state during initial fetch and page loads
- Visitor mode: sticky "Connectez-vous pour interagir" dismissible banner

**Explorer Screen:**
- Sticky `SearchBar` at top (`radius-full`, filled style)
- Below search: categories grid (2-column, `CategoryChip` with `cat-*` icons)
- "Tendances" horizontal scroll section with featured cards
- "Récents" vertical list
- Search results replace category grid on input focus
- Search debounce: 400ms before API call
- Empty search results: `EmptyState(context: no-results)`

---

### 4.3 Testimony Detail & Media Players

**File structure:**
```
lib/features/testimony/
├── screens/
│   ├── testimony_detail_screen.dart
│   ├── audio_player_screen.dart
│   └── video_player_screen.dart
└── widgets/
    ├── bible_verse_section.dart
    ├── reaction_bar.dart
    └── comment_section.dart
```

**Testimony Detail Screen widget tree:**

```
TestimonyDetailScreen
└─ Scaffold
   ├─ body: CustomScrollView
   │  ├─ _HeroSliverAppBar (expandedHeight 280)
   │  │   gradient + cross pattern
   │  │   back button, share + bookmark (top-right)
   │  └─ SliverToBoxAdapter > Column
   │     ├─ _AuthorCard (avatar, name, church, follow toggle)
   │     ├─ _MetaRow (CategoryChip + relative date)
   │     ├─ _TitleText (Poppins SemiBold h2)
   │     ├─ _ReactionSummaryRow (❤️ 89 · 🙏 156 · 💬 34)
   │     ├─ _ContentBody (Inter, collapsible "Voir plus/moins" at 500 words)
   │     ├─ _AudioPlayerEmbed? (gradient card, mini progress, tap → AudioPlayerScreen)
   │     ├─ _VideoPlayerEmbed? (200px thumbnail, play overlay, HD/duration badges)
   │     ├─ _BibleVerseSection (gold left-border, Playfair italic verse + reference)
   │     ├─ _CommentsSection (header + input + 2 preview items)
   │     └─ _SimilarTestimonies (horizontal ListView, 148×168 cards)
   └─ bottomNavigationBar: _StickyReactionBar
      └─ Row: ❤️ J'aime | 🙏 Je prie | 💬 Commenter | 🔖 Sauvegarder | 📤 Partager
```

**Comment Bottom Sheet:**
```
_CommentsBottomSheet
└─ DraggableScrollableSheet (0.4 → 0.95)
   ├─ _DragHandle + _BottomSheetHeader ("Commentaires (34)" + ×)
   ├─ ListView: _CommentItem × n
   │   └─ _ReplyItem (1-level threading)
   └─ _CommentInputBar (avatar + TextField + send)
```

**Audio Player Screen widget tree:**

```
AudioPlayerScreen
└─ Scaffold (deep purple → near-black gradient background)
   ├─ body: SafeArea > Column
   │  ├─ _AudioAppBar (chevron-down, centered title, ⋯ more)
   │  └─ Expanded > Column
   │     ├─ _CoverArt (280×280, category gradient + cross pattern + AUDIO badge)
   │     ├─ _TrackInfo (Poppins 20 white, Inter 16, flag + date)
   │     ├─ _CategoryChipLight
   │     ├─ _ProgressSection (SliderTheme white, elapsed/total labels)
   │     ├─ _PlayerControls (⏮15s | ▶/⏸ 72px circle | ⏭15s)
   │     ├─ _SpeedSelector (0.75x 1x 1.25x 1.5x 2x pill container)
   │     ├─ _CastRow (AirPlay + Bluetooth icons)
   │     └─ _TranscriptToggle (AnimatedCrossFade collapsible)
   └─ _AudioReactionBar (dark variant)
```

```
MiniAudioPlayer (exported, docks above nav bar)
└─ Material > InkWell → opens AudioPlayerScreen
   └─ Container (56px)
      ├─ 40×40 gradient thumbnail
      ├─ Expanded: title (truncated) + author
      ├─ 36px primary circle play/pause
      └─ × close icon
```

**Video Player Screen widget tree (Portrait):**

```
VideoPlayerScreen
└─ Scaffold
   ├─ _VideoSurface (AspectRatio 16:9)
   │  └─ Stack
   │     ├─ _VideoPlaceholder (dark gradient thumbnail)
   │     └─ AnimatedOpacity(_VideoOverlay) — tap to show/hide
   │        ├─ top gradient: back arrow + title + fullscreen
   │        ├─ _CenterPlayPause (56px semi-transparent circle)
   │        └─ _BottomControlBar (SliderTheme, time, HD badge, cc, ⚙)
   └─ Expanded > Column
      ├─ _VideoMeta (title h3 + CategoryChipSmall)
      ├─ _VideoStats (👁 views · 📅 date)
      ├─ _VideoAuthorRow (avatar + name + follow toggle)
      ├─ _VideoReactionBar
      ├─ _VideoDescription (collapsible)
      ├─ _CommentsPreview → VideoCommentsBottomSheet
      └─ _RelatedVideosList (horizontal, 128×72 thumbnails)
```

**Fullscreen / Landscape mode (`_FullscreenVideoRoute`):**
- Pushes as separate route, locks to landscape, hides system UI
- Overlay fades 3s after inactivity while playing
- `GestureDetector` tap toggles overlay visibility
- Controls: back arrow + title (top), play/pause + scrubber + skip + cc + speed + rotate-lock (bottom)

**Mini Video Player (`MiniVideoPlayer`):**
- Positioned bottom-right, draggable via `onPanUpdate`
- 160×90, `radius-sm` (8px), shadow
- Tap opens full `VideoPlayerScreen`

---

### 4.4 Publication Flow

**File structure:**
```
lib/features/publish/
├── screens/
│   ├── publish_chooser_screen.dart
│   ├── publish_text_screen.dart
│   ├── publish_audio_screen.dart
│   ├── publish_video_screen.dart
│   └── publish_confirm_screen.dart
└── widgets/
    ├── bible_search_modal.dart
    ├── rich_text_editor.dart
    └── audio_recorder_widget.dart
```

**Publish Chooser:** Three tappable cards (Texte / Audio / Vidéo), each with icon, description, and navigation arrow. Cards use `elevation-2` with pressed state `elevation-1`.

**Publish Text (Step 1):** Rich text editor (`flutter_quill` or equivalent), title field (100 char counter), category dropdown (10 options), Bible verse field (tap → `BibleSearchModal`), tags field (max 5, chip input pattern), auto-save indicator.

**Publish Text (Step 2):** Visibility radio group (Public / Communauté), allow-comments switch, allow-sharing switch, collapsible preview card.

**Bible Search Modal:** Book dropdown → chapter picker → verse picker. Cascading selection. Selected verse previews in Playfair Italic below.

**Publish Audio (Step 1):** Two tabs — Record (mic permission gate → live waveform visualizer → record/pause/stop/re-record, max 15:00) and Upload (file picker, preview player).

**Publish Video (Step 1):** Two tabs — Record (camera permission gate → front/back toggle → record, max 10:00) and Upload (gallery picker, thumbnail preview).

**Publish Video (Step 2):** Thumbnail selector (auto-extracted frame or gallery), same metadata fields as audio.

**Confirmation Screen:** Full-screen checkmark animation (scale elastic, green), "En cours de révision" heading, supporting text, two CTA buttons.

---

### 4.5 Notifications Screen

**File structure:**
```
lib/features/notifications/
├── screens/
│   └── notifications_screen.dart
└── providers/
    └── notifications_provider.dart
```

**Screen composition:**
- `SliverAppBar` with "Notifications" title + "Tout marquer lu" action + filter icon
- Filter chips row (Tous | Réactions | Commentaires | Abonnements | Système)
- Grouped `SliverList` by date: "Aujourd'hui", "Cette semaine", "Plus tôt"
- Each notification row: leading emoji icon + text description + trailing timestamp + unread dot
- Tapping any row marks it read + navigates per the notification type map (Section 1.9)
- Empty state: `EmptyState(context: no-notifications)`
- Pull-to-refresh: `RefreshIndicator` with `notifications_provider.refresh()`

---

### 4.6 Profile & Settings Screens

**File structure:**
```
lib/features/profile/
├── screens/
│   ├── profile_screen.dart
│   ├── edit_profile_screen.dart
│   ├── public_profile_screen.dart
│   ├── settings_screen.dart
│   └── rejection_detail_screen.dart
└── widgets/
    ├── profile_header.dart
    └── profile_tab_bar.dart
```

**Profile Screen:**
- `NestedScrollView` with `SliverAppBar` (expandedHeight 220) showing cover photo
- Avatar pinned at bottom-left of expanded header with edit overlay
- Stats row: X Témoignages | X Abonnés | X Abonnements (tappable each)
- `_ProfileTabBar` (underline style): Mes témoignages | Sauvegardés | Aimés
- "Mes témoignages" tab: filter bar (Tous | En révision | Publiés | Rejetés), grid/list toggle, swipe-left dismiss for delete/edit
- Status badges: `semantic-warning` for "En révision", `semantic-success` for "Publié", `semantic-error` for "Rejeté"
- Settings gear icon in app bar top-right

**Edit Profile Screen:**
- Avatar picker (camera or gallery) with `ImageCropper`
- Cover photo picker
- All fields from registration + Bio (160 char counter)
- `Sauvegarder` button — optimistic update, success toast on confirmation

**Public Profile Screen:**
- Same structure as own profile but without edit controls
- "Abonner / Se désabonner" toggle button replacing edit button
- Only shows "Publié" testimonies tab

**Settings Screen:**
- Grouped `ListView` with `_SettingsSection` containers
- Compte: email change, password change, account deletion (danger zone with confirm dialog)
- Notifications: `Switch` tiles per notification type
- Confidentialité: profile visibility radio
- Langue: `_LanguageSelector` bottom sheet
- Thème: `_ThemeSelector` (Clair / Sombre / Système)
- À propos: version number, legal links (CGU, privacy policy) opening `WebViewScreen`
- Se déconnecter: `semantic-error` colored `ListTile`, confirmation dialog before action

**Rejection Detail Screen:**
- Full testimony preview (read-only)
- Rejection reason banner (`semantic-error-subtle` background)
- Moderator note (quoted block, `border-default` left border)
- "Modifier ce témoignage" primary button → opens `PublishTextScreen` pre-filled with original content

---

### 4.7 Moderation & Admin Screens

**File structure:**
```
lib/features/moderation/
├── models/moderation_models.dart
├── providers/moderation_provider.dart
├── screens/
│   ├── moderation_screen.dart
│   └── moderation_detail_screen.dart
└── widgets/
    ├── moderation_stat_card.dart
    ├── testimony_type_badge.dart
    ├── moderation_item_card.dart
    └── review_bottom_sheet.dart

lib/features/admin/
├── models/admin_models.dart
├── providers/admin_provider.dart
├── screens/
│   ├── admin_dashboard_screen.dart
│   ├── admin_users_screen.dart
│   ├── admin_content_screen.dart
│   ├── admin_moderators_screen.dart
│   ├── admin_categories_screen.dart
│   ├── admin_stats_screen.dart
│   └── admin_settings_screen.dart
└── widgets/
    ├── admin_metric_card.dart
    ├── admin_user_row.dart
    └── admin_section_tile.dart
```

**Moderation Dashboard (`moderation_screen.dart`):**
- `NestedScrollView`: pinned `SliverAppBar` with pending badge counter
- Horizontal scroll stats row: 4 `ModerationStatCard` (En attente, Approuvés, Rejetés, Signalements)
- Animated filter tab bar (pill switcher style): En attente | Approuvés | Rejetés | Signalements
- `ListView.builder` of `ModerationItemCard` per filtered tab
- Empty state with check-circle illustration when queue is clear

**Moderation Item Card (`moderation_item_card.dart`):**
- 120px review card: author avatar with initials fallback, country flag, truncated title (2 lines)
- Category chip + `TestimonyTypeBadge` + submission time
- Three inline action buttons: ✅ Approuver (success) | ✏️ Modif. (gold) | ❌ Rejeter (error)
- "Prévisualiser" text link opens `ModerationDetailScreen`

**Moderation Detail Screen (`moderation_detail_screen.dart`):**
- `CustomScrollView`: pinned app bar with status chip
- Author header: full user info, previous submission stats
- Meta row: category chip + type badge + date
- Full content preview (text: Playfair italic verse + Inter body; audio: tinted placeholder player; video: thumbnail placeholder)
- Three full-width action buttons each opening `ReviewBottomSheet`

**Review Bottom Sheet (`review_bottom_sheet.dart`):**
- Rejection flow: `DropdownButtonFormField` with `initialValue`, all French rejection reasons, internal note field, Confirm enabled only when reason selected
- Modification request: checkbox list (5 reasons) + free text note (max 500), Confirm enabled when at least one reason selected

**Admin Dashboard (`admin_dashboard_screen.dart`):**
- `NestedScrollView`: pinned app bar with shield icon + shortcut to moderation
- 2×2 `_MetricsGrid` of `AdminMetricCard` (total users, testimonies, pending, reported)
- `_SectionNavList`: 6 `AdminSectionTile` cards navigating to sub-screens
- Inline sub-screen rendering via `AdminSection` enum switch

**Admin Users Screen:** Search bar with clear X, column header, `ListView` of `AdminUserRow` with `PopupMenuButton` (contextual: suspend/ban/promote/restore), confirmation `AlertDialog` for destructive actions.

**Admin Content Screen:** Published testimonies list with title, author, category chip, type badge, views/likes/date, "Dépublier" button + confirmation dialog.

**Admin Moderators Screen:** Two sections — active moderators (Remove button) and utilisateur candidates (Promote button). Both actions show confirmation dialogs.

**Admin Categories Screen:** `_AddCategoryBar` (enabled when input non-empty) + `ReorderableListView` with drag handle, order number, name, count badge, edit icon, and `Switch`.

**Admin Stats Screen:** Three `_ChartCard` containers using `CustomPainter`:
- 7-day bar chart (submitted vs approved)
- 6-month line chart with gradient fill (new users)
- Donut pie chart (top 5 categories by volume) + legend
- Progress-bar table for top categories

**Admin Settings Screen:** `_MaintenanceBanner` (visible when active), three `_SettingsSection` groups (Accès / Modération / Notifications) with `_ToggleTile`, `_DangerZone` with contextual maintenance toggle button.

---

---

## 5. FLUTTER TECHNICAL ARCHITECTURE

### 5.1 Folder Structure

```
lib/
├── core/
│   ├── app_constants.dart          # All API endpoints, keys, constants
│   ├── providers/
│   │   └── core_providers.dart     # Dio, SharedPreferences, SecureStorage
│   ├── router/
│   │   ├── app_routes.dart         # Route names and paths
│   │   └── app_router.dart         # GoRouter config + guards
│   └── theme/
│       ├── app_colors.dart         # All color tokens (light + dark)
│       ├── app_text_styles.dart    # Typography scale
│       ├── app_theme.dart          # ThemeData construction
│       └── app_spacing.dart        # Spacing constants
│
├── features/
│   ├── auth/
│   │   ├── providers/
│   │   │   └── auth_notifier.dart  # AuthState sealed + AuthNotifier
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   ├── forgot_password_screen.dart
│   │   │   └── verify_email_screen.dart
│   │   └── widgets/
│   │       └── auth_widgets.dart
│   ├── home/
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   └── explorer_screen.dart
│   │   └── widgets/
│   │       ├── verse_of_day_card.dart
│   │       └── home_header.dart
│   ├── testimony/
│   │   ├── screens/
│   │   │   ├── testimony_detail_screen.dart
│   │   │   ├── audio_player_screen.dart
│   │   │   └── video_player_screen.dart
│   │   ├── providers/
│   │   │   └── testimony_provider.dart
│   │   └── widgets/
│   ├── publish/
│   │   ├── screens/
│   │   │   ├── publish_chooser_screen.dart
│   │   │   ├── publish_text_screen.dart
│   │   │   ├── publish_audio_screen.dart
│   │   │   ├── publish_video_screen.dart
│   │   │   └── publish_confirm_screen.dart
│   │   ├── providers/
│   │   │   └── publish_provider.dart
│   │   └── widgets/
│   │       ├── bible_search_modal.dart
│   │       └── audio_recorder_widget.dart
│   ├── notifications/
│   │   ├── screens/
│   │   │   └── notifications_screen.dart
│   │   └── providers/
│   │       └── notifications_provider.dart
│   ├── profile/
│   │   ├── screens/
│   │   │   ├── profile_screen.dart
│   │   │   ├── edit_profile_screen.dart
│   │   │   ├── public_profile_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   └── rejection_detail_screen.dart
│   │   └── providers/
│   │       └── profile_provider.dart
│   ├── moderation/
│   │   ├── models/
│   │   │   └── moderation_models.dart
│   │   ├── providers/
│   │   │   └── moderation_provider.dart
│   │   ├── screens/
│   │   │   ├── moderation_screen.dart
│   │   │   └── moderation_detail_screen.dart
│   │   └── widgets/
│   │       ├── moderation_stat_card.dart
│   │       ├── testimony_type_badge.dart
│   │       ├── moderation_item_card.dart
│   │       └── review_bottom_sheet.dart
│   └── admin/
│       ├── models/
│       │   └── admin_models.dart
│       ├── providers/
│       │   └── admin_provider.dart
│       ├── screens/
│       │   ├── admin_dashboard_screen.dart
│       │   ├── admin_users_screen.dart
│       │   ├── admin_content_screen.dart
│       │   ├── admin_moderators_screen.dart
│       │   ├── admin_categories_screen.dart
│       │   ├── admin_stats_screen.dart
│       │   └── admin_settings_screen.dart
│       └── widgets/
│           ├── admin_metric_card.dart
│           ├── admin_user_row.dart
│           └── admin_section_tile.dart
│
├── services/
│   ├── api_service.dart            # Dio singleton + interceptors
│   └── audio_player_service.dart   # just_audio wrapper + state
│
├── shared/
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── testimony_model.dart
│   │   ├── comment_model.dart
│   │   ├── notification_model.dart
│   │   ├── category_model.dart
│   │   ├── reaction_model.dart
│   │   ├── publish_draft_model.dart
│   │   └── models.dart             # Barrel export
│   └── widgets/
│       ├── testimony_card.dart
│       ├── category_chip_list.dart
│       ├── reaction_bar.dart
│       ├── mini_audio_player.dart
│       ├── app_button.dart
│       ├── skeleton_loader.dart
│       ├── empty_state.dart
│       └── app_text_field.dart
│
└── main.dart

assets/
├── images/               # Onboarding illustrations, placeholders
├── icons/                # SVG brand icons (cross, logo)
├── animations/           # Lottie JSON files
└── fonts/
    ├── Poppins-*.ttf     # All required weights
    ├── Inter-*.ttf       # All required weights
    └── PlayfairDisplay-*.ttf
```

---

### 5.2 Dependencies (pubspec.yaml)

```yaml
name: testi_app
description: Témoignages — plateforme de partage de témoignages chrétiens
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.7

  # Data models
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Networking
  dio: ^5.4.3
  dio_smart_retry: ^6.0.0

  # Storage
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.2.2
  shared_preferences: ^2.3.2

  # Media
  just_audio: ^0.9.40
  audio_session: ^0.1.21
  cached_network_image: ^3.3.1
  image_picker: ^1.1.2
  image_cropper: ^7.1.0
  file_picker: ^8.1.2

  # UI utilities
  flutter_svg: ^2.0.10+1
  intl: ^0.19.0
  lottie: ^3.1.0
  url_launcher: ^6.3.0

  # Rich text editor (testimony composition)
  flutter_quill: ^10.6.3

  # Firebase (push notifications, auth)
  firebase_core: ^3.3.0
  firebase_messaging: ^15.1.0
  firebase_auth: ^5.1.2

  # Google Sign-In
  google_sign_in: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.12
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.3
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
    - assets/animations/
  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fonts/Poppins-Regular.ttf
        - asset: assets/fonts/Poppins-Medium.ttf
          weight: 500
        - asset: assets/fonts/Poppins-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Poppins-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
    - family: PlayfairDisplay
      fonts:
        - asset: assets/fonts/PlayfairDisplay-Regular.ttf
        - asset: assets/fonts/PlayfairDisplay-Italic.ttf
          style: italic
        - asset: assets/fonts/PlayfairDisplay-BoldItalic.ttf
          weight: 700
          style: italic
```

---

### 5.3 Theming

```dart
// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.spiritualPurple,
      brightness: Brightness.light,
      primary: AppColors.spiritualPurple,
      secondary: AppColors.spiritualGold,
      surface: AppColors.surfacePrimary,
      error: AppColors.semanticError,
    ),
    scaffoldBackgroundColor: AppColors.backgroundPrimary,
    fontFamily: 'Inter',
    textTheme: _buildTextTheme(Brightness.light),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfacePrimary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: AppTextStyles.heading3.copyWith(
        color: AppColors.textPrimary,
      ),
    ),
    cardTheme: CardTheme(
      color: AppColors.surfacePrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfacePrimary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: AppColors.interactivePrimary, width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.semanticError),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfacePrimary,
      selectedItemColor: AppColors.interactivePrimary,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    extensions: const [TemoignagesThemeExtension.light()],
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.spiritualPurpleDark,
      brightness: Brightness.dark,
      primary: AppColors.spiritualPurpleDark,
      secondary: AppColors.spiritualGoldDark,
      surface: AppColors.surfacePrimaryDark,
      error: AppColors.semanticErrorDark,
    ),
    scaffoldBackgroundColor: AppColors.backgroundPrimaryDark,
    fontFamily: 'Inter',
    textTheme: _buildTextTheme(Brightness.dark),
    // ... mirror of light with dark tokens
    extensions: const [TemoignagesThemeExtension.dark()],
  );

  static TextTheme _buildTextTheme(Brightness brightness) {
    final isPrimary = brightness == Brightness.light;
    final primaryColor = isPrimary
        ? AppColors.textPrimary : AppColors.textPrimaryDark;
    return TextTheme(
      displayLarge: AppTextStyles.displayXl.copyWith(color: primaryColor),
      headlineLarge: AppTextStyles.heading1.copyWith(color: primaryColor),
      headlineMedium: AppTextStyles.heading2.copyWith(color: primaryColor),
      headlineSmall: AppTextStyles.heading3.copyWith(color: primaryColor),
      bodyLarge: AppTextStyles.bodyLg.copyWith(color: primaryColor),
      bodyMedium: AppTextStyles.bodyMd.copyWith(color: primaryColor),
      bodySmall: AppTextStyles.bodySm.copyWith(color: primaryColor),
      labelLarge: AppTextStyles.labelLg,
      labelMedium: AppTextStyles.labelMd,
      labelSmall: AppTextStyles.labelSm,
    );
  }
}
```

---

### 5.4 State Management

Témoignages uses **Riverpod 2** exclusively. No `ChangeNotifier`, no `BLoC`, no `Provider` package. The following patterns are applied consistently:

**Provider taxonomy:**

| Provider Type | When to Use | Example |
|---|---|---|
| `Provider` | Synchronous, computed, no mutation | `routerProvider`, `formattedDateProvider` |
| `StateProvider` | Simple local UI state (toggle, filter, selected tab) | `selectedCategoryProvider`, `notificationFilterProvider` |
| `FutureProvider` | Single async fetch, auto-cached | `testimonyByIdProvider` |
| `StreamProvider` | Real-time data (WebSocket, Firestore listener) | `notificationsStreamProvider` |
| `AsyncNotifierProvider` | Complex async state with mutations | `authStateProvider`, `publishDraftProvider` |
| `NotifierProvider` | Sync state with complex mutations | `audioPlayerProvider`, `categoriesProvider` |

**Key providers:**

```dart
// Auth
final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.maybeWhen(
    authenticated: (user) => user,
    orElse: () => null,
  );
});
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
final canPublishProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.canPublish ?? false;
});
final canModerateProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider)?.canModerate ?? false;
});

// Testimony feed
final testimonyFeedProvider = StateNotifierProvider
    .family<TestimonyFeedNotifier, AsyncValue<List<TestimonyModel>>, String>(
  (ref, category) => TestimonyFeedNotifier(ref, category),
);

// Audio player
final audioPlayerProvider = NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);

// Publish draft (persisted to Hive)
final publishDraftProvider = AsyncNotifierProvider<PublishDraftNotifier, PublishDraftModel>(
  PublishDraftNotifier.new,
);

// Moderation
final moderationStatsProvider = FutureProvider<ModerationStats>(...);
final moderationItemsProvider = StateNotifierProvider
    .family<ModerationNotifier, AsyncValue<List<ModerationItem>>, ModerationStatus>(...);
```

**Optimistic updates pattern (reactions):**

```dart
// In ReactionNotifier
Future<void> toggleReaction(String testimonyId, ReactionType type) async {
  // 1. Read current state
  final current = state;
  // 2. Optimistically update local state
  state = current.copyWith(
    userReactions: {...current.userReactions, type: !current.userReactions[type]!},
    counts: _updatedCounts(current.counts, type, toggling: true),
  );
  // 3. Fire API call
  try {
    await ref.read(apiServiceProvider).post('/reactions', body: {...});
  } catch (e) {
    // 4. Revert on failure + show toast
    state = current;
    ref.read(toastProvider.notifier).show(ToastSemantic.error, 'Une erreur est survenue');
  }
}
```

---

### 5.5 Networking & Error Handling

**API Service (`lib/services/api_service.dart`):**

- `ApiService` constructed as a `Provider` singleton
- Three interceptors on the `Dio` instance:

| Interceptor | Role |
|---|---|
| `AuthInterceptor` | Attaches `Bearer` JWT from `FlutterSecureStorage`; on 401: silent token refresh → retry original request |
| `RetryInterceptor` | Exponential back-off on 5xx / network errors: 500ms → 1s → 2s, max 3 retries |
| `LoggingInterceptor` | Compact `[API] --> / <-- / ERR` log lines (debug builds only) |

**Methods:**

```dart
Future<Response> get(String path, {Map<String, dynamic>? params});
Future<Response> post(String path, {dynamic body});
Future<Response> put(String path, {dynamic body});
Future<Response> delete(String path);
Future<Response> uploadFile(
  String path,
  File file, {
  String fieldName = 'file',
  void Function(int sent, int total)? onProgress,
});
```

**Error model:**

```dart
sealed class ApiError {
  const ApiError();
}

class NetworkError extends ApiError { /* no connectivity */ }
class ServerError extends ApiError {
  final int statusCode;
  final String? message;
}
class UnauthorizedError extends ApiError { /* 401 after refresh failed */ }
class NotFoundError extends ApiError { /* 404 */ }
class ValidationError extends ApiError {
  final Map<String, List<String>> fieldErrors;
}
class UnknownError extends ApiError {
  final dynamic cause;
}
```

All notifiers wrap API calls in `try/catch` and expose `ApiError` subtypes to the UI. UI components consume errors from providers and render appropriate `ErrorState` widgets or inline field errors.

---

### 5.6 Offline & Caching

**Hive boxes:**

| Box Name | Content | TTL |
|---|---|---|
| `settings` | App settings, theme, language preference | Permanent |
| `onboarding` | `hasSeenOnboarding: bool` | Permanent |
| `publishDrafts` | `PublishDraftModel` list | Until submitted |
| `testimonyCache` | `TestimonyModel` list (home feed) | 15 minutes |
| `userCache` | `UserModel` (own profile) | 30 minutes |
| `notificationsCache` | `NotificationModel` list | 5 minutes |

**Caching strategy:**

1. **Stale-while-revalidate:** UI renders from cache immediately, then refreshes in background. Providers check TTL before deciding whether to use cache or re-fetch.
2. **Optimistic writes:** Reactions, comments, bookmarks update cache immediately; API confirms asynchronously.
3. **Audio offline download:** Downloaded files stored to `getApplicationDocumentsDirectory()` with path persisted in Hive. `just_audio` loads from local path when available.
4. **Image caching:** `cached_network_image` with default 7-day disk cache via its built-in `DefaultCacheManager`.

**Connectivity handling:**

```dart
// Providers check connectivity before API calls
final connectivityProvider = StreamProvider<ConnectivityResult>(
  (ref) => Connectivity().onConnectivityChanged,
);

// Usage in notifier:
final connectivity = await ref.read(connectivityProvider.future);
if (connectivity == ConnectivityResult.none) {
  // Serve from cache; queue mutation for later sync
  return _loadFromCache();
}
```

---

---

## 6. REUSABLE WIDGET LIBRARY

### Widget Catalogue Overview

All widgets reside in `lib/shared/widgets/`. They are designed to work independently of any specific provider — pass data in via props. Where self-managed variants exist (e.g., `CategoryChipListSelfManaged`), they are provided as convenience wrappers over the pure presentation widget.

| # | File | Key Features |
|---|---|---|
| 1 | `testimony_card.dart` | 3 variants (text/audio/video), `TestimonyModel`, all sub-widgets inline |
| 2 | `category_chip_list.dart` | Scrollable gradient chips, active/inactive animation, self-managed variant |
| 3 | `reaction_bar.dart` | 4 actions, scale + slide-count animations, haptic feedback, self-managed variant |
| 4 | `mini_audio_player.dart` | Riverpod `NotifierProvider`, seek bar, play/pause/skip, animated slide-in/out |
| 5 | `app_button.dart` | 4 variants × 3 sizes, gradient primary, loading spinner, disabled states |
| 6 | `skeleton_loader.dart` | Shader-mask shimmer, `card` / `listItem` / `profile` variants |
| 7 | `empty_state.dart` | 5 presets, Lottie slot, icon fallback, optional CTA via `AppButton` |
| 8 | `app_text_field.dart` | Label/hint/error/helper, leading/trailing icons, password toggle, live char counter |

---

### 6.1 TestimonyCard

```dart
// lib/shared/widgets/testimony_card.dart

enum TestimonyCardVariant { standard, featured, compact }

class TestimonyCard extends StatelessWidget {
  const TestimonyCard({
    super.key,
    required this.testimony,
    required this.onTap,
    this.onBookmark,
    this.onShare,
    this.showReactions = true,
    this.variant = TestimonyCardVariant.standard,
  });

  final TestimonyModel testimony;
  final VoidCallback onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final bool showReactions;
  final TestimonyCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12), // radius-md
          boxShadow: _buildShadow(context),
          border: testimony.isFeatured
              ? Border(
                  top: BorderSide(
                    color: AppColors.spiritualGold,
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(testimony: testimony, onShare: onShare),
            _CardBody(testimony: testimony, variant: variant),
            if (showReactions) _CardFooter(testimony: testimony),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  // Avatar (32px) + username (label-md) + timestamp (caption) + overflow menu (⋮)
}

class _CardBody extends StatelessWidget {
  // Text: 3-line excerpt + "Lire la suite" link
  // Audio: mini waveform + play/pause + duration
  // Video: 16:9 thumbnail + play overlay + duration badge
}

class _CardFooter extends StatelessWidget {
  // CategoryChip + ReactionBar compact
}
```

---

### 6.2 CategoryChipList

```dart
// lib/shared/widgets/category_chip_list.dart

class CategoryChipList extends StatelessWidget {
  const CategoryChipList({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final List<TestimonyCategory> categories;
  final TestimonyCategory? selectedCategory;
  final ValueChanged<TestimonyCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length + 1, // +1 for "Tous"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChipItem(
              label: 'Tous',
              isSelected: selectedCategory == null,
              onTap: () => onCategoryChanged(null),
            );
          }
          final category = categories[index - 1];
          return _CategoryChipItem(
            label: category.frenchLabel,
            icon: category.icon,
            isSelected: selectedCategory == category,
            onTap: () => onCategoryChanged(category),
          );
        },
      ),
    );
  }
}

// Self-managed convenience wrapper
class CategoryChipListSelfManaged extends ConsumerWidget {
  const CategoryChipListSelfManaged({super.key, this.onChanged});
  final ValueChanged<TestimonyCategory?>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    return CategoryChipList(
      categories: TestimonyCategory.values,
      selectedCategory: selected,
      onCategoryChanged: (cat) {
        ref.read(selectedCategoryProvider.notifier).state = cat;
        onChanged?.call(cat);
      },
    );
  }
}
```

---

### 6.3 ReactionBar

```dart
// lib/shared/widgets/reaction_bar.dart

class ReactionBar extends StatefulWidget {
  const ReactionBar({
    super.key,
    required this.heartCount,
    required this.prayCount,
    required this.commentCount,
    required this.shareCount,
    required this.hasUserReacted,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });

  final int heartCount;
  final int prayCount;
  final int commentCount;
  final int shareCount;
  final Map<ReactionType, bool> hasUserReacted;
  final ValueChanged<ReactionType> onReact;
  final VoidCallback onComment;
  final VoidCallback onShare;
  // ...
}

class _ReactionButton extends StatefulWidget {
  // Handles scale animation (1.0 → 1.4 → 1.0 on tap)
  // Color transition via AnimatedContainer
  // Haptic feedback via HapticFeedback.lightImpact()
  // Count label vertical slide-up on change
}
```

---

### 6.4 MiniAudioPlayer

```dart
// lib/shared/widgets/mini_audio_player.dart

class MiniAudioPlayer extends ConsumerWidget {
  // Reads audioPlayerProvider
  // Animated slide-in from bottom when audio is playing
  // Animated slide-out when stopped
  // Docks above bottom navigation bar using BottomNavigationBarTheme height
}

@riverpod
class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late final AudioPlayer _player;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();
    ref.onDispose(_player.dispose);
    // Set up stream listeners for position, duration, playing state
    return AudioPlayerState.initial();
  }

  Future<void> play(String url) async { /* ... */ }
  Future<void> pause() async { /* ... */ }
  Future<void> resume() async { /* ... */ }
  Future<void> seek(Duration position) async { /* ... */ }
  Future<void> setSpeed(double speed) async { /* ... */ }
  void stop() { /* ... */ }
  void skipForward({int seconds = 15}) { /* ... */ }
  void skipBackward({int seconds = 15}) { /* ... */ }
}
```

---

### 6.5 AppButton

```dart
// lib/shared/widgets/app_button.dart

enum AppButtonVariant { primary, secondary, ghost, danger }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final height = switch (size) {
      AppButtonSize.small  => 32.0,
      AppButtonSize.medium => 44.0,
      AppButtonSize.large  => 52.0,
    };
    // Primary: LinearGradient (spiritual-gradient-start → end)
    // Loading: replaces label with 16px CircularProgressIndicator
    // Disabled: 40% opacity, onPressed == null
    // ...
  }
}
```

---

### 6.6 SkeletonLoader

```dart
// lib/shared/widgets/skeleton_loader.dart

enum SkeletonType { card, listItem, profile }

class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.type = SkeletonType.card,
    this.count = 1,
  });

  final SkeletonType type;
  final int count;
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Renders ShaderMask with LinearGradient shimmer over placeholder shapes
  // Text lines: radius-full, ~12px tall
  // Image areas: radius-md
  // Matches exact geometry of corresponding real component
}
```

---

### 6.7 EmptyState

```dart
// lib/shared/widgets/empty_state.dart

enum EmptyStateContext {
  noTestimonies,
  noResults,
  noNotifications,
  noBookmarks,
  noComments,
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.context,
    this.customTitle,
    this.customBody,
    this.cta,
    this.lottieAsset, // optional: drop in Lottie animation
  });

  final EmptyStateContext context;
  final String? customTitle;
  final String? customBody;
  final AppButton? cta;
  final String? lottieAsset;

  // Presets per context:
  // noTestimonies: "Aucun témoignage pour l'instant"
  // noResults: "Aucun résultat trouvé"
  // noNotifications: "Pas encore de notifications"
  // noBookmarks: "Aucun témoignage sauvegardé"
  // noComments: "Soyez le premier à commenter"
}
```

---

### 6.8 AppTextField

```dart
// lib/shared/widgets/app_text_field.dart

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.placeholder,
    this.controller,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.nextFocusNode,
    this.enabled = true,
    this.showCharacterCount = false,
  });
  // ...
}

class _AppTextFieldState extends State<AppTextField> {
  bool _isObscured = true;
  // Floating label via InputDecoration labelText
  // Password toggle via suffix IconButton
  // Character count updates in real-time via _controller.addListener
  // Count turns semantic-error when > 90% of maxLength
  // Focus ring uses spiritual-purple-glow via InputDecoration.focusedBorder + BoxDecoration
}
```

---

---

## 7. DATA MODELS & SERVICES

### 7.1 User Model

```dart
// lib/shared/models/user_model.dart

enum UserRole {
  visiteur,
  utilisateur,
  moderateur,
  administrateur,
}

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? avatarUrl,
    String? coverUrl,
    String? church,
    String? city,
    String? country,
    String? bio,
    @Default(false) bool isEmailVerified,
    @Default(false) bool isProfilePublic,
    DateTime? createdAt,
    UserStats? stats,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int testimoniesCount,
    @Default(0) int followersCount,
    @Default(0) int followingCount,
  }) = _$UserStats;
  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
}

extension UserModelX on UserModel {
  String get fullName => '$firstName $lastName';
  bool get canPublish =>
      role == UserRole.utilisateur ||
      role == UserRole.moderateur ||
      role == UserRole.administrateur;
  bool get canModerate =>
      role == UserRole.moderateur ||
      role == UserRole.administrateur;
  bool get isAdmin => role == UserRole.administrateur;
}
```

---

### 7.2 Testimony Model

```dart
// lib/shared/models/testimony_model.dart

enum TestimonyType { text, audio, video }
enum TestimonyStatus { draft, pending, published, rejected, editRequested }
enum TestimonyVisibility { public, community }
enum TestimonyCategory {
  healing, deliverance, conversion, marriage, family,
  finances, miracles, protection, ministry, salvation,
}

@freezed
class TestimonyModel with _$TestimonyModel {
  const factory TestimonyModel({
    required String id,
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
    String? authorChurch,
    String? authorCountry,
    required String title,
    required TestimonyCategory category,
    required TestimonyType type,
    required TestimonyStatus status,
    required TestimonyVisibility visibility,
    String? textContent,
    String? audioUrl,
    String? videoUrl,
    String? thumbnailUrl,
    String? bibleVerse,
    String? bibleReference,
    Duration? mediaDuration,
    String? transcript,
    @Default([]) List<String> tags,
    @Default(false) bool allowComments,
    @Default(true) bool allowSharing,
    @Default(false) bool isFeatured,
    DateTime? publishedAt,
    DateTime? createdAt,
    TestimonyStats? stats,
    String? rejectionReason,
    String? moderatorNote,
  }) = _TestimonyModel;

  factory TestimonyModel.fromJson(Map<String, dynamic> json) =>
      _$TestimonyModelFromJson(json);
}

@freezed
class TestimonyStats with _$TestimonyStats {
  const factory TestimonyStats({
    @Default(0) int amenCount,
    @Default(0) int prayerCount,
    @Default(0) int touchedCount,
    @Default(0) int commentCount,
    @Default(0) int shareCount,
    @Default(0) int viewCount,
  }) = _TestimonyStats;
  factory TestimonyStats.fromJson(Map<String, dynamic> json) =>
      _$TestimonyStatsFromJson(json);
}

extension TestimonyModelX on TestimonyModel {
  String get formattedDuration {
    if (mediaDuration == null) return '';
    final m = mediaDuration!.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = mediaDuration!.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  bool get hasMedia => audioUrl != null || videoUrl != null;
  bool get isPending => status == TestimonyStatus.pending;
  bool get isPublished => status == TestimonyStatus.published;
}
```

---

### 7.3 Comment Model

```dart
@freezed
class CommentModel with _$CommentModel {
  const factory CommentModel({
    required String id,
    required String testimonyId,
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
    required String content,
    String? parentCommentId,
    @Default(0) int likeCount,
    @Default(false) bool isLikedByMe,
    @Default([]) List<CommentModel> replies,
    DateTime? createdAt,
  }) = _CommentModel;

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);
}

extension CommentModelX on CommentModel {
  bool get isReply => parentCommentId != null;
}
```

---

### 7.4 Notification Model

```dart
enum NotificationType {
  reaction, comment, prayer, newFollower,
  testimonApproved, testimonRejected, editRequested, system,
}

@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required NotificationType type,
    required String title,
    required String body,
    String? actorName,
    String? actorAvatarUrl,
    String? targetId,       // testimonyId or userId
    String? targetType,     // 'testimony' | 'user'
    @Default(false) bool isRead,
    DateTime? createdAt,```dart
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);
}
```

---

### 7.5 Publish Draft Model

```dart
@freezed
class PublishDraftModel with _$PublishDraftModel {
  const factory PublishDraftModel({
    required String id,
    required TestimonyType type,
    @Default('') String title,
    TestimonyCategory? category,
    @Default('') String textContent,
    String? audioPath,
    String? videoPath,
    String? thumbnailPath,
    String? bibleVerse,
    String? bibleReference,
    @Default([]) List<String> tags,
    @Default(TestimonyVisibility.public) TestimonyVisibility visibility,
    @Default(true) bool allowComments,
    @Default(true) bool allowSharing,
    DateTime? lastSavedAt,
  }) = _PublishDraftModel;

  factory PublishDraftModel.fromJson(Map<String, dynamic> json) =>
      _$PublishDraftModelFromJson(json);
}

extension PublishDraftModelX on PublishDraftModel {
  bool get isReadyToSubmit {
    if (title.trim().length < 5) return false;
    if (category == null) return false;
    if (type == TestimonyType.text && textContent.trim().length < 100) return false;
    if (type == TestimonyType.audio && audioPath == null) return false;
    if (type == TestimonyType.video && videoPath == null) return false;
    return true;
  }
}
```

---

### 7.6 AuthNotifier

```dart
// lib/features/auth/providers/auth_notifier.dart

sealed class AuthState {
  const AuthState();
}
class AuthStateLoading extends AuthState { const AuthStateLoading(); }
class AuthStateAuthenticated extends AuthState {
  const AuthStateAuthenticated(this.user);
  final UserModel user;
}
class AuthStateUnauthenticated extends AuthState { const AuthStateUnauthenticated(); }

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    // Attempt silent token refresh on startup
    final token = await ref.read(secureStorageProvider).read(
      key: AppConstants.accessTokenKey,
    );
    if (token == null) return const AuthStateUnauthenticated();
    try {
      final user = await ref.read(apiServiceProvider).get('/auth/me');
      return AuthStateAuthenticated(UserModel.fromJson(user.data));
    } catch (_) {
      return const AuthStateUnauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(apiServiceProvider).post('/auth/login', body: {
        'email': email,
        'password': password,
      });
      await _persistTokens(res.data);
      final user = UserModel.fromJson(res.data['user']);
      return AuthStateAuthenticated(user);
    });
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String country,
    String? church,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(apiServiceProvider).post('/auth/register', body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        'country': country,
        if (church != null) 'church': church,
      });
      return const AuthStateUnauthenticated(); // must verify email first
    });
  }

  Future<void> logout() async {
    await ref.read(secureStorageProvider).deleteAll();
    state = const AsyncValue.data(AuthStateUnauthenticated());
  }

  Future<void> forgotPassword(String email) async {
    await ref.read(apiServiceProvider).post('/auth/forgot-password',
      body: {'email': email});
  }

  Future<void> verifyEmail(String token) async {
    await ref.read(apiServiceProvider).post('/auth/verify-email',
      body: {'token': token});
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(
      key: AppConstants.accessTokenKey, value: data['accessToken']);
    await storage.write(
      key: AppConstants.refreshTokenKey, value: data['refreshToken']);
  }
}
```

---

### 7.7 AudioPlayerService

```dart
// lib/services/audio_player_service.dart

class AudioPlayerState {
  const AudioPlayerState({
    this.url,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.speed = 1.0,
    this.error,
  });

  final String? url;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final double speed;
  final String? error;

  static AudioPlayerState initial() => const AudioPlayerState();

  double get progress => duration.inMilliseconds == 0
      ? 0.0
      : position.inMilliseconds / duration.inMilliseconds;

  Duration get remaining => duration - position;

  AudioPlayerState copyWith({/* ... */}) => AudioPlayerState(/* ... */);
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late final AudioPlayer _player;

  @override
  AudioPlayerState build() {
    _player = AudioPlayer();
    ref.onDispose(_player.dispose);

    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });
    _player.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    _player.playerStateStream.listen((ps) {
      state = state.copyWith(
        isLoading: ps.processingState == ProcessingState.loading ||
                   ps.processingState == ProcessingState.buffering,
      );
    });

    return AudioPlayerState.initial();
  }

  Future<void> play(String url) async {
    if (state.url == url && !state.isPlaying) {
      await _player.play();
      return;
    }
    state = state.copyWith(url: url, isLoading: true);
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> seek(Duration position) => _player.seek(position);

  void seekToFraction(double fraction) {
    final target = Duration(
      milliseconds: (state.duration.inMilliseconds * fraction).round(),
    );
    _player.seek(target);
  }

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void skipForward({int seconds = 15}) {
    seek(state.position + Duration(seconds: seconds));
  }

  void skipBackward({int seconds = 15}) {
    seek(state.position - Duration(seconds: seconds));
  }

  void stop() {
    _player.stop();
    state = AudioPlayerState.initial();
  }
}

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);
final isAudioPlayingProvider =
    Provider<bool>((ref) => ref.watch(audioPlayerProvider).isPlaying);
final audioProgressProvider =
    Provider<double>((ref) => ref.watch(audioPlayerProvider).progress);
```

---

---

## 8. IMPLEMENTATION ROADMAP

### Sprint 1 — Setup + Auth (Weeks 1–2)

**Goal:** The app launches, onboarding runs, and a user can register, verify their email, and log in.

**Files to create:**

```
lib/main.dart
lib/core/app_constants.dart
lib/core/theme/app_colors.dart
lib/core/theme/app_text_styles.dart
lib/core/theme/app_theme.dart
lib/core/router/app_routes.dart
lib/core/router/app_router.dart
lib/services/api_service.dart
lib/shared/models/ (all 7 models + barrel)
lib/features/auth/providers/auth_notifier.dart
lib/features/auth/widgets/auth_widgets.dart
lib/features/auth/screens/splash_screen.dart
lib/features/auth/screens/onboarding_screen.dart
lib/features/auth/screens/login_screen.dart
lib/features/auth/screens/register_screen.dart
lib/features/auth/screens/forgot_password_screen.dart
lib/features/auth/screens/verify_email_screen.dart
pubspec.yaml (finalized)
assets/fonts/ (Poppins, Inter, Playfair Drop-in)
```

**Acceptance criteria:**

- [ ] Splash screen displays for 2.5s with animated logo; `authProvider` state resolved before navigation
- [ ] Onboarding shown only on first install (Hive flag); skip button works; final slide navigates to auth gate
- [ ] Registration creates account and sends verification email; confirmation screen shown
- [ ] Email verification OTP screen: 6-cell auto-advance, paste detection, 60s countdown, resend
- [ ] Login with valid credentials redirects to home shell stub; invalid shows inline error
- [ ] Forgot password sends reset email and shows masked address in success state
- [ ] Google Sign-In flow completes and lands on home
- [ ] All screens pass flutter analyze with 0 warnings
- [ ] Light and dark theme both render correctly on all auth screens

---

### Sprint 2 — Home + Feed + Testimony Detail (Weeks 3–4)

**Goal:** Authenticated users can browse the home feed, filter by category, and read full testimonies with comments.

**Files to create:**

```
lib/features/home/screens/home_screen.dart
lib/features/home/screens/explorer_screen.dart
lib/features/home/widgets/verse_of_day_card.dart
lib/features/home/widgets/home_header.dart
lib/features/testimony/screens/testimony_detail_screen.dart
lib/features/testimony/providers/testimony_provider.dart
lib/features/testimony/widgets/bible_verse_section.dart
lib/features/testimony/widgets/comment_section.dart
lib/shared/widgets/testimony_card.dart
lib/shared/widgets/category_chip_list.dart
lib/shared/widgets/reaction_bar.dart
lib/shared/widgets/skeleton_loader.dart
lib/shared/widgets/empty_state.dart
lib/shared/widgets/app_button.dart
lib/shared/widgets/app_text_field.dart
lib/core/providers/core_providers.dart
```

**Acceptance criteria:**

- [ ] Home feed loads with skeleton state then real cards from API
- [ ] Infinite scroll adds next page on scroll-to-bottom; no duplication
- [ ] Category chip filter sends filtered API request; feed replaces in place
- [ ] Verse of the day card renders Playfair italic text; share opens native sheet
- [ ] Testimony card renders all three types (text, audio, video) correctly
- [ ] Tapping card navigates to Testimony Detail; back returns to correct scroll position
- [ ] Bible verse renders with gold left border, Playfair italic font
- [ ] Reaction bar buttons animate (scale bounce); optimistic count update fires immediately
- [ ] Comments bottom sheet opens via `DraggableScrollableSheet`; comment submit posts to API
- [ ] Author avatar tap navigates to `PublicProfileScreen`
- [ ] Visitor mode: reactions/comments show auth-gate modal; share is allowed
- [ ] Explorer search debounces 400ms; empty state shown when no results
- [ ] SkeletonLoader matches exact geometry of real cards (no layout shift)

---

### Sprint 3 — Media Players + Publish Flow (Weeks 5–6)

**Goal:** Users can listen to audio testimonies, watch videos, and publish all three testimony types.

**Files to create:**

```
lib/features/testimony/screens/audio_player_screen.dart
lib/features/testimony/screens/video_player_screen.dart
lib/services/audio_player_service.dart
lib/shared/widgets/mini_audio_player.dart
lib/features/publish/screens/publish_chooser_screen.dart
lib/features/publish/screens/publish_text_screen.dart
lib/features/publish/screens/publish_audio_screen.dart
lib/features/publish/screens/publish_video_screen.dart
lib/features/publish/screens/publish_confirm_screen.dart
lib/features/publish/widgets/bible_search_modal.dart
lib/features/publish/widgets/audio_recorder_widget.dart
lib/features/publish/providers/publish_provider.dart
```

**Acceptance criteria:**

- [ ] Audio player screen opens from testimony detail; waveform animates during playback
- [ ] Speed selector (0.75x–2x) changes playback speed; selection persists on screen
- [ ] Skip ±15s buttons work; scrubber seek is accurate
- [ ] MiniAudioPlayer docks above bottom nav bar when audio is playing; close button stops and dismisses
- [ ] Video player renders 16:9 with custom overlay controls (auto-hide after 3s)
- [ ] Fullscreen mode locks to landscape and hides system UI; back returns to portrait
- [ ] Mini video player (`MiniVideoPlayer`) is draggable and tapping opens full screen
- [ ] Publish chooser shows all three type cards with correct icons
- [ ] Text publish: title char counter, category dropdown, Bible search modal cascades correctly, rich text editor autosaves, tags chip input handles max 5
- [ ] Audio publish: microphone permission gate shown; recorder shows live waveform; re-record clears previous
- [ ] Video publish: camera permission gate; front/back toggle works; max 10-minute enforced
- [ ] Upload progress bar shown for audio/video; cancellable
- [ ] Confirmation screen shows checkmark animation on successful submission
- [ ] Draft auto-saves to Hive every 30 seconds; restored on screen re-open

---

### Sprint 4 — Profile + Notifications + Social (Weeks 7–8)

**Goal:** Users have a full profile, receive real-time notifications, can follow others, bookmark testimonies, and manage account settings.

**Files to create:**

```
lib/features/profile/screens/profile_screen.dart
lib/features/profile/screens/edit_profile_screen.dart
lib/features/profile/screens/public_profile_screen.dart
lib/features/profile/screens/settings_screen.dart
lib/features/profile/screens/rejection_detail_screen.dart
lib/features/profile/providers/profile_provider.dart
lib/features/notifications/screens/notifications_screen.dart
lib/features/notifications/providers/notifications_provider.dart
```

**Acceptance criteria:**

- [ ] Profile screen: cover photo, avatar, stats row (with counts), three tabs with correct content
- [ ] "Mes témoignages" tab shows status badges; filter bar works; swipe-to-delete with confirmation
- [ ] Edit profile: image cropper launches for avatar and cover; 160-char bio counter
- [ ] Public profile: follow/unfollow toggle updates follower count optimistically; only "Publiés" shown
- [ ] Settings: theme switch persists and applies immediately via `ThemeMode` provider
- [ ] Settings: language switch (FR/EN) changes UI language via `Locale` provider
- [ ] Notifications screen: filter chips filter list in place; "Tout marquer lu" API call fires
- [ ] Each notification taps to correct deep-linked screen (testimony detail, public profile, rejection detail)
- [ ] Rejection detail shows reason + moderator note + "Modifier" button leading to pre-filled text editor
- [ ] Account deletion requires typed confirmation; calls API and clears all local data
- [ ] Push notifications (FCM) arrive in foreground and background; tapping navigates correctly
- [ ] Bookmarks add/remove optimistically; saved tab in profile reflects changes

---

### Sprint 5 — Moderation + Admin + Polish (Weeks 9–10)

**Goal:** Moderators can process the full review queue; admins have complete dashboard access; app is production-quality on both platforms.

**Files to create:**

```
lib/features/moderation/models/moderation_models.dart
lib/features/moderation/providers/moderation_provider.dart
lib/features/moderation/screens/moderation_screen.dart
lib/features/moderation/screens/moderation_detail_screen.dart
lib/features/moderation/widgets/ (all 4 widgets)
lib/features/admin/models/admin_models.dart
lib/features/admin/providers/admin_provider.dart
lib/features/admin/screens/ (all 7 screens)
lib/features/admin/widgets/ (all 3 widgets)
```

**Polish tasks (no new files, cross-cutting):**

- Motion: implement all 5 micro-animations from Section 2.8
- Accessibility: semantic labels, minimum touch targets, font scaling (Section 10)
- Error states: `ErrorState` widget for all network/server/404 scenarios
- Empty states: all 5 presets verified with correct copy
- Performance: `RepaintBoundary` around heavy painted widgets (waveform, video player)
- Testing: widget tests for `TestimonyCard`, `ReactionBar`, `AppButton`; integration test for auth flow
- CI: `flutter analyze` + `flutter test` gating pull requests
- App icons and splash: production assets for both platforms
- Android: `android:autoVerify` deep link setup + SHA certificate fingerprint
- iOS: Associated Domains entitlement + `apple-app-site-association` JSON on server

**Acceptance criteria:**

- [ ] Moderation dashboard loads with correct stats; badge shows pending count on nav tab
- [ ] Review screen: approve/reject/request-edit all update API and notify author
- [ ] Report review: all four actions work; ban action escalates (shows admin-only confirmation)
- [ ] Admin dashboard: all 6 sub-screens navigate and render data
- [ ] `ReorderableListView` category management saves new order to API
- [ ] `CustomPainter` charts in admin stats render without overflow on all screen sizes
- [ ] All 5 micro-animations implemented and triggered correctly
- [ ] Font scaling: UI does not break at 1.4× system text size
- [ ] All interactive elements have `Semantics` labels for screen readers
- [ ] `flutter analyze` returns zero issues; `flutter test` passes all tests
- [ ] Release build (APK + IPA) size under 50MB

---

---

## 9. UX RECOMMENDATIONS & BEST PRACTICES

### 1. Protect the First Post with a Warm Holding Screen

Publishing a testimony is an act of vulnerability. After the user submits, do not show a generic "pending" state. Show a full-screen holding screen with warm language: "Votre témoignage est entre de bonnes mains. Notre équipe le lira avec soin." Include a Bible verse in Playfair italic. This reduces abandonment and post-submission anxiety.

### 2. Use Progressive Disclosure for the Publish Form

The publish text flow's Step 1 is already long (title, category, verse, rich text, tags). Consider showing only the title and category first, then revealing the verse and tags fields after the user has typed at least 50 characters in the body. This prevents form abandonment by new users overwhelmed by a full form on first sight.

### 3. Implement a "Pray With Me" Notification Pattern

When a user taps the "Prier 🙏" reaction, optionally prompt: "Voulez-vous notifier [Auteur] que vous priez pour eux en ce moment?" If confirmed, send an immediate push: "🙏 [Prénom] prie pour vous maintenant." This creates a real-time intercession loop that is highly differentiated from secular social apps and deeply meaningful to users.

### 4. Audio Autoplay Must Opt-In, Not Default

Never autoplay audio testimonies when opening the detail screen. Audio testimonies may contain emotionally intense content (healing accounts, deliverance stories). Users may be in public, at work, or in a quiet moment of prayer. Always require an explicit tap to begin playback. Display the duration prominently before the play button so users can set aside time intentionally.

### 5. Make the Moderator Experience Fast, Not Frictionless

Do not remove friction from moderation actions. "Approve" should remain a one-tap action (the fastest). "Request edit" and "Reject" should each require at least one deliberate step (selecting a reason). This asymmetry ensures that approvals are quick while rejections are considered — matching how thoughtful moderation actually works.

### 6. Visitor Conversion at the Moment of Emotion

The current design gates interactions at the reaction tap. Go further: track how far a visitor scrolls through a testimony. If they scroll past 80% of the text (suggesting genuine engagement), show a subtle, non-blocking banner at the bottom: "Vous avez été touché? Rejoignez la communauté pour exprimer votre soutien." This converts based on demonstrated intent, not just presence.

### 7. Handle Offline Gracefully During Testimony Writing

The publish text editor auto-saves every 30 seconds. Add a connectivity-aware status indicator in the editor header: a small dot that is green when online ("Brouillon synchronisé") and amber when offline ("Hors ligne — brouillon local"). Users should feel safe writing a long testimony on a train without connectivity, knowing nothing will be lost.

### 8. Respect the Sacred Context of Notifications

Avoid notification fatigue. The default notification settings should be conservative: only approvals, rejections, and direct replies to own testimonies enabled by default. Reaction notifications (someone said "Amen") should default to OFF and users opt in. Batch reaction notifications ("12 personnes ont dit Amen à votre témoignage") after 6 hours rather than firing one per reaction.

### 9. Design the "Rejected" State as a Learning Moment, Not a Penalty

The rejection detail screen must feel like pastoral guidance, not a red card. Use warm, encouraging language: "Votre témoignage a besoin de quelques ajustements avant d'être partagé." Place the moderator's note in a visually gentle container (light border, not error red). The "Modifier et resoumettre" button should be the dominant CTA — never make the user feel the door is closed.

### 10. Test on Low-End Android Devices at Minimum Every Sprint

The French-speaking Christian community the app serves is predominantly in sub-Saharan Africa and the Caribbean. A significant portion of users will be on Android devices with 2–4GB RAM, slower processors, and intermittent 3G connectivity. Test every Sprint's deliverable on a real or emulated Tecno or Infinix device at minimum. Profile with `flutter run --profile` and target 60fps on these devices, not just flagship phones. Key areas to optimize: the waveform `CustomPainter`, the `ShaderMask` shimmer, and the video player overlay.

---

---

## 10. ACCESSIBILITY & INCLUSIVE DESIGN

### 10.1 Contrast Ratios

All color combinations in the design system must meet the following minimums:

| Combination | Required Ratio | Standard |
|---|---|---|
| Body text on background | 4.5:1 minimum | WCAG AA |
| Large text (18px+ or 14px+ bold) on background | 3:1 minimum | WCAG AA |
| UI components (borders, icons) on adjacent background | 3:1 minimum | WCAG AA |
| Placeholder text on input background | 3:1 minimum | WCAG AA |
| Text on `interactive-primary` (#6B21A8) | 4.5:1 (white passes at ~7.8:1) | WCAG AA |
| Text on `semantic-success` (#22C55E) | 4.5:1 (dark text required) | WCAG AA |
| Text on `spiritual-gold` (#F59E0B) | 4.5:1 (`text-on-gold` #1C0A00 passes) | WCAG AA |

**Verified critical pairs (light mode):**
- `text-primary` (#0F172A) on `background-primary` (#F8FAFC): ~18:1 ✓
- `text-secondary` (#64748B) on `surface-primary` (#FFFFFF): ~4.6:1 ✓
- `interactive-primary` (#6B21A8) on `background-primary` (#F8FAFC): ~7.8:1 ✓
- White on `interactive-primary` (#6B21A8): ~7.8:1 ✓

**Action required on implementation:** Run `flutter_accessibility_scanner` or equivalent tooling each sprint to catch any regressions. Pay special attention to skeleton loaders (ensure shimmer is never the only state — add a timeout empty state at 30s).

---

### 10.2 Touch Target Sizes

All interactive elements must meet the minimum touch target of **44×44 logical pixels** (iOS HIG and Material Design both specify this minimum).

```dart
// Enforce in shared components
const double kMinTouchTarget = 44.0;

// Pattern for small icons:
GestureDetector(
  onTap: onTap,
  child: SizedBox(
    width: kMinTouchTarget,
    height: kMinTouchTarget,
    child: Center(
      child: Icon(icon, size: 20), // Visual size smaller than touch target
    ),
  ),
)
```

**Areas requiring explicit touch target padding:**
- Reaction bar icons (20px visual → 44px target)
- Comment like/reply buttons
- Audio player skip buttons
- Close button on toast notifications
- Chip remove (×) button in tag input

---

### 10.3 Screen Reader (Semantics) Labels

Every interactive and meaningful widget must carry a `Semantics` label. No widget should rely solely on visual presentation for its meaning.

```dart
// Reaction button example
Semantics(
  label: 'Réagir avec Amen, actuellement ${amenCount} Amen',
  button: true,
  toggled: hasUserReacted[ReactionType.amen] ?? false,
  child: _ReactionButton(type: ReactionType.amen),
)

// Avatar example
Semantics(
  label: 'Photo de profil de $authorName',
  image: true,
  child: CircleAvatar(backgroundImage: CachedNetworkImageProvider(url)),
)

// Status badge example
Semantics(
  label: 'Statut: En cours de révision',
  child: _StatusBadge(status: TestimonyStatus.pending),
)

// Audio player play button
Semantics(
  label: isPlaying ? 'Mettre en pause' : 'Lire le témoignage audio',
  button: true,
  child: _PlayPauseButton(isPlaying: isPlaying),
)
```

**Required Semantics coverage by component:**

| Component | Required Label |
|---|---|
| `TestimonyCard` | Testimony title, author name, category, type (audio/video/text), reaction counts |
| `ReactionBar` each button | Action name + current count + toggled state |
| `Avatar` | Author name + "Photo de profil" |
| `CategoryChip` | Category name + selected/unselected state |
| `NavigationBar` each tab | Tab name + selected state + badge count when > 0 |
| `AudioPlayer` play/pause | "Lire" / "Mettre en pause" + testimony title |
| `AppButton` loading state | Original label + "chargement en cours" |
| `Switch` settings | Setting name + current state (activé/désactivé) |
| `ModerationItemCard` action buttons | "Approuver le témoignage de [Author]" / "Rejeter..." |

---

### 10.4 Font Scaling

The app must remain usable and visually intact at system text sizes up to **1.4× (Large)** without horizontal overflow, text truncation of essential information, or broken layouts.

**Implementation rules:**

```dart
// Never use fixed-height containers around text
// WRONG:
SizedBox(height: 48, child: Text(label))

// RIGHT: let text drive height
Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Text(label),
)

// For components that genuinely need fixed heights (nav bar, player controls):
// use textScaler.clamp() at the widget level
Builder(
  builder: (context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.of(context).textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.2,
        ),
      ),
      child: child,
    );
  },
)
```

**Components with hardcoded scale clamping (justified):**
- `NavigationBar` — max scale 1.1 (labels too long at higher scale; icon-only mode at 1.2+)
- `MiniAudioPlayer` (56px strip) — max scale 1.15
- `CategoryChip` — max scale 1.2 (horizontal scroll accommodates overflow)

---

### 10.5 Color-Blind Safety

Color must never be the sole conveyor of state or meaning. Every semantic state must include a redundant non-color signal.

| State | Color Signal | Redundant Signal |
|---|---|---|
| Testimony approved | `semantic-success` green | ✓ checkmark icon + "Publié" label |
| Testimony rejected | `semantic-error` red | ✗ X-circle icon + "Rejeté" label |
| Testimony pending | `semantic-warning` amber | Clock icon + "En révision" label |
| Reaction toggled active | Color change (red/gold) | Scale animation + icon fill change |
| Input error | Red border | Error icon + error text below field |
| Notification unread | Primary dot | Bold text weight on notification title |
| Online user indicator | Green dot | "En ligne" tooltip on long-press |

**Palette testing:** The design system palette has been checked against the three most common color vision deficiencies:
- **Deuteranopia** (red-green): Purple and gold remain distinguishable; error (red) and success (green) differ in luminance
- **Protanopia**: Same as deuteranopia — icon + label redundancy ensures comprehension
- **Tritanopia** (blue-yellow): Purple (#6B21A8) and gold (#F59E0B) remain distinguishable by luminance contrast

---

### 10.6 Motion & Vestibular Considerations

Users with vestibular disorders (affecting balance and spatial orientation) may experience nausea from excessive animation. Respect `MediaQuery.of(context).disableAnimations` and the iOS/Android "Reduce Motion" system setting.

```dart
// lib/core/theme/app_theme.dart — utility

bool reduceMotion(BuildContext context) {
  return MediaQuery.of(context).disableAnimations;
}

// Usage in animated widgets
final duration = reduceMotion(context)
    ? Duration.zero
    : AppDurations.medium;

// Crossfade vs instant swap
AnimatedSwitcher(
  duration: reduceMotion(context) ? Duration.zero : AppDurations.slow,
  child: currentWidget,
)
```

**Animations that must respect Reduce Motion:**
- Screen transition slide animations (replace with instant cut)
- Bottom sheet slide-in (replace with fade)
- Reaction scale-bounce (reduce to simple opacity toggle)
- Waveform bar breathing animation (disable idle animation)
- Onboarding slide transitions (replace with fade)

---

### 10.7 Language & Localization Readiness

The app ships in French first. The architecture must support English (and future languages) without structural changes.

```dart
// lib/l10n/app_localizations.dart (generated from .arb files)

// All user-facing strings must use:
AppLocalizations.of(context)!.homeGreeting(firstName)

// Never hardcode French strings directly in widgets
// WRONG: Text('Bonjour, $firstName')
// RIGHT: Text(l10n.homeGreeting(firstName))
```

**`arb` file structure:**
```
lib/l10n/
├── app_fr.arb    # French (primary)
└── app_en.arb    # English
```

**Minimum l10n coverage before launch:**
- All button labels, screen titles, empty state copy
- All error messages and validation text
- All notification body strings
- All moderation reason labels

RTL support is not required for v1.0 (no Arabic/Hebrew planned) but the layout should avoid hardcoded `left`/`right` directionality — use `start`/`end` in `EdgeInsetsDirectional` and `CrossAxisAlignment` throughout.

---

*End of Témoignages Complete Design & Architecture Reference v1.0*

*This document is the single source of truth for the Flutter development team. All implementation decisions should reference this document. When in doubt about any design, spacing, color, or behavioral detail, the answer is in this document.*

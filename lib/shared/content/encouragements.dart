// i18n-ignore-file
// Messages pour inciter à témoigner : versets (Louis Segond 1910 ; anglais : King James
// Version) et invitations. Table bilingue : le texte suit la langue affichée.
// Même liste que le site : config/encouragements.php du serveur — modifier les deux.
// Doc serveur : docs/fonctionnalites/encouragements.md

import '../../l10n/app_localizations.dart';

bool get _en => L10n.languageCode == 'en';

/// Un message d'encouragement : verset ([reference] non nulle) ou invitation.
/// [fr] / [referenceFr] : français ; [en] / [referenceEn] : anglais.
class Encouragement {
  const Encouragement(this.fr, this.referenceFr, {this.en, this.referenceEn});

  final String fr;
  final String? referenceFr;
  final String? en;
  final String? referenceEn;

  /// Texte dans la langue affichée.
  String get text => _en && en != null ? en! : fr;

  /// Référence dans la langue affichée (null pour une invitation).
  String? get reference => _en && referenceEn != null ? referenceEn : referenceFr;

  bool get isVerse => referenceFr != null;
}

/// Un message tous les [encouragementEvery] témoignages dans un fil.
const encouragementEvery = 8;

// ── Versets ──────────────────────────────────────────────────────────────────

const _rev12_11 = Encouragement(
    "Ils l'ont vaincu à cause du sang de l'agneau et à cause de la parole de leur témoignage, "
        "et ils n'ont pas aimé leur vie jusqu'à craindre la mort.",
    'Apocalypse 12:11',
    en: 'And they overcame him by the blood of the Lamb, and by the word of their testimony; '
        'and they loved not their lives unto the death.',
    referenceEn: 'Revelation 12:11');
const _ps78_4 = Encouragement(
    "Nous ne les cacherons point à leurs enfants; nous dirons à la génération future les louanges "
        "de l'Éternel, et sa puissance, et les prodiges qu'il a opérés.",
    'Psaume 78:4',
    en: 'We will not hide them from their children, shewing to the generation to come the praises '
        'of the LORD, and his strength, and his wonderful works that he hath done.',
    referenceEn: 'Psalm 78:4');
const _ps66_16 = Encouragement(
    "Venez, écoutez, vous tous qui craignez Dieu, et je raconterai ce qu'il a fait à mon âme.", 'Psaume 66:16',
    en: 'Come and hear, all ye that fear God, and I will declare what he hath done for my soul.',
    referenceEn: 'Psalm 66:16');
const _mark5_19 = Encouragement(
    "Va dans ta maison, vers les tiens, et raconte-leur tout ce que le Seigneur t'a fait, "
        "et comment il a eu pitié de toi.",
    'Marc 5:19',
    en: 'Go home to thy friends, and tell them how great things the Lord hath done for thee, '
        'and hath had compassion on thee.',
    referenceEn: 'Mark 5:19');
const _ps105_1 = Encouragement(
    "Louez l'Éternel, invoquez son nom! Faites connaître parmi les peuples ses hauts faits! "
        "Chantez, chantez en son honneur! Parlez de toutes ses merveilles!",
    'Psaume 105:1-2',
    en: 'O give thanks unto the LORD; call upon his name: make known his deeds among the people. '
        'Sing unto him, sing psalms unto him: talk ye of all his wondrous works.',
    referenceEn: 'Psalm 105:1-2');
const _ps145_4 = Encouragement('Que chaque génération célèbre tes œuvres, et publie tes hauts faits!', 'Psaume 145:4',
    en: 'One generation shall praise thy works to another, and shall declare thy mighty acts.',
    referenceEn: 'Psalm 145:4');
const _ps9_2 = Encouragement(
    "Je louerai l'Éternel de tout mon cœur, je raconterai toutes tes merveilles.", 'Psaume 9:2',
    en: 'I will praise thee, O LORD, with my whole heart; I will shew forth all thy marvellous works.',
    referenceEn: 'Psalm 9:1');
const _luke8_39 = Encouragement("Retourne dans ta maison, et raconte tout ce que Dieu t'a fait.", 'Luc 8:39',
    en: 'Return to thine own house, and shew how great things God hath done unto thee.',
    referenceEn: 'Luke 8:39');
const _ps118_17 = Encouragement(
    "Je ne mourrai pas, je vivrai, et je raconterai les œuvres de l'Éternel.", 'Psaume 118:17',
    en: 'I shall not die, but live, and declare the works of the LORD.', referenceEn: 'Psalm 118:17');
const _ps126_3 = Encouragement(
    "L'Éternel a fait pour nous de grandes choses; nous sommes dans la joie.", 'Psaume 126:3',
    en: 'The LORD hath done great things for us; whereof we are glad.', referenceEn: 'Psalm 126:3');
const _acts4_20 = Encouragement(
    'Car nous ne pouvons pas ne pas parler de ce que nous avons vu et entendu.', 'Actes 4:20',
    en: 'For we cannot but speak the things which we have seen and heard.', referenceEn: 'Acts 4:20');
const _ps107_2 = Encouragement(
    "Qu'ainsi disent les rachetés de l'Éternel, ceux qu'il a délivrés de la main de l'ennemi.", 'Psaume 107:2',
    en: 'Let the redeemed of the LORD say so, whom he hath redeemed from the hand of the enemy.',
    referenceEn: 'Psalm 107:2');
const _isa43_10Short = Encouragement("Vous êtes mes témoins, dit l'Éternel.", 'Ésaïe 43:10',
    en: 'Ye are my witnesses, saith the LORD.', referenceEn: 'Isaiah 43:10');
const _isa43_10 = Encouragement(
    "Vous êtes mes témoins, dit l'Éternel, vous, et mon serviteur que j'ai choisi.", 'Ésaïe 43:10',
    en: 'Ye are my witnesses, saith the LORD, and my servant whom I have chosen.', referenceEn: 'Isaiah 43:10');
const _ps40_10 = Encouragement(
    "J'annonce la justice dans la grande assemblée; voici, je ne ferme pas mes lèvres, Éternel, tu le sais!",
    'Psaume 40:10',
    en: 'I have preached righteousness in the great congregation: lo, I have not refrained my lips, '
        'O LORD, thou knowest.',
    referenceEn: 'Psalm 40:9');
const _acts1_8 = Encouragement(
    "Mais vous recevrez une puissance, le Saint-Esprit survenant sur vous, et vous serez mes témoins "
        "à Jérusalem, dans toute la Judée, dans la Samarie, et jusqu'aux extrémités de la terre.",
    'Actes 1:8',
    en: 'But ye shall receive power, after that the Holy Ghost is come upon you: and ye shall be witnesses '
        'unto me both in Jerusalem, and in all Judaea, and in Samaria, and unto the uttermost part of the earth.',
    referenceEn: 'Acts 1:8');
const _matt5_16 = Encouragement(
    "Que votre lumière luise ainsi devant les hommes, afin qu'ils voient vos bonnes œuvres, "
        "et qu'ils glorifient votre Père qui est dans les cieux.",
    'Matthieu 5:16',
    en: 'Let your light so shine before men, that they may see your good works, '
        'and glorify your Father which is in heaven.',
    referenceEn: 'Matthew 5:16');
const _2cor1_4 = Encouragement(
    "Qui nous console dans toutes nos afflictions, afin que, par la consolation dont nous sommes l'objet "
        "de la part de Dieu, nous puissions consoler ceux qui se trouvent dans quelque affliction!",
    '2 Corinthiens 1:4',
    en: 'Who comforteth us in all our tribulation, that we may be able to comfort them which are in any '
        'trouble, by the comfort wherewith we ourselves are comforted of God.',
    referenceEn: '2 Corinthians 1:4');
const _john4_39 = Encouragement(
    "Plusieurs Samaritains de cette ville crurent en Jésus à cause de cette déclaration formelle "
        "de la femme: Il m'a dit tout ce que j'ai fait.",
    'Jean 4:39',
    en: 'And many of the Samaritans of that city believed on him for the saying of the woman, '
        'which testified, He told me all that ever I did.',
    referenceEn: 'John 4:39');
const _1pet3_15 = Encouragement(
    "Mais sanctifiez dans vos cœurs Christ le Seigneur, étant toujours prêts à vous défendre, avec douceur "
        "et respect, devant quiconque vous demande raison de l'espérance qui est en vous.",
    '1 Pierre 3:15',
    en: 'But sanctify the Lord God in your hearts: and be ready always to give an answer to every man '
        'that asketh you a reason of the hope that is in you with meekness and fear.',
    referenceEn: '1 Peter 3:15');

const encouragementVerses = <Encouragement>[
  _rev12_11,
  _ps78_4,
  _ps66_16,
  _mark5_19,
  _ps105_1,
  _ps145_4,
  _ps9_2,
  _luke8_39,
  _ps118_17,
  _ps126_3,
  _acts4_20,
  _ps107_2,
  _isa43_10Short,
  _ps40_10,
];

const encouragementCalls = <Encouragement>[
  Encouragement(
      "Dieu a fait quelque chose pour vous ? Racontez-le : votre témoignage peut fortifier quelqu'un aujourd'hui.",
      null,
      en: 'Has God done something for you? Tell it: your testimony could strengthen someone today.'),
  Encouragement('Une prière exaucée, une guérison, une porte ouverte ? Partagez-la pour la gloire de Dieu.', null,
      en: 'An answered prayer, a healing, an open door? Share it for the glory of God.'),
  Encouragement('Ce que Dieu a fait pour vous, il peut le faire pour un autre. Témoignez !', null,
      en: 'What God has done for you, he can do for someone else. Testify!'),
  Encouragement('Ne gardez pas pour vous les merveilles de Dieu : votre histoire peut changer une vie.', null,
      en: "Don't keep God's wonders to yourself: your story can change a life."),
];

/// Versets sur les paroles prophétiques (page « Paroles prophétiques »).
const prophecyVerses = <Encouragement>[
  Encouragement(
      "Car c'est une prophétie dont le temps est déjà fixé, elle marche vers son terme, et elle ne mentira pas; "
          "si elle tarde, attends-la, car elle s'accomplira, elle s'accomplira certainement.",
      'Habakuk 2:3',
      en: 'For the vision is yet for an appointed time, but at the end it shall speak, and not lie: '
          'though it tarry, wait for it; because it will surely come, it will not tarry.',
      referenceEn: 'Habakkuk 2:3'),
  Encouragement(
      "Dieu n'est point un homme pour mentir, ni fils d'un homme pour se repentir. Ce qu'il a dit, "
          "ne le fera-t-il pas? Ce qu'il a déclaré, ne l'exécutera-t-il pas?",
      'Nombres 23:19',
      en: 'God is not a man, that he should lie; neither the son of man, that he should repent: '
          'hath he said, and shall he not do it? or hath he spoken, and shall he not make it good?',
      referenceEn: 'Numbers 23:19'),
  Encouragement(
      "Le commandement que je t'adresse, Timothée, mon enfant, selon les prophéties faites précédemment "
          "à ton sujet, c'est que, d'après elles, tu combattes le bon combat.",
      '1 Timothée 1:18',
      en: 'This charge I commit unto thee, son Timothy, according to the prophecies which went before '
          'on thee, that thou by them mightest war a good warfare.',
      referenceEn: '1 Timothy 1:18'),
];

/// Une raison de témoigner (bloc « Pourquoi témoigner ? », [WhyTestifyCard]) et ses versets.
class WhyTestifyReason {
  const WhyTestifyReason(this.titleFr, this.summaryFr, this.verses,
      {required this.titleEn, required this.summaryEn});

  final String titleFr;
  final String summaryFr;
  final String titleEn;
  final String summaryEn;
  final List<Encouragement> verses;

  String get title => _en ? titleEn : titleFr;
  String get summary => _en ? summaryEn : summaryFr;
}

/// « Pourquoi témoigner ? » — même contenu que le site (config/encouragements.php, why_testify).
/// Doc serveur : docs/fonctionnalites/pourquoi-temoigner.md
const whyTestifyReasons = <WhyTestifyReason>[
  WhyTestifyReason(
    "C'est l'appel du Seigneur",
    "Jésus demande à ceux qu'il a touchés de raconter ce qu'il a fait.",
    [_mark5_19, _isa43_10, _acts1_8],
    titleEn: "It is the Lord's call",
    summaryEn: 'Jesus asks those he has touched to tell what he has done.',
  ),
  WhyTestifyReason(
    'Le témoignage donne la victoire',
    "La parole du témoignage, avec le sang de l'Agneau, triomphe de l'ennemi.",
    [_rev12_11, _ps107_2],
    titleEn: 'Testimony brings victory',
    summaryEn: 'The word of testimony, with the blood of the Lamb, overcomes the enemy.',
  ),
  WhyTestifyReason(
    'Il rend gloire à Dieu',
    "Raconter ses merveilles, c'est le louer devant tous.",
    [_ps105_1, _ps9_2, _matt5_16],
    titleEn: 'It gives glory to God',
    summaryEn: 'Telling of his wonders is praising him before everyone.',
  ),
  WhyTestifyReason(
    'Il fortifie et console les autres',
    'Ce que Dieu a fait pour vous devient une espérance pour un autre.',
    [_ps66_16, _2cor1_4],
    titleEn: 'It strengthens and comforts others',
    summaryEn: 'What God has done for you becomes hope for someone else.',
  ),
  WhyTestifyReason(
    "Il conduit d'autres à la foi",
    'Un simple récit peut amener toute une ville à Jésus.',
    [_john4_39, _1pet3_15],
    titleEn: 'It leads others to faith',
    summaryEn: 'A simple story can bring a whole town to Jesus.',
  ),
  WhyTestifyReason(
    'Il transmet la foi aux générations',
    'Nos enfants doivent connaître les œuvres de Dieu.',
    [_ps78_4, _ps145_4],
    titleEn: 'It passes faith on to the generations',
    summaryEn: 'Our children must know the works of God.',
  ),
  WhyTestifyReason(
    'On ne peut pas se taire',
    "Celui qui a vu l'œuvre de Dieu ne garde pas ses lèvres fermées.",
    [_acts4_20, _ps40_10, _ps118_17],
    titleEn: 'We cannot keep silent',
    summaryEn: 'Whoever has seen the work of God does not keep their lips closed.',
  ),
];

/// Message n° [index] : versets et invitations en alternance (deux versets, une invitation).
Encouragement encouragementAt(int index) {
  final i = index.abs();
  if (i % 3 == 2) return encouragementCalls[(i ~/ 3) % encouragementCalls.length];
  return encouragementVerses[(i - i ~/ 3) % encouragementVerses.length];
}

/// Message du jour (change chaque jour, identique pour tous ce jour-là), décalé de [offset].
Encouragement encouragementOfTheDay([int offset = 0, DateTime? now]) {
  final d = now ?? DateTime.now();
  final day = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
  return encouragementAt(day + offset);
}

/// Fil avec messages insérés : positions des témoignages et des messages.
/// Renvoie le nombre total d'éléments pour [count] témoignages.
int feedLengthWithEncouragements(int count) =>
    count + (count >= encouragementEvery ? count ~/ encouragementEvery : 0);

/// Pour l'élément [position] d'un fil avec messages : l'indice du témoignage,
/// ou null si c'est un message (le n° du message est alors `position ~/ (every + 1)`).
int? testimonyIndexAt(int position) {
  const block = encouragementEvery + 1;
  if (position % block == encouragementEvery) return null;
  return position - position ~/ block;
}

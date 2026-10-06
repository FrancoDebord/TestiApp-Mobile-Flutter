// Messages pour inciter à témoigner : versets (Louis Segond 1910) et invitations.
// Même liste que le site : config/encouragements.php du serveur — modifier les deux.
// Doc serveur : docs/fonctionnalites/encouragements.md

/// Un message d'encouragement : verset ([reference] non nulle) ou invitation.
class Encouragement {
  const Encouragement(this.text, [this.reference]);

  final String text;
  final String? reference;

  bool get isVerse => reference != null;
}

/// Un message tous les [encouragementEvery] témoignages dans un fil.
const encouragementEvery = 8;

const encouragementVerses = <Encouragement>[
  Encouragement(
      "Ils l'ont vaincu à cause du sang de l'agneau et à cause de la parole de leur témoignage, "
          "et ils n'ont pas aimé leur vie jusqu'à craindre la mort.",
      'Apocalypse 12:11'),
  Encouragement(
      "Nous ne les cacherons point à leurs enfants; nous dirons à la génération future les louanges "
          "de l'Éternel, et sa puissance, et les prodiges qu'il a opérés.",
      'Psaume 78:4'),
  Encouragement("Venez, écoutez, vous tous qui craignez Dieu, et je raconterai ce qu'il a fait à mon âme.",
      'Psaume 66:16'),
  Encouragement(
      "Va dans ta maison, vers les tiens, et raconte-leur tout ce que le Seigneur t'a fait, "
          "et comment il a eu pitié de toi.",
      'Marc 5:19'),
  Encouragement(
      "Louez l'Éternel, invoquez son nom! Faites connaître parmi les peuples ses hauts faits! "
          "Chantez, chantez en son honneur! Parlez de toutes ses merveilles!",
      'Psaume 105:1-2'),
  Encouragement('Que chaque génération célèbre tes œuvres, et publie tes hauts faits!', 'Psaume 145:4'),
  Encouragement("Je louerai l'Éternel de tout mon cœur, je raconterai toutes tes merveilles.", 'Psaume 9:2'),
  Encouragement("Retourne dans ta maison, et raconte tout ce que Dieu t'a fait.", 'Luc 8:39'),
  Encouragement("Je ne mourrai pas, je vivrai, et je raconterai les œuvres de l'Éternel.", 'Psaume 118:17'),
  Encouragement("L'Éternel a fait pour nous de grandes choses; nous sommes dans la joie.", 'Psaume 126:3'),
  Encouragement('Car nous ne pouvons pas ne pas parler de ce que nous avons vu et entendu.', 'Actes 4:20'),
  Encouragement("Qu'ainsi disent les rachetés de l'Éternel, ceux qu'il a délivrés de la main de l'ennemi.",
      'Psaume 107:2'),
  Encouragement("Vous êtes mes témoins, dit l'Éternel.", 'Ésaïe 43:10'),
  Encouragement(
      "J'annonce la justice dans la grande assemblée; voici, je ne ferme pas mes lèvres, Éternel, tu le sais!",
      'Psaume 40:10'),
];

const encouragementCalls = <Encouragement>[
  Encouragement(
      "Dieu a fait quelque chose pour vous ? Racontez-le : votre témoignage peut fortifier quelqu'un aujourd'hui."),
  Encouragement('Une prière exaucée, une guérison, une porte ouverte ? Partagez-la pour la gloire de Dieu.'),
  Encouragement('Ce que Dieu a fait pour vous, il peut le faire pour un autre. Témoignez !'),
  Encouragement('Ne gardez pas pour vous les merveilles de Dieu : votre histoire peut changer une vie.'),
];

/// Versets sur les paroles prophétiques (page « Paroles prophétiques »).
const prophecyVerses = <Encouragement>[
  Encouragement(
      "Car c'est une prophétie dont le temps est déjà fixé, elle marche vers son terme, et elle ne mentira pas; "
          "si elle tarde, attends-la, car elle s'accomplira, elle s'accomplira certainement.",
      'Habakuk 2:3'),
  Encouragement(
      "Dieu n'est point un homme pour mentir, ni fils d'un homme pour se repentir. Ce qu'il a dit, "
          "ne le fera-t-il pas? Ce qu'il a déclaré, ne l'exécutera-t-il pas?",
      'Nombres 23:19'),
  Encouragement(
      "Le commandement que je t'adresse, Timothée, mon enfant, selon les prophéties faites précédemment "
          "à ton sujet, c'est que, d'après elles, tu combattes le bon combat.",
      '1 Timothée 1:18'),
];

/// Une raison de témoigner (bloc « Pourquoi témoigner ? », [WhyTestifyCard]) et ses versets.
class WhyTestifyReason {
  const WhyTestifyReason(this.title, this.summary, this.verses);

  final String title;
  final String summary;
  final List<Encouragement> verses;
}

/// « Pourquoi témoigner ? » — même contenu que le site (config/encouragements.php, why_testify).
/// Doc serveur : docs/fonctionnalites/pourquoi-temoigner.md
const whyTestifyReasons = <WhyTestifyReason>[
  WhyTestifyReason(
    "C'est l'appel du Seigneur",
    "Jésus demande à ceux qu'il a touchés de raconter ce qu'il a fait.",
    [
      Encouragement(
          "Va dans ta maison, vers les tiens, et raconte-leur tout ce que le Seigneur t'a fait, "
              "et comment il a eu pitié de toi.",
          'Marc 5:19'),
      Encouragement("Vous êtes mes témoins, dit l'Éternel, vous, et mon serviteur que j'ai choisi.", 'Ésaïe 43:10'),
      Encouragement(
          "Mais vous recevrez une puissance, le Saint-Esprit survenant sur vous, et vous serez mes témoins "
              "à Jérusalem, dans toute la Judée, dans la Samarie, et jusqu'aux extrémités de la terre.",
          'Actes 1:8'),
    ],
  ),
  WhyTestifyReason(
    'Le témoignage donne la victoire',
    "La parole du témoignage, avec le sang de l'Agneau, triomphe de l'ennemi.",
    [
      Encouragement(
          "Ils l'ont vaincu à cause du sang de l'agneau et à cause de la parole de leur témoignage, "
              "et ils n'ont pas aimé leur vie jusqu'à craindre la mort.",
          'Apocalypse 12:11'),
      Encouragement("Qu'ainsi disent les rachetés de l'Éternel, ceux qu'il a délivrés de la main de l'ennemi.",
          'Psaume 107:2'),
    ],
  ),
  WhyTestifyReason(
    'Il rend gloire à Dieu',
    "Raconter ses merveilles, c'est le louer devant tous.",
    [
      Encouragement(
          "Louez l'Éternel, invoquez son nom! Faites connaître parmi les peuples ses hauts faits! "
              "Chantez, chantez en son honneur! Parlez de toutes ses merveilles!",
          'Psaume 105:1-2'),
      Encouragement("Je louerai l'Éternel de tout mon cœur, je raconterai toutes tes merveilles.", 'Psaume 9:2'),
      Encouragement(
          "Que votre lumière luise ainsi devant les hommes, afin qu'ils voient vos bonnes œuvres, "
              "et qu'ils glorifient votre Père qui est dans les cieux.",
          'Matthieu 5:16'),
    ],
  ),
  WhyTestifyReason(
    'Il fortifie et console les autres',
    'Ce que Dieu a fait pour vous devient une espérance pour un autre.',
    [
      Encouragement("Venez, écoutez, vous tous qui craignez Dieu, et je raconterai ce qu'il a fait à mon âme.",
          'Psaume 66:16'),
      Encouragement(
          "Qui nous console dans toutes nos afflictions, afin que, par la consolation dont nous sommes l'objet "
              "de la part de Dieu, nous puissions consoler ceux qui se trouvent dans quelque affliction!",
          '2 Corinthiens 1:4'),
    ],
  ),
  WhyTestifyReason(
    "Il conduit d'autres à la foi",
    'Un simple récit peut amener toute une ville à Jésus.',
    [
      Encouragement(
          "Plusieurs Samaritains de cette ville crurent en Jésus à cause de cette déclaration formelle "
              "de la femme: Il m'a dit tout ce que j'ai fait.",
          'Jean 4:39'),
      Encouragement(
          "Mais sanctifiez dans vos cœurs Christ le Seigneur, étant toujours prêts à vous défendre, avec douceur "
              "et respect, devant quiconque vous demande raison de l'espérance qui est en vous.",
          '1 Pierre 3:15'),
    ],
  ),
  WhyTestifyReason(
    'Il transmet la foi aux générations',
    'Nos enfants doivent connaître les œuvres de Dieu.',
    [
      Encouragement(
          "Nous ne les cacherons point à leurs enfants; nous dirons à la génération future les louanges "
              "de l'Éternel, et sa puissance, et les prodiges qu'il a opérés.",
          'Psaume 78:4'),
      Encouragement('Que chaque génération célèbre tes œuvres, et publie tes hauts faits!', 'Psaume 145:4'),
    ],
  ),
  WhyTestifyReason(
    'On ne peut pas se taire',
    "Celui qui a vu l'œuvre de Dieu ne garde pas ses lèvres fermées.",
    [
      Encouragement('Car nous ne pouvons pas ne pas parler de ce que nous avons vu et entendu.', 'Actes 4:20'),
      Encouragement(
          "J'annonce la justice dans la grande assemblée; voici, je ne ferme pas mes lèvres, Éternel, tu le sais!",
          'Psaume 40:10'),
      Encouragement("Je ne mourrai pas, je vivrai, et je raconterai les œuvres de l'Éternel.", 'Psaume 118:17'),
    ],
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

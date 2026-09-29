// Pays proposés à l'inscription et dans le profil, en français et en toutes lettres,
// avec leur code ISO et leur indicatif téléphonique.
//
// GÉNÉRÉ depuis le serveur (App\Support\Countries, TestiApp-Backend-Laravel) : mêmes noms
// que le site, pour des données homogènes. Ne pas modifier à la main ; régénérer en cas d'ajout.
// Backend : docs/fonctionnalites/telephone.md

/// Un pays : nom affiché (et enregistré), code ISO 3166-1 (« bj »), indicatif (« 229 »).
class Country {
  const Country(this.name, this.code, this.dial);

  final String name;
  final String code;
  final String dial;

  /// Drapeau (émoji formé des deux lettres du code ISO).
  String get flag => String.fromCharCodes(
      code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

  /// « +229 »
  String get dialLabel => '+$dial';
}

/// Ordre alphabétique français, sans tenir compte des accents (comme le site).
const List<Country> kCountries = [
  Country('Afghanistan', 'af', '93'),
  Country('Afrique du Sud', 'za', '27'),
  Country('Albanie', 'al', '355'),
  Country('Algérie', 'dz', '213'),
  Country('Allemagne', 'de', '49'),
  Country('Andorre', 'ad', '376'),
  Country('Angola', 'ao', '244'),
  Country('Antigua-et-Barbuda', 'ag', '1'),
  Country('Arabie saoudite', 'sa', '966'),
  Country('Argentine', 'ar', '54'),
  Country('Arménie', 'am', '374'),
  Country('Australie', 'au', '61'),
  Country('Autriche', 'at', '43'),
  Country('Azerbaïdjan', 'az', '994'),
  Country('Bahamas', 'bs', '1'),
  Country('Bahreïn', 'bh', '973'),
  Country('Bangladesh', 'bd', '880'),
  Country('Barbade', 'bb', '1'),
  Country('Belgique', 'be', '32'),
  Country('Belize', 'bz', '501'),
  Country('Bénin', 'bj', '229'),
  Country('Bhoutan', 'bt', '975'),
  Country('Biélorussie', 'by', '375'),
  Country('Birmanie', 'mm', '95'),
  Country('Bolivie', 'bo', '591'),
  Country('Bosnie-Herzégovine', 'ba', '387'),
  Country('Botswana', 'bw', '267'),
  Country('Brésil', 'br', '55'),
  Country('Brunei', 'bn', '673'),
  Country('Bulgarie', 'bg', '359'),
  Country('Burkina Faso', 'bf', '226'),
  Country('Burundi', 'bi', '257'),
  Country('Cambodge', 'kh', '855'),
  Country('Cameroun', 'cm', '237'),
  Country('Canada', 'ca', '1'),
  Country('Cap-Vert', 'cv', '238'),
  Country('Chili', 'cl', '56'),
  Country('Chine', 'cn', '86'),
  Country('Chypre', 'cy', '357'),
  Country('Colombie', 'co', '57'),
  Country('Comores', 'km', '269'),
  Country('Congo (Brazzaville)', 'cg', '242'),
  Country('Congo (RDC)', 'cd', '243'),
  Country('Corée du Nord', 'kp', '850'),
  Country('Corée du Sud', 'kr', '82'),
  Country('Costa Rica', 'cr', '506'),
  Country('Côte d\'Ivoire', 'ci', '225'),
  Country('Croatie', 'hr', '385'),
  Country('Cuba', 'cu', '53'),
  Country('Danemark', 'dk', '45'),
  Country('Djibouti', 'dj', '253'),
  Country('Dominique', 'dm', '1'),
  Country('Égypte', 'eg', '20'),
  Country('Émirats arabes unis', 'ae', '971'),
  Country('Équateur', 'ec', '593'),
  Country('Érythrée', 'er', '291'),
  Country('Espagne', 'es', '34'),
  Country('Estonie', 'ee', '372'),
  Country('États-Unis', 'us', '1'),
  Country('Éthiopie', 'et', '251'),
  Country('Fidji', 'fj', '679'),
  Country('Finlande', 'fi', '358'),
  Country('France', 'fr', '33'),
  Country('Gabon', 'ga', '241'),
  Country('Gambie', 'gm', '220'),
  Country('Géorgie', 'ge', '995'),
  Country('Ghana', 'gh', '233'),
  Country('Grèce', 'gr', '30'),
  Country('Grenade', 'gd', '1'),
  Country('Guadeloupe', 'gp', '590'),
  Country('Guatemala', 'gt', '502'),
  Country('Guinée', 'gn', '224'),
  Country('Guinée équatoriale', 'gq', '240'),
  Country('Guinée-Bissau', 'gw', '245'),
  Country('Guyana', 'gy', '592'),
  Country('Guyane', 'gf', '594'),
  Country('Haïti', 'ht', '509'),
  Country('Honduras', 'hn', '504'),
  Country('Hongrie', 'hu', '36'),
  Country('Îles Marshall', 'mh', '692'),
  Country('Îles Salomon', 'sb', '677'),
  Country('Inde', 'in', '91'),
  Country('Indonésie', 'id', '62'),
  Country('Irak', 'iq', '964'),
  Country('Iran', 'ir', '98'),
  Country('Irlande', 'ie', '353'),
  Country('Islande', 'is', '354'),
  Country('Israël', 'il', '972'),
  Country('Italie', 'it', '39'),
  Country('Jamaïque', 'jm', '1'),
  Country('Japon', 'jp', '81'),
  Country('Jordanie', 'jo', '962'),
  Country('Kazakhstan', 'kz', '7'),
  Country('Kenya', 'ke', '254'),
  Country('Kirghizistan', 'kg', '996'),
  Country('Kiribati', 'ki', '686'),
  Country('Kosovo', 'xk', '383'),
  Country('Koweït', 'kw', '965'),
  Country('La Réunion', 're', '262'),
  Country('Laos', 'la', '856'),
  Country('Lesotho', 'ls', '266'),
  Country('Lettonie', 'lv', '371'),
  Country('Liban', 'lb', '961'),
  Country('Libéria', 'lr', '231'),
  Country('Libye', 'ly', '218'),
  Country('Liechtenstein', 'li', '423'),
  Country('Lituanie', 'lt', '370'),
  Country('Luxembourg', 'lu', '352'),
  Country('Macédoine du Nord', 'mk', '389'),
  Country('Madagascar', 'mg', '261'),
  Country('Malaisie', 'my', '60'),
  Country('Malawi', 'mw', '265'),
  Country('Maldives', 'mv', '960'),
  Country('Mali', 'ml', '223'),
  Country('Malte', 'mt', '356'),
  Country('Maroc', 'ma', '212'),
  Country('Martinique', 'mq', '596'),
  Country('Maurice', 'mu', '230'),
  Country('Mauritanie', 'mr', '222'),
  Country('Mayotte', 'yt', '262'),
  Country('Mexique', 'mx', '52'),
  Country('Micronésie', 'fm', '691'),
  Country('Moldavie', 'md', '373'),
  Country('Monaco', 'mc', '377'),
  Country('Mongolie', 'mn', '976'),
  Country('Monténégro', 'me', '382'),
  Country('Mozambique', 'mz', '258'),
  Country('Namibie', 'na', '264'),
  Country('Nauru', 'nr', '674'),
  Country('Népal', 'np', '977'),
  Country('Nicaragua', 'ni', '505'),
  Country('Niger', 'ne', '227'),
  Country('Nigeria', 'ng', '234'),
  Country('Norvège', 'no', '47'),
  Country('Nouvelle-Calédonie', 'nc', '687'),
  Country('Nouvelle-Zélande', 'nz', '64'),
  Country('Oman', 'om', '968'),
  Country('Ouganda', 'ug', '256'),
  Country('Ouzbékistan', 'uz', '998'),
  Country('Pakistan', 'pk', '92'),
  Country('Palaos', 'pw', '680'),
  Country('Palestine', 'ps', '970'),
  Country('Panama', 'pa', '507'),
  Country('Papouasie-Nouvelle-Guinée', 'pg', '675'),
  Country('Paraguay', 'py', '595'),
  Country('Pays-Bas', 'nl', '31'),
  Country('Pérou', 'pe', '51'),
  Country('Philippines', 'ph', '63'),
  Country('Pologne', 'pl', '48'),
  Country('Polynésie française', 'pf', '689'),
  Country('Portugal', 'pt', '351'),
  Country('Qatar', 'qa', '974'),
  Country('République centrafricaine', 'cf', '236'),
  Country('République dominicaine', 'do', '1'),
  Country('République tchèque', 'cz', '420'),
  Country('Roumanie', 'ro', '40'),
  Country('Royaume-Uni', 'gb', '44'),
  Country('Russie', 'ru', '7'),
  Country('Rwanda', 'rw', '250'),
  Country('Saint-Christophe-et-Niévès', 'kn', '1'),
  Country('Saint-Marin', 'sm', '378'),
  Country('Saint-Vincent-et-les-Grenadines', 'vc', '1'),
  Country('Sainte-Lucie', 'lc', '1'),
  Country('Salvador', 'sv', '503'),
  Country('Samoa', 'ws', '685'),
  Country('São Tomé-et-Príncipe', 'st', '239'),
  Country('Sénégal', 'sn', '221'),
  Country('Serbie', 'rs', '381'),
  Country('Seychelles', 'sc', '248'),
  Country('Sierra Leone', 'sl', '232'),
  Country('Singapour', 'sg', '65'),
  Country('Slovaquie', 'sk', '421'),
  Country('Slovénie', 'si', '386'),
  Country('Somalie', 'so', '252'),
  Country('Soudan', 'sd', '249'),
  Country('Soudan du Sud', 'ss', '211'),
  Country('Sri Lanka', 'lk', '94'),
  Country('Suède', 'se', '46'),
  Country('Suisse', 'ch', '41'),
  Country('Suriname', 'sr', '597'),
  Country('Swaziland', 'sz', '268'),
  Country('Syrie', 'sy', '963'),
  Country('Tadjikistan', 'tj', '992'),
  Country('Taïwan', 'tw', '886'),
  Country('Tanzanie', 'tz', '255'),
  Country('Tchad', 'td', '235'),
  Country('Thaïlande', 'th', '66'),
  Country('Timor oriental', 'tl', '670'),
  Country('Togo', 'tg', '228'),
  Country('Tonga', 'to', '676'),
  Country('Trinité-et-Tobago', 'tt', '1'),
  Country('Tunisie', 'tn', '216'),
  Country('Turkménistan', 'tm', '993'),
  Country('Turquie', 'tr', '90'),
  Country('Tuvalu', 'tv', '688'),
  Country('Ukraine', 'ua', '380'),
  Country('Uruguay', 'uy', '598'),
  Country('Vanuatu', 'vu', '678'),
  Country('Vatican', 'va', '39'),
  Country('Venezuela', 've', '58'),
  Country('Viêt Nam', 'vn', '84'),
  Country('Yémen', 'ye', '967'),
  Country('Zambie', 'zm', '260'),
  Country('Zimbabwe', 'zw', '263'),
];

Country? countryByName(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  for (final c in kCountries) {
    if (c.name == name.trim()) return c;
  }
  return null;
}

Country? countryByCode(String? code) {
  if (code == null || code.trim().isEmpty) return null;
  final lower = code.trim().toLowerCase();
  for (final c in kCountries) {
    if (c.code == lower) return c;
  }
  return null;
}

/// Minuscules sans accents, pour la recherche (« cote » trouve « Côte d'Ivoire »).
String normalizeForSearch(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to   = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final lower = s.toLowerCase().trim();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}

/// Pays correspondant à la recherche (nom ou indicatif) : ceux qui commencent
/// par la saisie d'abord, puis ceux qui la contiennent.
List<Country> searchCountries(String query) {
  final q = normalizeForSearch(query).replaceFirst('+', '');
  if (q.isEmpty) return kCountries;
  final starts = <Country>[];
  final contains = <Country>[];
  for (final c in kCountries) {
    final n = normalizeForSearch(c.name);
    if (n.startsWith(q) || c.dial.startsWith(q)) {
      starts.add(c);
    } else if (n.contains(q) || c.dial.contains(q)) {
      contains.add(c);
    }
  }
  return [...starts, ...contains];
}

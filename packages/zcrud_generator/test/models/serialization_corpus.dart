/// CORPUS de fixtures de rétro-compatibilité de (dé)sérialisation (E2-10, AD-10).
///
/// # Rôle : gate de merge « désérialisation défensive »
///
/// Ce module est la **source unique de vérité** du corpus exercé par le slot
/// `verify:serialization` (`scripts/ci/verify_serialization.dart`, câblé no-op
/// en E1-3, amorcé en E2-5). Les tests `serialization_corpus_test.dart`
/// (voie codegen directe + voie registre) itèrent CETTE liste : ajouter un cas
/// qui casse le parent fait mécaniquement échouer le gate (rouge au merge).
///
/// # Discipline AD-10 (source of truth : architecture.md#AD-10)
///
/// - **Évolution ADDITIVE seulement** : entre versions mineures, on n'AJOUTE
///   que des champs (nullable ou `@JsonKey(defaultValue)`) ; jamais de
///   renommage/suppression sans montée majeure.
/// - **Désérialisation DÉFENSIVE systématique** : `unknownEnumValue`,
///   `defaultValue`, `fromJsonSafe → null`. **Un champ absent/corrompu ne fait
///   JAMAIS échouer le parent.** Le corpus PROUVE cette règle en continu.
///
/// # Comportement OBSERVÉ du codegen défensif (E2-5) — à connaître
///
/// Le `fromMap` généré (`article.g.dart`) est défensif par construction, ET
/// **le `fromMap` du sous-modèle `Author` l'est aussi** (`name` non-`String`
/// → `''`). Conséquence importante, faithfully asserted par le corpus :
/// - un sous-objet `author` **présent mais partiel/vide** (`{}`,
///   `{'email':...}`) → `Author(name: '', …)` — il **ne s'effondre PAS en
///   `null`** (le `fromMap` d'`Author` ne lève pas) ;
/// - un sous-objet `author` **qui n'est PAS une Map** (`'x'`, `123`) →
///   `_$asStringMap` renvoie `null` → `author == null` ;
/// - en liste, seuls les éléments **non-`Map`** sont filtrés (`whereType`) ;
///   un élément Map partiel devient un `Author(name: '')` conservé.
/// Le corpus consigne ce comportement RÉEL (sans le modifier — cf. story T2).
///
/// # Les 7 familles de corruption couvertes
///
/// (a) historiques — champs récents ABSENTS → `defaultValue`.
/// (b) tronqués — top-level partiel + sous-objet coupé.
/// (c) champs inconnus — clés futures ignorées.
/// (d) enums inconnus — valeur d'enum future/retirée → `draft`.
/// (e) types faux — `String`↔`int`, `Map`↔`List`, non-`bool`, non-`Map`.
/// (f) clés non-`String` (régression H1) — sous-objet Hive/forgé `Map<int,…>`.
/// (g) `null` partout — chaque champ `null` → repli.
///
/// Les cas `historique_v_n_champ_ajoute_absent` (a) et
/// `futur_v_n1_champ_inconnu_ignore` (c) matérialisent explicitement la
/// **compat ascendante/descendante** de montée de version (AC7).
library;

/// Un cas de corpus : `name` (id unique), `family` (a…g), `map` (document
/// persisté simulé). Le `map` est typé `Map<Object?, Object?>` pour héberger
/// des sous-objets à clés non-`String` (famille f) ; ses clés TOP-LEVEL sont
/// toujours des `String` (contrat `Map<String, dynamic>` du repository), la
/// corruption non-`String` ne vivant que dans les sous-objets `dynamic`.
typedef CorpusCase = ({String name, String family, Map<Object?, Object?> map});

/// Le corpus complet, groupé par famille. Itéré par les deux voies de test.
const List<CorpusCase> serializationCorpus = <CorpusCase>[
  // ---- (a) historiques : champs récents absents → defaultValue -------------
  // AC7 — compat ASCENDANTE : document v(n) lu par le code v(n+1).
  (
    name: 'historique_v_n_champ_ajoute_absent',
    family: 'a',
    // Schéma ancien : seuls id/title/subtitle existaient.
    map: <Object?, Object?>{'id': 'a1', 'title': 'Vieux', 'subtitle': 'sub'},
  ),
  (
    name: 'historique_scalaires_absents',
    family: 'a',
    map: <Object?, Object?>{'title': 'Ancien'},
  ),

  // ---- (b) tronqués : top-level partiel + sous-objet coupé -----------------
  (
    name: 'tronque_toplevel_et_sous_objet_vide',
    family: 'b',
    // author:{} (name manquant) + coauthors avec éléments non-Map filtrés.
    map: <Object?, Object?>{
      'title': 'T',
      'author': <Object?, Object?>{},
      'coauthors': <Object?>[<Object?, Object?>{}, 'bad', 7],
    },
  ),
  (
    name: 'sous_objet_author_sans_name',
    family: 'b',
    map: <Object?, Object?>{
      'title': 'T2',
      'author': <Object?, Object?>{'email': 'e@x.com'},
    },
  ),

  // ---- (c) champs inconnus : clés futures ignorées -------------------------
  // AC7 — compat DESCENDANTE : document v(n+1) lu par le code v(n).
  (
    name: 'futur_v_n1_champ_inconnu_ignore',
    family: 'c',
    map: <Object?, Object?>{
      'title': 'X',
      'views': 5,
      '__future_key__': 42,
      'nested_future': <Object?, Object?>{'deep': <Object?>[1, 2]},
    },
  ),

  // ---- (d) enums inconnus : valeur future/retirée → draft ------------------
  (
    name: 'enum_legacy_retire',
    family: 'd',
    map: <Object?, Object?>{'title': 'E', 'status': 'legacyRemoved'},
  ),
  (
    name: 'enum_futur',
    family: 'd',
    map: <Object?, Object?>{'title': 'E2', 'status': 'futureStatus'},
  ),
  (
    name: 'enum_non_string',
    family: 'd',
    map: <Object?, Object?>{'title': 'E3', 'status': 123},
  ),

  // ---- (e) types faux : String↔int, Map↔List, non-bool, non-Map -----------
  (
    name: 'views_string_non_num',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'views': 'abc'},
  ),
  (
    name: 'views_string_num_coerce',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'views': '42'},
  ),
  (
    name: 'rating_string_num_coerce',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'rating': '3.5'},
  ),
  (
    name: 'rating_string_non_num',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'rating': 'x'},
  ),
  (
    name: 'tags_map_au_lieu_de_list',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'tags': <Object?, Object?>{}},
  ),
  (
    name: 'coauthors_map_au_lieu_de_list',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'coauthors': <Object?, Object?>{}},
  ),
  (
    name: 'published_non_bool',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'published': 1},
  ),
  (
    name: 'author_non_map',
    family: 'e',
    map: <Object?, Object?>{'title': 'T', 'author': 'x'},
  ),
  (
    name: 'tags_liste_mixte',
    family: 'e',
    map: <Object?, Object?>{
      'title': 'T',
      'tags': <Object?>['a', 7, null, 'b'],
    },
  ),

  // ---- (f) clés non-String (régression H1) : sous-objet Hive/forgé ---------
  (
    name: 'author_cles_int_hive',
    family: 'f',
    // Map<int,String> nichée : _$asStringMap coerce en {'1':'a','2':'b'} SANS
    // throw ; aucune clé 'name' → Author(name:''), parent survit.
    map: <Object?, Object?>{
      'title': 'T',
      'author': <Object?, Object?>{1: 'a', 2: 'b'},
    },
  ),
  (
    name: 'author_cles_mixtes_avec_name',
    family: 'f',
    // Clés mixtes String+int : la clé valide 'name' est PRÉSERVÉE malgré la
    // clé non-String — preuve que la coercition H1 n'écrase pas les vrais champs.
    map: <Object?, Object?>{
      'title': 'T',
      'author': <Object?, Object?>{'name': 'Bob', 1: 'x'},
    },
  ),

  // ---- (g) null partout : chaque champ null → repli ------------------------
  (
    name: 'null_partout',
    family: 'g',
    map: <Object?, Object?>{
      'id': null,
      'title': null,
      'subtitle': null,
      'views': null,
      'rating': null,
      'published': null,
      'status': null,
      'created_at': null,
      'tags': null,
      'author': null,
      'coauthors': null,
    },
  ),
];

/// Récupère un cas par son [name] (assertions ciblées de repli par famille).
CorpusCase corpusCase(String name) =>
    serializationCorpus.firstWhere((c) => c.name == name);

/// Coerce un cas en `Map<String, dynamic>` (contrat du repository / registre).
/// Les clés TOP-LEVEL de tout cas sont des `String` ; seule la corruption
/// non-`String` des sous-objets (famille f) reste, portée par les valeurs.
Map<String, dynamic> asTopLevelMap(CorpusCase c) =>
    Map<String, dynamic>.from(c.map);

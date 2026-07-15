/// Coercition **défensive et TOTALE** du contenu d'une note vers des **ops Delta
/// neutres** (`List<Map<String, dynamic>>`) — ES-2.2, **D5**.
///
/// ## 🔴 Pourquoi cette fonction existe : le repli « naturel » est DESTRUCTEUR
///
/// `zcrud_markdown` porte déjà une coercition d'ops (`DeltaNeutralOps.asDeltaOps`,
/// **privée**) : une `String` non-JSON y retombe sur **`null`**, donc sur **`[]`**
/// (`decodeDefensiveOps`). C'est **correct dans une tranche de formulaire** — il
/// n'y a pas de corpus legacy derrière une tranche. C'est **CATASTROPHIQUE dans
/// une entité adossée à un store** :
///
/// - lex persiste `content` en **`String` MARKDOWN** (`smart_note.dart` :
///   *« Contenu (markdown) »*, `final String content;`) ;
/// - IFFD persiste `content` en `String?` qui est **tantôt du Delta JSON, tantôt
///   du markdown** ;
/// - ⇒ transposer le repli `[]` ferait décoder **le vide** sur toute note
///   markdown, et le **premier `put` persisterait ce vide** : **perte
///   IRRÉVERSIBLE du corps de la note**, sans erreur ni test rouge.
///
/// ⇒ [normalizeNoteContentOps] est **TOTALE** et **PRÉSERVANTE** : *« si ce n'est
/// pas du Delta, c'est du TEXTE »*. Une `String` non-Delta non vide devient
/// **`[{'insert': '<raw>\n'}]`** — le texte **survit VERBATIM**. Jamais `[]`.
///
/// ## 🔴 DEUX politiques, DEUX fonctions (remédiation **HIGH-1**, code-review
/// ES-2.2)
///
/// La v1 n'avait **qu'une** validation de `List`, **tout-ou-rien**, partagée par
/// les deux branches. Conséquence **MESURÉE** :
/// `normalizeNoteContentOps([{'insert': '<5000 mots>'}, {'retain': 1}])` rendait
/// **`[]`** — **PERTE TOTALE du corps** à cause d'**une seule** op parasite, alors
/// que le **même** contenu présenté en `String` était **intégralement préservé**.
/// L'asymétrie prouvait le bug : la prémisse écrite (« une liste n'est pas du
/// texte, il n'y a rien à préserver ») **ne tient que pour `[1, 2]`** ; elle est
/// **fausse** dès que la liste porte des `insert` valides.
///
/// ⇒ Les deux besoins sont **opposés** et ont désormais chacun leur fonction :
///
/// | Fonction | Rôle | Politique |
/// |---|---|---|
/// | [_deltaOpsStrict] | **DÉCIDER** si une `String` décodée **EST** du Delta | **TOUT-OU-RIEN** — légitime : `'[1,2]'` **n'est pas** du Delta, c'est du **texte**, et il doit survivre **verbatim**. Une tolérance ici rendrait `'[1,2]'` « Delta vide » ⇒ **le texte serait détruit**. |
/// | [_coerceOpsPreserving] | **SAUVER** ce qu'une `List` **native** porte | **PRÉSERVANTE** — une op invalide est **écartée** ; **tout `insert` valide SURVIT**. `[]` **uniquement** si la liste ne porte **aucun** contenu (`[1, 2]`, `[{retain: 1}]`). |
///
/// ## ⚠️ Ce n'est **PAS** une heuristique (AD-28), ni un `ZCodec`
///
/// - **Aucune devinette markdown-vs-Delta pour DÉCIDER D'UN RENDU** : la fonction
///   ne choisit pas un format d'affichage, elle **coerce une valeur persistée vers
///   la forme canonique du champ** — exactement comme `_$asInt` ou
///   `ZDocumentLearningInfo.fromJsonSafe` le font pour les leurs. **Aucune classe
///   `implements ZCodec` n'est créée** (AD-28 respecté).
/// - La détection Delta est **STRUCTURELLE** (`jsonDecode` + forme `List<Map>`
///   portant `insert`), **JAMAIS TEXTUELLE**. ⛔ Il n'y a **aucun**
///   `startsWith('[')` ni `contains('"insert"')` dans ce package — c'est
///   **littéralement** le code d'IFFD (répété **verbatim en 4 sites** :
///   `rich_text_editor_screen.dart` l. 206 et 607, `delta_to_markdown_helper.dart`
///   l. 39, `editors/markdown_edition_field.dart` l. 68) que zcrud **refuse**
///   (R5).
///
/// ## Idempotence (exigée, testée sur CHAQUE ligne de la matrice)
///
/// `ZSmartNote.toMap()` réémet **toujours** la `List` native ⇒ après un premier
/// cycle, le fil ne porte plus que la forme canonique, et
/// `normalize(normalize(x)) == normalize(x)` pour **toute** entrée (toute op
/// produite est elle-même une op valide, `'\n'` final garanti).
///
/// ## Dette DW-ES22-1
///
/// Recouvrement (~20 lignes) avec `DeltaNeutralOps.asDeltaOps`
/// (`zcrud_markdown`, **privé**, Flutter/Quill, repli **destructeur**). Le
/// correctif de fond — hisser la primitive neutre dans `zcrud_core` — **écrirait
/// `zcrud_core`** et **casserait la parallélisation d'ES-2** : hors périmètre,
/// **à statuer en ES-6.1**.
///
/// 🔴 **Ce n'est PAS une simple duplication : les deux fonctions DIVERGENT, et en
/// SENS OPPOSÉ SUR LA DONNÉE** (`asDeltaOps('# T') ⇒ []` **détruit** ·
/// `normalizeNoteContentOps('# T') ⇒ [{insert: '# T\n'}]` **préserve**). En
/// **ES-6.1**, `note.content` traversera `ZMarkdownField → asDeltaOps` : un
/// aller-retour **domaine → éditeur → domaine** peut donc **EFFACER ce que le
/// domaine avait sauvé**. La divergence est **ÉPINGLÉE EN MACHINE**
/// (`test/source_policy_test.dart` › groupe `DW-ES22-1`) et **DOIT être
/// réconciliée AVANT ES-6.1**.
library;

import 'dart:convert';

// ⚠️ `domain.dart`, JAMAIS `zcrud_core.dart` (AD-14) : le barrel COMPLET du cœur
// ré-exporte la couche PRÉSENTATION (Flutter). `zcrud_note` est un package
// **PUR-DART** (`dart test`) et il est couvert par `gate:web` (default-ON) : le
// barrel complet le ferait basculer sur Flutter ⇒ `dart test -p node` ROUGE.
// (Mesuré pendant ES-2.2b : import du barrel complet ⇒ « [gate:web] ÉCHEC : la
// suite de zcrud_note ne passe pas en JS ».)
import 'package:zcrud_core/domain.dart';

/// Le contenu vide canonique (`const`, partagé, **non modifiable**).
const List<Map<String, dynamic>> kEmptyNoteContent = <Map<String, dynamic>>[];

/// Coerce [raw] (valeur **persistée**, de type quelconque) en **ops Delta
/// neutres** — **totale**, **déterministe**, **ne throw JAMAIS** (AD-10).
///
/// | Entrée persistée | Résultat |
/// |---|---|
/// | absente / `null` | `[]` |
/// | `List` d'ops valides (chaque élément = `Map` portant `insert`) | **ops verbatim** (clés coercées en `String`) — embeds opaques (LaTeX/tables) **préservés** |
/// | 🔴 `List` **PARTIELLEMENT** valide (`[{insert: …}, {retain: 1}]`, `[{insert: …}, null]`) | 🔴 **les ops portant `insert` SURVIVENT** ; l'élément parasite est **écarté**. **JAMAIS `[]`** (HIGH-1) |
/// | `List` portant une `String` (fragment texte) | l'élément devient `{'insert': '<txt>\n'}` — **le texte SURVIT** |
/// | `String` qui **parse** en JSON `List` d'ops **TOUTES** valides | ops décodées (compat `ZDeltaCodec.encode` / corpus Delta IFFD) |
/// | `String` **non-Delta** non vide (markdown lex, sticky-note IFFD, texte plat, `'[1,2]'`, `'{}'`) | 🔴 **`[{'insert': '<raw>\n'}]` — le texte SURVIT VERBATIM** |
/// | `String` vide / blanche | `[]` |
/// | `List` **sans aucun contenu** (`[]`, `[1, 2]`, `[{retain: 1}]`) | `[]` — il n'y a **rien** à préserver (aucun `insert`, aucun texte) |
/// | `int`, `bool`, `Map` nue | `[]` (défensif : aucune interprétation possible) |
///
/// 🔴 **Invariant** : **aucune** entrée portant du **contenu** (un `insert`, ou du
/// texte) ne rend `[]`. C'est la règle **D5**, et elle vaut désormais sur **les
/// deux** branches (`String` **et** `List`) — la v1 ne la tenait que sur `String`
/// (**HIGH-1**).
///
/// Le résultat est **non modifiable** (cohérence de contrat : une note vide et une
/// note pleine ont le **même** contrat — **L1**).
List<Map<String, dynamic>> normalizeNoteContentOps(Object? raw) {
  if (raw == null) return kEmptyNoteContent;

  if (raw is List) {
    // 🔴 HIGH-1 — branche PRÉSERVANTE : on sauve TOUT ce qui est sauvable.
    // Une op parasite (`retain`/`delete`, `null`, scalaire) est ÉCARTÉE ; elle
    // n'emporte PLUS le corps de la note avec elle.
    return _freeze(_coerceOpsPreserving(raw));
  }

  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return kEmptyNoteContent;

    // Détection STRUCTURELLE du Delta : on tente le décodage JSON et on exige la
    // FORME (`List` d'ops portant `insert`). Aucun examen textuel du contenu.
    //
    // ⚠️ ICI la validation DOIT être STRICTE (tout-ou-rien) : elle ne « valide »
    // pas une donnée, elle DÉCIDE d'une NATURE (« ce JSON est-il un Delta ? »).
    // Une tolérance rendrait `'[1,2]'` « Delta (vide) » ⇒ le TEXTE `'[1,2]'`
    // serait DÉTRUIT. Le doute profite au TEXTE, jamais au vide.
    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      decoded = null; // Pas du JSON ⇒ c'est du texte (voir plus bas).
    }
    if (decoded is List) {
      // `null` ⇒ ce n'est PAS un Delta (donc du texte). Une liste vide (`'[]'`)
      // EST un Delta — vide : elle ne porte AUCUN contenu, rien n'est détruit.
      final ops = _deltaOpsStrict(decoded);
      if (ops != null) return _freeze(ops);
    }

    // 🔴 D5 — LE POINT LE PLUS IMPORTANT DU PACKAGE : ce n'est pas du Delta, donc
    // c'est du TEXTE. On le PRÉSERVE VERBATIM. Retomber sur `[]` ici (le repli de
    // `DeltaNeutralOps`) effacerait le corps de toute note markdown lex au premier
    // `put`. Le rendu RICHE du markdown (markdown → Delta formaté) reste le travail
    // EXPLICITE d'ES-6.2 — jamais une devinette faite ici.
    return _freeze(<Map<String, dynamic>>[_textOp(raw)]);
  }

  // `int`, `bool`, `Map`, … : aucune interprétation possible ⇒ défaut sûr.
  return kEmptyNoteContent;
}

/// Op `insert` **texte** portant [raw] verbatim, `'\n'` final garanti (jamais
/// doublé).
Map<String, dynamic> _textOp(String raw) => <String, dynamic>{
      'insert': raw.endsWith('\n') ? raw : '$raw\n',
    };

/// Gèle une liste d'ops (**L1** — même contrat pour une note vide et une note
/// pleine ; cohérent avec `_extraFrom`, qui rend une `Map.unmodifiable`).
///
/// 🔴 **DW-ES24-1 (ES-3.0)** : gel **PROFOND** (liste + chaque op + valeurs
/// imbriquées) via [zUnmodifiableJsonMapList] — et non plus seulement la liste
/// extérieure (`List.unmodifiable`, qui laissait les op maps mutables). Idempotent
/// ⇒ l'accesseur `ZSmartNote.content` le rend TEL QUEL (zéro-copie sur le chemin
/// chaud fromMap/copyWith — AC14).
List<Map<String, dynamic>> _freeze(List<Map<String, dynamic>> ops) =>
    ops.isEmpty ? kEmptyNoteContent : zUnmodifiableJsonMapList(ops);

/// 🔴 **STRICTE (tout-ou-rien)** — sert **UNIQUEMENT** à *décider* si une `String`
/// décodée en JSON **EST** un Delta. Rend `null` dès qu'**un seul** élément n'est
/// pas une op de document (`Map` portant `insert`).
///
/// ⚠️ **Ne JAMAIS l'utiliser sur la branche `List` native** : elle y détruirait
/// les ops valides d'une liste partiellement corrompue (**HIGH-1**). Sa rigueur
/// est ce qui protège le texte `'[1,2]'` : *« ce n'est pas un Delta ⇒ c'est du
/// texte ⇒ préserve-le »*.
List<Map<String, dynamic>>? _deltaOpsStrict(List<Object?> raw) {
  final ops = <Map<String, dynamic>>[];
  for (final op in raw) {
    if (op is! Map) return null;
    final map = _stringKeyed(op);
    if (!map.containsKey('insert')) return null;
    ops.add(map);
  }
  return ops;
}

/// 🔴 **PRÉSERVANTE** — sert à la branche **`List` NATIVE** (la valeur persistée
/// est **déjà** une liste : sa nature n'est pas en question, seul son **contenu**
/// l'est). « Sauve tout ce qui est sauvable » :
///
/// - `Map` portant `insert` ⇒ **CONSERVÉE VERBATIM** (embed opaque inclus) ;
/// - `String` non blanche ⇒ **coercée en op texte** (le texte SURVIT) ;
/// - `Map` **sans** `insert` (`retain`/`delete` — ops de **diff**, sans aucun sens
///   dans un document au repos), `null`, `int`, `bool`, `List` imbriquée ⇒
///   **ÉCARTÉE** (elle ne porte **aucun** contenu) ;
/// - `[]` **seulement** si **rien** n'était sauvable.
///
/// C'est la remédiation de **HIGH-1** : une **seule** op parasite ne peut plus
/// emporter **tout le corps de la note**.
List<Map<String, dynamic>> _coerceOpsPreserving(List<Object?> raw) {
  final ops = <Map<String, dynamic>>[];
  for (final op in raw) {
    if (op is Map) {
      final map = _stringKeyed(op);
      // 🔴 L'op parasite est ÉCARTÉE — elle n'emporte PLUS les ops voisines.
      if (map.containsKey('insert')) ops.add(map);
      continue;
    }
    if (op is String) {
      // Un fragment TEXTE dans la liste : D5 s'applique — on ne détruit pas du
      // texte. (Une `String` VIDE/blanche ne porte rien : écartée.)
      if (op.trim().isNotEmpty) ops.add(_textOp(op));
      continue;
    }
    // `null`, `int`, `bool`, `List`… : aucun contenu, rien à préserver.
  }
  return ops;
}

/// Clés coercées en `String` (`Map<dynamic, dynamic>` relue de Hive/JSON).
///
/// 🔵 **L3** : le `try/catch` qui enveloppait cette boucle était **MORT**
/// (l'interpolation `'${e.key}'` d'un `Object?` ne peut pas lever) — bruit
/// défensif suggérant une protection inexistante (**R6** : aucun filet
/// décoratif).
Map<String, dynamic> _stringKeyed(Map<Object?, Object?> op) =>
    <String, dynamic>{for (final e in op.entries) '${e.key}': e.value};

/// Égalité **profonde** de deux contenus de note (les ops portent des valeurs
/// imbriquées : attributs, embeds opaques `{'formula': …}`).
///
/// `==` de `Map`/`List` est une égalité d'**identité** en Dart : sans cette
/// fonction, deux notes au contenu identique mais décodées séparément seraient
/// **différentes**, et l'`==` entre une note en mémoire et la même relue du store
/// **casserait**.
bool noteContentEquals(
  List<Map<String, dynamic>> a,
  List<Map<String, dynamic>> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!noteJsonEquals(a[i], b[i])) return false;
  }
  return true;
}

/// Hash **profond** cohérent avec [noteContentEquals] (ordre des ops signifiant ;
/// ordre des clés d'une op **non** signifiant).
int noteContentHash(List<Map<String, dynamic>> ops) {
  var h = 0;
  for (final op in ops) {
    h = Object.hash(h, noteJsonHash(op));
  }
  return h;
}

/// Égalité **PROFONDE** de deux valeurs JSON quelconques (`Map`/`List`/scalaire).
///
/// 🟡 **MEDIUM-1 (code-review ES-2.2)** — l'argument écrit pour [noteContentEquals]
/// (« sans profondeur, l'`==` entre une note en mémoire et la même relue du store
/// casse ») **s'applique MOT POUR MOT à `extra`**, dont la raison d'être (AD-4
/// pt.2) est de porter du **JSON ARBITRAIRE, donc IMBRIQUÉ** (maps/listes legacy
/// IFFD). Il n'y avait **pas** été appliqué : `_mapEquals` était **superficiel** ⇒
/// **MESURÉ** : deux décodages du **même** document portant `"legacy_meta":{"a":1}`
/// donnaient `a == b ⇒ false` et `Set{a, b}.length ⇒ 2`. Toute déduplication, tout
/// cache mémoïsé, tout `expect(relu, original)` était **cassé**.
///
/// ⚠️ **Le défaut était SYSTÉMIQUE** : le même `_mapEquals`/`_mapHash`
/// **superficiel** était copié dans `zcrud_document`, `zcrud_flashcard` et
/// `zcrud_study_kernel` ⇒ dette **DW-ES22-4**, **SOLDÉE par ES-2.2b**.
///
/// ## 🔴 ES-2.2b — cette fonction est désormais un **ALIAS DÉLÉGANT**
///
/// L'implémentation **UNIQUE** du repo est [zJsonEquals] (`zcrud_core`). Les six
/// entités des trois autres satellites **ne pouvaient pas** réutiliser celle-ci :
/// `zcrud_study_kernel → zcrud_note` serait une **arête entre satellites**
/// ⇒ **violation AD-1**. La primitive a donc été **hissée dans le cœur**.
///
/// ⚠️ **`noteJsonEquals`/`noteJsonHash` sont EXPORTÉES** (`zcrud_note.dart`) : elles
/// sont **CONSERVÉES**, jamais supprimées — une suppression de surface publique
/// casserait un consommateur en dépendance git **sans** que `melos analyze` du
/// repo ne le voie (leçon **`ZExportApi`**, E11a-3).
bool noteJsonEquals(Object? a, Object? b) => zJsonEquals(a, b);

/// Hash **profond** cohérent avec [noteJsonEquals].
///
/// 🔴 **ES-2.2b — ALIAS DÉLÉGANT** de [zJsonHash] (`zcrud_core`) : implémentation
/// unique du repo. Conservée pour la **rétro-compatibilité** de la surface
/// publique de `zcrud_note` (cf. [noteJsonEquals]).
int noteJsonHash(Object? v) => zJsonHash(v);

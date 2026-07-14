---
baseline_commit: 709406ddf1ea40c15c4f638ff9a84fcab1dcc789
---

# Story ES-2.2b : [TÊTE BLOQUANTE] Gardes systémiques du slot `extra` — `copyWith` rouvre le filtre réservé (DW-ES22-3) + égalité superficielle (DW-ES22-4)

Status: review

- **Clé sprint-status** : `es-2-2b-gardes-extra-systemiques`
- **Epic** : ES-2 (Domaine canonique éducatif + codegen)
- **Taille** : **L** (5 packages de code + harnais ; **aucun** changement de signature publique du registre)
- **Parallélisation** : ⛔ **AUCUNE — SÉQUENTIELLE STRICTE.** Cette story écrit `zcrud_core`, `zcrud_study_kernel`, `zcrud_document`, `zcrud_flashcard`, `zcrud_mindmap`, `zcrud_note` **et** `tool/reserved_keys_gate/`. **Aucune autre story ES-2 ne doit tourner en même temps** (garde-fou n°2 de CLAUDE.md : le seul point de contact tolérable est `zcrud_core`, et c'est précisément ce que cette story ouvre).
- **Couvre** : **DW-ES22-3**, **DW-ES22-4** · AD-4 (pts 1/2), AD-9, AD-10, AD-16, AD-19 (+19.1/.c), AD-1 · **R1**, **R2**, **R3**, **R5**, **R6**, **R8** (rétro ES-1).
- **Dépend de** : ES-2.0 (`done`), ES-2.1 (`done`), ES-2.2 (`done` — **c'est le modèle de la parade**).
- **Bloque** : **ES-2.3 → ES-2.8** (les 6 entités restantes reproduiraient le défaut) **et** ES-3.x (tout câblage de store).

---

## Story

**As a** développeur zcrud livrant les 6 entités restantes de l'epic ES-2,
**I want** que le dépouillement des clés réservées et l'égalité profonde du slot `extra` soient **tenus PAR UNE MACHINE générique** — et non par la vigilance de chaque story —,
**so that** aucune entité (livrée **ou future**) ne puisse ré-émettre `updated_at`/`is_deleted` depuis son corps (ce qui **fausse le merge LWW**, AD-9/AD-16/AD-19), ni se dédoubler dans un `Set` parce que son `extra` porte du JSON imbriqué (**la raison d'être même d'`extra`**, AD-4).

---

## 🔴 Ce qui est CASSÉ — MESURÉ EN MACHINE sur l'arbre réel (2026-07-14)

> **Ce ne sont pas des hypothèses.** Sonde exécutée dans `tool/reserved_keys_gate/` (`flutter test`, accès aux 6 packages), sur les entités **telles qu'elles sont livrées**. Sortie brute reproduite ci-dessous. Reproduire la mesure est la **première tâche** du dev (T0).

### DW-ES22-3 — la voie d'écriture applicative ROUVRE le filtre des clés réservées

Sonde : injecter `{updated_at: '1999-01-01…', is_deleted: true, zz_temoin: 'copie-ok'}` dans `extra` **par la voie d'écriture publique**, puis appeler `toMap()`/`toJson()`.

| Entité | Voie d'écriture exercée | `updated_at` réémis | `is_deleted` réémis | Verdict |
|---|---|---|---|---|
| `ZStudyFolder` | `copyWith(extra:)` | ✅ oui *(val=`null` — le champ métier écrase)* | 🔴 **oui (`true`)** | ⛔ **CASSÉ** |
| `ZStudySessionConfig` | `copyWith(extra:)` | 🔴 **oui (`1999-01-01…`)** | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZFlashcard` | `copyWith(extra:)` | ✅ oui *(val=`null`)* | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZStudyDocument` | `copyWith(extra:)` | 🔴 **oui (`1999-01-01…`)** | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZDocumentReadingState` | `copyWith(extra:)` | 🔴 **oui (`1999-01-01…`)** | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZRepetitionInfo` | 🔴 **constructeur nominal** *(aucun `copyWith`)* | 🔴 **oui** | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZMindmap` | 🔴 **constructeur nominal** *(aucun `copyWith`)* | 🔴 **oui** | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZMindmapNode` | 🔴 **constructeur nominal** *(aucun `copyWith`)* | 🔴 **oui** | 🔴 **oui** | ⛔ **CASSÉ** |
| `ZSmartNote` | `copyWith(extra:)` | ✅ **non** | ✅ **non** | ✅ **LE MODÈLE** (ES-2.2) |

**8 entités cassées sur 9.** Le témoin `zz_temoin` ressort à `copie-ok` **partout** ⇒ la voie exercée est bien réelle (anti-vacuité de la mesure).

> ### 🔴 PRESCRIPTION DU BRIEF **INVALIDÉE** (R4) — ce n'est PAS « `copyWith` », c'est **la voie d'écriture publique**
>
> Le brief nomme la dette « `copyWith(extra:)` rouvre le filtre ». **Trois des huit entités cassées n'ont AUCUN `copyWith`** (`ZRepetitionInfo` — seulement `withFolder(String)` ; `ZMindmap`/`ZMindmapNode` — *« aucun `copyWith` public, la mutation passe EXCLUSIVEMENT par TreeOps »*, dartdoc `z_mindmap_node.dart:6`). Chez elles, la voie fautive est le **CONSTRUCTEUR NOMINAL public**, qui accepte un `extra` arbitraire.
> ⇒ Une parade câblée sur « le `copyWith` » **manquerait 3 entités sur 8**, et le mécanisme du gate ne peut pas s'appeler `kExtraCopiers` : il doit couvrir **toute voie d'écriture publique de `extra`** (cf. **D2**).
> ⇒ Corollaire déjà énoncé par ES-2.2, ici **généralisé et confirmé par la mesure** : **c'est `toMap()`/`toJson()` — la frontière de SORTIE — qui rend la promesse INCONDITIONNELLE.** Le constructeur `const` de `ZRepetitionInfo` **ne peut structurellement rien filtrer** (et AD-10 **interdit** d'y mettre un `assert`).

**Pourquoi c'est destructif** (AD-19.2 pt.1) : le store écrit `ZSyncMeta` **APRÈS** le corps à chaque `put`. Un `is_deleted`/`updated_at` **métier** logé dans le corps entre donc en collision avec l'autorité de sync ⇒ **le merge LWW est faussé, silencieusement, sans un seul test rouge** (AD-9/AD-16).

**⚠️ Le gate actuel NE L'ATTRAPE PAS** : ses 6 assertions (a)…(f) sondent **`fromMap` / `registry.decode`** — **jamais** une voie d'écriture applicative. C'est un **angle mort structurel**, pas un oubli ponctuel.

### DW-ES22-4 — égalité/hash SUPERFICIELS sur `extra`

Sonde : décoder **deux fois** le **même** payload (via deux `jsonDecode(jsonEncode(…))` **indépendants** — cf. **D5**, piège critique), avec un `extra` portant du JSON **imbriqué** (`{'a':1,'l':[1,{'b':2}]}`).

| Kind | `extra` **scalaire** | `extra` **IMBRIQUÉ** |
|---|---|---|
| `study_folder` | ✅ `a==b` | 🔴 **`false`** · hash ≠ · `Set{a,b}.length == 2` |
| `study_session_config` | ✅ | 🔴 **`false`** |
| `flashcard` | ✅ | 🔴 **`false`** |
| `repetition_info` | ✅ | 🔴 **`false`** |
| `study_document` | ✅ | 🔴 **`false`** |
| `document_reading_state` | ✅ | 🔴 **`false`** |
| `smart_note` | ✅ | ✅ **`true`** — **LE MODÈLE** (ES-2.2) |
| `flashcard_choice` / `document_viewer_prefs` | ✅ | ✅ *(non-`ZExtensible` : aucun `extra`)* |
| **`ZMindmap` / `ZMindmapNode`** | 🔴 **`false` MÊME EN SCALAIRE** | 🔴 `false` — **AUCUN `operator ==`** (égalité d'**identité**) — cf. **D6** |

**6 entités cassées** par l'égalité superficielle + **2 entités sans aucune égalité de valeur**.

> **La colonne « scalaire » est la preuve du « vert pour une mauvaise raison »** : les sondes des tests existants n'utilisent **que des scalaires** (`'zz_cle_inconnue': 'gardee'`). Le filet a une **existence**, aucun **pouvoir discriminant**. Or porter du JSON imbriqué **est la raison d'être d'`extra`** (AD-4 pt.2 : maps/listes legacy IFFD, documents Firestore).

**Mesure de contrôle (écarte deux faux coupables)** : les canaux hors-codegen `ZFlashcard.source` (payload `Map`) et `ZDocumentReadingState.learning` (`quality_by_page` imbriqué) ont **DÉJÀ** une égalité profonde (`a == b ⇒ true` avec `extra` vide). ⇒ **Le seul fautif est `extra`**, et l'assertion (i.2) ne produira **aucun faux rouge** par ces canaux.

---

## 📋 INVENTAIRE RÉEL (mesuré sur disque, `grep` AST + exécution — ne pas se fier à la liste du brief)

**9 entités `ZExtensible`** dans le repo (le brief en supposait ~7 et **omettait `zcrud_mindmap`**) :

| # | Entité | Package | Kind (registre) | `copyWith(extra:)` | `==` de valeur | (i.1) | (i.2) |
|---|---|---|---|---|---|---|---|
| 1 | `ZStudyFolder` | `zcrud_study_kernel` | `study_folder` | ✅ | superficiel | 🔧 | 🔧 |
| 2 | `ZStudySessionConfig` | `zcrud_study_kernel` | `study_session_config` | ✅ | superficiel | 🔧 | 🔧 |
| 3 | `ZFlashcard` | `zcrud_flashcard` | `flashcard` | ✅ | superficiel | 🔧 | 🔧 |
| 4 | `ZRepetitionInfo` | `zcrud_flashcard` | `repetition_info` | ⛔ **aucun** | superficiel | 🔧 *(ctor)* | 🔧 |
| 5 | `ZStudyDocument` | `zcrud_document` | `study_document` | ✅ | superficiel | 🔧 | 🔧 |
| 6 | `ZDocumentReadingState` | `zcrud_document` | `document_reading_state` | ✅ | superficiel | 🔧 | 🔧 |
| 7 | `ZSmartNote` | `zcrud_note` | `smart_note` | ✅ | **profond** ✅ | ✅ déjà OK | ✅ déjà OK |
| 8 | `ZMindmap` | `zcrud_mindmap` | *(hors registre — sonde manuelle)* | ⛔ **aucun** | ⛔ **AUCUN `==`** | 🔧 *(ctor)* | ⏭️ **D6** |
| 9 | `ZMindmapNode` | `zcrud_mindmap` | *(hors registre — sonde manuelle)* | ⛔ **aucun** | ⛔ **AUCUN `==`** | 🔧 *(ctor)* | ⏭️ **D6** |

**NON-`ZExtensible` (aucun `extra` ⇒ hors périmètre, skip DÉCLARÉ)** : `ZChoice` (`flashcard_choice`), `ZDocumentViewerPrefs` (`document_viewer_prefs`) — déjà listés dans `kNonExtensibleKinds`.

**Duplication mesurée** : `_mapEquals`/`_mapHash` **superficiels** sont copiés **à l'identique dans 6 fichiers** (`z_study_folder.dart`, `z_study_session_config.dart`, `z_flashcard.dart`, `z_repetition_info.dart`, `z_study_document.dart`, `z_document_reading_state.dart`) — 3 packages.

---

## Décisions (D1..D9) — chacune CONFRONTÉE AU CODE RÉEL

### D1 — La parade : **une garde nommée UNIQUE, appelée aux frontières d'ENTRÉE *et* de SORTIE**

Patron **déjà prouvé** par `ZSmartNote` (ES-2.2, remédiation MAJEUR-3) — le reproduire, ne pas l'inventer :

```dart
// packages/zcrud_note/lib/src/domain/z_smart_note.dart:435
static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
    Map<String, dynamic>.unmodifiable(<String, dynamic>{
      for (final e in raw.entries)
        if (!_reservedKeys.contains(e.key)) e.key: e.value,
    });
```

appelée par **`fromMap`** (l. 164, via `_extraFrom`) **ET `copyWith`** (l. 356-358) **ET `toMap`** (l. 297).

- **Entités AVEC `copyWith(extra:)`** (1,2,3,5,6) ⇒ **3 sites** : `fromMap` + `copyWith` + `toMap`.
- **Entités SANS `copyWith`** (4,8,9) ⇒ **`fromMap` + `toMap`/`toJson`**. Le constructeur **ne peut pas** filtrer : `ZRepetitionInfo` est `const` (⇒ aucun appel de fonction possible), et **AD-10 INTERDIT** d'y mettre un `assert` (le décodeur généré appelle le constructeur avec des valeurs **BRUTES** : un `assert` ferait **throw la désérialisation d'une donnée corrompue**).
  - 🟡 *Nuance vérifiée* : `ZMindmap`/`ZMindmapNode` ont un constructeur **non-`const`** avec initializer (`extra = Map.unmodifiable(extra)`) ⇒ ils **peuvent** filtrer là (`extra = Map.unmodifiable(_sanitize(extra))`). **Faire les deux** (initializer **et** `toJson`) — mais `toJson` reste le filet **inconditionnel** qui porte la promesse.

⛔ **`toMap()` est NON NÉGOCIABLE dans la liste des sites** : c'est la seule frontière que **toutes** les voies d'écriture traversent.

### D2 — Le mécanisme du gate : `kExtraWriters`, **pas** `kExtraCopiers` (faisabilité PROUVÉE)

`copyWith` **n'a pas de signature uniforme** et **n'existe pas partout** (mesuré : 3 entités sur 9 n'en ont pas). Le harnais ne peut donc pas l'appeler génériquement. **Point d'entrée commun retenu** — une table `kind → voie d'écriture`, sur le patron **exact** de `kRegistrars` (tear-offs de fonctions top-level dans une `const Map`, forme **déjà employée et compilée** dans `registrars.dart:41`) :

```dart
// tool/reserved_keys_gate/lib/src/registrars.dart

/// Voie d'écriture PUBLIQUE de `extra` : `copyWith(extra:)` si l'entité en offre
/// une, SINON le CONSTRUCTEUR NOMINAL (mesuré : `ZRepetitionInfo`, `ZMindmap`,
/// `ZMindmapNode` n'ont AUCUN `copyWith`).
typedef ZExtraWriter = Object Function(Object entity, Map<String, dynamic> extra);

const Map<String, ZExtraWriter> kExtraWriters = <String, ZExtraWriter>{
  'study_folder': _writeStudyFolderExtra,
  'study_session_config': _writeStudySessionConfigExtra,
  'flashcard': _writeFlashcardExtra,
  'repetition_info': _writeRepetitionInfoExtra,   // ← CONSTRUCTEUR
  'study_document': _writeStudyDocumentExtra,
  'document_reading_state': _writeDocumentReadingStateExtra,
  'smart_note': _writeSmartNoteExtra,
};

Object _writeStudyFolderExtra(Object e, Map<String, dynamic> x) =>
    (e as ZStudyFolder).copyWith(extra: x);

// Aucun `copyWith` ⇒ reconstruction nominale (la voie que l'app EMPRUNTE).
Object _writeRepetitionInfoExtra(Object e, Map<String, dynamic> x) {
  final r = e as ZRepetitionInfo;
  return ZRepetitionInfo(
    flashcardId: r.flashcardId, folderId: r.folderId, interval: r.interval,
    repetitions: r.repetitions, easeFactor: r.easeFactor,
    nextReviewDate: r.nextReviewDate, learnedAt: r.learnedAt,
    lastQuality: r.lastQuality, extension: r.extension, extra: x,
  );
}
```

**Sondes manuelles** (`ZMindmap`/`ZMindmapNode`) : ajouter un champ `write` à `ZManualProbe` (à côté de `decode`/`encode`) — même contrat.

> **Coût réel : 1 ligne par entité** (le writer), pas « zéro ». **Le brief se trompe sur ce point, et c'est structurel** : sans point d'entrée uniforme dans le domaine, une closure par kind est **inévitable**. **Alternative évaluée et REJETÉE** : faire émettre le writer par `zcrud_generator` dans le registrar (`registry.register<T>(…, withExtra: …)`) ⇒ **(a)** écrit la **signature publique** de `ZcrudRegistry` (`zcrud_core`) + le générateur + les 9 `.g.dart` ; **(b)** ne compile pas — le générateur ne peut pas savoir qu'une entité a un `copyWith` (**`ZRepetitionInfo` n'en a pas**) ; **(c)** collisionne frontalement avec DW-ES14-2, qui ouvre **la même** signature (cf. **D8**).
>
> ✅ **En revanche (i.2) EST à zéro code par entité** : elle ne consomme que `registry.decode` + `==`/`hashCode`.

### D3 — La MACHINE (R1) : couverture **bidirectionnelle** de `kExtraWriters` ⇒ toute entité ES-2 future est couverte **le jour de sa naissance**

Patron **existant, éprouvé** (`reserved_keys_test.dart:119-135`, « chaque kind enregistré a un corps de sonde ») :
- kind `ZExtensible` enregistré **sans** writer ⇒ **ROUGE** (trou de couverture) ;
- writer **orphelin** (kind disparu) ⇒ **ROUGE** (entrée morte, anti-inertie).

Le gate confronte déjà `R_disk \ R_wired` et `E_disk \ E_covered` (AST). ⇒ **Une entité ES-2.3…ES-2.8 ne peut pas naître sans son writer**, donc **ne peut pas échapper à (i.1)/(i.2)**. C'est le **critère de clôture R1** de cette story : la parade devient une **machine**, pas une discipline.

### D4 — (i.1) : ce qu'on assERTE exactement (et pourquoi `is_deleted` est le discriminant)

```dart
void assertExtraWriteSanitized({
  required String label,
  required Object entity,
  required ZExtraWriter write,
  required Map<String, dynamic> Function(Object) encode,
  required bool legacyMirrorAllowed,
}) {
  final written = write(entity, <String, dynamic>{
    ZSyncMeta.kUpdatedAt: kWritePollutionUpdatedAt,   // '1999-01-01T00:00:00.000Z'
    ZSyncMeta.kIsDeleted: true,
    kExtraWriteWitnessKey: kExtraWriteWitnessValue,   // 'zz_temoin_ecriture'
  });
  final encoded = encode(written);

  // 🔴 ANTI-VACUITÉ (non négociable) : un writer MENTEUR (`(e, x) => e`) rendrait
  // (i.1) trivialement VERTE. Le témoin PROUVE que la voie a pris le nouvel `extra`.
  expect(encoded[kExtraWriteWitnessKey], kExtraWriteWitnessValue, reason: …);

  // (i.1a) `is_deleted` — JAMAIS réémis, AUCUNE exception (patron (c)).
  expect(encoded.containsKey(ZSyncMeta.kIsDeleted), isFalse, reason: …);

  // (i.1b) `updated_at` — hors allowlist : absent. Sous allowlist (`study_folder`,
  //        `flashcard`) : présent, mais sa valeur vient du CHAMP MÉTIER, JAMAIS de
  //        la pollution d'`extra` (sinon le corps écraserait l'autorité LWW).
  if (legacyMirrorAllowed) {
    expect(encoded[ZSyncMeta.kUpdatedAt], isNot(kWritePollutionUpdatedAt), reason: …);
  } else {
    expect(encoded.containsKey(ZSyncMeta.kUpdatedAt), isFalse, reason: …);
  }
}
```

⚠️ **Subtilité MESURÉE, à ne pas rater** : sur `study_folder` et `flashcard`, `toMap()` étale `{...extra, ...généré}` ⇒ **le champ métier `updatedAt` écrase la pollution** (mesuré : `val=null`). Une (i.1) qui ne regarderait **que** `updated_at` serait donc **VERTE sur ces deux entités alors qu'elles sont CASSÉES**. C'est **`is_deleted`** (qu'aucun champ n'écrase) qui les fait rougir. ⇒ **Les deux clés doivent être assertées**, et l'allowlist (d) doit discriminer **sur la VALEUR**.

### D5 — (i.2) : le piège de l'`identical` (la mesure serait FAUSSE sans lui)

Deux décodages doivent partir de **deux `Map` INDÉPENDANTES**. Si les deux `decode` reçoivent **la même instance** de sous-`Map`, `identical(a, b)` rend l'égalité **superficielle VERTE** — le filet serait **vert pour une mauvaise raison**, exactement le motif que la story combat.

```dart
Map<String, dynamic> _deep(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;   // ← deep copy OBLIGATOIRE

final a = registry.decode(kind, _deep(probe));
final b = registry.decode(kind, _deep(probe));
expect(a, equals(b));  expect(a.hashCode, b.hashCode);  expect(<Object>{a, b}, hasLength(1));
```

⚠️ **Un littéral `const` ne convient PAS** (canonicalisé ⇒ `identical` ⇒ faux vert).
⚠️ **La sonde d'(i.2) DOIT porter une `Map` ET une `List` imbriquées** (`{'a':1,'l':[1,{'b':2}]}`) — mesuré : avec un **scalaire**, **les 9 kinds sont VERTS**. **Anti-vacuité** : asserter que le témoin imbriqué est bien **arrivé dans `extra`** (`expect(a.extra[kProbeNestedKey], isA<Map>())`), sinon (i.2) serait verte sur une entité qui **jette** `extra`.

### D6 — `ZMindmap`/`ZMindmapNode` : (i.1) **OUI**, (i.2) **SKIP DÉCLARÉ ET CONTRÔLÉ** + dette

Mesuré : ces deux entités n'ont **AUCUN `operator ==`** (égalité d'**identité** — `false` même sur un `extra` **scalaire**). Ce n'est **pas** le défaut DW-ES22-4 (« égalité *superficielle* sur `extra` ») : c'est **l'absence totale d'égalité de valeur**, un défaut **préexistant et plus large**, hors du périmètre nommé.

Leur donner un `==` profond exigerait une **égalité récursive sur l'arbre `children`** (`ZMindmapNode` est un arbre : coût O(n), garde-fou de cycle, changement sémantique pour un package à **110 tests**). ⇒ **Hors périmètre.**

- ✅ **(i.1) leur est APPLIQUÉE** (leur constructeur public accepte un `extra` pollué — **mesuré CASSÉ**).
- ⏭️ **(i.2) est SAUTÉE — mais le skip est DÉCLARÉ ET CONTRÔLÉ** (**R6**, patron de l'assertion (e) / de l'anti-inertie de (d)) : liste `kNoValueEqualityProbes = {'ZMindmap', 'ZMindmapNode'}`, et le test **ASSERTE que deux décodages sont bien `isNot(equals(…))`** ⇒ le jour où quelqu'un leur donne un `==` de valeur, **l'entrée devient MORTE et le test ROUGIT** en exigeant de la retirer de la liste. **Jamais silencieux.**
- 📌 **Dette à ouvrir : `DW-ES22-5`** — *« `ZMindmap`/`ZMindmapNode` n'ont aucune égalité de valeur (`Set` en garde deux, `expect(relu, original)` cassé) »*, à statuer en ES-10.x / rétro ES-2.

### D7 — Égalité profonde : **hisser dans `zcrud_core`**, ne pas recopier une 7ᵉ fois

Le modèle existe et est prouvé : `noteJsonEquals`/`noteJsonHash` (`packages/zcrud_note/lib/src/domain/z_note_content.dart:274-306`, récursifs `Map` **et** `List`, hash XOR insensible à l'ordre des clés).

**Les réutiliser depuis `zcrud_study_kernel`/`zcrud_document`/`zcrud_flashcard` créerait une arête entre satellites ⇒ VIOLATION AD-1.** ⇒ **Hisser dans `zcrud_core`** (pur-Dart, additif) :

- `zJsonEquals(Object? a, Object? b)` / `zJsonHash(Object? v)` — **implémentation UNIQUE** ;
- **rétro-compat `zcrud_note`** : `noteJsonEquals`/`noteJsonHash` sont **exportés publiquement** (`zcrud_note.dart:68`) ⇒ les **conserver comme alias délégants** (`=> zJsonEquals(a, b)`), **jamais** les supprimer (leçon `ZExportApi`, E11a-3) ;
- **supprimer les 6 copies** de `_mapEquals`/`_mapHash`.

🟡 **Optionnel, recommandé** : hisser aussi `zSanitizeExtra(Map raw, Set<String> reserved)` dans `zcrud_core` (une implémentation au lieu de 9). Chaque entité garde son `static _sanitizeExtra(raw) => zSanitizeExtra(raw, _reservedKeys);`.
⚠️ `ZMindmap`/`ZMindmapNode` n'ont pas de `_reservedKeys` mais `_knownKeys` + `_reservedSyncKeys` ⇒ leur ensemble réservé est `_knownKeys ∪ ZSyncMeta.reservedKeys`. **Adapter, ne pas forcer le patron.**

### D8 — 🔴 DW-ES14-2 : **SÉPARER** (recommandation TRANCHÉE, avec preuve de disque)

**Question posée** : cette story ouvrant `zcrud_core` de toute façon, faut-il **absorber** DW-ES14-2 (le registre n'offre aucun slot d'injection ⇒ `extension` non typée + `sourceRegistry` ignoré) ?

**Recommandation : NON — SÉPARER.** Quatre raisons, toutes vérifiées sur disque :

1. **Ce n'est pas le même `zcrud_core`.** ES-2.2b ajoute des **helpers purs additifs** (`zJsonEquals`/`zJsonHash`/`zSanitizeExtra` — fonctions top-level, zéro impact sur une signature existante). DW-ES14-2 réécrit la **signature publique de `ZcrudRegistry`** (`register` / `decode`, pour y injecter `extensionParser` **et** `sourceRegistry`). **Zéro collision réelle** entre les deux diffs. L'argument « une seule ouverture du cœur » **ne tient pas**.
2. **Rayon d'explosion sans commune mesure.** DW-ES14-2 touche : `zcrud_core` (signature `register`/`decode`) → **`zcrud_generator`** (émission des registrars) → **les 9 `.g.dart`** (régénérés + committés) → **`zcrud_firestore`** (`fromRegistry`) → **le harnais** (inversion de ~12 verrous : groupe `DW-ES14-2` ×7 kinds + groupe « H2 — canal `source` » ×3 + suppression de `kExtensionPayloadPreservers`) → **`zcrud_note`** (inversion du verrou local). **Taille estimée : L/XL.** Fusionner ⇒ **story XXL, revue diluée** — le risque exact que la rétro ES-1 dénonce.
3. **Les jalons diffèrent.** ES-2.2b est **TÊTE BLOQUANTE des 6 entités restantes d'ES-2** (ES-2.3…2.8 reproduiraient le défaut) ⇒ elle doit être livrée **VITE**. DW-ES14-2 est bloquante avant **ES-3.2/ES-3.5** (câblage du store) — **un jalon plus tardif**. Les fusionner **retarderait la tête bloquante d'ES-2 derrière une refonte du registre**.
4. **Sa clause d'échappement n°1 est bien FALSIFIÉE** (`ZNoteAudio` = 1er `ZExtension` concret) — mais **le geste qui neutralise le piège coûte 5 lignes de dartdoc, pas une refonte** (cf. **D9**).

⇒ **Ouvrir une story dédiée `ES-2.9` (ou `ES-3.0`), à ordonnancer AVANT ES-3.2/ES-3.5.** Cette story-ci **ne l'implémente pas**.

### D9 — Le **piège actif** de `firebase_z_repository_impl.dart` : neutralisé ICI (geste documentaire)

`packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:202-212` **autorise encore** le câblage d'un store :

> *« Si — et seulement si — les trois conditions tiennent : **1. l'entité n'utilise pas le slot `extension`**… »*

Cette clause est **FACTUELLEMENT FAUSSE depuis ES-2.2** (`ZNoteAudio` la falsifie) et **reste écrite comme vraie**. C'est un **piège actif** pour la prochaine story qui câble un store. ⇒ **Corriger la dartdoc ici** (la clause n°1 est **tombée** ; nommer `ZSmartNote`/`ZNoteAudio` ; renvoyer à la story qui solde DW-ES14-2). **Aucun code de `zcrud_firestore` n'est modifié** — dartdoc seule.

---

## Acceptance Criteria

### Correctif du domaine

- **AC1 — Garde `extra` partagée sur les 8 entités mesurées cassées.** Une **fonction nommée UNIQUE** par entité (`_sanitizeExtra`, patron `ZSmartNote`) dépouille **toutes** les clés réservées (champs du schéma + canaux hors-codegen + `extension` + `...ZSyncMeta.reservedKeys`) et est appelée par **`fromMap`**, **`copyWith` (si l'entité en a un)** **ET `toMap`/`toJson`**. Vérifié entité par entité sur l'inventaire (D1).
- **AC2 — ⛔ AUCUN `assert` ajouté à un constructeur (AD-10).** La désérialisation d'une donnée corrompue ne throw **jamais**. Les entités sans `copyWith` (`ZRepetitionInfo`, `ZMindmap`, `ZMindmapNode`) sont couvertes **par `toMap()`/`toJson()`**, frontière de SORTIE — c'est ce qui rend la promesse **inconditionnelle**.
- **AC3 — Égalité/hash PROFONDS sur `extra`** pour les 6 entités du registre : `zJsonEquals`/`zJsonHash` **hissés dans `zcrud_core`** (implémentation unique, récursive `Map` **et** `List`), consommés par `zcrud_study_kernel`, `zcrud_document`, `zcrud_flashcard` (+ `zcrud_note` en alias). **Les 6 copies de `_mapEquals`/`_mapHash` sont SUPPRIMÉES.**
- **AC4 — Rétro-compatibilité de la surface publique.** `noteJsonEquals`/`noteJsonHash` (exportés par `zcrud_note`) **restent disponibles** (alias délégants). **`ZFlashcard` est consommée par la migration DODLP** : sa surface publique n'est **ni réduite ni changée** (ajouts uniquement). La règle **(h)** (aucune extension générée exportée) reste tenue.

### La MACHINE (le vrai livrable — R1)

- **AC5 — `kExtraWriters` câblée** (`tool/reserved_keys_gate/lib/src/registrars.dart`) : `kind → voie d'écriture publique de `extra`` (`copyWith` **ou constructeur nominal** — D2), + champ `write` sur `ZManualProbe` pour `ZMindmap`/`ZMindmapNode`.
- **AC6 — Assertion (i.1) GÉNÉRIQUE** (`assertions.dart`), câblée **pour chaque kind `ZExtensible`** + les 2 sondes manuelles : après écriture d'un `extra` **pollué**, `toMap()`/`toJson()` **ne réémet NI `is_deleted` (aucune exception) NI `updated_at`** (hors allowlist ; **sous** allowlist : la valeur **ne vient jamais de la pollution** — D4).
- **AC7 — (i.1) est ANTI-VACUELLE** : un **témoin** non réservé, injecté dans l'`extra` écrit, **doit ressortir** de l'encodage — sans quoi un writer menteur (`(e, x) => e`) rendrait (i.1) trivialement verte.
- **AC8 — Assertion (i.2) GÉNÉRIQUE** : deux décodages **indépendants** (deep-copy — **D5**) du **même** payload portant un `extra` **IMBRIQUÉ** (`Map` **et** `List`) sont **`==`**, de **même `hashCode`**, et `Set{a,b}.length == 1`. **Anti-vacuité** : le témoin imbriqué est bien présent dans `extra`.
- **AC9 — Couverture BIDIRECTIONNELLE de `kExtraWriters` (R6, la machine de R1)** : tout kind `ZExtensible` enregistré **sans** writer ⇒ **ROUGE** ; tout writer **orphelin** ⇒ **ROUGE**. ⇒ **aucune entité ES-2.3…ES-2.8 ne peut naître sans être couverte par (i.1)/(i.2).**
- **AC10 — Skips DÉCLARÉS ET CONTRÔLÉS (R6)** : (i.1)/(i.2) ne s'appliquent **qu'aux `ZExtensible`** — le saut de `ZChoice`/`ZDocumentViewerPrefs` est **contrôlé contre le type RÉEL** (patron de l'assertion (e) : liste périmée ⇒ **ROUGE**). Le skip d'(i.2) sur `ZMindmap`/`ZMindmapNode` est **déclaré** (`kNoValueEqualityProbes`) **et anti-inertie** : si elles gagnent un `==` de valeur, le skip devient MORT ⇒ **ROUGE** (D6).
- **AC11 — Contre-exemples PERMANENTS, ISOLÉS PAR RÈGLE (R2)**, dans `reserved_keys_test.dart` (patron `_LyingEntity` / `_ExtraDroppingEntity` / `_ChannelLeakingEntity`) :
  - `_ExtraReopeningEntity` — **VERTE sur (a)(b)(c)(d)(e)(f)**, **SEULE (i.1)** peut la faire rougir (son `fromMap` filtre ; sa voie d'écriture **ne filtre pas**) ;
  - `_ShallowExtraEqualityEntity` — **VERTE sur (a)…(f) ET (i.1)**, **SEULE (i.2)** peut la faire rougir (`==` superficiel sur `extra`).
  *Si (i.1)/(i.2) ne mordent pas ici, elles ne mordent nulle part.*

### Preuves & non-régression

- **AC12 — R3 : injections de régression, rejouées par l'orchestrateur.** Pour **chaque** filet : casser la garde d'**UNE SEULE** entité ⇒ l'assertion **ROUGIT EN LA NOMMANT** ; restaurer à l'octet près ⇒ **VERT**. Minimum :
  1. retirer `_sanitizeExtra` du `copyWith` de **`ZStudyDocument`** ⇒ (i.1) rouge, **nommant `study_document`** ;
  2. retirer `_sanitizeExtra` du `toMap` de **`ZRepetitionInfo`** (entité **sans `copyWith`** — la voie constructeur) ⇒ (i.1) rouge ;
  3. remettre `_mapEquals` superficiel sur **`ZStudyFolder`** ⇒ (i.2) rouge, **nommant `study_folder`** ;
  4. retirer un writer de `kExtraWriters` ⇒ **AC9 rouge** (couverture).
  Sortie brute **collée** dans les Completion Notes.
- **AC13 — R5 : aucune regex sur du Dart.** Tout raisonnement sur des déclarations Dart passe par l'AST (`package:analyzer`). *(Cette story n'ajoute aucune règle au volet AST — cf. « Prescriptions invalidées ».)*
- **AC14 — `gate:web` (default-ON) reste VERT.** Les packages pur-Dart (`zcrud_study_kernel`, `zcrud_note`, `zcrud_annotations`…) sont couverts : **tout test important `dart:io` doit être `@TestOn('vm')`** ou porter une **raison écrite**. *(Ce rouge a surpris ES-2.2 — ne pas le rejouer.)* Les tests ajoutés ici (égalité, sanitize) **n'ont aucun besoin de `dart:io`**.
- **AC15 — Non-régression STRICTE, repo-wide (R9).** `melos run generate` RC=0 · **`melos run analyze` RC=0 REPO-WIDE** · **`melos run verify` RC=0 REPO-WIDE** · `graph_proof` **ACYCLIQUE / CORE OUT=0** · `melos list` = **17** · **`prove_gates` ≥ 41 OK / 0 FAIL** (**jamais** régresser).
  **Baselines de tests à ne pas régresser** : note **130** · document **129** · harnais **49** *(doit AUGMENTER)* · generator **102** (`dart test`) · flashcard **189** · kernel **108** · core **911** *(doit AUGMENTER : `zJsonEquals`/`zJsonHash`)* · firestore **90** · mindmap **110**.
- **AC16 — Dettes : escalade écrite.** (1) **DW-ES22-3 / DW-ES22-4** passent à **SOLDÉES** dans `architecture.md` § Deferred, avec le **critère de clôture** = les assertions (i.1)/(i.2) + la couverture bidirectionnelle. (2) **`DW-ES22-5` OUVERTE** (`ZMindmap`/`ZMindmapNode` sans égalité de valeur — D6). (3) **DW-ES14-2 : la clause d'échappement n°1 est corrigée dans la dartdoc de `FirebaseZRepositoryImpl.fromRegistry`** (`firebase_z_repository_impl.dart:202-212`) — elle **ne doit plus autoriser** le câblage d'un store sur une entité qui utilise `extension` (**D9**) — **et la recommandation de D8 (SÉPARER, story dédiée avant ES-3.2/3.5) est inscrite** dans le § Deferred.

---

## Tasks / Subtasks

- [x] **T0 — REPRODUIRE les deux dettes en machine** (avant tout correctif — R3/R4). Sonde jetable dans `tool/reserved_keys_gate/test/`, exécutée par `flutter test`. Coller la sortie brute. *(Les tableaux de mesure ci-dessus donnent le résultat attendu : 8 entités cassées en (i.1), 6+2 en (i.2).)*
- [x] **T1 — `zcrud_core`** (AC3) : `zJsonEquals` / `zJsonHash` (+ `zSanitizeExtra` optionnel) — purs, exportés par le barrel, **additifs** ; tests dédiés (`Map` imbriquée, `List` imbriquée, ordre des clés non signifiant, ordre de liste signifiant, cycles impossibles car JSON).
- [x] **T2 — `zcrud_note`** (AC4) : `noteJsonEquals`/`noteJsonHash` deviennent des **alias délégants** de `zJsonEquals`/`zJsonHash`. **Aucune suppression de surface publique.**
- [x] **T3 — `zcrud_study_kernel`** (AC1, AC3) : `ZStudyFolder`, `ZStudySessionConfig` — garde partagée (3 sites) + égalité profonde ; supprimer `_mapEquals`/`_mapHash`.
- [x] **T4 — `zcrud_document`** (AC1, AC3) : `ZStudyDocument`, `ZDocumentReadingState` — idem.
- [x] **T5 — `zcrud_flashcard`** (AC1, AC3, AC4) : `ZFlashcard` (garde 3 sites) + `ZRepetitionInfo` (**garde 2 sites — aucun `copyWith`, ctor `const` ⇒ `toMap()` porte la promesse**) ; égalité profonde ; **surface publique inchangée (DODLP)**.
- [x] **T6 — `zcrud_mindmap`** (AC1, AC2) : `ZMindmap`, `ZMindmapNode` — garde dans l'**initializer du ctor** (non-`const` ⇒ possible) **ET** dans `toJson()` (filet inconditionnel). ⛔ **NE PAS** leur ajouter d'`==` (**D6** ⇒ dette DW-ES22-5).
- [x] **T7 — Harnais : `kExtraWriters`** (AC5) + champ `write` sur `ZManualProbe`.
- [x] **T8 — Harnais : assertions (i.1) et (i.2)** (AC6, AC7, AC8, AC10) dans `assertions.dart`, câblées dans la boucle `for (final kind in kProbeBodies.keys)` **et** dans la boucle `kManualProbes`.
- [x] **T9 — Harnais : couverture bidirectionnelle** de `kExtraWriters` (AC9) + `kNoValueEqualityProbes` avec anti-inertie (AC10).
- [x] **T10 — Harnais : contre-exemples permanents isolés** `_ExtraReopeningEntity` / `_ShallowExtraEqualityEntity` (AC11) — **chacune verte sur TOUTES les autres règles** (le vérifier par un test explicite, patron `reserved_keys_test.dart:399` et `:499`).
- [x] **T11 — `zcrud_firestore`** (AC16.3) : **dartdoc seule** — clause d'échappement n°1 de DW-ES14-2 **corrigée** (elle est FALSIFIÉE par `ZNoteAudio`).
- [x] **T12 — `architecture.md`** (AC16) : DW-ES22-3/4 **SOLDÉES** (critère de clôture = (i.1)/(i.2) + couverture) · **DW-ES22-5 OUVERTE** · recommandation **D8** inscrite sous DW-ES14-2.
- [x] **T13 — R3 : les 4 injections de régression** (AC12), sorties brutes collées.
- [x] **T14 — Vérif verte repo-wide** (AC15) : `generate` → `analyze` → `verify` → `prove_gates` → baselines de tests. **Committer les `*.g.dart`** s'ils changent *(a priori : aucun — les annotations ne bougent pas)*.

---

## Dev Notes

### Fichiers à MODIFIER (état actuel lu et vérifié)

| Fichier | État actuel | Ce que la story change | À NE PAS casser |
|---|---|---|---|
| `packages/zcrud_note/lib/src/domain/z_smart_note.dart` | ✅ **le MODÈLE** (`_sanitizeExtra` l.435, appelée l.164/297/356) | **RIEN** (référence) | — |
| `.../z_note_content.dart:274-306` | `noteJsonEquals`/`noteJsonHash` (profonds), **exportés** | alias délégants vers `zcrud_core` | **surface publique** |
| `packages/zcrud_study_kernel/.../z_study_folder.dart` | `_extraFrom` l.333 (fromMap **seul**) ; `_mapEquals` l.402 | garde 3 sites + `zJsonEquals` | miroir legacy `updatedAt` (allowlist (d)) |
| `.../z_study_session_config.dart` | idem (l.203 / l.256) | idem | — |
| `packages/zcrud_flashcard/.../z_flashcard.dart` | idem (l.341 / l.414) | idem | **surface DODLP** ; miroir `updatedAt` |
| `.../z_repetition_info.dart` | ⛔ **AUCUN `copyWith`** — `withFolder(String)` l.185 propage `extra` tel quel ; ctor **`const`** | garde **2 sites** (`fromMap` + `toMap`) | ctor `const` (**aucun `assert`**) ; voie SRS unique |
| `packages/zcrud_document/.../z_study_document.dart` | `_extraFrom` l.307 ; `_mapEquals` l.356 | garde 3 sites + `zJsonEquals` | invariants de valeur déjà en place (H2 ES-2.1) |
| `.../z_document_reading_state.dart` | idem ; canal `learning` (`kLearningKey`) | idem | **`learning` reste RÉSERVÉE** (règle (g1)) |
| `packages/zcrud_mindmap/.../z_mindmap.dart` | ctor **non-`const`**, `extra = Map.unmodifiable(extra)` l.33 ; filtre `_knownKeys`+`_reservedSyncKeys` **dans `fromJson` seulement** ; **aucun `==`** | garde **initializer + `toJson`** | **aucun `==` ajouté** (D6) |
| `.../z_mindmap_node.dart` | idem (l.46) ; *« aucun `copyWith` public »* (l.6) | idem | topologie/TreeOps |
| `tool/reserved_keys_gate/lib/src/registrars.dart` | `kRegistrars` (9), `kProbeBodies` (9), `kNonExtensibleKinds` (2), `kExtensionPayloadPreservers` (1), `kLegacyUpdatedAtMirrors` (2) | **+ `kExtraWriters`** | ⚠️ **`kLegacyUpdatedAtMirrors` est FIGÉE par un verrou** (`==` à `{'study_folder','flashcard'}`) — **ne pas y toucher** |
| `.../lib/src/assertions.dart` | (a)(b)(c)(d)(e)(f) | **+ (i.1) + (i.2)** | les 6 assertions existantes |
| `.../lib/src/manual_probes.dart` | `ZManualProbe{className, body, decode, encode}` — ⚠️ `className` est **LU PAR LE GATE** (littéral) | **+ `write`** | `className` **reste un littéral** |
| `.../test/reserved_keys_test.dart` | 49 tests, 3 contre-exemples isolés | + (i.1)/(i.2) + 2 contre-exemples | les verrous `DW-ES14-2` et « H2 — canal `source` » |
| `packages/zcrud_firestore/.../firebase_z_repository_impl.dart:202-212` | clause n°1 **FAUSSE** (autorise le câblage) | **dartdoc seule** | aucun code |

### Invariants d'architecture applicables

- **AD-1** — ⛔ **aucune arête entre satellites.** C'est **la** raison de hisser l'égalité profonde dans `zcrud_core` (D7) : `zcrud_study_kernel` **ne peut pas** importer `zcrud_note`. `graph_proof` doit rester **ACYCLIQUE / CORE OUT=0**.
- **AD-4** — `extra` porte du **JSON arbitraire, donc IMBRIQUÉ** : c'est **exactement** le cas que l'égalité superficielle casse. Le round-trip des clés inconnues (assertion (b)/(e)) **ne doit pas régresser**.
- **AD-10** — désérialisation **défensive** : **jamais** de throw, donc **jamais d'`assert` au constructeur**. La garde vit **aux frontières** (`fromMap`, `copyWith`, `toMap`).
- **AD-16 / AD-19 / AD-9** — `updated_at`/`is_deleted` appartiennent au **store** (`ZSyncMeta`, **hors-entité**). Le store les écrit **APRÈS** le corps ⇒ un doublon dans le corps **fausse le merge LWW**.
- **R8** — chaque entité reste câblée au gate ; **cette story ajoute la 3ᵉ ligne du contrat d'extension** (`kRegistrars` + `kProbeBodies` + **`kExtraWriters`**). ⇒ **mettre à jour la dartdoc du « Contrat d'extension » en tête de `registrars.dart`** (elle annonce « 2 lignes par entité »).

### ⚠️ PRESCRIPTIONS DU BRIEF INVALIDÉES (R4 — « ne prescris rien que tu n'aies confronté au code réel »)

1. **« `copyWith` rouvre le filtre »** ⇒ **INCOMPLET**. **3 entités sur 8 n'ont AUCUN `copyWith`** : la voie fautive y est le **constructeur nominal**. Le mécanisme s'appelle `kExtraWriters` (voie d'écriture), **pas** `kExtraCopiers`.
2. **« zéro code par entité »** ⇒ **FAUX pour (i.1)** : sans point d'entrée uniforme, **1 ligne par entité** (le writer) est inévitable. *(L'alternative « le générateur émet le writer » **ne compile pas** : `ZRepetitionInfo` n'a pas de `copyWith`.)* ✅ **Vrai pour (i.2)** (zéro code par entité).
3. **« sur le modèle de `kExtensionPayloadPreservers` »** ⇒ **ce n'est pas un modèle utilisable** : c'est un `Set<String>`, pas une table de fonctions. Le vrai précédent est **`kRegistrars`** (`const List<ZRegistrar>` de tear-offs top-level) — **forme déjà compilée dans le repo**.
4. **« fixture d'échec isolée dans `scripts/ci/prove_gates.dart` ; il doit AUGMENTER »** ⇒ **HORS-PATRON, vérifié sur disque.** `prove_gates` ne porte que les règles **AST / de couverture** (volet B) : **aucune** des assertions comportementales (a)…(f) n'y a de fixture — **(e) et (f), les deux dernières ajoutées, ont leurs contre-exemples isolés dans `reserved_keys_test.dart`** (`_ExtraDroppingEntity`, `_ChannelLeakingEntity`). **R2 est donc satisfaite DANS LE HARNAIS** (fixtures **permanentes**, **isolées par règle**) — c'est le patron réel du volet (A). ⇒ **`prove_gates` reste à 41 OK (non-régression assertée)** ; le faire croître exigerait d'inventer une règle AST **sans pouvoir supplémentaire** (normer un nom privé `_sanitizeExtra` = valider une **forme**, pas un **pouvoir** — précisément le motif que l'epic combat).
5. **L'inventaire du brief omettait `zcrud_mindmap`** (2 entités `ZExtensible`, **cassées sur (i.1)**, et sans **aucune** égalité de valeur).

### Risques

| # | Risque | Parade |
|---|---|---|
| 1 | **Ordre du spread dans `toMap()`** : `{...extra, ...généré}` — le généré **écrase** l'extra. Sur `study_folder`/`flashcard`, la pollution `updated_at` est donc **invisible** dans `toMap()` (mesuré : `val=null`). Une (i.1) qui ne regarderait qu'`updated_at` serait **VERTE sur deux entités CASSÉES**. | (i.1) asserte **`is_deleted`** (qu'aucun champ n'écrase) **et** discrimine `updated_at` **sur la VALEUR** sous allowlist (**D4**). **Ne pas changer l'ordre du spread** (il protège les champs du schéma). |
| 2 | **Faux vert d'(i.2) par `identical`** si les deux décodages partagent la même sous-`Map`. | Deep-copy **obligatoire** (`jsonDecode(jsonEncode(…))` ×2) ; **jamais** un littéral `const` (**D5**). |
| 3 | **Faux vert d'(i.2) par sonde scalaire** (mesuré : **9/9 verts** en scalaire). | La sonde imbriquée porte une **`Map` ET une `List`** ; anti-vacuité : le témoin imbriqué **doit être dans `extra`**. |
| 4 | **Writer menteur** (`(e, x) => e`) ⇒ (i.1) trivialement verte. | **Témoin d'écriture** obligatoire (**AC7**). |
| 5 | **Régression cross-package invisible** (précédent : `ZExportApi` supprimé en E11a-3, `melos analyze` RED plusieurs commits). 6 packages écrits ici. | **`melos run analyze` ET `melos run verify` REPO-WIDE** au gate de commit (AC15). Un `graph_proof` vert **ne remplace pas** `melos analyze`. |
| 6 | **`gate:web`** (default-ON) rougit sur un `dart:io` non tagué (a surpris ES-2.2). | Aucun test ajouté n'a besoin de `dart:io` ; sinon `@TestOn('vm')` **+ raison écrite** (AC14). |
| 7 | **Surface publique `ZFlashcard`** (migration DODLP) / `noteJsonEquals` (exporté). | **Ajouts seulement** ; alias délégants ; **aucune suppression** (AC4). |
| 8 | **`kLegacyUpdatedAtMirrors` est FIGÉE par un verrou d'égalité** — la toucher rend la suite rouge. | **Ne pas y toucher.** (i.1) la **consomme** (`legacyMirrorAllowed`), ne l'étend pas. |

### References

- Findings mesurés : `_bmad-output/implementation-artifacts/stories/code-review-es-2-2.md` — **MAJEUR-3** (l. 213-244), **MEDIUM-1** (l. 247-277).
- **Le modèle de la parade** : `packages/zcrud_note/lib/src/domain/z_smart_note.dart` — `_sanitizeExtra` (l. 422-439), appels (l. 164, 297, 356-358) ; `noteJsonEquals`/`noteJsonHash` (`.../z_note_content.dart` l. 259-306).
- Garde partagée (origine) : `code-review-es-2-1.md` › **H2** ; règles de gate génériques (f)/(g1)/(g2)/(h) : `code-review-es-2-1.md` › **H1**.
- Rétro : `epic-es-1-retrospective.md` › **R1** (règle sans gate = vœu), **R2** (fixture isolée par règle), **R3** (injection rejouée), **R5** (AST), **R6** (aucune dégradation silencieuse), **R8** (câblage du gate dans la même story), **R9** (vérif repo-wide).
- Architecture study : `architecture/architecture-zcrud-study-2026-07-12/architecture.md` — **AD-19.1.c** (spec du gate, règles (a)…(f)), **AD-19.2** (miroirs legacy), § **Deferred** (DW-ES14-2, DW-ES22-1..4).
- Architecture socle : `architecture/architecture-zcrud-2026-07-09/architecture.md` — **AD-1**, **AD-4**, **AD-9**, **AD-10**, **AD-16**.
- Harnais : `tool/reserved_keys_gate/lib/src/{registrars,assertions,manual_probes}.dart` · `test/reserved_keys_test.dart` (contre-exemples isolés : l. 36-62, 68-109).
- Piège actif : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:202-212`.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, effort high).

### Debug Log References

- Sonde T0 (jetable, supprimée en fin de story) : `tool/reserved_keys_gate/test/t0_probe_test.dart`.
- Logs de vérif : `melos run verify` RC=0 ; `prove_gates` 41 OK / 0 FAIL.

### Completion Notes List

#### T0 — Reproduction en machine (AVANT correctif)

Sortie brute de la sonde (les mesures de la story sont **confirmées à l'identique**) :

```
(i.1) ZStudyFolder          : updated_at=true(val=null)                     is_deleted=true(val=true) temoin=copie-ok
(i.1) ZStudySessionConfig   : updated_at=true(val=1999-01-01T00:00:00.000Z) is_deleted=true(val=true) temoin=copie-ok
(i.1) ZFlashcard            : updated_at=true(val=null)                     is_deleted=true(val=true) temoin=copie-ok
(i.1) ZStudyDocument        : updated_at=true(val=1999-01-01T00:00:00.000Z) is_deleted=true(val=true) temoin=copie-ok
(i.1) ZDocumentReadingState : updated_at=true(val=1999-01-01T00:00:00.000Z) is_deleted=true(val=true) temoin=copie-ok
(i.1) ZSmartNote (MODELE)   : updated_at=false                              is_deleted=false          temoin=copie-ok
(i.1) ZRepetitionInfo (ctor): updated_at=true(val=1999-01-01T00:00:00.000Z) is_deleted=true(val=true) temoin=copie-ok
(i.1) ZMindmap (ctor)       : updated_at=true(val=1999-01-01T00:00:00.000Z) is_deleted=true(val=true) temoin=copie-ok
(i.1) ZMindmapNode (ctor)   : updated_at=true(val=1999-01-01T00:00:00.000Z) is_deleted=true(val=true) temoin=copie-ok

(i.2) study_folder           [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? false · Set=2
(i.2) study_session_config   [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? false · Set=2
(i.2) flashcard              [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? false · Set=2
(i.2) repetition_info        [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? false · Set=2
(i.2) study_document         [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? false · Set=2
(i.2) document_reading_state [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? false · Set=2
(i.2) smart_note (MODELE)    [SCALAIRE] a==b ? true   | [IMBRIQUE] a==b ? true  · Set=1
(i.2) ZMindmap               [SCALAIRE] a==b ? false  | [IMBRIQUE] a==b ? false · Set=2   ← AUCUN ==
(i.2) ZMindmapNode           [SCALAIRE] a==b ? false  | [IMBRIQUE] a==b ? false · Set=2   ← AUCUN ==
```

**APRÈS correctif** : (i.1) `is_deleted=false` sur **9/9** ; `updated_at` ne subsiste que sur les 2 miroirs
legacy (`study_folder`, `flashcard`) avec la valeur du **champ métier** (`val=null`), **jamais** la
pollution. (i.2) : les **6 kinds** du registre sont `a==b ? true · Set=1` **même en imbriqué**. Les
mindmaps restent `false` ⇒ **DW-ES22-5** (skip déclaré et contrôlé).

#### 🔴 REMISES EN CAUSE DE LA STORY (4 — toutes prouvées en machine)

1. **AC12.1 est FAUSSE.** *« Retirer `_sanitizeExtra` du `copyWith` de `ZStudyDocument` ⇒ (i.1) rouge »* —
   **l'injection est restée VERTE.** Cause : `toMap()` re-sanitise, et (i.1a)/(i.1b) ne regardent que
   l'**ENCODAGE**. En l'état de la spec, **la garde du `copyWith` n'était exigée par AUCUNE machine —
   donc décorative** (violation R1 dans la story elle-même). ⇒ **Assertion (i.1c) AJOUTÉE** : l'`extra`
   **EN MÉMOIRE** de l'entité écrite ne porte aucune clé réservée. Elle rend la garde du `copyWith`
   **porteuse** (l'actif protégé n'est pas la persistance — `toMap()` la porte — mais l'état mémoire :
   `zExtraRead`, `==`, `hashCode`, toute UI). Skip **déclaré et contrôlé** (`kConstCtorOnlyWriters`)
   pour `ZRepetitionInfo` (ctor `const` ⇒ ne peut structurellement rien filtrer ; AD-10 y interdit
   l'`assert`).
2. **Bug introduit puis démasqué par l'injection n° 2.** Mon premier jet plaçait le skip d'(i.1c) **en
   tête** avec un `return` ⇒ il **court-circuitait (i.1a)/(i.1b) sur `repetition_info`**, c.-à-d. les
   seules assertions qui portent la promesse sur cette entité. L'injection n° 2 (retrait de la garde de
   son `toMap`) est restée **VERTE** et l'a révélé. (i.1c) est désormais **après** (i.1a)/(i.1b), sans
   `return` prématuré.
3. **7ᵉ copie de `_mapEquals` non recensée** : `ZCustomSource.payload` (`z_flashcard_source.dart:218`).
   La story affirmait *« `ZFlashcard.source` a DÉJÀ une égalité profonde »* — **faux** : elle est
   **superficielle**, et n'était verte que parce que la sonde `source` est **plate**. Corrigée
   (`zJsonEquals`/`zJsonHash`) : **7 copies supprimées**, pas 6.
4. **Fixture d'anti-inertie couplée à la production.** Mon test d'anti-inertie du skip d'(i.2) empruntait
   `study_folder` : l'injection n° 3 le faisait rougir **parasitairement**. Remplacé par une fixture
   dédiée `_DeepExtraEqualityEntity` (esprit **R2** : une fixture par règle). *(Un premier jet utilisait
   `_ShallowExtraEqualityEntity` — il ne rougissait PAS, car sur un `extra` imbriqué une égalité
   superficielle rend bel et bien `a != b` : le test était vert en ne prouvant rien.)*

**Piège `gate:web` (AC14) — rejoué malgré l'avertissement, puis corrigé** : j'ai d'abord importé
`package:zcrud_core/zcrud_core.dart` (barrel **complet**, qui ré-exporte la couche **Flutter**) dans
`zcrud_note`, package **pur-Dart** ⇒ `[gate:web] ÉCHEC : la suite de zcrud_note ne passe pas en JS`.
Corrigé en `package:zcrud_core/domain.dart` (AD-14), avec commentaire en place.

#### T13 — Les 4 injections de régression (R3), réellement exécutées

| # | Injection | Résultat |
|---|---|---|
| 1 | `_sanitizeExtra` retirée du `copyWith` de **`ZStudyDocument`** | 🔴 **ROUGE** — `[study_document] (i.1c) DW-ES22-3 VIOLÉ (ÉTAT EN MÉMOIRE) : la voie d'écriture a laissé les clés réservées {updated_at, is_deleted} DANS extra`. **1 seul** échec ⇒ (i.2) reste VERTE (**isolation R2**). Restaurée ⇒ 81 verts. |
| 2 | `_sanitizeExtra` retirée du `toMap` de **`ZRepetitionInfo`** (entité **sans `copyWith`**) | 🔴 **ROUGE** — `[repetition_info] (i.1a) DW-ES22-3 VIOLÉ (PERSISTANCE) : ... is_deleted est RÉÉMIS par l'encodage`. Restaurée ⇒ 81 verts. |
| 3 | `_mapEquals`/`_mapHash` **superficiels** rétablis sur **`ZStudyFolder`** | 🔴 **ROUGE** — `[study_folder] (i.2) DW-ES22-4 VIOLÉ : deux décodages INDÉPENDANTS du MÊME payload ne sont PAS ÉGAUX`. **(i.1) reste VERTE** (**isolation R2**). Restaurée ⇒ 81 verts. |
| 4 | Writer `study_document` retiré de **`kExtraWriters`** | 🔴 **ROUGE** — `AC9 ... 🔴 TROU DE COUVERTURE : ce/ces kind(s) ZExtensible sont enregistrés SANS voie d'écriture dans kExtraWriters`. Restaurée ⇒ 81 verts. |

#### Vérif verte finale (repo-wide, rejouée)

```
melos run generate ............ SUCCESS   (aucun nouveau .g.dart : les annotations n'ont pas bougé)
melos run analyze ............. RC=0      REPO-WIDE
melos run verify .............. RC=0      REPO-WIDE (10 gates, gate:web inclus)
prove_gates ................... 41 OK, 0 FAIL      (non-régression — inchangé, cf. R4 §4 de la story)
graph_proof ................... noeuds=17 · ACYCLIQUE OK · CORE OUT=0 OK
melos list .................... 17
```

| Package | Avant | Après |
|---|---|---|
| `zcrud_core` | 911 | **922** *(+11 — `zJsonEquals`/`zJsonHash`/`zSanitizeExtra`)* |
| `reserved_keys_gate` | 49 | **81** *(+32 — (i.1a/b/c), (i.2), couverture bidirectionnelle, 3 fixtures)* |
| `zcrud_note` | 130 | 130 |
| `zcrud_document` | 129 | 129 |
| `zcrud_flashcard` | 189 | 189 |
| `zcrud_study_kernel` | 108 | 108 |
| `zcrud_firestore` | 90 | 90 |
| `zcrud_mindmap` | 110 | 110 |
| `zcrud_generator` | 102 | 102 |

#### Dettes

- ✅ **DW-ES22-3 SOLDÉE** · ✅ **DW-ES22-4 SOLDÉE** (`architecture.md` § Deferred, avec critères de clôture).
- 🟡 **DW-ES22-5 OUVERTE** — `ZMindmap`/`ZMindmapNode` sans égalité de valeur (skip d'(i.2) déclaré et
  contrôlé par `kNoValueEqualityProbes` + anti-inertie).
- 🔴 **DW-ES14-2** : **non implémentée** (D8 — story dédiée `ES-2.9`/`ES-3.0` avant ES-3.2/3.5, inscrite
  au § Deferred). Son **piège actif est neutralisé** : la clause d'échappement n° 1 de
  `FirebaseZRepositoryImpl.fromRegistry` (falsifiée par `ZNoteAudio`) n'autorise plus le câblage d'un
  store — **dartdoc seule, aucun code de `zcrud_firestore` modifié**.

### File List

**`zcrud_core`** (additif pur — aucune signature existante touchée)
- `packages/zcrud_core/lib/src/domain/extension/z_json_equality.dart` *(nouveau)*
- `packages/zcrud_core/lib/src/domain/extension/z_extensible.dart` *(+ `zSanitizeExtra`)*
- `packages/zcrud_core/lib/domain.dart` *(+1 export)*
- `packages/zcrud_core/test/domain/extension/z_json_equality_test.dart` *(nouveau — 11 tests)*

**`zcrud_note`** (surface publique **inchangée** — alias délégants)
- `packages/zcrud_note/lib/src/domain/z_note_content.dart`

**`zcrud_study_kernel`**
- `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart`
- `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart`

**`zcrud_document`**
- `packages/zcrud_document/lib/src/domain/z_study_document.dart`
- `packages/zcrud_document/lib/src/domain/z_document_reading_state.dart`

**`zcrud_flashcard`** (surface publique **inchangée** — migration DODLP)
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart`
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart` *(7ᵉ copie de `_mapEquals`)*

**`zcrud_mindmap`** (⛔ aucun `==` ajouté — D6)
- `packages/zcrud_mindmap/lib/src/domain/z_mindmap.dart`
- `packages/zcrud_mindmap/lib/src/domain/z_mindmap_node.dart`

**`zcrud_firestore`** (dartdoc seule)
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart`

**Harnais du gate**
- `tool/reserved_keys_gate/lib/src/registrars.dart` *(+ `kExtraWriters`, `kConstCtorOnlyWriters`, `kNoValueEqualityProbes`)*
- `tool/reserved_keys_gate/lib/src/assertions.dart` *(+ (i.1a/b/c), (i.2))*
- `tool/reserved_keys_gate/lib/src/manual_probes.dart` *(+ champ `write`)*
- `tool/reserved_keys_gate/test/reserved_keys_test.dart` *(+ 32 tests, + 3 fixtures isolées)*

**Architecture**
- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md`

### Change Log

| Date | Changement |
|---|---|
| 2026-07-14 | ES-2.2b implémentée. DW-ES22-3 et DW-ES22-4 **soldées** sur les 9 entités `ZExtensible` ; garde `extra` partagée (`zSanitizeExtra`) + égalité profonde (`zJsonEquals`/`zJsonHash`) hissées dans `zcrud_core` (AD-1) ; 7 copies de `_mapEquals` supprimées. **Machine (R1)** : `kExtraWriters` à couverture bidirectionnelle + assertions **(i.1a/b/c)** et **(i.2)** ⇒ aucune entité ES-2.3…2.8 ne peut naître non couverte. **DW-ES22-5 ouverte.** Piège actif de DW-ES14-2 neutralisé (dartdoc). 4 injections de régression rejouées. Repo-wide vert. |

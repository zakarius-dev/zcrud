# Code Review — ES-2.2b : Gardes systémiques du slot `extra` (DW-ES22-3 / DW-ES22-4)

- **Story** : `_bmad-output/implementation-artifacts/stories/es-2-2b-gardes-extra-systemiques.md` (16 ACs, D1..D9)
- **Skill** : `bmad-code-review` (tool `Skill`, effort high) — workflow réel, step-01 → step-04.
- **Diff** : non committé, baseline `709406d`, périmètre ES-2.2b (File List de la story).
- **Date** : 2026-07-14
- **Verdict** : ⛔ **NE PAS PASSER `done` EN L'ÉTAT** — 2 HIGH, 2 MAJEUR, 1 MEDIUM, 1 LOW.
  **Le code de production livré est correct** (persistance protégée sur les 9 entités) ; **c'est la MACHINE qui ne tient pas sa promesse** : le critère de clôture inscrit pour DW-ES22-3 est **falsifié en machine** (4 injections vertes ci-dessous).

---

## Méthode — tout est MESURÉ, rien n'est déduit par lecture

5 injections appliquées sur l'arbre réel, gate rejoué (`cd tool/reserved_keys_gate && flutter test`), **puis restauration vérifiée par `diff -q` fichier par fichier**. Baseline : **81/81 verts**. Arbre rendu à l'identique (`diff -q` OK ×4, harnais re-vert 81/81).

| # | Injection | Attendu par la story | **MESURÉ** |
|---|---|---|---|
| INJ-A | `_sanitizeExtra` **retirée du `toMap()` de `ZStudyFolder`** | ROUGE | 🟢 **81/81 VERTS** |
| INJ-B | `_sanitizeExtra` **retirée du `toJson()` de `ZMindmap`** | ROUGE | 🟢 **81/81 VERTS** |
| INJ-D | `copyWith` de `ZStudyDocument` **ne filtre plus** + `'study_document'` ajouté à `kConstCtorOnlyWriters` | ROUGE | 🟢 **81/81 VERTS** |
| INJ-E | `_writeStudyFolderExtra` **sanitise lui-même** avant `copyWith` (writer menteur « poli ») | ROUGE (témoin) | 🟢 **81/81 VERTS** |
| SONDE | `ZXxx(…, extra: {updated_at, is_deleted})` — **constructeur nominal** sur les 9 entités | — | 🔴 **6/9 polluées EN MÉMOIRE** |

---

## 🔴 HIGH-1 — La garde de `toMap()`/`toJson()` est **DÉCORATIVE sur 8 entités sur 9** : aucune machine ne l'exige

**Fichiers** : `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart:239` · `packages/zcrud_mindmap/lib/src/domain/z_mindmap.dart:182` · idem `z_study_session_config.dart`, `z_flashcard.dart`, `z_study_document.dart:197`, `z_document_reading_state.dart`, `z_smart_note.dart:297`, `z_mindmap_node.dart:192` · **cause** : `tool/reserved_keys_gate/lib/src/assertions.dart:445-541` ((i.1a)/(i.1b))

**Le dev a trouvé que la garde du `copyWith` n'était exigée par aucune machine (AC12.1 fausse) et a ajouté (i.1c). Il s'est arrêté d'un cran trop bas : la garde de `toMap()` — celle que D1 déclare « ⛔ NON NÉGOCIABLE… la SEULE frontière que TOUTES les voies traversent », celle qui « rend la promesse INCONDITIONNELLE » — n'est exigée par aucune machine non plus.**

**Scénario d'échec REPRODUIT (INJ-A)** — dans `z_study_folder.dart:239`, remplacer :

```dart
..._sanitizeExtra(extra),          //  ⇢  ...extra,
...ZStudyFolderZcrud(this).toMap(),
```

⇒ `cd tool/reserved_keys_gate && flutter test` ⇒ **`00:00 +81: All tests passed!`**. Idem INJ-B sur `ZMindmap.toJson()`.

**Cause structurelle** — (i.1a)/(i.1b) encodent l'entité **produite par `kExtraWriters[kind]`**. Or :

| Kind | Writer câblé | `extra` en mémoire **avant** `encode` | (i.1a)/(i.1b) mordent-elles sur `toMap()` ? |
|---|---|---|---|
| `study_folder`, `study_session_config`, `flashcard`, `study_document`, `document_reading_state`, `smart_note` | `copyWith` — **qui sanitise** | **déjà propre** | ⛔ **NON — vacuellement vertes** |
| `ZMindmap`, `ZMindmapNode` | ctor nominal — **dont l'initializer sanitise** | **déjà propre** | ⛔ **NON — vacuellement vertes** |
| `repetition_info` | ctor `const` — **ne filtre rien** | **pollué** | ✅ **OUI — seule entité couverte** |

⇒ **Les assertions de persistance (i.1a)/(i.1b) n'ont de pouvoir discriminant que sur 1 kind sur 9.** L'injection n° 2 du dev (retrait de la garde du `toMap` de `ZRepetitionInfo` ⇒ rouge) est **la seule qui pouvait rougir** — elle a validé 1/9 et laissé croire à la couverture des 9. C'est **exactement le motif dominant du projet** (« un artefact déclaré valide sur son existence, jamais sur son pouvoir discriminant observé »), **rejoué à l'intérieur de la parade qui prétend le clore** — onzième occurrence.

**Conséquence** : le critère de clôture inscrit pour **DW-ES22-3** dans `architecture.md:411` (« critère de clôture = les assertions (i.1)/(i.2) + la couverture bidirectionnelle ») est **FAUX**. La dette peut se ré-ouvrir demain sur 8 entités — par un refactor, un `dart fix`, un merge — **sans un seul test rouge**. Et le filet retiré n'est pas redondant : cf. **HIGH-2**, le constructeur nominal est une voie polluante non filtrée dont `toMap()` est **le seul** rempart.

**Geste attendu** : (i.1) doit encoder une entité dont l'`extra` **EST pollué en mémoire au moment de l'encodage** — c.-à-d. exercer une voie d'écriture **NON filtrante** (le constructeur nominal, cf. HIGH-2), et non la voie la plus sûre. Tant que la seule entité encodée avec un `extra` sale est `repetition_info`, la frontière de SORTIE reste un vœu sur les 8 autres.

---

## 🔴 HIGH-2 — Le **constructeur nominal** (public, `const`) reste une voie d'écriture **NON FILTRÉE** : 6 entités sur 9 portent `updated_at`+`is_deleted` dans leur `extra` **EN MÉMOIRE** — dont `ZSmartNote`, « LE MODÈLE »

**Fichiers** : `z_study_folder.dart:82` · `z_study_session_config.dart` · `z_flashcard.dart` · `z_study_document.dart:59` · `z_document_reading_state.dart` · `z_smart_note.dart` — **cause** : `tool/reserved_keys_gate/lib/src/registrars.dart:260-306` (`kExtraWriters` ne câble **qu'une seule** voie par entité, et c'est **la voie filtrante**)

**Mesure brute (sonde de revue, arbre courant, gardes EN PLACE)** :

```
[CTOR NOMINAL] ZStudyFolder         : extra EN MEMOIRE pollue=[updated_at, is_deleted] | encode=[updated_at=null] | temoin=ok
[CTOR NOMINAL] ZStudySessionConfig  : extra EN MEMOIRE pollue=[updated_at, is_deleted] | encode=PROPRE
[CTOR NOMINAL] ZFlashcard           : extra EN MEMOIRE pollue=[updated_at, is_deleted] | encode=[updated_at=null]
[CTOR NOMINAL] ZStudyDocument       : extra EN MEMOIRE pollue=[updated_at, is_deleted] | encode=PROPRE
[CTOR NOMINAL] ZDocumentReadingState: extra EN MEMOIRE pollue=[updated_at, is_deleted] | encode=PROPRE
[CTOR NOMINAL] ZSmartNote           : extra EN MEMOIRE pollue=[updated_at, is_deleted] | encode=PROPRE   ← « LE MODÈLE »
[CTOR NOMINAL] ZMindmap             : extra EN MEMOIRE pollue=NON                      | encode=PROPRE   ← seule entité SAINE
```

**Scénario d'échec REPRODUCTIBLE (aucune injection — code livré tel quel)** :

```dart
final f = ZStudyFolder(id: 'f1', title: 't', extra: {'is_deleted': true});
f.extra['is_deleted'];                       // ⇒ true          🔴
f == ZStudyFolder.fromMap(f.toMap());        // ⇒ false         🔴  (l'un porte la clé, l'autre non)
<ZStudyFolder>{f, ZStudyFolder.fromMap(f.toMap())}.length;  // ⇒ 2   🔴
```

C'est **littéralement le dommage DW-ES22-4** (`Set` en garde deux, `expect(relu, original)` cassé) — que la story déclare **SOLDÉ** — **entrant par une autre porte**, et **c'est l'actif exact que (i.1c) prétend protéger** (« l'actif protégé n'est pas la persistance, c'est l'ÉTAT EN MÉMOIRE : `zExtraRead`, `==`, `hashCode`, toute UI » — `assertions.dart:543-551`).

**Le raisonnement du dev sur (i.1c) est donc JUSTE mais INCOMPLET** : il a identifié le bon actif (l'état mémoire), et l'a protégé **sur la seule voie que le harnais interroge** (`copyWith`). Les 5 entités codegen ont **exactement le même constructeur `const`** que `ZRepetitionInfo` — la raison pour laquelle elles ne sont pas dans `kConstCtorOnlyWriters` n'est **pas** qu'elles filtrent à la construction (elles ne le peuvent pas : `const`), c'est que **`kExtraWriters` a choisi de câbler leur `copyWith`**. La liste `kConstCtorOnlyWriters` (`registrars.dart:339`) **décrit donc faux** ce qu'elle prétend décrire (« kinds dont la **SEULE** voie d'écriture est un ctor `const` ») : **6 kinds** ont un ctor `const` non filtrant, un seul y figure.

⇒ **AC1 (« la garde est appelée par toutes les voies d'écriture ») est factuellement fausse** pour la voie constructeur des 6 entités codegen, et **AC16.1 (DW-ES22-3 SOLDÉE) est prématurée**.

**Geste attendu** : câbler la voie **constructeur nominal** dans le harnais (2ᵉ writer par entité, ou `ZExtraWriter` renvoyant une paire), et faire porter (i.1a)/(i.1b)/(i.1c) sur **les deux** voies — ce qui referme du même coup HIGH-1 (l'encodage verrait enfin un `extra` sale). À défaut : assumer par écrit que l'état mémoire n'est **pas** tenu sur la voie ctor pour 6 entités, et inscrire la dette (elle est **observable**, cf. scénario ci-dessus).

---

## 🟠 MAJEUR-1 — `kConstCtorOnlyWriters` est une échappatoire **d'auto-exemption**, **non verrouillée** (deux poids, deux mesures avec `kLegacyUpdatedAtMirrors`)

**Fichiers** : `tool/reserved_keys_gate/lib/src/registrars.dart:339-341` · `tool/reserved_keys_gate/test/reserved_keys_test.dart:445-462` · `assertions.dart:561-576`

**Scénario d'échec REPRODUIT (INJ-D)** — deux gestes, aucun rouge :

1. `z_study_document.dart:268` : `: _sanitizeExtra(extra as Map<String, dynamic>)` → `: Map<String, dynamic>.unmodifiable(extra as Map<String, dynamic>)` (le `copyWith` **rouvre le filtre** — le défaut DW-ES22-3 **exact**) ;
2. `registrars.dart:340` : ajouter `'study_document',` à `kConstCtorOnlyWriters`.

⇒ **`00:00 +81: All tests passed!`**

**La condition d'appartenance à la liste n'est vérifiée par AUCUNE machine.** Rien ne contrôle que le kind exempté a réellement un ctor `const` ni qu'il n'a **aucun** `copyWith` (`ZStudyDocument` a les deux… et un `copyWith`). L'unique contrôle « anti-inertie » (`assertions.dart:565` : `expect(leaked, isNotEmpty)`) exige **la présence du défaut lui-même** : **on s'exempte de (i.1c) en commettant précisément ce que (i.1c) attrape.** L'anti-inertie est **inversée**.

**Contraste, dans le même fichier** : `kLegacyUpdatedAtMirrors` est **figée par un verrou d'égalité** (`reserved_keys_test.dart:481` : `expect(kLegacyUpdatedAtMirrors, equals(<String>{'study_folder','flashcard'}))`) — toute croissance **ou** réduction rend la suite rouge, et sa dartdoc dit « ⛔ TOUTE nouvelle entrée = DÉCISION D'ARCHITECTURE ». `kConstCtorOnlyWriters` porte **la même prose** (`registrars.dart:335`) **sans le verrou**. La prose n'est pas une machine (R1).

**Geste attendu** : verrou d'égalité figé sur `kConstCtorOnlyWriters` (patron `kLegacyUpdatedAtMirrors`) **+**, idéalement, règle AST (volet B, R5) prouvant que le kind exempté n'expose **aucun** `copyWith` et n'a qu'un ctor `const`.

---

## 🟠 MAJEUR-2 — Le **témoin d'écriture** ne défend PAS contre le writer menteur réaliste : celui qui **sanitise lui-même**

**Fichiers** : `tool/reserved_keys_gate/lib/src/assertions.dart:460-478` (anti-vacuité) · `registrars.dart:257-259` (dartdoc : « un writer MENTEUR (`(e, x) => e`) rendrait (i.1) trivialement verte »)

**Scénario d'échec REPRODUIT (INJ-E)** — `registrars.dart:270` :

```dart
Object _writeStudyFolderExtra(Object e, Map<String, dynamic> x) {
  final propre = {for (final en in x.entries)
      if (!ZSyncMeta.reservedKeys.contains(en.key)) en.key: en.value};
  return (e as ZStudyFolder).copyWith(extra: propre);   // sanitise AVANT la voie publique
}
```

⇒ **`00:00 +81: All tests passed!`** — le témoin `zz_temoin_ecriture` **n'est pas une clé réservée** : il ressort intact de l'encodage, l'anti-vacuité est **verte**, et (i.1a/b/c) n'ont plus rien à voir.

**Le témoin prouve « la voie a pris UN `extra` », pas « la voie a pris LES CLÉS RÉSERVÉES ».** Ce n'est pas une hypothèse d'école : **c'est la forme que `kExtraWriters` a DÉJÀ en production** — il câble systématiquement la voie qui filtre (HIGH-1/HIGH-2). Le garde-fou « anti-writer-menteur » (AC7, risque n° 4 de la story) attrape le cas trivial (`(e,x) => e`) et **manque le cas réel**.

**Geste attendu** : ancrer (i.1) sur un invariant que le writer ne peut pas contourner — p. ex. exiger que l'`extra` **effectivement porté par l'entité écrite** (avant sanitisation d'entité) contienne le témoin **ET** que la persistance soit exercée sur une voie non filtrante (HIGH-2). Un témoin **réservé** (impossible : il serait filtré) n'est pas la réponse ; la réponse est de **ne pas laisser le harnais choisir la voie**.

---

## 🟡 MEDIUM-1 — `kNoValueEqualityProbes` : même régime d'échappatoire non verrouillée

**Fichiers** : `registrars.dart:368-371` · `reserved_keys_test.dart:464-474`

Le test ne vérifie que **l'absence d'entrée morte** (la classe est-elle encore une sonde manuelle ?). Aucun **verrou d'égalité figé**. Un futur `ZExtensible` **écrit à la main** (patron `ZMindmap`, scénario H1 d'ES-1.4) peut donc s'exempter d'(i.2) en s'ajoutant à la liste — l'anti-inertie (`assertions.dart:643` : `expect(a, isNot(equals(b)))`) est **satisfaite par le défaut lui-même** (« je n'ai pas d'`==` »), même famille de faille que MAJEUR-1. Portée moindre : les 7 kinds du **registre** ont `expectValueEquality: true` **en dur** (`reserved_keys_test.dart:331`) — la faille ne concerne que les sondes manuelles.

**Geste** : verrou d'égalité figé (`equals(<String>{'ZMindmap','ZMindmapNode'})`).

---

## 🔵 LOW-1 — La dartdoc de `zJsonEquals` sur-promet (« implémentation UNIQUE du repo »)

**Fichier** : `packages/zcrud_core/lib/src/domain/extension/z_json_equality.dart:1-2, 683` (`assertions.dart`) — il subsiste **3 `_mapEquals`/`_mapHash` superficiels** dans `zcrud_core` : `src/presentation/list/z_list_render_request.dart:126`, `src/domain/edition/z_sub_list_config.dart:180`, `src/presentation/edition/families/z_relation_field_widget.dart:345`. Ils ne portent **pas** de slot `extra` (hors périmètre DW-ES22-4, aucun risque de sync) — mais la formule « implémentation **UNIQUE** du repo » est inexacte et invite un futur lecteur à conclure trop vite. Reformuler (« unique implémentation pour le slot `extra` ») ou les rallier.

---

## ✅ Points VÉRIFIÉS — aucune régression (mesurés, pas déduits)

| Axe | Vérification | Résultat |
|---|---|---|
| **Égalité profonde** (axe 5) | `zJsonEquals`/`zJsonHash` : `Map`/`List` imbriquées, `List` de `Map`, `null` vs clé absente (`{'a':null}` ≠ `{}` — **OK**, contrôle de longueur + `containsKey`), `Map` vs `List`, ordre des clés non signifiant (`==` **et** hash), ordre de liste signifiant. **Contrat Dart `a == b ⇒ a.hashCode == b.hashCode`** : vérifié **y compris sur le piège `int`/`double`** (`{'n':1}` vs `{'n':1.0}` — `==` true, **hash identiques** : Dart garantit `1.hashCode == 1.0.hashCode`) — or `jsonDecode('{"n":1.0}')` rend bien un `double` et Firestore rend des `double` : **le piège existait, il ne mord pas**. Hash XOR : collisions bénignes (`{}`, `[]`, `0` → 0), contrat respecté. | ✅ **RAS** |
| **AD-10** (axe 6) | Aucun `assert(` ajouté à un constructeur dans le diff (grep AST sur les 6 packages) ; `registry.decode({})` ne lève sur aucun kind (test du harnais, 9/9). | ✅ |
| **Régression cross-package** (axe 7) | Aucun symbole public supprimé/renommé. `ZFlashcard` : **ajouts seuls** (surface DODLP intacte). `noteJsonEquals`/`noteJsonHash` **conservés en alias délégants** (`z_note_content.dart:293` / `:300`), toujours exportés. | ✅ |
| **Règle (h)** (axe 10) | Les 6 barrels masquent l'extension générée : `hide ZStudyFolderZcrud`, `ZStudySessionConfigZcrud`, `ZFlashcardZcrud`, `ZRepetitionInfoZcrud`, `ZStudyDocumentZcrud`, `ZDocumentReadingStateZcrud`, `ZSmartNoteZcrud`. | ✅ |
| **`gate:web`** (AC14) | `zcrud_note` importe `package:zcrud_core/domain.dart` (pur-Dart), pas le barrel Flutter. | ✅ |
| **Couverture bidirectionnelle** (axe 4) | Kind `ZExtensible` sans writer ⇒ ROUGE (rejoué par le dev, injection n° 4) ; writer orphelin ⇒ ROUGE ; writer ciblant un non-`ZExtensible` ⇒ ROUGE. Entité `ZExtensible` **écrite à la main** : couverte par `E_disk \ E_covered` (volet AST) **et** `write` est un champ **`required`** de `ZManualProbe` ⇒ **ne compile pas** sans lui. **La machine tient** — sous réserve de MAJEUR-1/MEDIUM-1 (elle peut être **désarmée par déclaration**). | ✅ (nuancé) |
| **(i.2) anti-vacuité** (axe 2b/2c) | Deep-copy `jsonDecode(jsonEncode())` **par décodage** (`assertions.dart:411`, deux appels indépendants l. 638-639) ⇒ le piège `identical` est bien désamorcé ; sonde **imbriquée** (`Map` + `List` + `Map` dans la `List`) ; témoin imbriqué asserté présent dans `extra`. | ✅ |
| **(i.1) `is_deleted` discriminant** (axe 2a) | (i.1a) asserte `is_deleted` **sans exception** ; (i.1b) discrimine `updated_at` **sur la VALEUR** sous allowlist. Le piège du miroir legacy est correctement traité. *(Mais l'entité encodée a un `extra` déjà propre — cf. HIGH-1.)* | ✅ (portée réduite par HIGH-1) |
| **DW-ES22-5** (axe 8) | Skip d'(i.2) **déclaré** (`kNoValueEqualityProbes`) **et contrôlé** (anti-inertie : rougit si les mindmaps gagnent un `==`) ; dette **OUVERTE** dans `architecture.md:426`. Fixture d'anti-inertie **dédiée** (`_DeepExtraEqualityEntity`) — le dev a corrigé de lui-même une fixture qui ne prouvait rien. | ✅ |
| **Piège actif DW-ES14-2** (axe 9) | `firebase_z_repository_impl.dart:202-232` : la clause d'échappement n° 1 est marquée **« CLAUSE TOMBÉE »**, nomme `ZNoteAudio`/`ZSmartNote`, et **n'autorise plus** le câblage d'un store sur une entité qui utilise `extension`. Dartdoc seule, aucun code modifié. | ✅ |
| **AC16 / architecture** | DW-ES22-3 (`:411`) et DW-ES22-4 (`:419`) marquées SOLDÉES ; DW-ES22-5 OUVERTE (`:426`) ; recommandation **D8** (séparer DW-ES14-2, story dédiée avant ES-3.2/3.5) inscrite (`:379`). ⚠️ **Le « SOLDÉE » de DW-ES22-3 est à réviser** (HIGH-1/HIGH-2). | ⚠️ |

---

## Ce que la story a fait de REMARQUABLE (à conserver en rétro)

Le dev a **falsifié sa propre spec en machine** (AC12.1 : l'injection prescrite restait verte), a **nommé** la conséquence (« la garde du `copyWith` était décorative — violation R1 *à l'intérieur de la parade elle-même* »), et a ajouté (i.1c). Il a en outre démasqué **trois** autres faux-verts de son propre travail : un skip placé en tête qui court-circuitait (i.1a/b) sur `repetition_info` (révélé par l'injection n° 2), une **7ᵉ** copie de `_mapEquals` non recensée (`ZCustomSource.payload`, contredisant la « mesure de contrôle » de la story), et une fixture d'anti-inertie qui **ne rougissait pas**. C'est exactement la discipline que la rétro ES-1 réclame.

**La présente revue ne conteste pas ce raisonnement : elle le prolonge d'un cran.** La question « si je retire cette garde, QUELLE machine rougit ? » n'a pas été posée à la garde de `toMap()` — et la réponse, mesurée, est **« aucune, sur 8 entités sur 9 »**.

---

## Recommandation

1. **HIGH-1 + HIGH-2 sont un seul geste** : câbler la **voie constructeur nominal** dans `kExtraWriters` (en plus du `copyWith`) et faire porter (i.1a/b/c) sur **les deux voies**. L'encodage verra alors un `extra` réellement sale ⇒ la garde de `toMap()` devient **porteuse** sur les 9 entités, et la pollution mémoire de la voie ctor devient **observable**. Les gardes de production sont **déjà en place** : le correctif est **dans le harnais**, pas dans le domaine (sauf décision d'assumer la voie ctor comme non filtrable — à écrire).
2. **MAJEUR-1 / MEDIUM-1** : verrous d'égalité figés sur `kConstCtorOnlyWriters` et `kNoValueEqualityProbes` (patron `kLegacyUpdatedAtMirrors`, déjà dans le fichier).
3. **MAJEUR-2** : découle de 1 (une fois la voie non filtrante câblée, un writer auto-sanitisant ne peut plus masquer la pollution du `toMap`).
4. **AC16.1** : repasser **DW-ES22-3** de « SOLDÉE » à **partiellement soldée** (persistance ✅ / état mémoire sur voie ctor ❌) jusqu'à correction — sinon `architecture.md` porte un **faux signal de succès**, exactement ce que le § DW-ES14-2 (`:393`) apprend à redouter.

---
---

# 🔁 REMÉDIATION (2026-07-14) — statut de CHAQUE finding, prouvé par injection

> **Verdict de remédiation** : **2 HIGH + 2 MAJEUR + 1 MEDIUM + 1 LOW — TOUS CORRIGÉS.**
> Le correctif recommandé par la revue (« câbler la voie CTOR dans le harnais ») est **VALIDÉ ET ÉTENDU** ;
> **un point de la direction donnée est REFUTÉ** (cf. § « Ce qui a été réfuté »).

## La décision de conception, TRANCHÉE (question ouverte de la revue)

La revue laissait deux issues. **La mesure impose la seconde, et prouve que les deux HIGH sont ANTAGONISTES sous la v1** :

> **Une garde de `toMap()` n'est EXIGIBLE par une machine QUE SI l'`extra` en mémoire peut être POLLUÉ.**
> Or **HIGH-2 exige exactement l'inverse** (l'`extra` en mémoire ne doit JAMAIS porter de clé réservée).
> ⇒ **On ne peut pas rendre la garde de `toMap()` porteuse ET fermer HIGH-2.** L'une des deux gardes est
> nécessairement décorative. **R1 tranche : on garde celle qui porte l'invariant, on SUPPRIME l'autre.**

**Issue retenue = (b), variante « slot stocké BRUT + ACCESSEUR normalisant »** — la seule qui ferme HIGH-2
**sans `assert`, sans `throw` (AD-10), sans perdre `const`** (surface DODLP inchangée) :

```dart
const ZSmartNote({ …, Map<String, dynamic> extra = const {} }) : _extra = extra;   // ctor `const` : ne filtre RIEN
final Map<String, dynamic> _extra;                                                 // slot BRUT (jamais lu ailleurs)
@override
Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);          // 🔴 LA GARDE — toutes les voies la traversent
```

`zNormalizeExtra` (`zcrud_core`) rend **le slot lui-même** s'il est déjà propre (lecture **zéro-copie** — cas de
`fromMap`/`copyWith`, qui normalisent **EAGER**), sinon une **copie dépouillée**. `toMap()` étale l'**ACCESSEUR**
(`...extra`), plus le champ brut.

**Vérifié sur disque** (scénario HIGH-2 de l'orchestrateur, rejoué tel quel) :

```
[CTOR] ZStudyFolder.extra = {}                                  (avant : {is_deleted: true, updated_at: X})
[CTOR] f == fromMap(f.toMap()) ? true                           (avant : false)
[CTOR] Set{f, relu}.length = 1                                  (avant : 2)
[CTOR] ZSmartNote.extra = {}                                    (avant : {is_deleted: true})
[CTOR] zExtraRead(n.extra, 'is_deleted') = null
[ZERO-COPIE] fromMap  : identical(e.extra, e.extra) = true
[ZERO-COPIE] ctor pollué : identical(f.extra, f.extra) = false  ← le témoin (i.3)
```

## Statut des findings

| Finding | Statut | Correctif | Machine qui l'EXIGE désormais |
|---|---|---|---|
| **🔴 HIGH-1** — garde de `toMap()` décorative sur 8/9 | ✅ **CORRIGÉ** | La garde **descend** dans l'**ACCESSEUR** (`zNormalizeExtra`) ; le rappel dans `toMap()`/`toJson()` est **SUPPRIMÉ** (structurellement décoratif — R1). `kExtraWriters` câble **TOUTES** les voies (**15 voies** / 9 entités), dont la voie **`ctor`** — celle qui pollue. | (i.1a)/(i.1b) via la voie `ctor` **+ règle AST (j)** (voies dérivées du DISQUE : le harnais **ne choisit plus** la voie) |
| **🔴 HIGH-2** — ctor nominal = voie NON filtrée (6/9 polluées en mémoire) | ✅ **CORRIGÉ** (dommage réellement fermé, pas « documenté ») | Accesseur normalisant sur les **7** entités à ctor `const` ; les 2 mindmaps (ctor **non-`const`**) filtrent déjà dans leur initializer. **Aucun `assert` ajouté** (AD-10). | (i.1c) — **sans aucune exemption** — via la voie `ctor` |
| **🟠 MAJEUR-1** — `kConstCtorOnlyWriters` auto-exemptante | ✅ **CORRIGÉ par SUPPRESSION** | La liste **n'existe plus** : aucune entité n'a plus besoin d'être exemptée d'(i.1c). Un verrou d'égalité aurait figé une exemption **devenue inutile**. | Test `MAJEUR-1 : (i.1c) n'a AUCUNE liste d'exemption` + (i.1c) inconditionnelle |
| **🟠 MAJEUR-2** — témoin aveugle au writer AUTO-SANITISANT | ✅ **CORRIGÉ (2 filets)** | **(i.3)** (dynamique) : sur une voie `const`, le slot stocké **DOIT** rester pollué ⇒ un writer qui sanitise lui-même le rend propre ⇒ **ROUGE**. **(k)** (AST) : le writer doit passer `extra` **VERBATIM**. | (i.3) + règle AST (k) |
| **🟡 MEDIUM-1** — `kNoValueEqualityProbes` non verrouillée | ✅ **CORRIGÉ** | **Verrou d'égalité FIGÉ** (patron `kLegacyUpdatedAtMirrors`) : `equals({'ZMindmap','ZMindmapNode'})`. | Test `VERROU D'ÉGALITÉ FIGÉ + anti-inertie (MEDIUM-1)` |
| **🔵 LOW-1** — dartdoc `zJsonEquals` sur-promet | ✅ **CORRIGÉ** | « unique implémentation **pour le slot `extra`** » + les 3 `_mapEquals` de configuration **nommés** et leur hors-périmètre justifié. | — (prose, mais désormais EXACTE) |

## Les 4 injections de la revue — REJOUÉES, elles ROUGISSENT

Chaque injection est appliquée sur l'arbre réel, le harnais rejoué (`cd tool/reserved_keys_gate && flutter test`),
puis le fichier **restauré à l'octet** (sha256 identique — vérifié). Baseline : **92/92 VERTS**.
**R2 (isolation) : chaque injection ne fait rougir qu'UN test.**

| # | Injection (revue) | v1 | **v2 (remédiation)** | Assertion qui MORD |
|---|---|---|---|---|
| INJ-A | garde retirée du **`toMap()` de `ZStudyFolder`** → **ré-instanciée** : `toMap()` étale le champ **BRUT** (`..._extra`) au lieu de l'accesseur | 🟢 81/81 | 🔴 **RC=1 · +91 -1** | `[study_folder#ctor] (i.1a) DW-ES22-3 VIOLÉ (PERSISTANCE)` |
| INJ-A′ | **garde de l'ACCESSEUR retirée** (`get extra => _extra;`) | *(n'existait pas)* | 🔴 **RC=1 · +91 -1** | `[study_folder#ctor] (i.1a) DW-ES22-3 VIOLÉ (PERSISTANCE)` |
| INJ-B | garde retirée du **`toJson()` de `ZMindmap`** → **ré-instanciée** : garde retirée de son **initializer** (son unique point de garde) | 🟢 81/81 | 🔴 **RC=1 · +91 -1** | `[ZMindmap#ctor] (i.1a) DW-ES22-3 VIOLÉ (PERSISTANCE)` |
| INJ-D | **`copyWith` de `ZStudyDocument` ne filtre plus** (+ auto-ajout à `kConstCtorOnlyWriters` — **désormais IMPOSSIBLE : la liste n'existe plus**) | 🟢 81/81 | 🔴 **RC=1 · +91 -1** | `[study_document#copyWith] (i.3) … `eagerlyNormalized: true` mais le slot STOCKÉ est POLLUÉ` |
| INJ-E | **writer AUTO-SANITISANT** (voie `ctor`) | 🟢 81/81 | 🔴 **RC=1 · +91 -1** *(harnais)* **et** RC=1 *(gate AST (k))* | `[study_folder#ctor] (i.3) … `eagerlyNormalized: false` — or le slot STOCKÉ est PROPRE` |
| INJ-E′ | **writer AUTO-SANITISANT** (voie `copyWith`) | — | 🟢 92/92 *(harnais)* · 🔴 **RC=1 (gate AST (k))** | `(k) WRITER MENTEUR — study_folder#copyWith : le paramètre `x` doit être transmis VERBATIM` |
| INJ-J | **voie `ctor` retirée** de `kExtraWriters['study_folder']` | — | 🔴 **RC=1 (gate AST (j))** | `(j) VOIE D'ÉCRITURE NON SONDÉE : ZStudyFolder.ctor` |

## R1 appliquée à TOUTES les gardes du diff (pas seulement à celles citées)

Test appliqué à chaque garde : *« si je la retire, QUELLE machine rougit ? »*

| Garde | Machine qui l'exige | Injection |
|---|---|---|
| **Accesseur** `get extra => zNormalizeExtra(_extra, _reservedKeys)` (×7) | (i.1a)/(i.1b)/(i.1c)/(i.3) via voie `ctor` | **INJ-A′** (ZStudyFolder) 🔴 · **INJ-8** (ZSmartNote, « le modèle ») 🔴 |
| `toMap()` étale l'**accesseur** (`...extra`) (×7) | (i.1a) via voie `ctor` | **INJ-A** 🔴 |
| `_sanitizeExtra` dans **`copyWith`** (×6) | **(i.3)** (`eagerlyNormalized: true`) | **INJ-D** 🔴 |
| `_extraFrom(map)` dans **`fromMap`** (×7) | **(i.3b)** — *AJOUTÉE : elle n'était exigée par AUCUNE machine* | **INJ-7** 🔴 (`[study_folder] (i.3b) fromMap ne NORMALISE PLUS extra à l'ENTRÉE`) |
| Filtre dans l'**initializer** du ctor (mindmaps, ×2) | (i.1a)/(i.1c) via voie `ctor` | **INJ-B** 🔴 |
| `voie`/`eagerlyNormalized` des writers | (i.3) + règles AST (j)/(k) | **INJ-E**, **INJ-E′**, **INJ-J** 🔴 |
| Verrou `kNoValueEqualityProbes` | test de verrou d'égalité | — (verrou lui-même) |
| ~~`kConstCtorOnlyWriters`~~ | **SUPPRIMÉE** (garde d'exemption devenue sans objet) | — |
| ~~`_sanitizeExtra` dans `toMap()`/`toJson()`~~ | **SUPPRIMÉE** (aucune machine ne peut l'exiger — démontré) | — |

**Deux gardes retirées, une garde ajoutée, une garde déplacée** — aucune garde du diff final n'est décorative.

## Ce qui a été RÉFUTÉ dans la direction donnée

1. **« Le correctif est DANS LE HARNAIS, PAS DANS LE DOMAINE »** — **partiellement FAUX**. Le harnais seul rend
   HIGH-1 observable, mais **il ne peut pas fermer HIGH-2** : `entity.extra` continuerait de porter `is_deleted`
   en mémoire (`==`, `hashCode`, `Set`, `zExtraRead`, UI). Le domaine **devait** bouger — et le seul geste
   compatible `const` + AD-10 est la **garde d'accesseur**.
2. **Issue (a) de la question ouverte** (« `toMap()` porte la PERSISTANCE, `zExtraRead` porte la LECTURE
   MÉMOIRE ») — **RÉFUTÉE** : `zExtraRead` n'est pas la seule voie de lecture. `entity.extra` (le contrat
   `ZExtensible`), `operator ==`, `hashCode` et toute UI itérant `extra.entries` la contournent. Une promesse
   portée par `zExtraRead` seul serait **une dartdoc qui promet plus que la machine ne tient** — le finding
   suivant. La garde doit être sur **l'accesseur `extra` lui-même**.
3. **« INJ-A/INJ-B doivent rougir »** — elles rougissent, mais **l'injection a dû être RÉ-INSTANCIÉE** : la garde
   qu'elles retiraient (`_sanitizeExtra` dans `toMap()`/`toJson()`) **n'existe plus** — elle est **structurellement
   décorative** dès lors que toutes les voies normalisent (démonstration ci-dessus). L'injection équivalente
   (contourner l'accesseur / retirer la garde de l'accesseur) **rougit**. Garder les deux gardes aurait recréé,
   à l'intérieur même de la remédiation, le défaut que la revue condamne : **une garde qu'aucune machine n'exige.**
4. **MAJEUR-2 n'est PAS entièrement fermable dynamiquement** — **démontré** : sur une voie **filtrante**
   (`copyWith`), l'entité produite est **identique** que le writer ait sanitisé ou que la voie l'ait fait ⇒
   **aucune** assertion sur l'entité ne peut les distinguer (INJ-E′ : harnais **VERT**). Le filet **doit** être
   **statique** ⇒ règle AST **(k)**. Sur une voie `const` (non filtrante), (i.3) le ferme **dynamiquement**.

## Vérif verte finale (rejouée)

`melos run generate` OK · `melos run analyze` **RC=0** (repo-wide) · `melos run verify` **RC=0** (repo-wide) ·
`prove_gates` **41 OK / 0 FAIL** · `graph_proof` OK · `melos list` = **17**.
Tests : **core 922 · harnais 92** *(81 + 11 : 6 voies `ctor` + 4 fixtures (i.3)/HIGH-2/MAJEUR-2 + 1 verrou de voie)* ·
**note 130 · document 129 · flashcard 189 · kernel 108 · firestore 90 · mindmap 110 · generator 102**.

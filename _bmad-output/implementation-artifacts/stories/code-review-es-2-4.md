<!-- Code-review adversariale BMAD — skill réel : bmad-code-review (tool Skill, succès — PAS de fallback disque). -->

# Code-review ES-2.4 — `ZFolderContentsOrder` (ordre de contenu de dossier personnel)

- **Story** : `es-2-4-ordre-contenu-dossier` (Epic ES-2, FR-S7)
- **Statut à la revue** : `review`
- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (**succès** — pas de fallback disque `.claude/skills/bmad-code-review/SKILL.md`).
- **Périmètre du diff** (ES-2.4 seul, working-tree entrelacé avec ES-2.3 non committé) :
  - `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart` (+ `.g.dart` généré)
  - `packages/zcrud_study_kernel/test/z_folder_contents_order_test.dart`
  - `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (barrel : `hide ZFolderContentsOrderZcrud`)
  - `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (liste `hide` : `ZFolderContentsOrder`, `ZFolderContentsOrderExtensionParser`, `kSectionOrdersKey`)
  - `tool/reserved_keys_gate/lib/src/registrars.dart` (câblage R8/D6)

## Verdict : **APPROUVÉ** (aucun finding HIGH / MAJEUR / MEDIUM ; 1 LOW consigné)

Story verte et solide. Le patron ES-2.2b est reproduit intégralement, le canal hors-codegen `section_orders` est correctement réservé/décodé/réémis, l'égalité D5 possède un **pouvoir discriminant OBSERVÉ** sur ses deux axes, et les trois filets (h)/(j)/(canal réservé) **rougissent réellement** quand on les casse. Le seul point relevé (M3 sur la voie ctor `const`) est une caractéristique **pré-existante et cohérente** avec le jumeau explicitement cité — pas une régression.

---

## OBSERVÉ (rejoué réellement sur disque)

### 1. Les trois injections R3 (AC10) — chacune ROUGIT avec le bon message, restauration par édition ciblée (JAMAIS `git checkout`)

Baseline avant injections : `dart test z_folder_contents_order_test.dart` = **+35 All tests passed** ; `dart run scripts/ci/gate_reserved_keys.dart` = **+106 All tests passed** + `OK — clés de sync réservées`.

**Injection (j)** — retrait de la voie `ctor` de `kExtraWriters['folder_contents_order']` (garde `_ctorFolderContentsOrder` non listée) → `flutter test --tags reserved-keys` :
```
00:00 +104 -1: Some tests failed.
  .../reserved_keys_test.dart: AC9 — `kExtraWriters` : couverture BIDIRECTIONNELLE
  (la MACHINE) CHAQUE kind câble la voie `ctor` (la voie NON filtrante)
```
Constaté aussi dans la trace : `folder_contents_order` ne présentait plus QUE la voie `copyWith` (+48), la voie `ctor` disparue. **RC ≠ 0** (`Some tests failed`). Restauré → vert.

**Injection (h)** — retrait de `hide ZFolderContentsOrderZcrud` du barrel kernel → `gate_reserved_keys.dart` (volet AST) :
```
[gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : `ZFolderContentsOrderZcrud`
est exposée par le point d'entrée public packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart
(`export 'src/domain/z_folder_contents_order.dart';` sans `hide`), alors que
`ZFolderContentsOrder` est `ZExtensible`.
[gate:reserved-keys] 1 violation(s) — AD-19.1.
```
Restauré → vert.

**Injection (canal réservé)** — retrait de `kSectionOrdersKey` de `_reservedKeys` → `dart test z_folder_contents_order_test.dart` :
```
00:00 +2 -1: round-trip PLEIN : fromMap(toMap(x)) == x [E]
00:00 +4 -2: section_orders TOUJOURS émise, même {} (idempotence) [E]
00:00 +4 -3: section_orders décodée depuis la map, jamais dans extra [E]
  Expected: false
    Actual: <true>          ← la clé du canal fuit DANS extra (double émission)
00:00 ... Some tests failed.
```
Restauré → vert.

**Conclusion (j)/(h)/(canal)** : les trois filets ont un **pouvoir discriminant réel** — aucun n'est décoratif.

### 2. 🔴 PIÈGE D5 (égalité ordre-sensible) — le `==` ET le `hashCode` sont RÉELLEMENT ordre-sensibles, prouvés par DEUX rouges provoqués

Le motif dominant (un golden qui passe par coïncidence) a été attaqué frontalement, **en isolant chaque jambe** :

**D5a — jambe `==`** : `_listEquals` rendu ensembliste (tri-puis-compare) →
```
00:00 +0 -1: ordre-SENSIBLE dans une liste : [a,b] != [b,a] (INÉGALES + hash≠) [E]
  Expected: not <Instance of 'ZFolderContentsOrder'>
    Actual: <Instance of 'ZFolderContentsOrder'>     ← x == y à tort
```
Seule « ordre-SENSIBLE » rougit ; « ordre-INSENSIBLE entre sections », « folderId discriminant » et « extra profond » restent **VERTS** ⇒ le test isole exactement l'ordre-sensibilité intra-liste. Restauré (positionnel) → vert.

**D5b — jambe `hashCode`** : hash intérieur de liste rendu COMMUTATIF (`Σ e.hashCode` au lieu de `Object.hashAll`) →
```
00:00 +0 -1: ordre-SENSIBLE dans une liste : [a,b] != [b,a] (INÉGALES + hash≠) [E]
  Expected: not <479946875>
    Actual: <479946875>      ← les deux instances collapsent sur le MÊME hash
```
La jambe `==` passe (positionnel restauré), c'est **purement la jambe `hashCode`** qui rougit ; « ordre-INSENSIBLE » reste verte. Restauré (`Object.hashAll(entry.value)`) → vert.

**Réponse à la question posée** : **OUI**, le `==` est réellement ordre-sensible dans une liste, et le `hashCode` l'est aussi — chacun **prouvé par un rouge provoqué distinct**, et non par coïncidence. Le hash extérieur reste bien **commutatif entre sections** (somme sur les clés). Ce n'est PAS un golden fortuit.

### 3. Reprise du working-tree partiel — voie `ctor` bien câblée (vérif demandée)

`tool/reserved_keys_gate/lib/src/registrars.dart` l.439-450 : `kExtraWriters['folder_contents_order']` liste **`[ctor, copyWith]`** — `_ctorFolderContentsOrder` (l.619-627, `eagerlyNormalized: false`) **ET** `_copyWithFolderContentsOrder` (l.479-480, `eagerlyNormalized: true`), tous deux transmettant `extra` **VERBATIM** (règle (k)). Le défaut résiduel signalé par le dev (voie `ctor` manquante) est **effectivement corrigé** : l'injection (j) ci-dessus prouve que la voie ctor est désormais SONDÉE. Aucune autre incohérence de reprise détectée (les 4 références aux writers ES-2.4 sont présentes et cohérentes).

### 4. Autres vérifications adversariales rejouées

- **Décodage défensif AD-10 à 2 niveaux** (AC3) : `fromMap(const {})` sans throw ; `section_orders` = `42`/`"x"`/liste/absente ⇒ `{}` ; `{"a":7}` ⇒ section ignorée ; `["x",3,null]` ⇒ `["x"]` (ordre relatif préservé). **Tests passants observés** (35/35).
- **Canal hors-codegen (D3)** : `.g.dart` — `_$ZFolderContentsOrderFromMap` ne décode **QUE** `folder_id` (l.175-178), `ZFolderContentsOrderZcrud.toMap()` n'émet **QUE** `folder_id` (l.182) ; aucune branche `Map`. Le `Map` `section_orders` est intégralement manuel (`_decodeSectionOrders`/`_encodeSectionOrders`). `toMap` d'instance émet TOUJOURS `section_orders` (idempotence) et étale l'**accesseur** `...extra` (l.229). **CONFIRMÉ.**
- **AC7 anti-vacuité / AD-19** : clé inconnue `zz_cle_inconnue` survit fromMap+toMap ; `updated_at`/`is_deleted` ni dans `extra` ni réémis ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` (l.362-367) ; `$FieldSpecs ∩ ZSyncMeta.reservedKeys == {}` ; `kLegacyUpdatedAtMirrors` **inchangé** = `{study_folder, flashcard}` (registrars l.262). **CONFIRMÉ (tests + lecture).**
- **AC8 pollution ctor** : `ZFolderContentsOrder(extra:{'is_deleted':true, 'section_orders':{}, 'ok':1}).extra` = `{ok:1}` (réservées filtrées par l'accesseur), `x == fromMap(x.toMap())`. **Test passant.**
- **copyWith à sentinelle** (l.247-269) : couvre `folderId`/`sectionOrders`/`extension`/`extra`, `_$undefined` ; `extra` re-sanitisé par `_sanitizeExtra` (même fonction que `fromMap`) ; `sectionOrders` re-gardé M3 par `_guardSectionOrders`. **CONFIRMÉ.**
- **Réutilisation `applyOrder` (D4)** : `applyTo` (l.283-294) **délègue** à `applyOrder<T>` d'ES-1.2, aucune primitive d'intégrité neuve. Vecteurs discriminants passants (`['c','a']`⇒`[c,a,b,d]` end / `[b,d,c,a]` start ; id fantôme ignoré ; doublon 1re occurrence). **CONFIRMÉ.**
- **Périmètre (AC14)** : fichiers ES-2.4-neufs = `z_folder_contents_order.dart(.g.dart)` + son test uniquement ; aucune ligne dans `zcrud_core`/`zcrud_firestore`/lex/iffd, aucun widget, aucun repository. Le diff de `z_kernel_surface_guard_test.dart` (7 lignes) est du **résidu ES-2.3** (ZFlashcardTag/ZSuggestedTag/remapColorKey/orphanTagIds), pas ES-2.4 : les symboles ES-2.4 sont classés par la liste `hide` du barrel flashcard (que la garde lit directement), aucune édition du test requise. **CONFIRMÉ.**
- **Acyclicité (AC13)** : `packages/zcrud_study_kernel/pubspec.yaml` dependencies = `{zcrud_core, zcrud_annotations}` — aucune arête satellite (AD-1/AD-17). **CONFIRMÉ.**
- **AC12 gate:web** : `z_folder_contents_order_test.dart` n'importe que `test` / `zcrud_core/domain.dart` / `zcrud_study_kernel` ; les 2 occurrences de `dart:io` sont dans le **commentaire d'en-tête** (l.5-6), aucun import. **CONFIRMÉ.**

---

## Findings

### LOW-1 — L'immuabilité M3 de `sectionOrders` est **CONDITIONNELLE** : la voie du constructeur nominal `const` (invoqué non-`const` avec une `Map` mutable) laisse la liste interne mutable

- **Fichier** : `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart` — ctor l.137-146 ; champ `sectionOrders` l.189 (`final Map<String, List<String>>` **sans accesseur normalisant**, contrairement à `extra` l.204).
- **Scénario OBSERVÉ (sonde ad hoc rejouée)** :
  ```
  final mutable = {'a': ['x','y']};
  final o = ZFolderContentsOrder(folderId:'f', sectionOrders: mutable); // non-const
  o.sectionOrders['a']!.add('z');   // ⇒ mutatedViaGetter=true (PAS de throw)
  mutable['a']!.add('EXT');          // mutation via la réf externe retenue
  // ⇒ order = [x, y, z, EXT] ; o.hashCode a CHANGÉ (hashChanged=true)
  ```
  L'instance est donc mutable en place ⇒ **exactement la menace M3 décrite par la story** (« perdrait l'instance dans son propre `Set` »), mais **sur la voie ctor**, que le test M3 (AC3) ne sonde PAS — il ne couvre que `fromMap` et `copyWith`.
- **Pourquoi LOW (et non MEDIUM/régression)** :
  1. **Le vecteur de perte de données persistantes est FERMÉ** : le store décode toujours via `fromMap` (gardé, `List.unmodifiable` en profondeur, l.302-320). Round-trip et double-émission restent sûrs. L'exposition est un **hasard in-memory**, pas une perte au store.
  2. **Cohérence avec le jumeau EXPLICITEMENT cité** : `ZDocumentLearningInfo` (ES-2.1) a le **même** trou documenté — `const ZDocumentLearningInfo({this.qualityByPage = const {}})` (l.57) « **Ne filtre pas** [qualityByPage] : un constructeur `const` ne le peut » (l.46), garde uniquement à `fromJson`/`copyWith`. C'est un **tradeoff `const`-ctor pré-existant à l'échelle du repo**, pas une divergence ES-2.4.
  3. Une invocation **`const`** (idiomatique, cohérente avec le défaut `const {}` du champ) fige des collections `const` **déjà immuables** ; seule l'invocation **non-`const` avec une réf mutable retenue** est vulnérable — un motif contrôlé, non-persistant.
- **Réserve honnête** : la formulation « immuabilité **PROFONDE** M3 » d'AC3/DoD **surpromet** légèrement (la garantie est inconditionnelle pour `extra` via son accesseur, mais **conditionnelle** pour `sectionOrders`). Rendre la garantie inconditionnelle exigerait un accesseur normalisant (`get sectionOrders => Map.unmodifiable(...)`) ou un champ privé + getter — un **changement de conception** hors périmètre S, à trancher au niveau du **patron** (avec le jumeau `ZDocumentLearningInfo`), pas de cette story isolée.
- **Recommandation** : **consigner** (dette de patron, à statuer en rétro ES-2 avec `DW-ES22-*`) ; ne PAS bloquer `done`. Aucune correction ES-2.4 requise (corriger ici seul créerait une incohérence avec le jumeau).

---

## Notes / nits (non bloquants, non comptés)

- **Duplication `_asStringMap`** (entité l.437-447) ≈ `_$asStringMap` généré (`.g.dart` l.149-159). Le doublon isole l'entité des internes du codegen (choix défendable) ; sinon dé-dupliquer vers un helper de `zcrud_core`. Trivial.
- `_sectionOrdersEquals` (l.407-409) : la double garde `other == null` est légèrement redondante (les valeurs sont non-null `List<String>`) mais **correcte et défensive**. Aucune action.

---

## Traçabilité DoD

| DoD | État |
|---|---|
| Patron ES-2.2b intégral (AC1) | ✅ (lu + tests) |
| Canal `section_orders` réservé, décodage 2 niveaux, round-trip idempotent (AC2/AC3) | ✅ (tests + injection canal) |
| `applyTo` délègue à `applyOrder`, intégrité gratuite (AC4) | ✅ (vecteurs discriminants) |
| Égalité D5 ordre-sensible-liste / insensible-sections (AC5) | ✅ **OBSERVÉ par 2 rouges provoqués** |
| AD-19 zéro clé de sync (AC6/AC7/AC8) | ✅ |
| Câblage gate (ctor+copyWith VERBATIM), `kLegacyUpdatedAtMirrors` inchangé (AC9) | ✅ |
| 3 injections R3 rougissent + restauration verte (AC10) | ✅ **REJOUÉ** |
| Barrel `hide` + surface-guard (AC11) | ✅ |
| Tests `dart test`, zéro `dart:io` (AC12) | ✅ |
| Vérif verte repo-wide, `.g.dart` committé, acyclique (AC13) | ✅ (déjà rejoué par l'orchestrateur) |
| Périmètre kernel + gate + hide (AC14) | ✅ |
| Immuabilité **PROFONDE** M3 | 🟡 **LOW-1** — conditionnelle (voie ctor non gardée), cohérente avec le jumeau |

**Décision** : aucune correction obligatoire (0 HIGH/MAJEUR/MEDIUM). LOW-1 consigné comme dette de patron. La story peut transiter `review → done`.

---

## Statut orchestrateur (post-revue)

**LOW-1 — NON corrigé dans ES-2.4, consigné en dette de PATRON `DW-ES24-1`** (sprint-status). Justification (validée par l'orchestrateur sur disque) :
- Le dartdoc du **code** est déjà honnête (champ `sectionOrders` l.184 : « non modifiable en profondeur *dès lors qu'elle vient de fromMap/copyWith* ») et le test M3 (AC3) ne sonde QUE les voies gardées (`fromMap`/`copyWith`) — donc **aucun filet décoratif**, pas de faux-vert : la surpromesse est un libellé d'AC légèrement optimiste, pas un test sans pouvoir discriminant.
- Le vecteur de perte persistante est **FERMÉ** (le store décode via `fromMap` gardé — `List.unmodifiable` en profondeur).
- Le fix inconditionnel (accesseur normalisant sur `sectionOrders`, à la manière de `extra`) est un **changement de PATRON repo-wide** partagé avec `ZDocumentLearningInfo`, `ZDocumentReadingState`, `ZSmartNote` — le corriger dans la seule ES-2.4 créerait une **incohérence de patron**. À trancher uniformément en rétrospective ES-2 (`DW-ES24-1`).

**Vérif verte re-scellée par l'orchestrateur (R9)** : generate OK · analyze RC=0 repo-wide · gate:reserved-keys RC=0 · prove_gates 41 OK/0 FAIL · graph_proof ACYCLIQUE+CORE OUT=0 · tests kernel 196.

**Verdict final : ✅ 0 finding bloquant.** LOW-1 → dette de patron consignée (non reporté silencieusement).

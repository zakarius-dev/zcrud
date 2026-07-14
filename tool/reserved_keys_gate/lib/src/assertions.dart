/// Assertions RÉUTILISABLES du volet (A) comportemental du gate AD-19.1.c.
///
/// Une entité de domaine ne capture **JAMAIS** les clés réservées à la couche
/// de synchronisation (`ZSyncMeta.reservedKeys` = `updated_at` / `is_deleted`)
/// dans son échappatoire `extra` (AD-4) et ne les réémet **JAMAIS** depuis son
/// `toMap`/`toJson` : elles appartiennent au **store**, pas au domaine (AD-16).
///
/// Les 2 findings **HIGH** d'ES-1.3 (`ZRepetitionInfo`, `ZStudySessionConfig`
/// polluant `extra`) sont passés **sous 1193 tests verts** : la protection ne
/// peut donc pas reposer sur la vigilance, seulement sur la machine.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'registrars.dart';

/// Clé inconnue du cœur injectée dans chaque sonde : sert d'ORACLE de
/// non-régression du round-trip AD-4 (assertion (b)). Sans elle, une entité
/// pourrait « passer le gate » en **vidant** `extra` — ce qui satisferait (a)
/// tout en détruisant l'échappatoire d'extension.
const String kProbeUnknownKey = 'zz_cle_inconnue';

/// Valeur attendue au round-trip de [kProbeUnknownKey].
const String kProbeUnknownValue = 'gardee';

/// Horodatage injecté sous la clé réservée `updated_at` dans chaque sonde.
const String kProbeUpdatedAt = '2026-01-01T00:00:00.000Z';

/// Sonde POLLUÉE d'un kind : corps métier minimal valide + les **deux** clés
/// réservées (`updated_at`, `is_deleted`) écrites par le store **dans le corps**
/// du document + une clé **inconnue** du cœur.
///
/// C'est exactement la map qu'un store passe à `fromMap` en lecture (le store
/// écrit ses métadonnées dans le corps, cf. AD-19.2 pt.1).
Map<String, dynamic> buildProbe(Map<String, dynamic> body) => <String, dynamic>{
      ...body,
      ZSyncMeta.kUpdatedAt: kProbeUpdatedAt,
      ZSyncMeta.kIsDeleted: true,
      kProbeUnknownKey: kProbeUnknownValue,
    };

/// Assertions **(a)** et **(b)** — état interne de l'entité DÉCODÉE.
///
/// - **(a)** : `extra` ne contient AUCUNE clé de `ZSyncMeta.reservedKeys` ;
/// - **(b)** : `extra[kProbeUnknownKey] == kProbeUnknownValue` (round-trip AD-4
///   non régressé).
///
/// **Piège n°1 (spec figée corrigée, ES-1.4)** : AD-19.1.c prescrivait
/// `(e as ZExtensible).extra` — or `ZChoice` est enregistrée (`flashcard_choice`)
/// **sans** être `ZExtensible` : le cast **throw**. Les kinds non extensibles
/// n'ont pas d'`extra` : ils ne sont donc pas concernés par (a)/(b).
///
/// ## ⚠️ [expectExtensible] — anti-vacuité (L1, code-review ES-1.4)
///
/// La v1 faisait un **early-return SILENCIEUX** sur une entité non-`ZExtensible`.
/// Conséquence : si un registrar était un jour recâblé (faute de frappe,
/// refactor) vers un type qui n'est **pas** `ZExtensible`, (a) et (b) devenaient
/// **vacuellement vertes SANS LE MOINDRE SIGNAL** — le défaut même que ce gate
/// combat. Le skip est désormais **DÉCLARÉ** : l'appelant dit s'il ATTEND une
/// entité extensible, et tout écart (attendue extensible mais ne l'est pas, ou
/// l'inverse : la liste `kNonExtensibleKinds` a pourri) est **ROUGE**.
///
/// ## 🔴 [probeBody] — assertion **(f)** (H1, code-review ES-2.1)
///
/// Le **corps de sonde** ne contient, **par construction**, que des clés que le
/// domaine **CONNAÎT** : champs de schéma (`@ZcrudField`) + **canaux
/// hors-codegen** (`source`, `learning` — décodés/réémis à la main, clé
/// RÉSERVÉE). `extra`, lui, est l'échappatoire des clés **INCONNUES** du domaine
/// (AD-4).
///
/// ⇒ **Trouver une clé du corps de sonde DANS `extra` PROUVE qu'un canal a été
/// oublié dans `_reservedKeys`.** C'est un invariant **GÉNÉRIQUE, piloté par les
/// sondes** : il couvre `source` **et** `learning` **et tout canal futur**
/// (ES-2.2 `ZSmartNote.content`, ES-2.5…) **sans une ligne de code par entité** —
/// là où le repo n'avait que des tests **artisanaux, par canal, dans deux
/// packages différents**, dont AUCUN n'était exigé par une machine (R1 violé).
///
/// **Le fait mesuré** : sans (f), retirer `kLearningKey` de `_reservedKeys`
/// laissait le **gate VERT** — aucune des assertions (a)…(e) ne regarde une clé
/// du CORPS de sonde ((a)/(c)/(d) ne voient que `ZSyncMeta.reservedKeys`, (b)/(e)
/// que l'unique [kProbeUnknownKey]). La sonde **TRANSPORTAIT** le canal ; **rien
/// ne l'OBSERVAIT**.
///
/// **Ses DENTS viennent de la règle (g)** du volet AST
/// (`scripts/ci/gate_reserved_keys.dart`) : tout canal hors-codegen déclaré
/// **DOIT** figurer dans `kProbeBodies[kind]`. Sans (g), (f) se désactiverait en
/// **vidant la sonde**.
void assertExtraClean({
  required String label,
  required Object entity,
  required bool expectExtensible,
  required Map<String, dynamic> probeBody,
}) {
  if (entity is! ZExtensible) {
    // Skip EXPLICITE, jamais silencieux : il doit être ATTENDU (`ZChoice`).
    expect(
      expectExtensible,
      isFalse,
      reason:
          '[$label] VACUITÉ : le kind est attendu `ZExtensible` (il n\'est pas '
          'dans `kNonExtensibleKinds`) mais l\'entité décodée ne l\'est PAS '
          '(${entity.runtimeType}). Les assertions (a)/(b) seraient passées à la '
          'trappe SANS SIGNAL — vérifiez le registrar câblé dans '
          '`kRegistrars` (registrars.dart) et `kNonExtensibleKinds`.',
    );
    return;
  }
  // Sens inverse : un kind listé comme NON extensible qui l'est devenu ⇒ la
  // liste est PÉRIMÉE et exempterait à tort une entité de (a)/(b).
  expect(
    expectExtensible,
    isTrue,
    reason:
        '[$label] `kNonExtensibleKinds` est PÉRIMÉE : ce kind y figure alors que '
        'son entité EST `ZExtensible` — retirez-le, sinon (a)/(b) ne seraient '
        'plus exercées sur elle.',
  );
  final extra = entity.extra;

  // (a) — aucune clé de sync capturée dans l'échappatoire.
  //
  // Le « dépouillement » est délégué à `ZSyncMeta.stripReserved` (solde **L4** :
  // le helper n'avait aucun appelant) : les assertions ne re-dérivent PAS la
  // notion de clé réservée, elles la CONSOMMENT — si `ZSyncMeta` gagne une clé,
  // le gate la couvre sans édition.
  final stripped = ZSyncMeta.stripReserved(extra);
  final polluted = extra.keys.toSet().difference(stripped.keys.toSet());
  expect(
    polluted,
    isEmpty,
    reason:
        '[$label] (a) AD-19.1 VIOLÉ : les clés réservées $polluted ont été '
        'capturées dans `extra`. Ajoutez `...ZSyncMeta.reservedKeys` à '
        '`_reservedKeys` de l\'entité (la clé ne doit pas pouvoir ENTRER dans '
        '`extra`, donc plus en ressortir).',
  );

  // (b) — le round-trip AD-4 n'a pas été « réparé » en vidant `extra`.
  expect(
    extra[kProbeUnknownKey],
    kProbeUnknownValue,
    reason:
        '[$label] (b) AD-4 RÉGRESSÉ : la clé inconnue `$kProbeUnknownKey` n\'a '
        'pas survécu au décodage. `extra` doit PRÉSERVER les clés inconnues du '
        'cœur — on ne passe pas (a) en vidant `extra`.',
  );

  // (f) — AUCUNE clé du CORPS DE SONDE ne doit atterrir dans `extra`.
  assertProbeBodyNotInExtra(label: label, extra: extra, probeBody: probeBody);

  // ═══ (i.3b) — NORMALISATION EAGER À L'ENTRÉE (R1, remédiation ES-2.2b) ════
  //
  // Sans cette assertion, la garde de `fromMap` (`extra: _extraFrom(map)`) ne
  // serait exigée par **AUCUNE** machine — donc DÉCORATIVE (R1) : depuis que
  // l'ACCESSEUR normalise, passer la map BRUTE (`extra: map`) donnerait le MÊME
  // `extra` observable… au prix d'un slot stocké qui retient TOUT le document
  // persisté et d'une COPIE à chaque lecture d'`extra`.
  //
  // La lecture zéro-copie (`identical`) OBSERVE, de l'extérieur, que le slot
  // STOCKÉ est bien déjà propre. C'est le pendant d'(i.3) sur la frontière
  // d'ENTRÉE (même mécanique : `zNormalizeExtra` rend le slot LUI-MÊME s'il est
  // propre, une copie dépouillée sinon).
  expect(
    identical(entity.extra, entity.extra),
    isTrue,
    reason:
        '[$label] (i.3b) `fromMap` ne NORMALISE PLUS `extra` à l\'ENTRÉE : le slot '
        'STOCKÉ porte encore des clés réservées (l\'accesseur doit COPIER à chaque '
        'lecture).\n'
        '\n'
        'L\'invariant tient encore (l\'ACCESSEUR filtre), mais la garde de `fromMap` '
        'est devenue INERTE : le slot brut retient les clés de STORE et le SCHÉMA '
        'entier du document, et chaque lecture d\'`extra` alloue.\n'
        '\n'
        'GESTE : `extra: _extraFrom(map)` (clés NON réservées de la map) dans la '
        'factory de DOMAINE.',
  );
}

/// Assertion **(f)** — le CORPS DE SONDE n'a **AUCUNE** clé dans `extra`
/// (H1, code-review ES-2.1). Générique : **zéro code par entité**.
///
/// Le corps de sonde ne porte que des clés **connues du domaine** (schéma +
/// canaux hors-codegen). `extra` ne porte que des clés **inconnues** (AD-4).
/// L'intersection est donc **structurellement vide** — et toute intersection non
/// vide **NOMME le canal oublié** dans `_reservedKeys`.
void assertProbeBodyNotInExtra({
  required String label,
  required Map<String, dynamic> extra,
  required Map<String, dynamic> probeBody,
}) {
  final leaked = extra.keys.toSet().intersection(probeBody.keys.toSet());
  expect(
    leaked,
    isEmpty,
    reason:
        '[$label] (f) CANAL HORS-CODEGEN OUBLIÉ : la/les clé(s) $leaked du CORPS '
        'DE SONDE ont été capturées dans `extra`.\n'
        '\n'
        'Le corps de sonde ne contient QUE des clés que le domaine CONNAÎT '
        '(champs `@ZcrudField` du schéma + canaux hors-codegen décodés/réémis à '
        'la main). `extra` (AD-4) ne doit contenir que les clés INCONNUES du '
        'domaine. Trouver l\'une des premières parmi les secondes PROUVE qu\'une '
        'clé connue n\'est PAS RÉSERVÉE.\n'
        '\n'
        'CONSÉQUENCE (silencieuse, sans cette assertion) : la clé est réémise '
        'DEUX FOIS par `toMap()` (une par `...extra`, une par le câblage manuel), '
        'l\'`==` entre une instance mémoire et la même relue du store CASSE, et '
        'le round-trip du store n\'est plus IDEMPOTENT.\n'
        '\n'
        'GESTE : ajouter ces clés à `_reservedKeys` de l\'entité (patron '
        '`ZFlashcard.source` / `ZDocumentReadingState.learning` = `kLearningKey`). '
        'Le volet AST du gate le vérifie aussi — règle (g1).',
  );
}

/// Assertion **(e)** — ROUND-TRIP COMPLET de la clé inconnue (DW-ES14-1, AD-4).
///
/// `decode → encode` doit **réémettre** [kProbeUnknownKey]. C'est l'assertion qui
/// **solde DW-ES14-1** : tant que le registrar généré câblait `_$ZXxxFromMap`
/// (factory du **codegen**, aveugle au canal hors-codegen `extra`), la voie
/// registre rendait une entité à `extra == {}` — et `toMap()` (`{...extra, …}`)
/// ne pouvait donc **jamais** réémettre la clé : **destruction irréversible** à
/// chaque cycle lecture → écriture d'un store câblé sur `registry.decode`.
///
/// ## Pourquoi (e) NE PEUT PAS s'appliquer « à chaque kind » (D3)
///
/// La lettre d'AD-19.1.c / de la rétro dit « pour chaque kind ». **Pris au pied
/// de la lettre, c'est FAUX** : `ZChoice` (kind `flashcard_choice`) est
/// enregistrée mais n'est **pas** `ZExtensible` — elle ne peut structurellement
/// pas préserver une clé inconnue, et (e) serait **ROUGE À JAMAIS** sur elle.
/// (e) s'applique donc **exactement** là où (a)/(b) s'appliquent.
///
/// Le saut est **DÉCLARÉ, jamais silencieux** (patron L1) : il est vérifié dans
/// les **deux** sens contre le type réel de l'entité décodée — un `expectExtensible`
/// faux sur une entité qui EST `ZExtensible` (liste `kNonExtensibleKinds` périmée)
/// exempterait à tort ce kind de (e) ⇒ **ROUGE**.
void assertUnknownKeyRoundTrip({
  required String label,
  required Object entity,
  required Map<String, dynamic> encoded,
  required bool expectExtensible,
}) {
  if (!expectExtensible) {
    // Skip EXPLICITE (`ZChoice`) : contrôlé contre le type RÉEL — une entité
    // `ZExtensible` déclarée non extensible serait exemptée à tort de (e).
    expect(
      entity,
      isNot(isA<ZExtensible>()),
      reason:
          '[$label] (e) SKIP NON DÉCLARÉ : ce kind est listé dans '
          '`kNonExtensibleKinds` alors que son entité EST `ZExtensible` — (e) '
          'serait sautée SANS SIGNAL et la destruction d\'`extra` (DW-ES14-1) '
          'redeviendrait invisible. Retirez-le de la liste.',
    );
    return;
  }
  expect(
    entity,
    isA<ZExtensible>(),
    reason:
        '[$label] (e) VACUITÉ : le kind est attendu `ZExtensible` mais l\'entité '
        'décodée ne l\'est pas (${entity.runtimeType}) — le round-trip AD-4 ne '
        'serait pas exercé.',
  );
  expect(
    encoded[kProbeUnknownKey],
    kProbeUnknownValue,
    reason:
        '[$label] (e) DW-ES14-1 / AD-4 VIOLÉ : la clé inconnue '
        '`$kProbeUnknownKey` n\'a PAS survécu au round-trip '
        '`registry.decode → registry.encode` — elle est DÉTRUITE. Un store câblé '
        'sur cette voie EFFACERAIT toutes les clés métier inconnues du schéma, à '
        'chaque cycle lecture → écriture.\n'
        '\n'
        'OÙ CHERCHER — dans cet ordre (H1, code-review ES-2.0 : le `reason` de la '
        'v1 accusait le GÉNÉRATEUR, alors que le registrar peut être parfaitement '
        'correct et la faute être DANS LA FACTORY DE DOMAINE. Il envoyait le '
        'mainteneur au mauvais endroit) :\n'
        '  1. **La factory de DOMAINE `ZXxx.fromMap` de l\'entité** — cause la '
        'plus probable. Peuple-t-elle `extra` (`extra: _extraFrom(map)`) ? Une '
        'factory qui délègue nuement à `_\$ZXxxFromMap`, ou qui recopie les champs '
        'en OUBLIANT `extra:`, laisse `extra` VIDE. ⚠️ Ce cas devrait déjà avoir '
        'été attrapé EN AMONT : le build le refuse (délégation nue) et le garde '
        '`_\$zRequireExtraPreserved` émis dans le `.g.dart` lève à '
        'l\'enregistrement. Si (e) rougit SEULE ici, c\'est que ces deux filets '
        'ont été contournés — le dire dans le rapport.\n'
        '  2. **Le `toMap()` d\'INSTANCE de l\'entité** — a-t-il cessé d\'étaler '
        '`...extra` ? (Le `toMap()` GÉNÉRÉ, lui, n\'étale JAMAIS `extra`.)\n'
        '  3. **Le registrar généré** (`zcrud_generator`) — câble-t-il encore '
        '`fromMap: ZXxx.fromMap` (DOMAINE) et non `_\$ZXxxFromMap` (CODEGEN) ? '
        'C\'est la régression d\'origine de DW-ES14-1, désormais la MOINS '
        'probable des trois.',
  );
}

/// Assertions **(c)** et **(d)** — map ENCODÉE (`toMap`/`toJson`).
///
/// - **(c)** : `is_deleted` n'est **JAMAIS** réémis — **aucune exception,
///   aucun kind** (y compris les miroirs legacy) ;
/// - **(d)** : `updated_at` n'est pas réémis, **sauf** si [legacyMirrorAllowed]
///   (allowlist `kLegacyUpdatedAtMirrors`, portée MINIMALE : (d) seule).
void assertEncodedClean({
  required String label,
  required Map<String, dynamic> encoded,
  required bool legacyMirrorAllowed,
}) {
  // (c) — sans aucune exception.
  expect(
    encoded.containsKey(ZSyncMeta.kIsDeleted),
    isFalse,
    reason:
        '[$label] (c) AD-19.1 VIOLÉ : l\'encodage réémet `${ZSyncMeta.kIsDeleted}` '
        '— préoccupation de STORE qui fuit dans le domaine (AD-16). Aucun kind '
        'n\'est exempté de (c), miroirs legacy compris.',
  );

  // (d) — allowlist legacy strictement bornée.
  if (legacyMirrorAllowed) {
    // Anti-inertie : une entrée d'allowlist qui n'émet PLUS `updated_at` est
    // MORTE → elle doit sortir de `kLegacyUpdatedAtMirrors` (sinon l'allowlist
    // se fossilise et couvre un jour une VRAIE régression).
    expect(
      encoded.containsKey(ZSyncMeta.kUpdatedAt),
      isTrue,
      reason:
          '[$label] (d) ENTRÉE MORTE dans `kLegacyUpdatedAtMirrors` : ce kind '
          'n\'émet plus `${ZSyncMeta.kUpdatedAt}` — retirez-le de l\'allowlist '
          '(anti-inertie, D3 pt.3).',
    );
    return;
  }
  expect(
    encoded.containsKey(ZSyncMeta.kUpdatedAt),
    isFalse,
    reason:
        '[$label] (d) AD-19.1 VIOLÉ : l\'encodage réémet `${ZSyncMeta.kUpdatedAt}` '
        'hors allowlist. L\'autorité Last-Write-Wins est `ZSyncMeta.updatedAt` '
        '(HORS-entité) : le domaine ne réémet pas cette clé. Si c\'est un miroir '
        'de compat assumé, c\'est une DÉCISION D\'ARCHITECTURE (AD-19.2), pas un '
        'ajout discret à `kLegacyUpdatedAtMirrors`.',
  );
}

/// Les **6** assertions (a)(b)(c)(d)(e)**(f)** d'AD-19.1.c sur une entité décodée
/// depuis une sonde polluée et ré-encodée.
///
/// [encoded] provient de la **voie registre** (`registry.encode`) sur une entité
/// décodée par la **voie registre** (`registry.decode`) — c'est LA voie que
/// `FirebaseZRepositoryImpl.fromRegistry` emprunte, donc celle qu'il faut garder.
///
/// [expectExtensible] : l'entité DOIT-elle être `ZExtensible` ? (cf. L1 —
/// le skip de (a)/(b)/(e) est DÉCLARÉ, jamais silencieux).
///
/// [probeBody] : le corps **métier** de la sonde (avant pollution par
/// [buildProbe]) — consommé par **(f)** (H1, ES-2.1 : les canaux hors-codegen
/// n'étaient TRANSPORTÉS par aucune assertion). Il est **REQUIS** : un paramètre
/// optionnel se serait oublié en silence, et (f) serait redevenue vacuelle — la
/// faute exacte que ce gate combat.
void assertReservedKeysClean({
  required String label,
  required Object entity,
  required Map<String, dynamic> encoded,
  required bool legacyMirrorAllowed,
  required bool expectExtensible,
  required Map<String, dynamic> probeBody,
}) {
  assertExtraClean(
    label: label,
    entity: entity,
    expectExtensible: expectExtensible,
    probeBody: probeBody,
  );
  assertEncodedClean(
    label: label,
    encoded: encoded,
    legacyMirrorAllowed: legacyMirrorAllowed,
  );
  assertUnknownKeyRoundTrip(
    label: label,
    entity: entity,
    encoded: encoded,
    expectExtensible: expectExtensible,
  );
}

// ===========================================================================
// 🔴 ES-2.2b — (i.1) et (i.2) : LES DEUX ANGLES MORTS STRUCTURELS DU GATE.
//
// Les 6 assertions (a)…(f) sondent TOUTES `fromMap` / `registry.decode` — la
// frontière d'ENTRÉE. **AUCUNE ne regarde une voie d'ÉCRITURE applicative**, et
// aucune ne regarde l'ÉGALITÉ. Ce ne sont pas des oublis ponctuels : ce sont
// deux angles morts STRUCTURELS, et 8 entités sur 9 étaient cassées dessous.
// ===========================================================================

/// Horodatage **POLLUANT** injecté par (i.1) dans l'`extra` ÉCRIT.
///
/// Volontairement DIFFÉRENT de [kProbeUpdatedAt] (la pollution de la sonde
/// d'entrée) : ainsi, sous allowlist legacy, on peut discriminer **sur la
/// VALEUR** — un `updated_at` réémis depuis le CHAMP MÉTIER est LÉGITIME ;
/// le même réémis depuis la POLLUTION d'`extra` est la VIOLATION.
const String kWritePollutionUpdatedAt = '1999-01-01T00:00:00.000Z';

/// Clé **TÉMOIN D'ÉCRITURE** (non réservée) injectée dans l'`extra` écrit.
const String kExtraWriteWitnessKey = 'zz_temoin_ecriture';

/// Valeur attendue du témoin au ré-encodage.
const String kExtraWriteWitnessValue = 'ecriture-reelle';

/// Clé **TÉMOIN IMBRIQUÉ** d'(i.2) — porte une `Map` **ET** une `List`.
const String kProbeNestedKey = 'zz_imbrique';

/// Valeur imbriquée d'(i.2) : `Map` + `List` + `Map` dans la `List`.
///
/// ⚠️ **Un SCALAIRE ne suffit PAS** — MESURÉ : avec `'zz_cle': 'x'`, **les 9
/// kinds sont VERTS** (l'`==` superficiel compare des scalaires, et il a raison).
/// Le filet aurait une **existence** et **aucun pouvoir discriminant**. Or porter
/// du JSON **imbriqué** est **la raison d'être d'`extra`** (AD-4 pt.2).
Map<String, dynamic> nestedProbeValue() => <String, dynamic>{
      'a': 1,
      'l': <dynamic>[
        1,
        <String, dynamic>{'b': 2},
      ],
    };

/// Deep-copy JSON — **OBLIGATOIRE** pour (i.2).
///
/// ⚠️ **Sans lui, (i.2) est un FAUX VERT.** Si les deux `decode` reçoivent la
/// **même instance** de sous-`Map`, `identical(a, b)` court-circuite la
/// comparaison et une égalité **SUPERFICIELLE** paraît **VERTE** — exactement le
/// « vert pour une mauvaise raison » que ce gate combat. (La première sonde
/// écrite pour cette story est tombée dans le piège.)
///
/// ⚠️ Un littéral `const` est **pire encore** : canonicalisé ⇒ `identical`.
Map<String, dynamic> deepCopyJson(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// 🔴 Assertion **(i.1)** — **DW-ES22-3** : la **VOIE D'ÉCRITURE PUBLIQUE** de
/// `extra` ne **ROUVRE PAS** le filtre des clés réservées.
///
/// ## Ce que (a)…(f) ne pouvaient PAS voir
///
/// Un invariant de valeur a **DEUX** frontières : la **désérialisation** (une clé
/// réservée qui ENTRE) **et** la **mutation applicative** (une clé réservée qu'on
/// ÉCRIT). Les 6 assertions existantes ne sondent que la **première**. **MESURÉ :
/// 8 entités sur 9** réémettaient `is_deleted`/`updated_at` après un simple
/// `copyWith(extra:)` — ou, pour les 3 sans `copyWith`, après un **constructeur
/// nominal**. Le merge Last-Write-Wins était faussé **silencieusement, sans un
/// seul test rouge** (AD-9/AD-16/AD-19).
///
/// ## Les deux pièges que cette assertion désamorce
///
/// 1. **WRITER MENTEUR** — un writer `(e, x) => e` (qui n'écrit rien) rendrait
///    (i.1) **trivialement verte**. ⇒ le **TÉMOIN D'ÉCRITURE** est asserté
///    **EN PREMIER** : il PROUVE que la voie a réellement pris le nouvel `extra`.
/// 2. **`updated_at` VACUELLEMENT PROPRE** — sur `study_folder` et `flashcard`,
///    `toMap()` étale `{...extra, ...généré}` : le **champ métier** `updatedAt`
///    **ÉCRASE** la pollution (MESURÉ : `val=null`). Une (i.1) qui ne regarderait
///    qu'`updated_at` serait donc **VERTE sur deux entités CASSÉES**.
///    ⇒ **`is_deleted`** (qu'aucun champ n'écrase) est le **discriminant**, et
///    `updated_at` est discriminé **SUR LA VALEUR** sous allowlist.
/// ## 🔴 CE QUI A CHANGÉ À LA REMÉDIATION (HIGH-1/HIGH-2/MAJEUR-1/MAJEUR-2)
///
/// 1. **Aucune exemption** : (i.1c) — l'état MÉMOIRE — s'applique désormais à
///    **TOUTES** les voies de **TOUTES** les entités. `kConstCtorOnlyWriters` a été
///    **SUPPRIMÉE** (et non « verrouillée ») : une liste d'exemption qui n'exempte
///    plus rien n'a pas lieu d'être. L'accesseur `extra` **normalise** (garde
///    `zNormalizeExtra`) ⇒ le ctor `const` n'est plus une voie polluante.
/// 2. **Toutes les voies sont sondées** ([ZExtraWriter.voie]), pas seulement la
///    plus sûre — la règle AST **(j)** du gate les dérive du **DISQUE**.
/// 3. **(i.3)** ([ZExtraWriter.eagerlyNormalized]) discrimine « le slot STOCKÉ est
///    déjà propre » de « l'ACCESSEUR a nettoyé à la lecture » — c'est le témoin qui
///    prouve que la garde de l'accesseur **travaille réellement**, et qui démasque
///    un writer **auto-sanitisant** (**MAJEUR-2**).
void assertExtraWriteSanitized({
  required String label,
  required Object entity,
  required ZExtraWriter writer,
  required Map<String, dynamic> Function(Object entity) encode,
  required bool legacyMirrorAllowed,
}) {
  final written = writer.write(entity, <String, dynamic>{
    ZSyncMeta.kUpdatedAt: kWritePollutionUpdatedAt,
    ZSyncMeta.kIsDeleted: true,
    kExtraWriteWitnessKey: kExtraWriteWitnessValue,
  });
  final encoded = encode(written);

  // ── ANTI-VACUITÉ (non négociable) : la voie a-t-elle RÉELLEMENT écrit ? ────
  expect(
    encoded[kExtraWriteWitnessKey],
    kExtraWriteWitnessValue,
    reason:
        '[$label] (i.1) VACUITÉ : le TÉMOIN D\'ÉCRITURE `$kExtraWriteWitnessKey` '
        'n\'est pas ressorti de l\'encodage — la voie d\'écriture câblée dans '
        '`kExtraWriters` (ou `ZManualProbe.write`) n\'a donc PAS pris le nouvel '
        '`extra`.\n'
        '\n'
        'Un writer MENTEUR (`(e, x) => e`) rendrait (i.1) TRIVIALEMENT VERTE : '
        'elle ne prouverait plus rien. Corrigez le writer (il doit exercer la '
        'VRAIE voie d\'écriture publique de l\'entité : `copyWith(extra:)`, ou le '
        'CONSTRUCTEUR NOMINAL si l\'entité n\'a pas de `copyWith`).\n'
        '\n'
        '⚠️ Autre cause possible, PLUS GRAVE : l\'entité DÉTRUIT `extra` à '
        'l\'écriture (elle « passerait » (i.1) en vidant l\'échappatoire AD-4) — '
        'exactement l\'anti-patron que l\'assertion (b) interdit à l\'entrée.',
  );

  // ═══ (i.1a) — PERSISTANCE : `is_deleted` JAMAIS réémis. ══════════════════
  // AUCUNE exception, AUCUN kind (patron (c)). C'est le DISCRIMINANT : sur
  // `study_folder`/`flashcard`, le champ métier `updatedAt` ÉCRASE la pollution
  // (`{...extra, ...généré}` — MESURÉ `val=null`), donc une (i.1) qui ne
  // regarderait qu'`updated_at` serait VERTE sur deux entités CASSÉES.
  expect(
    encoded.containsKey(ZSyncMeta.kIsDeleted),
    isFalse,
    reason:
        '[$label] (i.1a) DW-ES22-3 VIOLÉ (PERSISTANCE) : la VOIE D\'ÉCRITURE de '
        '`extra` a ROUVERT le filtre — `${ZSyncMeta.kIsDeleted}` est RÉÉMIS par '
        'l\'encodage.\n'
        '\n'
        'L\'entité filtre `extra` à la DÉSÉRIALISATION (`fromMap`) mais PAS à la '
        'SORTIE : un invariant a DEUX frontières, et n\'en fermer qu\'une laisse '
        'la garde ROUVRABLE.\n'
        '\n'
        'CONSÉQUENCE (silencieuse) : `is_deleted` est une préoccupation de STORE '
        '(`ZSyncMeta`, HORS-entité — AD-16). Le store écrit sa méta APRÈS le corps '
        'à chaque `put` : un `is_deleted` MÉTIER logé dans le corps entre en '
        'COLLISION avec l\'autorité de sync ⇒ le merge Last-Write-Wins est FAUSSÉ '
        '(AD-9/AD-19), sans un seul test rouge.\n'
        '\n'
        'GESTE : `toMap()`/`toJson()` doit étaler **l\'ACCESSEUR** (`...extra`) — '
        'JAMAIS le champ brut (`_extra`) — et l\'accesseur doit NORMALISER '
        '(`zNormalizeExtra(_extra, _reservedKeys)`).\n'
        '\n'
        '⛔ L\'ACCESSEUR est la SEULE frontière que TOUTES les voies traversent : '
        'une entité à constructeur `const` ne peut RIEN filtrer à la construction, '
        'et AD-10 INTERDIT d\'y mettre un `assert` (la désérialisation d\'une donnée '
        'corrompue ne doit JAMAIS throw). ⚠️ Rejouer `_sanitizeExtra` DANS '
        '`toMap()` serait DÉCORATIF (MESURÉ, code-review ES-2.2b/INJ-A : le retirer '
        'laissait le gate VERT sur 8 entités sur 9) — la garde doit vivre là où '
        'AUCUNE voie ne la contourne. Patron de référence : `ZSmartNote`.',
  );

  // ═══ (i.1b) — PERSISTANCE : `updated_at`. ═══════════════════════════════
  // Hors allowlist : ABSENT. Sous allowlist : présent, mais sa valeur vient du
  // CHAMP MÉTIER — JAMAIS de la pollution d'`extra` (discrimination SUR LA
  // VALEUR : le corps ne doit pas pouvoir écraser l'autorité LWW).
  if (legacyMirrorAllowed) {
    expect(
      encoded[ZSyncMeta.kUpdatedAt],
      isNot(kWritePollutionUpdatedAt),
      reason:
          '[$label] (i.1b) DW-ES22-3 VIOLÉ (miroir legacy) : la valeur de '
          '`${ZSyncMeta.kUpdatedAt}` réémise est CELLE DE LA POLLUTION d\'`extra` '
          '($kWritePollutionUpdatedAt) — le CORPS écrase donc l\'autorité LWW.\n'
          '\n'
          'L\'allowlist `kLegacyUpdatedAtMirrors` tolère que ce kind ÉMETTE '
          '`updated_at` DEPUIS SON CHAMP MÉTIER (miroir de compat AD-19.2, sans '
          'autorité : l\'adapter l\'écrase à chaque `put`). Elle ne tolère '
          'ABSOLUMENT PAS qu\'une valeur ARBITRAIRE écrite dans `extra` en '
          'ressorte : ce serait une voie d\'écriture applicative sur une clé de '
          'STORE.',
    );
  } else {
    expect(
      encoded.containsKey(ZSyncMeta.kUpdatedAt),
      isFalse,
      reason:
          '[$label] (i.1b) DW-ES22-3 VIOLÉ (PERSISTANCE) : la VOIE D\'ÉCRITURE a '
          'ROUVERT le filtre — `${ZSyncMeta.kUpdatedAt}` est RÉÉMIS hors '
          'allowlist. L\'autorité Last-Write-Wins est `ZSyncMeta.updatedAt` '
          '(HORS-entité) : le domaine ne réémet pas cette clé. Même geste que '
          '(i.1a) : la garde nommée partagée, appelée AUSSI par `toMap()`.',
    );
  }

  // ═══ (i.1c) — ÉTAT EN MÉMOIRE de l'entité ÉCRITE. SANS EXCEPTION. ════════
  //
  // 🔴 L'actif protégé n'est PAS la persistance ((i.1a)/(i.1b) la portent) :
  // c'est l'ÉTAT EN MÉMOIRE. `entity.extra` porterait `is_deleted`, et TOUT
  // consommateur (`zExtraRead`, `==`, `hashCode`, une UI, un diff) le verrait —
  // `f != ZXxx.fromMap(f.toMap())`, `Set{f, relu}.length == 2` : le dommage
  // **DW-ES22-4** exact (HIGH-2).
  //
  // ⚠️ PLUS AUCUNE EXEMPTION (remédiation MAJEUR-1). La v1 exemptait les entités
  //    à ctor `const` via `kConstCtorOnlyWriters` — une liste dont l'anti-inertie
  //    exigeait **la présence du défaut lui-même** (`leaked isNotEmpty`) : on s'y
  //    exemptait EN COMMETTANT ce que (i.1c) attrape. La liste est **SUPPRIMÉE** :
  //    l'ACCESSEUR `extra` (`zNormalizeExtra`) normalise à la LECTURE, donc même
  //    un ctor `const` (qui ne peut RIEN filtrer — AD-10 y interdit l'`assert`) ne
  //    peut plus exposer une clé réservée.
  final writtenExtra = (written as ZExtensible).extra;
  final leaked = writtenExtra.keys.toSet().intersection(ZSyncMeta.reservedKeys);
  expect(
    leaked,
    isEmpty,
    reason:
        '[$label] (i.1c) DW-ES22-3/DW-ES22-4 VIOLÉ (ÉTAT EN MÉMOIRE) : la voie '
        'd\'écriture `${writer.voie}` a laissé les clés réservées $leaked DANS '
        '`extra` — l\'entité écrite les porte EN MÉMOIRE.\n'
        '\n'
        '⚠️ L\'ENCODAGE, lui, peut être PROPRE : ce n\'est PAS une excuse, c\'est '
        'exactement pourquoi cette assertion existe (R1).\n'
        '\n'
        'CE QUI CASSE : `f == ZXxx.fromMap(f.toMap())` devient FALSE, un `Set` en '
        'garde DEUX, `zExtraRead`/une UI voient une clé de STORE (AD-16).\n'
        '\n'
        'GESTE : la garde vit sur l\'**ACCESSEUR** `extra` — '
        '`Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);` '
        '(le champ stocké `_extra` reste BRUT : le ctor `const` ne peut pas '
        'filtrer). C\'est le SEUL point que TOUTES les voies traversent. Patron de '
        'référence : `ZSmartNote`. Pour une entité à ctor NON-`const` '
        '(`ZMindmap`), l\'initializer suffit.',
  );

  // ═══ (i.3) — LE SLOT STOCKÉ : normalisé EAGER, ou nettoyé par l'ACCESSEUR ? ══
  //
  // 🔴 C'EST LE TÉMOIN QUI EMPÊCHE (i.1) D'ÊTRE VERTE POUR UNE MAUVAISE RAISON.
  //
  // `zNormalizeExtra` rend le slot **LUI-MÊME** (zéro copie) s'il est déjà propre,
  // et une **COPIE dépouillée** sinon ⇒ `identical(e.extra, e.extra)` OBSERVE,
  // de l'extérieur, laquelle des deux gardes a travaillé :
  //
  //   • `eagerlyNormalized: true`  (copyWith, ctor NON-`const`) ⇒ identical TRUE.
  //     Retirer `_sanitizeExtra` de `copyWith` (le défaut DW-ES22-3 EXACT) ⇒ le
  //     slot stocké devient POLLUÉ ⇒ l'accesseur se met à COPIER ⇒ **ROUGE**.
  //     Sans (i.3), cette garde serait **DÉCORATIVE** (l'accesseur la couvre).
  //
  //   • `eagerlyNormalized: false` (ctor `const`) ⇒ identical FALSE.
  //     (1) PROUVE que l'accesseur a RÉELLEMENT nettoyé (la garde est PORTEUSE) ;
  //     (2) **MAJEUR-2** : un writer **AUTO-SANITISANT** (« menteur POLI » : il
  //         dépouille `x` avant d'appeler la voie publique — la forme que
  //         `kExtraWriters` avait DÉJÀ en production) rendrait le slot stocké
  //         PROPRE ⇒ identical TRUE ⇒ **ROUGE**. Le témoin d'écriture seul ne
  //         l'attrapait PAS (il n'observe qu'une clé NON réservée).
  final zeroCopy = identical(writtenExtra, (written as ZExtensible).extra);
  expect(
    zeroCopy,
    writer.eagerlyNormalized,
    reason: writer.eagerlyNormalized
        ? '[$label] (i.3) la voie `${writer.voie}` est déclarée '
            '`eagerlyNormalized: true` mais le slot STOCKÉ est POLLUÉ (la lecture '
            'd\'`extra` COPIE au lieu de rendre le slot).\n'
            '\n'
            'CAUSE la plus probable : la garde `_sanitizeExtra` a été RETIRÉE de '
            'cette voie (`copyWith(extra:)`, ou l\'initializer du ctor NON-`const`) '
            '— c\'est le défaut **DW-ES22-3** exact. L\'invariant tient encore (à '
            'la LECTURE, via l\'accesseur), mais la NORMALISATION EAGER est perdue : '
            'chaque lecture d\'`extra` alloue, et le slot brut retient des clés de '
            'STORE. RÉTABLISSEZ-la.\n'
            '\n'
            'AUTRE CAUSE : l\'accesseur a cessé d\'être « zéro-copie » (il '
            'copie TOUJOURS) ⇒ (i.3) ne peut plus discriminer, et le témoin '
            'anti-writer-menteur ci-dessous tombe. C\'est une DÉCISION DE '
            'CONCEPTION : à trancher, pas à contourner.'
        : '[$label] (i.3) la voie `${writer.voie}` est déclarée '
            '`eagerlyNormalized: false` (constructeur `const` : il ne peut RIEN '
            'filtrer) — or le slot STOCKÉ est PROPRE. Deux causes, toutes deux '
            'GRAVES :\n'
            '\n'
            '1. 🔴 **WRITER MENTEUR « POLI » (MAJEUR-2)** : le writer de '
            '`kExtraWriters`/`ZManualProbe.writes` **DÉPOUILLE `extra` LUI-MÊME** '
            'avant d\'appeler la voie publique. (i.1a)/(i.1b)/(i.1c) deviennent '
            'alors TRIVIALEMENT VERTES : elles n\'exercent plus AUCUNE garde de '
            'l\'entité. Le writer DOIT passer `extra` **VERBATIM** (la règle AST '
            '(k) du gate l\'exige aussi). ⛔ NE « RÉPAREZ » PAS en basculant le '
            'drapeau.\n'
            '\n'
            '2. L\'entité a gagné une voie de normalisation à la CONSTRUCTION '
            '(ctor devenu non-`const`, ou slot stocké déjà sanitisé) ⇒ l\'étiquette '
            'est PÉRIMÉE : passez `eagerlyNormalized: true` — et vérifiez alors que '
            'la garde de l\'ACCESSEUR reste exigée par une machine.',
  );
}


/// 🔴 Assertion **(i.2)** — **DW-ES22-4** : l'égalité/le hash d'`extra` sont
/// **PROFONDS**. **Zéro code par entité.**
///
/// Deux décodages **INDÉPENDANTS** du **MÊME** payload — dont l'`extra` porte du
/// JSON **IMBRIQUÉ** — doivent être `==`, de même `hashCode`, et **fusionner dans
/// un `Set`**.
///
/// ## Pourquoi c'est vital (et pourquoi c'était invisible)
///
/// L'`==` d'une `Map`/`List` est une égalité d'**IDENTITÉ** en Dart. Six entités
/// comparaient leur `extra` avec un `_mapEquals` **SUPERFICIEL** (copié à
/// l'identique dans 3 packages). **MESURÉ** : deux décodages du même document
/// portant `"legacy_meta": {"a": 1}` donnaient `a == b ⇒ false`,
/// `Set{a, b}.length ⇒ 2`. **Toute déduplication, tout cache mémoïsé, tout
/// `expect(relu, original)` était CASSÉ** — et **aucun test ne le voyait**, parce
/// que toutes les sondes du repo n'utilisaient que des **scalaires**.
///
/// [expectValueEquality] : `false` **UNIQUEMENT** pour les entités déclarées dans
/// `kNoValueEqualityProbes` (`ZMindmap`/`ZMindmapNode`, qui n'ont **AUCUN**
/// `operator ==` — dette **DW-ES22-5**). Le skip est **CONTRÔLÉ** : on asserte
/// alors que l'égalité est bien **ABSENTE** ⇒ le jour où ces entités gagnent un
/// `==` de valeur, l'entrée devient **MORTE** et le test **ROUGIT**. Jamais
/// silencieux (**R6**).
void assertExtraDeepEquality({
  required String label,
  required Map<String, dynamic> probeBody,
  required Object Function(Map<String, dynamic> map) decode,
  required bool expectValueEquality,
}) {
  final payload = <String, dynamic>{
    ...probeBody,
    kProbeNestedKey: nestedProbeValue(),
  };

  // ⚠️ DEUX deep-copies INDÉPENDANTES : sans elles, `identical` sur la
  //    sous-`Map` partagée rendrait une égalité SUPERFICIELLE **VERTE**.
  final a = decode(deepCopyJson(payload));
  final b = decode(deepCopyJson(payload));

  if (!expectValueEquality) {
    // SKIP DÉCLARÉ **ET CONTRÔLÉ** (R6) — patron de l'assertion (e).
    expect(
      a,
      isNot(equals(b)),
      reason:
          '[$label] (i.2) ENTRÉE MORTE dans `kNoValueEqualityProbes` : cette '
          'entité a désormais une ÉGALITÉ DE VALEUR — la dette **DW-ES22-5** est '
          'en voie de clôture. RETIREZ-la de la liste (sinon le skip se fossilise '
          'et (i.2) ne serait plus exercée sur elle). Ne « réparez » pas ce test '
          'en supprimant l\'assertion.',
    );
    return;
  }

  // ── ANTI-VACUITÉ : le témoin imbriqué est-il bien ARRIVÉ dans `extra` ? ────
  // Sans ceci, (i.2) serait VERTE sur une entité qui **JETTE** `extra` (deux
  // `extra` vides sont trivialement égaux).
  expect(
    (a as ZExtensible).extra[kProbeNestedKey],
    isA<Map<String, dynamic>>(),
    reason:
        '[$label] (i.2) VACUITÉ : le témoin IMBRIQUÉ `$kProbeNestedKey` n\'est pas '
        'arrivé dans `extra` (ou n\'y est plus une `Map`). L\'égalité serait alors '
        'comparée sur un `extra` VIDE — trivialement égale, prouvant RIEN. '
        'Vérifiez que `fromMap` peuple bien `extra` (assertion (b)).',
  );

  expect(
    a,
    equals(b),
    reason:
        '[$label] (i.2) DW-ES22-4 VIOLÉ : deux décodages INDÉPENDANTS du MÊME '
        'payload ne sont PAS ÉGAUX. L\'`==` d\'`extra` est **SUPERFICIEL** — or '
        'l\'`==` d\'une `Map`/`List` est une égalité d\'IDENTITÉ en Dart, et '
        'porter du JSON IMBRIQUÉ est **LA RAISON D\'ÊTRE d\'`extra`** (AD-4 pt.2 : '
        'maps/listes legacy IFFD, documents Firestore).\n'
        '\n'
        'CONSÉQUENCE : toute déduplication, tout cache mémoïsé, tout '
        '`expect(relu, original)` CASSE — une entité en mémoire et la MÊME relue '
        'du store sont dites DIFFÉRENTES.\n'
        '\n'
        'GESTE : `zJsonEquals(extra, other.extra)` / `zJsonHash(extra)` '
        '(`zcrud_core` — l\'unique implémentation du repo POUR LE SLOT `extra`). '
        '⛔ NE PAS recopier une énième `_mapEquals` locale, et NE PAS importer '
        '`noteJsonEquals` depuis `zcrud_note` (arête entre satellites ⇒ '
        'VIOLATION AD-1).',
  );
  expect(
    a.hashCode,
    b.hashCode,
    reason:
        '[$label] (i.2) le `hashCode` n\'est pas PROFOND (il doit être cohérent '
        'avec l\'`==` : `zJsonHash`). Un `==` profond avec un hash superficiel '
        'casse `Set`/`Map` — le bug est alors PIRE, car intermittent.',
  );
  expect(
    <Object>{a, b},
    hasLength(1),
    reason:
        '[$label] (i.2) un `Set` en garde DEUX : c\'est la manifestation OBSERVABLE '
        'du défaut (déduplication cassée).',
  );
}

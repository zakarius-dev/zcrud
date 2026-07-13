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

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

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
/// Conséquence : si `kDomainDecoders` était un jour recâblé (faute de frappe,
/// refactor) vers un type qui n'est **pas** `ZExtensible`, (a) et (b) devenaient
/// **vacuellement vertes SANS LE MOINDRE SIGNAL** — le défaut même que ce gate
/// combat. Le skip est désormais **DÉCLARÉ** : l'appelant dit s'il ATTEND une
/// entité extensible, et tout écart (attendue extensible mais ne l'est pas, ou
/// l'inverse : la liste `kNonExtensibleKinds` a pourri) est **ROUGE**.
void assertExtraClean({
  required String label,
  required Object entity,
  required bool expectExtensible,
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
          'trappe SANS SIGNAL — vérifiez `kDomainDecoders` (registrars.dart).',
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

/// Les **4** assertions (a)(b)(c)(d) d'AD-19.1.c sur une entité décodée depuis
/// une sonde polluée et ré-encodée.
///
/// [expectExtensible] : l'entité DOIT-elle être `ZExtensible` ? (cf. L1 —
/// le skip de (a)/(b) est DÉCLARÉ, jamais silencieux).
void assertReservedKeysClean({
  required String label,
  required Object entity,
  required Map<String, dynamic> encoded,
  required bool legacyMirrorAllowed,
  required bool expectExtensible,
}) {
  assertExtraClean(
    label: label,
    entity: entity,
    expectExtensible: expectExtensible,
  );
  assertEncodedClean(
    label: label,
    encoded: encoded,
    legacyMirrorAllowed: legacyMirrorAllowed,
  );
}

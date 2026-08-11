/// Contrat de **slot d'extension** `ZExtensible` (AD-4).
///
/// Patron « slots d'extension » : composition d'un [ZExtension] typé
/// versionné + échappatoire non typée [extra].
///
/// Mixé **en plus** par les entités canoniques concrètes qui en ont besoin —
/// **jamais** dans `ZEntity`, qui reste un contrat pur d'identité.
library;

import 'z_extension.dart';

/// Mixin exposant les deux voies d'extension AD-4 sur une entité :
/// - [extension] : slot type additif **versionné** (`null` si absent) ;
/// - [extra] : échappatoire **non typée** (défaut `const {}` côté
///   implémentation), préservant des clés inconnues du cœur.
mixin ZExtensible {
  /// Extension type additive versionnée, ou `null` si l'entité n'en porte pas.
  ZExtension? get extension;

  /// Échappatoire non typée : paires arbitraires préservées telles quelles
  /// (round-trip), y compris des clés inconnues du cœur. L'implémentation
  /// fournit le défaut `const {}` (jamais `null`).
  Map<String, dynamic> get extra;
}

/// Lecture **typée défensive** d'une clé d'[extra] : renvoie la valeur si elle
/// est présente **et** du type `T` attendu, sinon `null` (jamais de throw,
/// AD-10). Commodité pour consommer l'échappatoire non typée sans cast risqué.
T? zExtraRead<T>(Map<String, dynamic> extra, String key) {
  final value = extra[key];
  return value is T ? value : null;
}

/// **LA GARDE PARTAGÉE DU SLOT `extra`** — dépouille
/// [raw] de **toutes** les clés [reserved] et rend une `Map` **non modifiable**.
///
/// ## Un invariant de valeur a DEUX frontières — pas une
///
/// La **désérialisation** (une clé réservée qui ENTRE, via un store qui écrit
/// `updated_at`/`is_deleted` **dans le corps** du document) **ET** la **mutation
/// applicative** (une clé réservée qu'on ÉCRIT : `copyWith(extra:)`, ou — pour
/// les entités qui n'ont **aucun** `copyWith` — le **constructeur nominal**).
///
/// Ne fermer que la première laisse la garde **ROUVRABLE** : un
/// `updated_at`/`is_deleted` **métier** logé dans le corps entre alors en
/// collision avec l'autorité de sync — le store écrit `ZSyncMeta` **APRÈS**
/// le corps ⇒ **le merge Last-Write-Wins est faussé, silencieusement, sans un
/// seul test rouge** (AD-9).
///
/// ## Où l'appeler — NORMALISATION **EAGER**
///
/// Aux voies **capables** de filtrer : `fromMap` (frontière d'ENTRÉE) et
/// `copyWith(extra:)`, **plus** l'initializer d'un constructeur **non-`const`**.
/// Elle y garde le slot STOCKÉ **déjà propre** ⇒ la lecture d'`extra` est
/// **SANS COPIE** ([zNormalizeExtra] rend le slot lui-même).
///
/// **Elle NE SUFFIT PAS** : le **constructeur `const`** d'une entité codegen
/// **ne peut appeler AUCUNE fonction** dans son initializer, et **AD-10 INTERDIT**
/// d'y mettre un `assert` (le décodeur généré l'appelle avec des valeurs
/// **BRUTES** : un `assert` ferait **throw la désérialisation d'une donnée
/// corrompue**). C'est [zNormalizeExtra], **posée sur l'ACCESSEUR `extra`**, qui
/// ferme cette voie — et c'est **le seul point que TOUTES les voies traversent**.
///
/// **Ce que cette garde ne fait PAS** : elle n'est **pas** appelée par
/// `toMap()`/`toJson()`. `toMap()` étale **l'ACCESSEUR** (`...extra`), déjà
/// normalisé — appeler la garde une seconde fois à l'encodage serait une
/// vérification décorative, sans effet observable, puisque l'accesseur a déjà
/// fait le travail.
///
/// [reserved] est l'ensemble réservé **de l'entité** : champs du schéma
/// (`$ZXxxFieldSpecs`) + `extension` + canaux hors-codegen (`source`, `learning`,
/// `content`…) + **`...ZSyncMeta.reservedKeys`**.
Map<String, dynamic> zSanitizeExtra(
  Map<String, dynamic> raw,
  Set<String> reserved,
) =>
    Map<String, dynamic>.unmodifiable(<String, dynamic>{
      for (final e in raw.entries)
        if (!reserved.contains(e.key)) e.key: e.value,
    });

/// **LA GARDE DE L'ACCESSEUR `extra`** : normalisation **LAZY**, **SANS
/// COPIE** quand le slot stocké est déjà propre.
///
/// ## Le trou qu'elle ferme
///
/// ```dart
/// const ZSmartNote(folderId: 'f', title: 't', extra: {'is_deleted': true})
/// ```
///
/// Le **constructeur nominal** est une **voie d'écriture publique** — et il est
/// `const` : il **ne peut RIEN filtrer** (aucun appel de fonction dans un
/// initializer `const`), et **AD-10 INTERDIT** l'`assert`. Sans cette garde à
/// la lecture, une entité construite ainsi porterait une clé de STORE dans son
/// `extra` **EN MÉMOIRE** : `f != ZStudyFolder.fromMap(f.toMap())`,
/// `Set{f, relu}.length == 2` — la même désynchronisation d'égalité que sur le
/// slot `extra` en général, mais par une autre porte.
///
/// ## Pourquoi l'ACCESSEUR, et pas le champ
///
/// Le champ stocké reste **BRUT** (le ctor `const` l'exige) ; c'est la **LECTURE**
/// qui est normalisée. Toutes les voies d'observation (`entity.extra`,
/// [zExtraRead], `==`, `hashCode`, `toMap()` — qui étale `...extra` —, une UI, un
/// diff) passent par cet accesseur : la promesse « `extra` ne porte JAMAIS une clé
/// réservée » devient **EXACTEMENT vraie**, sans `assert`, sans `throw`, **sans
/// perdre `const`** (surface publique INCHANGÉE).
///
/// ## Zéro copie sur le chemin chaud — vérifiable, pas juste souhaité
///
/// Si [raw] ne porte **aucune** clé [reserved] (le cas de **toute** entité issue
/// de `fromMap`/`copyWith`, qui normalisent **EAGER** via [zSanitizeExtra]), on
/// rend **le slot lui-même** : `identical(e.extra, e.extra)` est alors **`true`**.
/// Un test peut donc **asserter** cette identité — ce qui fait rougir toute
/// régression qui retirerait [zSanitizeExtra] de `fromMap`/`copyWith` (la
/// lecture se mettrait à copier). Sur la voie CTOR polluée, l'assertion
/// inverse (`false`) prouve que l'accesseur a **réellement travaillé**.
Map<String, dynamic> zNormalizeExtra(
  Map<String, dynamic> raw,
  Set<String> reserved,
) {
  for (final key in raw.keys) {
    if (reserved.contains(key)) return zSanitizeExtra(raw, reserved);
  }
  return raw;
}

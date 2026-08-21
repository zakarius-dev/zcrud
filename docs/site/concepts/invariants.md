---
title: Invariants d'architecture (AD-1 … AD-16)
description: Les 16 règles non négociables qui bornent tout paquet zcrud — définitions canoniques.
sidebar_position: 5
---

# Invariants d'architecture

Seize règles gouvernent l'écosystème zcrud. Chaque dartdoc ou README qui invoque un
invariant (« invariant AD-13 ») pointe **ici** — cette page est la définition canonique,
il n'en existe pas d'autre. Elles ne sont pas des préférences de style : la plupart sont
**vérifiées par des gates** (`melos run verify`) ou par des tests de garde.

## AD-1 — Graphe de dépendances acyclique, cœur léger {#ad-1}

`zcrud_core` ne dépend d'**aucun** autre paquet zcrud ni d'aucune dépendance lourde
(Firebase, Syncfusion, Quill, cartes). Tout satellite dépend du cœur — jamais l'inverse —
et toute nouvelle arête doit préserver l'acyclicité (vérifiée par gate). Conséquence pour
vous : importer `zcrud_markdown` ne tire jamais Syncfusion, importer `zcrud_core` ne tire
jamais Firebase.

## AD-2 — Rebuilds granulaires, réactivité Flutter-native {#ad-2}

L'état d'un formulaire vit dans un `ZFormController` (`ChangeNotifier` pur Flutter) qui
expose une `ValueListenable` **par champ** ; chaque champ n'écoute que sa tranche. Taper
100 caractères ne reconstruit que le champ courant — jamais le formulaire. Interdits dans
le cœur : `setState` à l'échelle du formulaire, recréation de `TextEditingController` au
rebuild, ré-injection de valeur écrasant la sélection.

## AD-3 — Le modèle est la source unique de vérité (codegen) {#ad-3}

`zcrud_generator` produit depuis `@ZcrudModel`/`@ZcrudField` : `toMap`/`fromMap`/`copyWith`,
le `ZFieldSpec[]` et l'enregistrement au `ZcrudRegistry`. Jamais de `reflectable` ;
`freezed` n'est pas imposé. Un type non enregistré échoue **explicitement**.

## AD-4 — Extension par composition, jamais par héritage {#ad-4}

Chaque entité canonique s'étend par (1) un slot `ZExtension?` versionné
(`formatVersion`, `fromJsonSafe`), (2) une `Map<String, dynamic> extra`, (3) des registres
ouverts (`ZTypeRegistry`/`ZSourceRegistry`). L'héritage de classes sérialisées et `sealed`
inter-paquet sont rejetés. Tout enum public porte `@JsonKey(unknownEnumValue:)`.

## AD-5 — Domaine backend-agnostique (ports & adapters) {#ad-5}

Les ports (`ZRepository<T>`, `ZLocalStore`, `ZRemoteStore`, `ZDataRequest`) vivent dans le
cœur sans aucun type backend ; `Timestamp`, `Filter` ou `FirebaseException` n'y entrent
jamais. Les adaptateurs concrets vivent dans `zcrud_firestore`.

## AD-6 — Injection et cycle de vie pluggables {#ad-6}

Dépendances (resolver, toasts, l10n, codecs) et cycle de vie des controllers passent par
des seams résolus par un binding au choix de l'hôte : `ZcrudScope` (défaut,
zéro-dépendance), `zcrud_riverpod`, `zcrud_get` ou `zcrud_provider`. Le cœur ne référence
jamais `WidgetRef`, `Get.find` ni `Provider.of`.

## AD-7 — Rich-text : Delta interne, codec pluggable {#ad-7}

L'éditeur travaille en Delta (Quill) ; le format **persisté** passe par un `ZCodec`
pluggable (Delta / Markdown / HTML) choisi par l'application. Le round-trip est testé,
embeds compris (formules, tables).

## AD-8 — Liste : abstraction dans le cœur, Syncfusion en satellite {#ad-8}

Le cœur n'expose que `ZListRenderer` et les modèles de liste ; le rendu `SfDataGrid` par
défaut vit dans `zcrud_list`. Sans `zcrud_list`, aucun octet Syncfusion n'entre dans
votre build.

## AD-9 — Offline-first : local d'abord, écriture SRS unique {#ad-9}

Le store local est la source de vérité ; le distant est fire-and-forget ; le merge est
Last-Write-Wins sur `updatedAt` ; la suppression est un soft-delete (`ZSyncMeta`,
`is_deleted`). L'état de répétition espacée est séparé de la carte ; sa seule voie
d'écriture est `reviewCard() → ZSrsScheduler.apply`.

## AD-10 — Schéma additif, désérialisation défensive {#ad-10}

Entre versions mineures : **ajout seulement** (nullable ou `defaultValue`). Un champ
absent, inconnu ou corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`,
`fromJsonSafe → null`). Un document écrit il y a deux ans se relit aujourd'hui.

## AD-11 — Either sur les contrats, Stream nu {#ad-11}

Tout contrat repository retourne `Either<ZFailure, T>` (`Unit` pour void) ; les flux sont
des `Stream<List<T>>` nus, jamais enveloppés. La hiérarchie `ZFailure` est maison
(`ZDomainFailure`, `ZCacheFailure`, `ZNotFoundFailure`, `ZServerFailure`…).

## AD-12 — Zéro secret dans les paquets {#ad-12}

Aucune clé API, aucun endpoint en dur non surchargeable, jamais
`badCertificateCallback => true`. Les clés viennent de la config plateforme de l'hôte.
Vérifié par gate de scan — **commentaires compris** : un exemple de doc n'écrit jamais
une clé plausible.

## AD-13 — RTL, accessibilité, l10n injectable {#ad-13}

Toute surface UI utilise les variantes directionnelles (`EdgeInsetsDirectional`,
`AlignmentDirectional`, `TextAlign.start/end`, `PositionedDirectional`), des `Semantics`
explicites et des cibles ≥ 48 dp. La l10n est injectée (delegate + registre de libellés),
jamais un singleton statique.

## AD-14 — Pureté des couches {#ad-14}

Le `domain/` du cœur est du Dart pur (ni Flutter, ni Firebase, ni Hive). Les invariants
métier vivent au repository, jamais dans les entités (entités = données + `copyWith`).
Le paquet `zcrud_core` dans son ensemble autorise Flutter (moteur d'édition) — c'est la
couche domaine qui est pure.

## AD-15 — Multi-gestionnaire d'état par bindings {#ad-15}

Le cœur n'importe aucun gestionnaire d'état ; sa réactivité repose sur
`Listenable`/`ValueListenable`. Chaque idiome a son binding optionnel (Riverpod, GetX,
provider) ; un même controller fonctionne à l'identique sous les quatre. Ajouter un
manager = un nouveau paquet de binding, jamais une modification du cœur.

## AD-16 — ACL et pagination curseur dans le contrat neutre {#ad-16}

Le contrôle d'accès passe par un port `ZAcl` fourni par l'application ; la pagination par
curseur (`startAfter`) est exprimée dans le contrat neutre `ZDataRequest` et implémentée
par l'adaptateur backend.

**Le repli est refusant (fail-closed).** Tout point qui consulte une ACL sans en avoir
reçu une retombe sur `ZDenyAllAcl`, qui refuse tout : une application qui oublie de
brancher la sienne n'offre **aucun** geste, au lieu de tous les offrir. La résolution est
partout la même — **paramètre explicite > ACL du `ZcrudScope` ambiant > refus**. Sur un
écran assemblé, `ZCrudAction.view` refusé bloque l'écran entier, qui affiche un état
« accès refusé » **sans interroger le dépôt**.

L'ouverture totale reste possible, mais **déclarée** :
`ZcrudScope(acl: const ZAllowAllAcl())`. C'est toute la différence avec un repli
implicite — le geste est volontaire et lisible dans le code de l'application.

## Voir aussi

- [Architecture hexagonale](architecture-hexagonale.md) — comment ces règles se traduisent
  en couches et en paquets.
- [Réactivité granulaire](reactivite-granulaire.md) — AD-2 en pratique.
- [Offline-first](offline-first.md) — AD-9 en pratique.

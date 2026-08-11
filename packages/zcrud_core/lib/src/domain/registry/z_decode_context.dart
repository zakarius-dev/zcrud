/// Contexte de (dé)codage injecté au [ZcrudRegistry] (AD-4/AD-10).
///
/// Une entité extensible décode son slot `extension`/`source` via des
/// collaborateurs **injectables** (`extensionParser`, `sourceRegistry`).
/// Sans ce contexte câblé au registre, la voie de décodage empruntée par un
/// store offline-first ne peut fournir ces collaborateurs : une extension
/// reste alors sur son canal de survie non typé (`fromJsonSafe` jamais
/// invoqué), et un `ZSourceRegistry` d'app enregistré ne serait jamais
/// consulté — deux pertes fonctionnelles silencieuses dès la première
/// écriture.
///
/// ## Forme du seam — pourquoi un CHAMP de constructeur
///
/// Le contexte est un **champ du constructeur** de [ZcrudRegistry], consommé
/// par un décodeur conscient du contexte (`ZModelCodec.fromMapWithContext`),
/// plutôt qu'un paramètre additif `decode(kind, map, {context})`. Ce choix
/// **préserve la signature `decode(kind, map)` et `encode(kind, value)`**
/// (AD-10 additif) : tout appelant existant reste **INCHANGÉ**. Le contexte
/// est câblé **une fois** au bootstrap du registre — un paramètre additif
/// aurait forcé chaque site d'appel à le threader et cassé la signature
/// publique de `decode`.
///
/// ## AD-1 — CORE OUT=0 préservé
///
/// Ce contexte ne porte **que** des types **déjà** dans `zcrud_core`
/// ([ZExtension], [ZSourceRegistry]) : le registre **ne gagne AUCUNE arête
/// sortante**. Les sous-classes concrètes d'extension (`ZNoteAudio`, dans l'app —
/// AD-4) sont résolues **par le résolveur injecté**, jamais connues du cœur.
///
/// ## AD-4 — COMPOSE, ne DUPLIQUE pas
///
/// [sourceRegistry] est le registre ouvert de provenance de l'app (AD-4 pt.3),
/// threadé **tel quel** aux `fromMap`/`toMap` d'entité. [extensionParser] est un
/// résolveur **par kind** : une app peut le brancher sur son [ZTypeRegistry] ou
/// un `switch` de ses `X.fromJsonSafe` — le cœur n'impose aucun schéma de
/// discrimination et ne réplique aucun de ces registres.
library;

import '../extension/z_extension.dart';
import 'z_source_registry.dart';

/// Résout, pour un `kind` de modèle donné, le payload `extension` **brut** en une
/// [ZExtension] **typée** (`X.fromJsonSafe`), ou `null` s'il ne sait pas le typer.
///
/// **Défensif (AD-10)** : ne doit **jamais** throw — toute exception est de toute
/// façon absorbée par `ZExtension.guard` côté entité ; un `null` fait retomber le
/// slot sur le canal de survie (`ZOpaqueNoteExtension`) ou sur `null`, jamais une
/// destruction.
typedef ZExtensionResolver = ZExtension? Function(
  String kind,
  Map<String, dynamic> json,
);

/// Contexte **immuable** de (dé)codage, injecté au [ZcrudRegistry] au bootstrap
/// et threadé par lui aux `fromMap`/`toMap` conscients du contexte des entités
/// extensibles (voir `ZModelCodec.fromMapWithContext`/`toMapWithContext`).
class ZDecodeContext {
  /// Construit un contexte (les deux collaborateurs sont optionnels — un contexte
  /// vide se comporte **exactement** comme l'absence de contexte : AD-10 additif).
  const ZDecodeContext({
    this.extensionParser,
    this.sourceRegistry,
  });

  /// Résolveur de slot `extension` typé **par kind** (AD-4). `null` ⇒ aucune
  /// résolution typée (comportement historique : `ZOpaqueNoteExtension`/`null`).
  final ZExtensionResolver? extensionParser;

  /// Registre ouvert de provenance de l'app (AD-4 pt.3), threadé aux `fromMap`/
  /// `toMap` d'entité. `null` ⇒ provenance non résolue (payload brut).
  final ZSourceRegistry? sourceRegistry;
}

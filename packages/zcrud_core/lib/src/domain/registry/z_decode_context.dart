/// Contexte de (dé)codage injecté au [ZcrudRegistry] (**DW-ES14-2**, AD-4/AD-10).
///
/// origine: ES-3.0 (TÊTE BLOQUANTE d'ES-3) — solde **DW-ES14-2** : sur la voie
/// registre — la SEULE qu'un store offline-first (ES-3.1/3.2/3.5) emprunte — les
/// entités extensibles décodaient leur slot `extension`/`source` via des
/// collaborateurs **injectables** (`extensionParser`, `sourceRegistry`) que le
/// registre **n'avait aucun moyen de fournir**. Résultat MESURÉ : `note.extension`
/// n'était **jamais** un `ZNoteAudio` typé (toujours un `ZOpaqueNoteExtension`),
/// et le `ZSourceRegistry` de l'app était **court-circuité** — deux pertes
/// fonctionnelles irréversibles dès le premier `put`.
///
/// ## Forme du seam (spike R4, AC10) — pourquoi un CHAMP de constructeur
///
/// Deux formes ont été prototypées :
///  - **(a)** contexte **champ du constructeur** de [ZcrudRegistry] + décodeur
///    conscient du contexte porté par `ZModelCodec` (`fromMapWithContext`) ;
///  - **(b)** paramètre additif `decode(kind, map, {context})`.
///
/// **(a) est RETENUE** : elle **préserve la signature `decode(kind, map)` et
/// `encode(kind, value)`** (AD-10 additif) — donc le call-site
/// `FirebaseZRepositoryImpl.fromRegistry` (`registry.decode(kind, map)`) reste
/// **INCHANGÉ**. Le contexte est câblé **une fois** au bootstrap du registre.
/// (b) aurait forcé chaque call-site à threader le contexte et **cassé** la
/// signature publique de `decode` — rejetée.
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

/// Extension **opaque** — préserve un slot `extension` que personne n'a su
/// typer, au lieu de le DÉTRUIRE (CR-LEX-33).
///
/// ## Le défaut que ce type ferme
///
/// Une entité déclare `extension` parmi ses clés CONNUES — donc exclue du canal
/// opaque `extra` — alors que son décodage dépend d'un paramètre **optionnel**
/// du lecteur (`extensionParser`). Les deux propriétés sont incompatibles : un
/// hôte qui n'a aucune raison de connaître le schéma d'un autre lit `null`, la
/// clé brute n'est recueillie **nulle part**, et la première réécriture
/// l'efface — du store local, puis du cloud à la synchronisation suivante.
///
/// **Un hôte détruisait donc les données d'un autre, silencieusement, au
/// DÉCODAGE — avant qu'une seule ligne de code applicatif ne s'exécute.** C'est
/// exactement ce que le slot d'extension AD-4 existe pour éviter, et `extension`
/// — le slot **versionné**, donc le plus structurant — en était le seul exclu.
///
/// Le remède existait déjà dans le dépôt (`ZOpaqueNoteExtension`, `zcrud_note`),
/// écrit pour ce problème précis mais confiné à UNE entité sur quatorze. Il est
/// ici **promu** au cœur, pour que toutes en bénéficient.
library;

import 'z_extension.dart';
import 'z_json_equality.dart';

/// Payload `extension` porté **verbatim**, faute d'avoir été typé.
///
/// Produite quand — et seulement quand — la clé `extension` porte une **`Map`**
/// que rien n'a su typer :
/// - aucun `extensionParser` n'a été injecté (le cas de CR-LEX-33) ;
/// - **ou** le parser injecté a rendu `null` (version future, sous-schéma
///   inconnu).
///
/// Jamais produite pour un payload non-`Map` (`42`, `'texte'`, `[]`) : il n'y a
/// alors rien de structuré à préserver ⇒ `extension == null`.
///
/// ⚠️ **Ce n'est PAS un type applicatif.** Une app ne doit jamais en dépendre
/// pour lire ses données — elle teste `entity.extension is MonType`. Sa seule
/// raison d'être est de **ne pas détruire ce qu'on ne sait pas lire**.
class ZOpaqueExtension implements ZExtension {
  const ZOpaqueExtension._(this.payload);

  /// Enveloppe [raw] s'il s'agit d'une `Map` (clés coercées en `String` — Hive
  /// rend des `Map<dynamic, dynamic>`), sinon `null`. **Ne throw JAMAIS** (AD-10).
  static ZOpaqueExtension? of(Object? raw) {
    if (raw is! Map) return null;
    return ZOpaqueExtension._(
      Map<String, dynamic>.unmodifiable(<String, dynamic>{
        for (final MapEntry<Object?, Object?> e in raw.entries)
          '${e.key}': e.value,
      }),
    );
  }

  /// Le payload JSON **brut**, tel qu'il a été lu du store (non modifiable).
  ///
  /// Un hôte qui doit inspecter un slot non typé (migration, diagnostic) le lit
  /// ici — sans que le domaine ait eu à l'interpréter.
  final Map<String, dynamic> payload;

  /// Version déclarée par le payload (`format_version`), ou `0` si absente.
  ///
  /// ⚠️ **Rapportée, jamais interprétée** : ce type ne prétend rien comprendre
  /// au sous-schéma — c'est précisément pourquoi il le préserve au lieu de le
  /// juger.
  @override
  int get formatVersion {
    final Object? v = payload['format_version'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// 🔴 **IDENTITÉ** — réémet le payload VERBATIM. C'est tout le correctif : ce
  /// que le domaine n'a pas su lire, il le rend tel quel au lieu de l'effacer.
  @override
  Map<String, dynamic> toJson() => payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZOpaqueExtension &&
          // Égalité PROFONDE : un payload opaque est du JSON arbitraire, donc
          // imbriqué. Une égalité superficielle casserait l'`==` entre une
          // entité en mémoire et la même relue du store.
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => zJsonHash(payload);

  @override
  String toString() => 'ZOpaqueExtension(payload: $payload)';
}

/// Décode le slot `extension`, **sans jamais le détruire** (CR-LEX-33).
///
/// Remplace le motif `if (parser == null) return null;` que treize entités du
/// dépôt portaient à l'identique. Ordre de résolution :
///
/// 1. le [parser] de l'hôte, s'il est fourni ET s'il sait typer le payload ;
/// 2. à défaut, un [ZOpaqueExtension] qui porte le payload verbatim ;
/// 3. `null` seulement si `raw` n'est pas une `Map` — il n'y a alors rien de
///    structuré à préserver.
///
/// **Ne throw JAMAIS** (AD-10) : un parser d'hôte qui lève est traité comme un
/// parser qui n'a pas su typer, donc le payload est préservé quand même.
ZExtension? zDecodeExtension(
  Object? raw,
  ZExtension? Function(Map<String, dynamic>)? parser,
) {
  if (raw is! Map) return null;
  final Map<String, dynamic> map = <String, dynamic>{
    for (final MapEntry<Object?, Object?> e in raw.entries) '${e.key}': e.value,
  };
  if (parser != null) {
    try {
      final ZExtension? typed = parser(map);
      if (typed != null) return typed;
    } on Object {
      // Un parser d'hôte défaillant ne doit pas coûter la donnée : on retombe
      // sur la préservation opaque plutôt que sur la destruction.
    }
  }
  return ZOpaqueExtension.of(map);
}

/// `ZOpaqueNoteExtension` — **canal de SURVIE** du payload `extension` **non
/// décodé** (remédiation **MAJEUR-1** et **MAJEUR-2**, code-review ES-2.2).
///
/// ## 🔴 Le problème : `formatVersion` avait une EXISTENCE, aucun POUVOIR
///
/// `ZExtension` promet une extension *« riche, **rétro-compatible**, versionnée
/// indépendamment du parent »* et une **« évolution additive »** (AD-4 pt.1 /
/// AD-10). **Le mécanisme livré en v1 ne savait faire qu'une chose de la version :
/// la JETER.**
///
/// **MESURÉ (v1)** — les **deux** voies par lesquelles un payload d'extension
/// disparaissait **définitivement** :
///
/// ```dart
/// // (1) MAJEUR-1 — LA VOIE DU REGISTRE (la SEULE que le store emprunte) :
/// //     `ZcrudRegistry` n'offre AUCUN slot d'injection ⇒ il appelle
/// //     `ZSmartNote.fromMap(map)` TOUT COURT, sans `extensionParser`.
/// ZSmartNote.fromMap({'extension': {'format_version': 1, 'url': '…'}});
/// //   ⇒ extension == null  ⇒  toMap() N'ÉMET PAS la clé  ⇒  ⛔ EFFACÉE au `put`.
///
/// // (2) MAJEUR-2 — UNE VERSION FUTURE, MÊME AVEC LE PARSER :
/// ZSmartNote.fromMap({'extension': {'format_version': 2, …}},
///                    extensionParser: ZNoteAudio.fromJsonSafe);
/// //   ⇒ ZNoteAudio.fromJsonSafe rend `null` (version non gérée)
/// //   ⇒ extension == null  ⇒  ⛔ le payload v2 est EFFACÉ à la réécriture.
/// ```
///
/// **Scénario réel de (2)** : l'app **v2** écrit un slot v2 ; l'app **v1** (client
/// resté en arrière) **lit** la note, l'utilisateur en **change le titre**, l'app
/// **réécrit** ⇒ **le slot v2 est effacé du store**. La version suivante ne le
/// retrouvera **jamais**. C'est l'**exact contraire** d'une « évolution additive ».
///
/// ## ✅ Le correctif : un payload non décodé n'est plus JETÉ, il est PORTÉ
///
/// [ZSmartNote.fromMap] ne rend plus `null` sur un payload `Map` qu'il ne sait pas
/// typer : il l'enveloppe dans une [ZOpaqueNoteExtension] qui **réémet le JSON
/// VERBATIM** ([toJson] = identité). Le round-trip devient **conservatif** :
///
/// ```dart
/// final n = ZSmartNote.fromMap(map);                 // aucun parser (registre)
/// n.extension is ZOpaqueNoteExtension                // true
/// n.toMap()['extension'] == map['extension']         // ✅ PAYLOAD PRÉSERVÉ
/// ```
///
/// **C'est la SEULE lecture d'AD-4 qui rende le mot « additive » VRAI** : ce qu'on
/// ne sait pas lire, on ne le détruit pas — on le rend tel qu'on l'a reçu.
///
/// ## ⛔ Ce que ce correctif NE règle PAS — **DW-ES14-2 reste OUVERTE**
///
/// La **donnée** survit ; le **type** ne revient pas. Sur la voie registre, le
/// parser de l'app (`ZNoteAudio.fromJsonSafe`) n'est **toujours pas injectable** ⇒
/// `note.extension` est une [ZOpaqueNoteExtension], **jamais** un `ZNoteAudio` :
/// l'app **ne peut pas s'en servir**. Le correctif de fond (slot d'injection dans
/// `ZcrudRegistry`) **écrit `zcrud_core`** ⇒ **hors périmètre ES-2.2** (D9).
///
/// ⇒ La perte **fonctionnelle** est **ÉPINGLÉE EN MACHINE** (verrou
/// `z_smart_note_test.dart` › groupe `DW-ES14-2`), et la dette est **escaladée**
/// (`architecture.md` § Deferred) : `ZNoteAudio` **FALSIFIE** la clause
/// d'échappement n°1 de DW-ES14-2 (*« l'entité n'utilise pas le slot
/// `extension` »*) — elle est la **première `ZExtension` concrète du repo**.
library;

import 'package:zcrud_core/domain.dart';

import 'z_note_content.dart';

/// Extension **opaque** : un payload `extension` **non décodé**, porté **verbatim**
/// pour qu'il **SURVIVE** au round-trip (AD-4 pt.1 « évolution additive »).
///
/// Produite par [ZSmartNote.fromMap] quand — et **seulement** quand — la clé
/// `extension` porte une **`Map`** que **rien** n'a su typer :
/// - **aucun** `extensionParser` n'a été injecté (⚠️ **voie du registre** —
///   DW-ES14-2) ;
/// - **ou** le parser injecté a rendu `null` (version **future/non gérée**,
///   sous-schéma inconnu).
///
/// Elle n'est **jamais** produite pour un payload non-`Map` (`42`, `'texte'`,
/// `[]`) : il n'y a alors **rien de structuré à préserver** ⇒ `extension == null`.
///
/// ⚠️ **Ce n'est PAS un type applicatif** : une app ne doit **jamais** en dépendre
/// pour lire l'audio — elle doit tester `note.extension is ZNoteAudio`. Sa seule
/// raison d'être est de **ne pas détruire** ce qu'on ne sait pas lire.
class ZOpaqueNoteExtension implements ZExtension {
  const ZOpaqueNoteExtension._(this.payload);

  /// Enveloppe [raw] s'il s'agit d'une `Map` (clés coercées en `String` — Hive),
  /// sinon `null` (rien de structuré à préserver). **Ne throw JAMAIS** (AD-10).
  static ZOpaqueNoteExtension? of(Object? raw) {
    if (raw is! Map) return null;
    return ZOpaqueNoteExtension._(
      Map<String, dynamic>.unmodifiable(<String, dynamic>{
        for (final e in raw.entries) '${e.key}': e.value,
      }),
    );
  }

  /// Le payload JSON **brut**, tel qu'il a été lu du store (non modifiable).
  ///
  /// Une app qui doit inspecter un slot non typé (migration, diagnostic) le lit
  /// **ici** — sans que le domaine ait eu à l'interpréter.
  final Map<String, dynamic> payload;

  /// La version **déclarée par le payload** (`format_version`), ou `0` si elle est
  /// absente/illisible.
  ///
  /// ⚠️ Elle est **rapportée, jamais interprétée** : cette classe ne prétend
  /// **rien** comprendre au sous-schéma — c'est précisément pourquoi elle le
  /// **préserve** au lieu de le juger.
  @override
  int get formatVersion {
    final v = payload['format_version'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  /// 🔴 **IDENTITÉ** — réémet le payload **VERBATIM**. C'est tout le correctif :
  /// ce que le domaine n'a pas su lire, il le **rend tel quel**, au lieu de
  /// l'effacer.
  @override
  Map<String, dynamic> toJson() => payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZOpaqueNoteExtension &&
          // Égalité PROFONDE : un payload opaque est du JSON ARBITRAIRE, donc
          // IMBRIQUÉ. Une égalité superficielle casserait l'`==` entre une note
          // en mémoire et la même relue du store (MEDIUM-1).
          noteJsonEquals(payload, other.payload);

  @override
  int get hashCode => noteJsonHash(payload);

  @override
  String toString() => 'ZOpaqueNoteExtension(payload: $payload)';
}

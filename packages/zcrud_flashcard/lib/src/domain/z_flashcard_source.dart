/// Provenance polymorphe d'une flashcard `ZFlashcardSource` (Story E9-1, AC6).
///
/// origine: lex_core (module « Étude ») — `flashcard_source.dart:13` : union
/// `sealed` interne à discriminant `kind`. **Recommandation zcrud (canonique
/// §2.1)** : router les `kind` non reconnus vers un variant de repli
/// [ZCustomSource] **au lieu de lever** — l'app hôte branche le variant
/// « article » (douane) via `ZSourceRegistry.register('article', …)`, **sans
/// forker** le package flashcard ni le cœur.
///
/// **AD-4 (extension inter-package par registre, PAS par `sealed`)** : la
/// hiérarchie `sealed` ci-dessous reste `sealed` **en interne** (exhaustivité
/// du `switch` du package) ; l'ouverture inter-package passe **exclusivement**
/// par le [ZSourceRegistry] injecté. **`'article'` n'est JAMAIS un variant codé
/// en dur ici** (sinon fork douane dans le générique).
///
/// **Seam d'injection du registre (Dev Notes Tâche 3)** : le générateur ne peut
/// pas passer le registre au `fromMap` du modèle. `ZFlashcardSource` expose donc
/// un [fromJson]/[toJson] **manuels** paramétrés par un `ZSourceRegistry?`
/// optionnel, branchés depuis `ZFlashcard.fromMap`/`ZFlashcard.toMap`. Sans
/// registre, un `kind` inconnu retombe **sûrement** sur [ZCustomSource]
/// (payload conservé, round-trip préservé), **jamais** de throw (AD-10).
library;

import 'package:zcrud_core/domain.dart';

/// Discriminant persisté du variant de provenance.
const String _kKind = 'kind';

/// Union scellée de provenance. Chaque variant porte son discriminant [kind] et
/// sait se sérialiser via [toJson] (consultant le [ZSourceRegistry] injecté pour
/// les `kind` ouverts, ex. « article »).
sealed class ZFlashcardSource {
  /// Constructeur `const` (variants immuables).
  const ZFlashcardSource();

  /// Discriminant du variant (`'note'`, `'conversation'`, `'document'`, ou un
  /// `kind` ouvert porté par [ZCustomSource]).
  String get kind;

  /// Sérialise vers la map persistée (incluant [kind]).
  ///
  /// Pour un [ZCustomSource] dont le [kind] est **enregistré** dans [registry],
  /// le codec de l'app produit le corps ; sinon le payload est émis tel quel.
  Map<String, dynamic> toJson({ZSourceRegistry? registry});

  /// Reconstruit **défensivement** une provenance depuis [raw] (AD-10).
  ///
  /// - `raw` non-map / `null` → `null` ;
  /// - `kind` reconnu (`note`/`conversation`/`document`) → variant générique
  ///   (champs manquants → défauts sûrs) ;
  /// - `kind` **enregistré** dans [registry] → [ZCustomSource] dont le payload
  ///   est reconstruit par le codec de l'app ;
  /// - `kind` inconnu et non enregistré → [ZCustomSource] conservant le payload ;
  /// - **jamais** de throw (un `kind` absent → `null`).
  static ZFlashcardSource? fromJson(
    Object? raw, {
    ZSourceRegistry? registry,
  }) {
    final map = _coerceStringMap(raw);
    if (map == null) return null;
    final kind = map[_kKind];
    if (kind is! String || kind.isEmpty) return null;

    switch (kind) {
      case 'note':
        return ZNoteSource(noteId: _asString(map['note_id']));
      case 'conversation':
        return ZConversationSource(
          conversationId: _asString(map['conversation_id']),
          messageId: _asString(map['message_id']),
        );
      case 'document':
        return ZDocumentSource(
          documentId: _asString(map['document_id']),
          page: _asIntOrNull(map['page']),
        );
      default:
        final body = _bodyOf(map);
        final codec = registry?.tryCodecFor(kind);
        if (codec != null) {
          // Codec de l'app hôte (ex. « article ») : reconstruction défensive.
          final decoded = _guard(() => codec.fromJson(map));
          final payload = _coerceStringMap(decoded) ?? body;
          return ZCustomSource(kind, payload);
        }
        return ZCustomSource(kind, body);
    }
  }
}

/// Provenance : note personnelle (`kind = 'note'`).
class ZNoteSource extends ZFlashcardSource {
  /// Construit une provenance de note.
  const ZNoteSource({required this.noteId});

  /// Identifiant de la note d'origine.
  final String noteId;

  @override
  String get kind => 'note';

  @override
  Map<String, dynamic> toJson({ZSourceRegistry? registry}) => <String, dynamic>{
        _kKind: kind,
        'note_id': noteId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNoteSource && noteId == other.noteId;

  @override
  int get hashCode => Object.hash(kind, noteId);
}

/// Provenance : conversation (`kind = 'conversation'`).
class ZConversationSource extends ZFlashcardSource {
  /// Construit une provenance de conversation.
  const ZConversationSource({
    required this.conversationId,
    required this.messageId,
  });

  /// Identifiant de la conversation d'origine.
  final String conversationId;

  /// Identifiant du message précis.
  final String messageId;

  @override
  String get kind => 'conversation';

  @override
  Map<String, dynamic> toJson({ZSourceRegistry? registry}) => <String, dynamic>{
        _kKind: kind,
        'conversation_id': conversationId,
        'message_id': messageId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZConversationSource &&
          conversationId == other.conversationId &&
          messageId == other.messageId;

  @override
  int get hashCode => Object.hash(kind, conversationId, messageId);
}

/// Provenance : document importé (`kind = 'document'`).
class ZDocumentSource extends ZFlashcardSource {
  /// Construit une provenance de document.
  const ZDocumentSource({required this.documentId, this.page});

  /// Identifiant du document d'origine.
  final String documentId;

  /// Page optionnelle.
  final int? page;

  @override
  String get kind => 'document';

  @override
  Map<String, dynamic> toJson({ZSourceRegistry? registry}) => <String, dynamic>{
        _kKind: kind,
        'document_id': documentId,
        if (page != null) 'page': page,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDocumentSource &&
          documentId == other.documentId &&
          page == other.page;

  @override
  int get hashCode => Object.hash(kind, documentId, page);
}

/// Provenance **ouverte** de repli (`kind` arbitraire + payload libre).
///
/// Porte tout `kind` non reconnu par les variants génériques — notamment le
/// variant « article » (douane) branché par l'app hôte via [ZSourceRegistry].
/// Le [payload] préserve la donnée telle quelle (round-trip garanti même sans
/// codec enregistré).
class ZCustomSource extends ZFlashcardSource {
  /// Construit une provenance ouverte pour [kind] portant [payload].
  ZCustomSource(this.kind, Map<String, dynamic> payload)
      : payload = Map<String, dynamic>.unmodifiable(payload);

  @override
  final String kind;

  /// Charge utile arbitraire (clés hors [_kKind]), préservée telle quelle.
  final Map<String, dynamic> payload;

  @override
  Map<String, dynamic> toJson({ZSourceRegistry? registry}) {
    final codec = registry?.tryCodecFor(kind);
    final body = codec != null
        ? (_guard(() => codec.toJson(payload)) ?? payload)
        : payload;
    return <String, dynamic>{
      ...body,
      _kKind: kind,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCustomSource &&
          kind == other.kind &&
          _mapEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(kind, _mapHash(payload));
}

// ---------------------------------------------------------------------------
// Helpers défensifs (AD-10) — pur-Dart, sans throw.
// ---------------------------------------------------------------------------

/// Corps de la map sans le discriminant [_kKind].
Map<String, dynamic> _bodyOf(Map<String, dynamic> map) => <String, dynamic>{
      for (final e in map.entries)
        if (e.key != _kKind) e.key: e.value,
    };

/// Coerce défensive vers `Map<String, dynamic>` (repli `null` — jamais de throw).
Map<String, dynamic>? _coerceStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Lecture défensive d'une `String` (repli `''`).
String _asString(Object? v) => v is String ? v : '';

/// Lecture défensive d'un `int?` (tolère `String`/`num`, repli `null`).
int? _asIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Exécute [parse] et renvoie son résultat, ou `null` sur toute exception.
T? _guard<T>(T Function() parse) {
  try {
    return parse();
  } catch (_) {
    return null;
  }
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

int _mapHash(Map<String, dynamic> m) {
  var h = 0;
  for (final e in m.entries) {
    h ^= Object.hash(e.key, e.value);
  }
  return h;
}

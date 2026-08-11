/// Provenance polymorphe d'une flashcard `ZFlashcardSource`.
///
/// Union scellée en interne, à discriminant `kind`. Les `kind` non reconnus
/// sont routés vers un variant de repli ([ZCustomSource]) au lieu de lever :
/// une application hôte peut brancher un variant applicatif (par exemple une
/// provenance « article ») via `ZSourceRegistry.register('article', …)`,
/// sans forker ce paquet ni le cœur.
///
/// L'extension inter-paquet passe exclusivement par le [ZSourceRegistry]
/// injecté (invariant AD-4) : la hiérarchie `sealed` ci-dessous reste scellée
/// en interne (exhaustivité du `switch` de ce paquet), mais aucun variant
/// applicatif n'est jamais codé en dur ici.
///
/// Le générateur ne peut pas transmettre le registre au décodeur d'un
/// modèle : `ZFlashcardSource` expose donc un [fromJson]/[toJson] manuels,
/// paramétrés par un `ZSourceRegistry?` optionnel, branchés depuis
/// `ZFlashcard.fromMap`/`ZFlashcard.toMap`. Sans registre, un `kind` inconnu
/// retombe sûrement sur [ZCustomSource] (payload conservé, round-trip
/// préservé), jamais sur une exception (invariant AD-10).
library;

import 'package:zcrud_core/domain.dart';

/// Discriminant persisté du variant de provenance.
const String _kKind = 'kind';

/// Union scellée de provenance. Chaque variant porte son discriminant [kind]
/// et sait se sérialiser via [toJson] (consultant le [ZSourceRegistry]
/// injecté pour les `kind` ouverts).
sealed class ZFlashcardSource {
  /// Constructeur `const` (variants immuables).
  const ZFlashcardSource();

  /// Discriminant du variant (`'note'`, `'conversation'`, `'document'`, ou un
  /// `kind` ouvert porté par [ZCustomSource]).
  String get kind;

  /// Sérialise vers la map persistée (incluant [kind]).
  ///
  /// Pour un [ZCustomSource] dont le [kind] est enregistré dans [registry],
  /// le codec de l'application produit le corps ; sinon le payload est émis
  /// tel quel.
  Map<String, dynamic> toJson({ZSourceRegistry? registry});

  /// Reconstruit défensivement une provenance depuis [raw] (invariant
  /// AD-10).
  ///
  /// - `raw` non-map ou `null` → `null` ;
  /// - `kind` reconnu (`note`/`conversation`/`document`) → variant générique
  ///   (champs manquants → défauts sûrs) ;
  /// - `kind` enregistré dans [registry] → [ZCustomSource] dont le payload
  ///   est reconstruit par le codec de l'application ;
  /// - `kind` inconnu et non enregistré → [ZCustomSource] conservant le
  ///   payload ;
  /// - jamais d'exception (un `kind` absent rend `null`).
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
          // Codec de l'application hôte : reconstruction défensive.
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

/// Provenance ouverte de repli (`kind` arbitraire et payload libre).
///
/// Porte tout `kind` non reconnu par les variants génériques — notamment un
/// variant applicatif branché par l'hôte via [ZSourceRegistry]. Le [payload]
/// préserve la donnée telle quelle (round-trip garanti même sans codec
/// enregistré).
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
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(kind, zJsonHash(payload));
}

// ---------------------------------------------------------------------------
// Fonctions défensives (invariant AD-10) — pur-Dart, sans exception.
// ---------------------------------------------------------------------------

/// Corps de la map sans le discriminant [_kKind].
Map<String, dynamic> _bodyOf(Map<String, dynamic> map) => <String, dynamic>{
      for (final e in map.entries)
        if (e.key != _kKind) e.key: e.value,
    };

/// Coerce défensive vers `Map<String, dynamic>` (repli `null` — jamais
/// d'exception).
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

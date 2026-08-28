/// Contrats purs d'extraction du texte d'un document.
///
/// L'application hôte fournit le moteur et interprète [ZDocumentTextRequest.source]
/// comme une référence opaque. Ce domaine ne connaît ni format de fichier, ni
/// transport, ni plugin.
library;

import 'package:zcrud_core/domain.dart';

/// Requête immuable d'extraction de texte.
class ZDocumentTextRequest {
  /// Construit une requête pour [documentId] et sa [source] opaque.
  ZDocumentTextRequest({
    required this.documentId,
    required this.source,
    Set<int>? pages,
  }) : pages = pages == null ? null : Set<int>.unmodifiable(pages);

  /// Identifiant opaque du document.
  final String documentId;

  /// Pages à extraire, ou `null` pour laisser le moteur traiter le document.
  final Set<int>? pages;

  /// Référence source opaque, de même nature que le chemin de stockage du
  /// document ; le port décide comment la résoudre.
  final String source;

  /// Reconstruit une requête sans lever sur une valeur absente ou corrompue.
  factory ZDocumentTextRequest.fromMap(Map<String, dynamic> map) {
    final rawPages = map['pages'];
    return ZDocumentTextRequest(
      documentId: zJsonString(map['document_id']),
      source: zJsonString(map['source']),
      pages: rawPages is List
          ? <int>{for (final value in rawPages) ?zJsonIntOrNull(value)}
          : null,
    );
  }

  /// Sérialise la requête avec des clés snake_case.
  Map<String, dynamic> toMap() {
    final sortedPages = pages == null ? null : (<int>[...pages!]..sort());
    return <String, dynamic>{
      'document_id': documentId,
      'pages': ?sortedPages,
      'source': source,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDocumentTextRequest &&
          documentId == other.documentId &&
          source == other.source &&
          _setEquals(pages, other.pages);

  @override
  int get hashCode => Object.hash(
    documentId,
    source,
    pages == null ? null : Object.hashAllUnordered(pages!),
  );
}

/// Texte extrait d'une page, immuable et comparable par valeur.
class ZDocumentPageText {
  /// Construit le texte [text] de la [page].
  const ZDocumentPageText({
    required this.page,
    required this.text,
    this.confidence,
  });

  /// Numéro ou index de page tel que fourni par le moteur.
  final int page;

  /// Texte reconnu sur la page, éventuellement vide.
  final String text;

  /// Niveau de confiance du moteur, ou `null` s'il n'en fournit pas.
  final double? confidence;

  /// Reconstruit une page sans lever sur une valeur absente ou corrompue.
  factory ZDocumentPageText.fromMap(Map<String, dynamic> map) {
    final decodedConfidence = zJsonDoubleOrNull(map['confidence']);
    return ZDocumentPageText(
      page: zJsonInt(map['page'], 0),
      text: zJsonString(map['text']),
      confidence:
          decodedConfidence?.isFinite ?? false ? decodedConfidence : null,
    );
  }

  /// Sérialise la page avec ses champs canoniques.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'page': page,
    'text': text,
    if (confidence != null) 'confidence': confidence,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDocumentPageText &&
          page == other.page &&
          text == other.text &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(page, text, confidence);
}

/// Résultat immuable d'une extraction, ordonné par pages produites.
class ZDocumentText {
  /// Construit un résultat et fige la liste [pages].
  ZDocumentText({List<ZDocumentPageText> pages = const <ZDocumentPageText>[]})
    : pages = List<ZDocumentPageText>.unmodifiable(pages);

  /// Pages reconnues, dans l'ordre choisi par le moteur.
  final List<ZDocumentPageText> pages;

  /// Reconstruit un résultat en ignorant chaque enfant illisible sans perdre
  /// les autres pages valides.
  factory ZDocumentText.fromMap(Map<String, dynamic> map) => ZDocumentText(
    pages:
        zJsonDecodeList<ZDocumentPageText>(map['pages'], (Object? element) {
          final pageMap = zJsonMap(element);
          return pageMap == null ? null : ZDocumentPageText.fromMap(pageMap);
        }) ??
        const <ZDocumentPageText>[],
  );

  /// Sérialise les pages dans leur ordre.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'pages': <Map<String, dynamic>>[for (final page in pages) page.toMap()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDocumentText && zListEquals(pages, other.pages);

  @override
  int get hashCode => zListHash(pages);
}

/// Port neutre d'extraction du texte déjà porté par un document.
abstract interface class ZDocumentTextExtractionPort {
  /// `true` si l'implémentation peut servir une extraction maintenant.
  bool get isAvailable;

  /// Extrait [request] ; rend `Left` pour tout échec et `Right` au succès.
  Future<ZResult<ZDocumentText>> extract(ZDocumentTextRequest request);
}

/// Extraction inerte utilisée quand aucun moteur n'est configuré.
class ZInertDocumentTextExtractionPort
    implements ZDocumentTextExtractionPort {
  /// Construit le port inerte.
  const ZInertDocumentTextExtractionPort();

  @override
  bool get isAvailable => false;

  @override
  Future<ZResult<ZDocumentText>> extract(ZDocumentTextRequest request) async =>
      const Left<ZFailure, ZDocumentText>(
        ZUnsupportedOperationFailure(
          'document text extraction is not configured',
          operation: 'extract',
        ),
      );
}

bool _setEquals<T>(Set<T>? a, Set<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  return a.containsAll(b);
}

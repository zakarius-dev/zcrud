/// Seam IA neutre de **génération de flashcards** `ZFlashcardGenerationPort`
/// (Story ES-9.1, AC1/AC5).
///
/// origine: seam IA neutre du domaine `zcrud_study` (AD-5/AD-11/AD-12). Le port
/// est un **contrat pur** (`abstract interface class`) : l'app hôte l'*implements*
/// avec son routeur IA. **Aucune** mécanique de transport ne fuit dans le
/// domaine — prompts, `toWireJson`, SSE, endpoints et clés restent CÔTÉ APP.
///
/// **`abstract interface class` (AD-4)** : frontière inter-package ⇒ **jamais
/// `sealed`** (pas d'exhaustivité imposée, l'app *implements* librement). Aucune
/// impl de référence n'est fournie dans le package : le port n'a aucun
/// comportement neutre à factoriser (contraste avec un repository Template
/// Method).
///
/// **Provenance registre-pluggable (AC5)** : la requête porte une
/// [ZFlashcardSource] optionnelle (variant IFFD/lex `article`/`subject`/
/// `hsSection`/`chatConversationId` enregistré par l'app via `ZSourceRegistry`,
/// AD-4). L'impl app-side **estampille** `request.provenance` dans
/// [ZFlashcard.source] des cartes produites, de sorte que la provenance
/// round-trippe **exactement** via `ZFlashcard.toMap`/`fromMap(sourceRegistry:)`.
/// `zcrud_study` ne code **aucun** `kind` de provenance en dur.
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Requête **immuable** de génération de flashcards (value-object, `==`/`hashCode`
/// par valeur).
///
/// Ne porte que du **contenu source neutre** : aucun prompt, aucun endpoint,
/// aucune clé (AC2/AD-12). Le [provenance] optionnel est apposé aux cartes
/// produites (AC5).
class ZFlashcardGenerationRequest {
  /// Construit une requête de génération à partir du [content] source.
  const ZFlashcardGenerationRequest({
    required this.content,
    this.count,
    this.languageTag,
    this.provenance,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu source neutre à partir duquel générer les cartes (texte, note…).
  final String content;

  /// Nombre de cartes souhaité, ou `null` (l'app décide un défaut).
  final int? count;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

  /// Provenance **ouverte** à estampiller dans `ZFlashcard.source` des cartes
  /// produites (variant IFFD/lex enregistré via `ZSourceRegistry`, AC5). `null`
  /// = pas de provenance imposée.
  final ZFlashcardSource? provenance;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres app-specific neutres). Défaut `const {}`.
  /// **Normalisée à la LECTURE (AD-19.1)** : les clés de sync réservées
  /// (`updated_at`/`is_deleted`) sont écartées — jamais réémises. Ce DTO n'est
  /// pas persisté, mais la garde machine reste uniforme sur tout porteur d'`extra`.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardGenerationRequest &&
          content == other.content &&
          count == other.count &&
          languageTag == other.languageTag &&
          provenance == other.provenance &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(content, count, languageTag, provenance, zJsonHash(extra));
}

/// Port neutre de **génération de flashcards** (AD-5 : `Either<ZFailure,·>`).
///
/// L'app hôte l'*implements* avec son routeur IA. Retourne
/// `ZResult<List<ZFlashcard>>` (`Either<ZFailure, List<ZFlashcard>>`) — **jamais**
/// une `List<ZFlashcard>` nue, **jamais** un `Stream` enveloppé (AD-5).
abstract interface class ZFlashcardGenerationPort {
  /// Génère des flashcards depuis [request]. `Left` en cas d'échec (quota,
  /// réseau, parsing), `Right` avec les cartes produites en cas de succès.
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  );
}

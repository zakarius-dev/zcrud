/// Génération d'un artefact — `ZChatArtifactGenerationRequest`,
/// `ZChatArtifactContent`, `ZChatArtifactGenerationPort`, et **la séquence
/// de génération** que le socle exécute ([zChatRunArtifactGeneration],
/// [ZChatArtifactGenerationRunner]).
///
/// ## La séquence, et pourquoi le socle l'exécute
///
/// Générer un artefact se fait toujours en cinq temps :
///
/// 1. **refuser** une matière vide — sans appel, sans occupation ;
/// 2. **marquer** l'artefact occupé ;
/// 3. **appeler** le port ;
/// 4. **écrire** le résultat, **seulement** s'il est complet, sans erreur et
///    non vide ;
/// 5. **démarquer** — dans **tous** les cas, exception du port comprise.
///
/// Le cinquième temps est celui qu'un hôte perd sans s'en apercevoir : sans
/// lui, l'indicateur reste allumé indéfiniment et le verbe reste désactivé,
/// un état dont l'utilisateur ne sort qu'en quittant l'écran, **sans
/// qu'aucune erreur ne s'affiche**. Le socle porte donc la séquence, et la
/// garde.
///
/// ## L'échec remonte, toujours
///
/// Un refus, une exception du port, un résultat vide, un échec d'écriture :
/// chacun rend un `Left` **typé**. Aucun n'est avalé — un échec silencieux
/// laisserait l'utilisateur attendre un artefact qui n'arrivera jamais.
///
/// ## Généralité
///
/// [zChatRunArtifactGeneration] est générique sur le type produit : un
/// générateur d'artefact **structuré** (une liste de cartes, un arbre) s'y
/// branche avec ses propres `generate`/`write`, sans passer par une `String`.
/// [ZChatArtifactGenerationRunner] en est le cas particulier sur contenu
/// opaque, câblé aux ports de ce fichier et au stockage.
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_generation_style.dart';
import '../ai/z_chat_request_token.dart';
import 'z_chat_artifact_store_port.dart';

/// Marqueur d'occupation : `busy: true` au début d'une génération,
/// `busy: false` à sa fin, **quelle qu'en soit l'issue**.
///
/// Tenu par le contrôleur (seul à savoir qu'une génération est en vol) ;
/// jamais par le port de stockage ni par celui d'existence.
typedef ZChatArtifactOccupancyMarker =
    void Function(String messageId, String artifactKey, {required bool busy});

/// Échec : la génération a été **refusée** parce que la matière (ou le sujet
/// exigé) est vide. Aucun appel n'a eu lieu, aucune occupation n'a été posée.
class ZChatArtifactEmptyInputFailure extends ZFailure {
  /// Construit l'échec.
  const ZChatArtifactEmptyInputFailure({
    required this.messageId,
    required this.artifactKey,
  }) : super('artifact generation refused: empty input');

  /// Message concerné.
  final String messageId;

  /// Artefact concerné.
  final String artifactKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactEmptyInputFailure &&
          messageId == other.messageId &&
          artifactKey == other.artifactKey;

  @override
  int get hashCode => Object.hash(runtimeType, messageId, artifactKey);

  @override
  String toString() =>
      'ZChatArtifactEmptyInputFailure($messageId, $artifactKey)';
}

/// Échec : le port a répondu, mais avec un contenu **vide** — rien n'a été
/// écrit, l'artefact précédent (s'il existait) est intact.
class ZChatArtifactEmptyResultFailure extends ZFailure {
  /// Construit l'échec.
  const ZChatArtifactEmptyResultFailure({
    required this.messageId,
    required this.artifactKey,
  }) : super('artifact generation produced an empty result');

  /// Message concerné.
  final String messageId;

  /// Artefact concerné.
  final String artifactKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactEmptyResultFailure &&
          messageId == other.messageId &&
          artifactKey == other.artifactKey;

  @override
  int get hashCode => Object.hash(runtimeType, messageId, artifactKey);

  @override
  String toString() =>
      'ZChatArtifactEmptyResultFailure($messageId, $artifactKey)';
}

/// Échec : le port ou l'écriture a **levé** une exception. Elle est capturée
/// et convertie — jamais propagée (invariant AD-10) — et l'occupation a été
/// retirée.
class ZChatArtifactGenerationFailure extends ZFailure {
  /// Construit l'échec, en conservant la [cause] pour le diagnostic.
  const ZChatArtifactGenerationFailure(
    super.message, {
    required this.messageId,
    required this.artifactKey,
    this.cause,
  });

  /// Message concerné.
  final String messageId;

  /// Artefact concerné.
  final String artifactKey;

  /// Exception d'origine, ou `null`.
  final Object? cause;

  @override
  String toString() =>
      'ZChatArtifactGenerationFailure($messageId, $artifactKey: $message)';
}

/// Requête **immuable** de génération d'un artefact.
///
/// Ne porte aucune mécanique de transport ni de prompt (invariant AD-12) :
/// le [style] est une donnée ouverte, les [instructions] une consigne neutre.
class ZChatArtifactGenerationRequest {
  /// Construit une requête.
  ZChatArtifactGenerationRequest({
    required this.messageId,
    required this.artifactKey,
    required this.notes,
    this.subject = '',
    this.subjectRequired = false,
    this.style,
    this.conversationId,
    this.languageTag,
    this.instructions,
    this.modelId,
    this.providerId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Message porteur de l'artefact.
  final String messageId;

  /// Clé de l'artefact à produire.
  final String artifactKey;

  /// **Matière première** (le contenu du message, des notes…).
  final String notes;

  /// Sujet (`''` si sans objet).
  final String subject;

  /// `true` si un sujet vide doit faire **refuser** la génération, au même
  /// titre qu'une matière vide.
  final bool subjectRequired;

  /// Style demandé, ou `null`.
  final ZChatGenerationStyle? style;

  /// Conversation concernée, ou `null`.
  final String? conversationId;

  /// Étiquette de langue BCP-47, ou `null`.
  final String? languageTag;

  /// Consigne libre neutre, ou `null`. **Jamais** un prompt système.
  final String? instructions;

  /// Identifiant de modèle opaque, transporté verbatim.
  final String? modelId;

  /// Identifiant de fournisseur **opaque**, même statut que [modelId] :
  /// transporté verbatim, jamais interprété, aucun défaut. `null` ⇒ le port
  /// de l'hôte décide. Ce n'est pas un endpoint : c'est une donnée de
  /// routage que l'adaptateur de l'hôte lit. Le fournisseur voyage dans ce
  /// champ typé, pas dans [extra].
  final String? providerId;

  /// Échappatoire non typée (invariant AD-4), immuable.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) en sont
  /// **retirées**, quelle que soit la voie d'écriture (constructeur ou
  /// [copyWith]) : une requête ne transporte jamais de métadonnée de store.
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  // Slot brut, lu uniquement par l'accesseur `extra`.
  final Map<String, dynamic> _extra;

  // La requête n'est pas persistée (aucun `toJson`) : seules les clés de sync
  // hors-entité (AD-9) sont réservées.
  static const Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// `true` si la requête doit être **refusée** sans appel : matière vide,
  /// ou sujet vide alors qu'il est exigé.
  bool get isEmptyInput =>
      notes.trim().isEmpty || (subjectRequired && subject.trim().isEmpty);

  /// Rend une requête **identique**, sauf les champs fournis.
  ///
  /// Un paramètre omis conserve la valeur courante ; un champ nullable se
  /// **retire** en passant `null` explicitement (`copyWith(style: null)`).
  /// C'est ce qui permet à un ajusteur d'hôte de poser [subjectRequired] ou
  /// [style] sans reconstruire toute la requête.
  ZChatArtifactGenerationRequest copyWith({
    Object? messageId = _unset,
    Object? artifactKey = _unset,
    Object? notes = _unset,
    Object? subject = _unset,
    Object? subjectRequired = _unset,
    Object? style = _unset,
    Object? conversationId = _unset,
    Object? languageTag = _unset,
    Object? instructions = _unset,
    Object? modelId = _unset,
    Object? providerId = _unset,
    Object? extra = _unset,
  }) => ZChatArtifactGenerationRequest(
    messageId: identical(messageId, _unset)
        ? this.messageId
        : messageId! as String,
    artifactKey: identical(artifactKey, _unset)
        ? this.artifactKey
        : artifactKey! as String,
    notes: identical(notes, _unset) ? this.notes : notes! as String,
    subject: identical(subject, _unset) ? this.subject : subject! as String,
    subjectRequired: identical(subjectRequired, _unset)
        ? this.subjectRequired
        : subjectRequired! as bool,
    style: identical(style, _unset)
        ? this.style
        : style as ZChatGenerationStyle?,
    conversationId: identical(conversationId, _unset)
        ? this.conversationId
        : conversationId as String?,
    languageTag: identical(languageTag, _unset)
        ? this.languageTag
        : languageTag as String?,
    instructions: identical(instructions, _unset)
        ? this.instructions
        : instructions as String?,
    modelId: identical(modelId, _unset) ? this.modelId : modelId as String?,
    providerId: identical(providerId, _unset)
        ? this.providerId
        : providerId as String?,
    extra: identical(extra, _unset)
        ? this.extra
        : extra! as Map<String, dynamic>,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactGenerationRequest &&
          messageId == other.messageId &&
          artifactKey == other.artifactKey &&
          notes == other.notes &&
          subject == other.subject &&
          subjectRequired == other.subjectRequired &&
          style == other.style &&
          conversationId == other.conversationId &&
          languageTag == other.languageTag &&
          instructions == other.instructions &&
          modelId == other.modelId &&
          providerId == other.providerId &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    messageId,
    artifactKey,
    notes,
    subject,
    subjectRequired,
    style,
    conversationId,
    languageTag,
    instructions,
    modelId,
    providerId,
    zJsonHash(extra),
  );

  @override
  String toString() =>
      'ZChatArtifactGenerationRequest($artifactKey on $messageId, '
      'providerId: $providerId, modelId: $modelId)';
}

/// Contenu **opaque** produit par un port de génération d'artefact.
///
/// Le socle ne l'interprète jamais ; il sait seulement s'il est vide.
class ZChatArtifactContent {
  /// Construit un contenu.
  ZChatArtifactContent(
    this.data, {
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Contenu produit (JSON, Markdown…).
  final String data;

  /// Métadonnées d'hôte libres (invariant AD-4), immuables.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) en sont
  /// **retirées** : un contenu produit ne porte jamais de métadonnée de store.
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  // Slot brut, lu uniquement par l'accesseur `extra`.
  final Map<String, dynamic> _extra;

  static const Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// `true` si [data] est blanc — un tel contenu n'est **jamais** écrit.
  bool get isEmpty => data.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactContent &&
          data == other.data &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(data, zJsonHash(extra));

  @override
  String toString() => 'ZChatArtifactContent(${data.length} chars)';
}

/// Port de génération d'un artefact à contenu opaque — implémenté par l'hôte.
///
/// Un seul membre, paramétré par la requête : le style, le sujet, la
/// matière sont des **données**, pas des signatures. Un port qui diffuse au
/// fil de l'eau agrège et rend **un** résultat : un artefact n'a pas d'état
/// « partiellement écrit ».
///
/// Invariants AD-5/AD-10 : `Either<ZFailure, ·>`. Une exception qui
/// s'échapperait malgré tout est capturée par la séquence et rendue en
/// [ZChatArtifactGenerationFailure].
abstract interface class ZChatArtifactGenerationPort {
  /// Produit l'artefact décrit par [request], annulable par [token].
  Future<ZResult<ZChatArtifactContent>> generate(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
  });
}

/// **La séquence de génération**, générique sur le type produit.
///
/// Ordre garanti : refus sur entrée vide (sans marquage) → `mark(busy: true)`
/// → [generate] → si `Right` non vide, [write] → `mark(busy: false)` —
/// ce dernier **inconditionnellement**, y compris si [generate] ou [write]
/// lève. Le résultat rendu est celui de la génération si l'écriture a
/// réussi, le `Left` de l'étape qui a échoué sinon.
///
/// * [isEmpty] décide si un résultat est vide (⇒
///   [ZChatArtifactEmptyResultFailure], rien n'est écrit) ;
/// * [write] n'est appelé que sur un résultat non vide.
Future<ZResult<T>> zChatRunArtifactGeneration<T>({
  required String messageId,
  required String artifactKey,
  required String notes,
  String subject = '',
  bool subjectRequired = false,
  required ZChatArtifactOccupancyMarker mark,
  required Future<ZResult<T>> Function() generate,
  required bool Function(T result) isEmpty,
  required Future<ZResult<Unit>> Function(T result) write,
}) async {
  if (notes.trim().isEmpty || (subjectRequired && subject.trim().isEmpty)) {
    return Left<ZFailure, T>(
      ZChatArtifactEmptyInputFailure(
        messageId: messageId,
        artifactKey: artifactKey,
      ),
    );
  }
  mark(messageId, artifactKey, busy: true);
  try {
    final ZResult<T> produced;
    try {
      produced = await generate();
    } catch (error) {
      return Left<ZFailure, T>(
        ZChatArtifactGenerationFailure(
          'artifact generation threw: $error',
          messageId: messageId,
          artifactKey: artifactKey,
          cause: error,
        ),
      );
    }
    return await produced.fold((ZFailure f) async => Left<ZFailure, T>(f), (
      T result,
    ) async {
      if (isEmpty(result)) {
        return Left<ZFailure, T>(
          ZChatArtifactEmptyResultFailure(
            messageId: messageId,
            artifactKey: artifactKey,
          ),
        );
      }
      final ZResult<Unit> written;
      try {
        written = await write(result);
      } catch (error) {
        return Left<ZFailure, T>(
          ZChatArtifactGenerationFailure(
            'artifact write threw: $error',
            messageId: messageId,
            artifactKey: artifactKey,
            cause: error,
          ),
        );
      }
      return written.fold(
        (ZFailure f) => Left<ZFailure, T>(f),
        (Unit _) => Right<ZFailure, T>(result),
      );
    });
  } finally {
    // Le démarquage est la garantie qui compte : il a lieu sur chaque chemin
    // de sortie, exception comprise.
    mark(messageId, artifactKey, busy: false);
  }
}

/// La séquence de génération câblée aux ports de ce fichier : un port de
/// génération à contenu opaque, un stockage.
class ZChatArtifactGenerationRunner {
  /// Construit l'exécuteur de séquence.
  const ZChatArtifactGenerationRunner({
    required this.port,
    required this.store,
  });

  /// Port de génération.
  final ZChatArtifactGenerationPort port;

  /// Stockage cible.
  final ZChatArtifactStorePort store;

  /// Exécute la séquence pour [request]. Voir [zChatRunArtifactGeneration]
  /// pour l'ordre garanti et les échecs rendus.
  Future<ZResult<ZChatArtifactContent>> run(
    ZChatArtifactGenerationRequest request, {
    required ZChatRequestToken token,
    required ZChatArtifactOccupancyMarker mark,
  }) => zChatRunArtifactGeneration<ZChatArtifactContent>(
    messageId: request.messageId,
    artifactKey: request.artifactKey,
    notes: request.notes,
    subject: request.subject,
    subjectRequired: request.subjectRequired,
    mark: mark,
    generate: () => port.generate(request, token: token),
    isEmpty: (ZChatArtifactContent c) => c.isEmpty,
    write: (ZChatArtifactContent c) => store.write(
      messageId: request.messageId,
      artifactKey: request.artifactKey,
      content: c.data,
    ),
  );
}

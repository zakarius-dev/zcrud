/// Constitution du pool de session : cartes du dossier union cartes de la
/// conversation, dédoublonnées.
///
/// ## Ce fichier ne réécrit aucun filtre
///
/// Le filtrage (dossier, étiquettes, types, puis plafond de nombre de
/// cartes) est celui de `ZStudySessionSelector` (`zcrud_study_kernel`),
/// réutilisé tel quel. Ce module n'ajoute que ce que le sélecteur ne peut
/// pas savoir : qu'il y a deux origines de cartes, et que leur union doit
/// être dédoublonnée.
///
/// ## Les cartes de conversation entrent sans détour par le dossier
///
/// Le filtre dossier ne s'applique qu'aux cartes déjà rangées dans un
/// dossier. Les cartes produites dans la conversation entrent dans le pool
/// directement : elles sont éphémères (sans `folderId`), et leur appliquer
/// le filtre dossier les éliminerait toutes — obligeant à les ranger d'abord
/// pour pouvoir les réviser, ce que ce parcours évite délibérément. Les
/// filtres étiquettes/types, eux, restent appliqués aux deux origines
/// puisqu'ils portent sur le contenu, pas sur le rangement : c'est
/// [_withoutFolderFilter] qui neutralise la seule dimension « rangement »,
/// en réutilisant le même sélecteur.
///
/// ## Dédoublonnage, et pourquoi la carte persistée gagne
///
/// Une même carte peut arriver des deux côtés (l'assistant régénère une
/// carte déjà rangée dans le dossier). L'ordre de parcours est dossier
/// d'abord, et c'est la première occurrence qui est retenue. Ce n'est pas
/// arbitraire : la carte du dossier porte un `id`, donc son état de
/// répétition espacée (`ZRepetitionInfo`, entité séparée jointe par
/// `flashcardId`) lui est attaché. Retenir la copie éphémère effacerait cet
/// historique de la session, qui repartirait de zéro sur une carte déjà
/// apprise, en silence.
///
/// ## Soft-delete uniquement (invariant AD-9)
///
/// Écarter une carte du pool est une lecture filtrée, jamais une
/// suppression : ce module ne détient aucun repository, n'écrit rien et
/// n'efface rien. Une carte soft-supprimée (`ZSyncMeta.isDeleted`, méta
/// hors-entité — la carte elle-même ne porte pas le drapeau) est exclue via
/// [ZStudyPoolRequest.softDeletedIds], résolu par l'appelant depuis son
/// store.
library;

// `ZStudySessionConfig`/`ZStudySessionSelector`/`ZReviewMode` viennent de
// `zcrud_study_kernel` — mais `zcrud_flashcard` RÉEXPORTE le barrel du kernel
// (politique `hide` documentée dans son barrel), donc l'importer en plus est
// signalé `unnecessary_import`. L'arête `zcrud_chat_study → zcrud_study_kernel`
// reste DÉCLARÉE au pubspec et TANGIBLE : `z_chat_study_launch.dart` importe le
// kernel directement, sans passer par `zcrud_flashcard`.
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Requête immuable de constitution de pool.
class ZStudyPoolRequest {
  /// Construit une requête de pool.
  const ZStudyPoolRequest({
    this.folderCards = const <ZFlashcard>[],
    this.conversationCards = const <ZFlashcard>[],
    this.config,
    this.softDeletedIds = const <String>{},
  });

  /// Cartes déjà rangées dans le dossier d'étude (persistées, `id` non nul).
  final List<ZFlashcard> folderCards;

  /// Cartes produites dans la conversation (typiquement éphémères,
  /// `id == null`).
  final List<ZFlashcard> conversationCards;

  /// Filtres et plafond de session (`null` = aucun filtre, aucun plafond).
  final ZStudySessionConfig? config;

  /// Identifiants soft-supprimés (`ZSyncMeta.isDeleted`), résolus par
  /// l'appelant depuis son store — la méta est hors-entité (invariant AD-9).
  final Set<String> softDeletedIds;
}

/// Résultat de la constitution du pool — la sélection et ce qu'elle a coûté.
///
/// Les compteurs ne sont pas décoratifs : sans eux, « le pool fait 12
/// cartes » ne distingue pas « rien n'a été dédoublonné » de « la moitié a
/// été jetée ».
class ZStudyPool {
  /// Construit un pool.
  const ZStudyPool({
    required this.cards,
    required this.fromFolder,
    required this.fromConversation,
    required this.duplicatesDropped,
    required this.softDeletedDropped,
  });

  /// Pool vide (aucune carte, aucun rejet) — repli neutre.
  static const ZStudyPool empty = ZStudyPool(
    cards: <ZFlashcard>[],
    fromFolder: 0,
    fromConversation: 0,
    duplicatesDropped: 0,
    softDeletedDropped: 0,
  );

  /// Cartes retenues, dans l'ordre déterministe « dossier puis conversation ».
  final List<ZFlashcard> cards;

  /// Nombre de cartes retenues provenant du dossier.
  final int fromFolder;

  /// Nombre de cartes retenues provenant de la conversation.
  final int fromConversation;

  /// Nombre de doublons écartés (une occurrence ultérieure d'une clé déjà vue).
  final int duplicatesDropped;

  /// Nombre de cartes écartées parce que soft-supprimées (invariant AD-9).
  final int softDeletedDropped;

  /// `true` si aucune carte n'est révisable.
  bool get isEmpty => cards.isEmpty;
}

/// Clés de dédoublonnage d'une carte — toujours au moins la clé de contenu.
///
/// Une carte peut porter jusqu'à deux clés : une clé d'identifiant si elle
/// est persistée, et une clé de contenu dans tous les cas. Émettre la clé de
/// contenu pour toute carte, persistée ou non, est ce qui permet de détecter
/// le cas de doublon le plus fréquent de ce parcours : une carte déjà rangée
/// dans le dossier (clé d'identifiant) et sa régénération éphémère par
/// l'assistant (clé de contenu seule, sans identifiant partagé) doivent
/// pouvoir collisionner. N'émettre qu'une seule clé par carte, selon qu'elle
/// est persistée ou non, ferait vivre les deux familles dans des espaces
/// disjoints et laisserait ce cas passer à travers.
///
/// Deux cartes sont donc des doublons dès qu'elles partagent une clé
/// quelconque.
///
/// Corollaire assumé : deux cartes persistées de contenu identique (même
/// type, même question, même réponse) sont fusionnées. C'est voulu — revoir
/// deux fois la même question dans une session est un défaut, pas une
/// fonctionnalité.
///
/// La normalisation est volontairement minimale (casse et espaces
/// collapsés) : plus agressive, elle fusionnerait des cartes réellement
/// distinctes.
Set<String> zStudyPoolKeys(ZFlashcard card) {
  final String content = 'content:${card.type.name}'
      '|${_normalize(card.question)}'
      '|${_normalize(card.answer ?? '')}';
  final String? id = card.id;
  if (id == null || id.trim().isEmpty) return <String>{content};
  return <String>{'id:${id.trim()}', content};
}

/// Constitue le pool de session (fonction pure, sans E/S ni horloge).
///
/// Ne lève jamais (invariant AD-10) : entrées vides, `config` nulle,
/// `count <= 0` dégradent en pool vide.
ZStudyPool zBuildStudyPool(ZStudyPoolRequest request) {
  final ZStudySessionConfig? config = request.config;
  final ZStudySessionSelector? folderSelector =
      config == null ? null : ZStudySessionSelector(config);
  // Le filtre dossier est neutralisé pour l'origine « conversation » : une
  // carte tout juste produite n'a pas de `folderId` (voir la dartdoc de tête,
  // section sur l'absence de détour par le dossier).
  final ZStudySessionSelector? chatSelector = config == null
      ? null
      : ZStudySessionSelector(_withoutFolderFilter(config));

  final Set<String> seen = <String>{};
  final List<ZFlashcard> kept = <ZFlashcard>[];
  var fromFolder = 0;
  var fromConversation = 0;
  var duplicates = 0;
  var softDeleted = 0;

  void absorb(
    List<ZFlashcard> source,
    ZStudySessionSelector? selector, {
    required bool isFolder,
  }) {
    for (final ZFlashcard card in source) {
      final String? id = card.id;
      if (id != null && request.softDeletedIds.contains(id)) {
        softDeleted++;
        continue;
      }
      if (selector != null && !selector.matches(card)) continue;
      final Set<String> keys = zStudyPoolKeys(card);
      // Doublon dès qu'UNE clé quelconque a déjà été vue (cf. `zStudyPoolKeys`).
      if (keys.any(seen.contains)) {
        duplicates++;
        continue;
      }
      seen.addAll(keys);
      kept.add(card);
      if (isFolder) {
        fromFolder++;
      } else {
        fromConversation++;
      }
    }
  }

  absorb(request.folderCards, folderSelector, isFolder: true);
  absorb(request.conversationCards, chatSelector, isFolder: false);

  // Le plafond `count` s'applique à l'UNION dédoublonnée — jamais avant, sinon
  // des doublons consommeraient des places du plafond.
  final int? count = config?.count;
  if (count == null) {
    return ZStudyPool(
      cards: List<ZFlashcard>.unmodifiable(kept),
      fromFolder: fromFolder,
      fromConversation: fromConversation,
      duplicatesDropped: duplicates,
      softDeletedDropped: softDeleted,
    );
  }
  if (count <= 0) {
    return ZStudyPool(
      cards: const <ZFlashcard>[],
      fromFolder: 0,
      fromConversation: 0,
      duplicatesDropped: duplicates,
      softDeletedDropped: softDeleted,
    );
  }
  if (kept.length <= count) {
    return ZStudyPool(
      cards: List<ZFlashcard>.unmodifiable(kept),
      fromFolder: fromFolder,
      fromConversation: fromConversation,
      duplicatesDropped: duplicates,
      softDeletedDropped: softDeleted,
    );
  }
  // Les cartes du dossier sont absorbées EN PREMIER, donc elles occupent
  // exactement les `fromFolder` premières places de `kept` : la troncature ne
  // peut retirer que des cartes de conversation tant qu'il reste des cartes de
  // dossier. Le recomptage est donc EXACT, sans re-parcours.
  final int keptFolder = count < fromFolder ? count : fromFolder;
  return ZStudyPool(
    cards: List<ZFlashcard>.unmodifiable(kept.sublist(0, count)),
    fromFolder: keptFolder,
    fromConversation: count - keptFolder,
    duplicatesDropped: duplicates,
    softDeletedDropped: softDeleted,
  );
}

/// Copie de [config] avec le seul filtre dossier neutralisé.
///
/// `copyWith` ne peut pas remettre `folderId` à `null` (une sentinelle
/// traite `null` comme « inchangé ») : le constructeur nominal est la seule
/// voie correcte. Le plafond `count` est aussi neutralisé ici : il
/// s'applique à l'union des deux origines, pas à chacune séparément.
ZStudySessionConfig _withoutFolderFilter(ZStudySessionConfig config) =>
    ZStudySessionConfig(
      mode: config.mode,
      tagIds: config.tagIds,
      types: config.types,
      extension: config.extension,
      extra: config.extra,
    );

/// Normalisation minimale d'un texte de carte (casse + espaces collapsés).
String _normalize(String raw) =>
    raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

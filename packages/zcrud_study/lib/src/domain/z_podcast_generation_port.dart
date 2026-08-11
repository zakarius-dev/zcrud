/// Seam neutre de génération de podcasts à partir d'un contenu d'étude.
///
/// Le port est un contrat pur (`abstract interface class`, jamais `sealed`
/// — invariant AD-4, l'application hôte l'implémente librement) : elle le
/// branche sur son propre pipeline de synthèse vocale. Aucune mécanique de
/// transport, prompt, endpoint, clé, stockage ni primitive de chiffrement ne
/// fuit dans le domaine (invariant AD-12) — synthèse, routage, streaming,
/// téléversement et hachage restent côté application.
///
/// L'empreinte de la source (`sourceHash`) est **opaque et jamais calculée
/// ici** : le domaine n'importe aucune bibliothèque de hachage. Elle
/// transite par [ZPodcastGenerationRequest.sourceHash] comme `String`
/// fournie par l'appelant (calculée côté application ou binding) ; le seam
/// se contente de la transporter de bout en bout pour permettre une
/// invalidation de cache adressée par contenu.
///
/// La nature de la source d'un podcast est un enum fermé du kernel
/// ([ZPodcastSourceKind] : note, dossier, document), pas une provenance
/// ouverte : contrairement à d'autres seams IA de ce paquet, il n'y a
/// délibérément aucun registre de type ici — la requête porte l'enum kernel
/// tel quel.
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyPodcast, ZPodcastSourceKind, ZPodcastMode;

/// Requête immuable de génération de podcast (value-object, `==`/`hashCode`
/// par valeur — égalité profonde de [extra]).
///
/// Ne porte que du contenu source neutre, adressable par contenu : aucun
/// prompt, aucun endpoint, aucune clé, aucun paramètre de transport
/// (invariant AD-12). Le [sourceHash] est une empreinte opaque fournie par
/// l'appelant — le domaine ne la calcule pas. Le [sourceKind] est un enum
/// kernel fermé.
class ZPodcastGenerationRequest {
  /// Construit une requête de génération à partir du [content] source.
  const ZPodcastGenerationRequest({
    required this.content,
    this.sourceKind = ZPodcastSourceKind.note,
    this.sourceId = '',
    this.folderId = '',
    this.mode = ZPodcastMode.simple,
    this.sourceHash = '',
    this.languageTag,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu source neutre à synthétiser (texte de note, agrégat de dossier…).
  final String content;

  /// Nature fermée de la source (note, dossier ou document) — enum kernel
  /// [ZPodcastSourceKind], pas une provenance ouverte.
  final ZPodcastSourceKind sourceKind;

  /// Identifiant opaque `String` de la source d'étude. Compose l'identité
  /// *content-addressed* du podcast produit via `ZStudyPodcast.buildId`.
  final String sourceId;

  /// Dossier d'appartenance — clé NEUTRE `String` (défaut `''`).
  final String folderId;

  /// Mode de synthèse (voix unique / dialogue) — enum kernel [ZPodcastMode].
  /// Compose le suffixe de l'identité *content-addressed* via `buildId`.
  final ZPodcastMode mode;

  /// Empreinte opaque fournie de la source (défaut `''`) — clé
  /// d'invalidation adressée par contenu.
  ///
  /// Jamais calculée par le domaine : le hachage est un seam
  /// application/binding. Le port se contente de la transporter, et
  /// l'implémentation l'estampille dans `ZStudyPodcast.sourceHash`.
  final String sourceHash;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée pour des paramètres spécifiques à l'application,
  /// normalisée à la lecture : les clés de synchronisation réservées
  /// (`updated_at`, `is_deleted`) sont toujours écartées. Ce DTO n'est pas
  /// persisté, mais cette normalisation garde un comportement uniforme sur
  /// tout porteur d'`extra` du domaine. Défaut `const {}`.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] à la lecture.
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPodcastGenerationRequest &&
          content == other.content &&
          sourceKind == other.sourceKind &&
          sourceId == other.sourceId &&
          folderId == other.folderId &&
          mode == other.mode &&
          sourceHash == other.sourceHash &&
          languageTag == other.languageTag &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        content,
        sourceKind,
        sourceId,
        folderId,
        mode,
        sourceHash,
        languageTag,
        zJsonHash(extra),
      );
}

/// Port neutre de génération de podcast (invariant AD-5 : domaine
/// backend-agnostique).
///
/// L'application hôte l'implémente avec son propre pipeline de synthèse
/// vocale. Retourne `ZResult<ZStudyPodcast>` (`Either<ZFailure,
/// ZStudyPodcast>`) — jamais un `ZStudyPodcast` nu. `Left(ZFailure)` en cas
/// d'échec (quota, réseau, synthèse, analyse), `Right(ZStudyPodcast)` en
/// succès.
///
/// Contrat adressé par contenu : l'implémentation estampille
/// `request.sourceHash` dans `ZStudyPodcast.sourceHash` et matérialise
/// l'identité via `ZStudyPodcast.buildId(request.sourceId, request.mode)`,
/// de sorte que `podcast.isStale(currentHash)` invalide correctement le
/// cache. Le hachage du contenu source reste en amont, côté application.
abstract interface class ZPodcastGenerationPort {
  /// Génère un podcast depuis [request]. `Left` en cas d'échec (quota, réseau,
  /// TTS, parsing), `Right` avec le [ZStudyPodcast] produit en cas de succès.
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  );
}

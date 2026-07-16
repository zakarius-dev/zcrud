/// Seam neutre de **génération de podcasts** `ZPodcastGenerationPort`
/// (Story ES-9.3, AC1/AC4).
///
/// origine: seam de synthèse audio du domaine `zcrud_study` (AD-5/AD-11/AD-12,
/// AD-26). Le port est un **contrat pur** (`abstract interface class`) : l'app
/// hôte l'*implements* avec son pipeline TTS/synthèse audio. **Aucune** mécanique
/// de transport, prompt, endpoint, clé, storage ni **crypto** ne fuit dans le
/// domaine — TTS, routeur, streaming, upload et hashing restent CÔTÉ APP.
///
/// **`abstract interface class` (AD-4)** : frontière inter-package ⇒ **jamais
/// `sealed`** (pas d'exhaustivité imposée, l'app *implements* librement). Aucune
/// impl de référence n'est fournie : le port n'a aucun comportement neutre à
/// factoriser (contraste avec un repository Template Method).
///
/// **`sourceHash` OPAQUE, JAMAIS calculé ici (D4, NFR-S10/SM-S7)** : `package:crypto`
/// / SHA-256 est **INTERDIT** dans le domaine (parité kernel `ZStudyPodcast`,
/// précédent verrouillé `ZColorPalette`). L'empreinte de la source transite par
/// [ZPodcastGenerationRequest.sourceHash] comme `String` **FOURNI par l'appelant**
/// (calculé app-side / binding — SHA-256 côté lex, parité backend préservée sans
/// que le domaine acquière crypto). Le domaine ne hashe **RIEN** ; le seam
/// **transporte** l'empreinte de bout en bout (content-addressed AD-26/D4).
///
/// **Pas de `ZSourceRegistry` ici (contraste ES-9.1)** : la nature de source d'un
/// podcast est un **enum FERMÉ** du kernel ([ZPodcastSourceKind] `{note, folder,
/// document}`), pas une provenance OUVERTE. Le request porte l'enum kernel tel
/// quel — aucun registre, aucun `switch`/`kind` codé en dur (AD-4 : registre
/// **seulement** pour l'ouverture inter-package, absente ici).
library;

import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyPodcast, ZPodcastSourceKind, ZPodcastMode;

/// Requête **immuable** de génération de podcast (value-object, `==`/`hashCode`
/// par valeur — égalité **profonde** de [extra]).
///
/// Ne porte que du **contenu source neutre** *content-addressable* : aucun prompt,
/// aucun endpoint, aucune clé, aucun paramètre de transport (AC2/AC4, AD-12). Le
/// [sourceHash] est une empreinte **OPAQUE FOURNIE** par l'appelant — le domaine
/// ne la **calcule pas** (D4). Le [sourceKind] est un **enum kernel FERMÉ** (pas de
/// `ZSourceRegistry`, contraste ES-9.1).
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

  /// Nature **FERMÉE** de la source (note / dossier / document) — enum kernel
  /// [ZPodcastSourceKind], **pas** une provenance ouverte (aucun `ZSourceRegistry`).
  final ZPodcastSourceKind sourceKind;

  /// Identifiant opaque `String` de la source d'étude. Compose l'identité
  /// *content-addressed* du podcast produit via `ZStudyPodcast.buildId`.
  final String sourceId;

  /// Dossier d'appartenance — clé NEUTRE `String` (défaut `''`).
  final String folderId;

  /// Mode de synthèse (voix unique / dialogue) — enum kernel [ZPodcastMode].
  /// Compose le suffixe de l'identité *content-addressed* via `buildId`.
  final ZPodcastMode mode;

  /// 🔴 Empreinte **OPAQUE FOURNIE** de la source (défaut `''`) — **clé
  /// d'invalidation** *content-addressed* (D4).
  ///
  /// **JAMAIS calculée par le domaine** : le hashing (SHA-256 côté lex) est un
  /// seam app/binding. Le port se contente de la **transporter** et l'impl
  /// l'estampille dans `ZStudyPodcast.sourceHash` (aucun `crypto` ici).
  final String sourceHash;

  /// Étiquette de langue BCP-47 souhaitée (ex. `"fr"`), ou `null`.
  final String? languageTag;

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

/// Port neutre de **génération de podcast** (AD-5 : `Either<ZFailure,·>`).
///
/// L'app hôte l'*implements* avec son pipeline TTS/synthèse audio. Retourne
/// `ZResult<ZStudyPodcast>` (`Either<ZFailure, ZStudyPodcast>`) — **jamais** un
/// `ZStudyPodcast` nu, **jamais** un `Stream` enveloppé (AD-5). `Left(ZFailure)`
/// en cas d'échec (quota, réseau, TTS, parsing), `Right(ZStudyPodcast)` en succès.
///
/// **Contrat *content-addressed* (D4)** : l'impl **estampille**
/// `request.sourceHash` dans `ZStudyPodcast.sourceHash` et matérialise l'identité
/// via `ZStudyPodcast.buildId(request.sourceId, request.mode)` — de sorte que
/// `podcast.isStale(currentHash)` invalide correctement le cache. Le hashing du
/// contenu source reste **amont/app-side** (aucun `crypto` dans ce seam).
abstract interface class ZPodcastGenerationPort {
  /// Génère un podcast depuis [request]. `Left` en cas d'échec (quota, réseau,
  /// TTS, parsing), `Right` avec le [ZStudyPodcast] produit en cas de succès.
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  );
}

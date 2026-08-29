/// Contrat de **lecture** de la galerie publique des dossiers d'étude.
///
/// Port **compagnon** de `ZStudySharingPort` : additif et indépendant. Un
/// implémenteur du port de partage n'a rien à changer pour continuer à
/// fonctionner — ce contrat vit à côté, jamais à l'intérieur. Fournir ce
/// compagnon débloque les surfaces de lecture correspondantes (la galerie
/// publique sait alors s'alimenter seule) ; ne pas le fournir laisse ces
/// surfaces exactement dans leur état antérieur.
///
/// Seam optionnelle du domaine : contrat pur (`abstract interface class`,
/// jamais `sealed`, invariant AD-4). Aucun SDK, endpoint, clé, jeton, nom de
/// collection ni primitive de chiffrement n'y fuit (invariant AD-12).
///
/// Le flux est un `Stream<List<T>>` **nu** (invariant AD-5) — jamais
/// enveloppé dans [ZResult] ; la lecture unitaire retourne
/// `Future<ZResult<T?>>` (invariant AD-11), où `Right(null)` signifie
/// « aucune fiche publiée pour ce dossier » et se distingue donc d'un
/// `Left` (échec de lecture).
///
/// La **pagination** passe par le `ZDataRequest` neutre du socle (curseur
/// `startAfter`, `limit`, tris, filtres) : ce port n'invente aucune
/// primitive de pagination et ne code aucun nom de champ de tri.
library;

import 'package:zcrud_core/domain.dart';

import 'z_public_study_folder.dart';

/// Contrat neutre de lecture de la galerie publique (invariant AD-5 :
/// domaine backend-agnostique).
abstract interface class ZStudySharingReadPort {
  /// Flux **NU** des fiches publiées (`Stream<List<T>>`, AD-5).
  ///
  /// [request] est la requête neutre du socle : `limit` + `startAfter`
  /// paginent, `sorts`/`filters` restreignent. `null` ⇒ « tout, non paginé ».
  /// Un adaptateur reste libre de ne pas honorer une clause qu'il ne sait pas
  /// traduire, comme partout ailleurs sur `ZDataRequest`.
  Stream<List<ZPublicStudyFolder>> watchPublicFolders({ZDataRequest? request});

  /// Lit la fiche publique de [folderId].
  ///
  /// `Right(null)` ⇒ le dossier n'est pas publié (absence, pas une erreur) ;
  /// `Left(ZFailure)` ⇒ échec de lecture. Ne lève jamais.
  Future<ZResult<ZPublicStudyFolder?>> publicFolderById(String folderId);

  /// `true` si la lecture de galerie est utilisable **maintenant**.
  ///
  /// Permet à un hôte de brancher une seule implémentation et d'en couper la
  /// lecture à chaud (quota, réglage, indisponibilité du backend) sans
  /// retirer le port de l'arbre. Un consommateur qui le voit à `false` se
  /// comporte comme si aucun port n'était fourni.
  bool get isAvailable;
}

/// Port de lecture **inerte** : disponible nulle part, ne rend rien.
///
/// Valeur par défaut pour un hôte qui veut câbler la fente sans encore avoir
/// de voie de lecture, et sujet neutre aux tests. `isAvailable` valant
/// `false`, un consommateur correct ne l'appelle jamais ; s'il l'appelle
/// quand même, il reçoit un flux vide qui se termine immédiatement et un
/// `Right(null)` — jamais une exception, jamais une attente infinie.
class ZInertStudySharingReadPort implements ZStudySharingReadPort {
  /// Construit le port inerte (`const` : une seule instance suffit).
  const ZInertStudySharingReadPort();

  @override
  bool get isAvailable => false;

  @override
  Stream<List<ZPublicStudyFolder>> watchPublicFolders({
    ZDataRequest? request,
  }) =>
      const Stream<List<ZPublicStudyFolder>>.empty();

  @override
  Future<ZResult<ZPublicStudyFolder?>> publicFolderById(String folderId) async =>
      const Right<ZFailure, ZPublicStudyFolder?>(null);
}

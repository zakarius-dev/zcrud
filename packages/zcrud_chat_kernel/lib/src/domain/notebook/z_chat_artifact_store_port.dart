/// Port de **stockage** d'un artefact — `ZChatArtifactStorePort` — et son
/// implémentation en mémoire de référence `ZChatInMemoryArtifactStore`.
///
/// ## Le contrat impératif de `delete`
///
/// Un artefact peut exister sous **plusieurs représentations** : un champ du
/// message, et — héritage d'une forme de stockage antérieure — une paire
/// requête/réponse annexe dans laquelle un repli de lecture le retrouve.
/// **Supprimer doit emporter toutes les représentations, atomiquement.**
/// Vider le champ ne suffit pas : le repli de lecture retrouve la paire, et
/// l'artefact supprimé **réapparaît** au chargement suivant.
///
/// Le socle ne connaît pas la forme du stockage ; il exige cette propriété,
/// et la fait respecter par son implémentation de référence, que les gardes
/// de tout hôte peuvent rejouer : après `delete`, `read` rend `null`, **quel
/// que soit** le nombre de représentations écrites avant.
library;

import 'package:zcrud_core/domain.dart';

/// Port de stockage d'un artefact, implémenté par l'hôte.
///
/// Le contenu est une `String` **opaque** (JSON, Markdown, identifiant…) : le
/// socle la transporte, ne l'interprète jamais.
///
/// Invariants AD-5/AD-10 : `Either<ZFailure, ·>`, aucune exception.
abstract interface class ZChatArtifactStorePort {
  /// Le contenu de [artifactKey] sur [messageId], ou `Right(null)` s'il
  /// n'existe sous **aucune** représentation.
  Future<ZResult<String?>> read({
    required String messageId,
    required String artifactKey,
  });

  /// Écrit (ou remplace) le contenu **principal** de [artifactKey].
  Future<ZResult<Unit>> write({
    required String messageId,
    required String artifactKey,
    required String content,
  });

  /// Supprime [artifactKey] sur [messageId] sous **toutes** ses
  /// représentations, atomiquement. Après un `Right`, [read] rend `null` ;
  /// supprimer un artefact déjà absent est un `Right` (idempotent).
  Future<ZResult<Unit>> delete({
    required String messageId,
    required String artifactKey,
  });
}

/// Nom de la représentation **principale** d'un artefact.
const String kZChatArtifactPrimaryRepresentation = 'primary';

/// Implémentation en mémoire de [ZChatArtifactStorePort] — référence du
/// contrat, utilisable en test et comme stockage volatil.
///
/// Elle modélise explicitement les **représentations multiples** : en plus
/// du contenu principal, [writeRepresentation] dépose une représentation
/// annexe (par exemple `'legacy_pair'`) que [read] retrouve en **repli** si
/// le principal est absent — exactement la configuration dans laquelle une
/// suppression incomplète fait réapparaître l'artefact. [delete] les emporte
/// toutes.
class ZChatInMemoryArtifactStore implements ZChatArtifactStorePort {
  /// Construit un magasin vide.
  ZChatInMemoryArtifactStore();

  final Map<String, Map<String, String>> _slots =
      <String, Map<String, String>>{};

  static String _slot(String messageId, String artifactKey) =>
      '$messageId\u0000$artifactKey';

  @override
  Future<ZResult<String?>> read({
    required String messageId,
    required String artifactKey,
  }) async {
    final Map<String, String>? reps = _slots[_slot(messageId, artifactKey)];
    if (reps == null || reps.isEmpty) {
      return const Right<ZFailure, String?>(null);
    }
    final String? primary = reps[kZChatArtifactPrimaryRepresentation];
    if (primary != null) return Right<ZFailure, String?>(primary);
    // Repli de lecture sur la première représentation annexe.
    return Right<ZFailure, String?>(reps.values.first);
  }

  @override
  Future<ZResult<Unit>> write({
    required String messageId,
    required String artifactKey,
    required String content,
  }) =>
      writeRepresentation(
        messageId: messageId,
        artifactKey: artifactKey,
        content: content,
        representation: kZChatArtifactPrimaryRepresentation,
      );

  /// Dépose [content] sous la représentation [representation] (annexe si
  /// différente de [kZChatArtifactPrimaryRepresentation]).
  Future<ZResult<Unit>> writeRepresentation({
    required String messageId,
    required String artifactKey,
    required String content,
    required String representation,
  }) async {
    final String rep = representation.trim();
    if (rep.isEmpty) {
      return const Left<ZFailure, Unit>(
        ZDomainFailure('artifact representation name must not be blank'),
      );
    }
    _slots.putIfAbsent(
      _slot(messageId, artifactKey),
      () => <String, String>{},
    )[rep] = content;
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> delete({
    required String messageId,
    required String artifactKey,
  }) async {
    // Toutes les représentations, d'un coup : c'est le contrat.
    _slots.remove(_slot(messageId, artifactKey));
    return const Right<ZFailure, Unit>(unit);
  }

  /// Les noms des représentations présentes (vide si absent).
  List<String> representationsOf({
    required String messageId,
    required String artifactKey,
  }) =>
      List<String>.unmodifiable(
        _slots[_slot(messageId, artifactKey)]?.keys ?? const <String>[],
      );

  /// Vide le magasin.
  void clear() => _slots.clear();
}

/// **Constat de capacités** — `ZChatCapabilityAudit` (lot K1, AD-4/AD-10).
///
/// ## 🔴 Le pendant exact de `ZChatCorpusScope.audit`, côté capacités
///
/// Le canal ouvert de `ZChatGenerationSettings.capabilities` (clés opaques,
/// AD-4) a le même risque structurel que la portée documentaire avant le
/// lot β : une demande **inaudible**. Un hôte coche « résumé » ; le port d'un
/// autre hôte ne connaît pas cette clé, l'ignore, et génère quand même —
/// l'appelant **croit** avoir demandé un résumé. C'est le REPLI MUET mesuré
/// chez IFFD (étude CR-IFFD-72 § 1.1 : six drapeaux transmis par le contrôleur
/// puis jetés par le repository, sans aucun signal), et la règle v0.52.0 :
/// **jamais de repli muet**.
///
/// ⇒ Ce fichier livre la moitié « lecture » du bouclage :
/// * l'**écriture** est `ZChatGenerationSettings.capabilities` (+ le champ typé
///   `webSearch`, projeté sous sa clé canonique) ;
/// * la **lecture** est `ZChatGenerationSettings.auditCapabilities(honored)`,
///   qui confronte l'**écho** des clés honorées par l'exécuteur aux clés
///   **exprimées** par la demande, et **nomme** celles restées lettre morte.
///
/// ## D'où vient l'écho ? — De l'exécuteur, et c'est voulu
///
/// Le socle ne peut pas deviner ce qu'un backend a honoré ; il peut seulement
/// l'exiger de qui le sait. L'écho est donc un `Iterable<String>` fourni par
/// l'hôte, depuis ce que SON transport lui donne :
/// * une clé de `ZChatResponseMetadata.extra` que son backend émet ;
/// * la connaissance **statique** de son adaptateur (« mon port comprend
///   `web_search` et rien d'autre ») — un port qui déclare ses clés comprises
///   suffit à rendre le repli détectable **avant même l'envoi** ;
/// * à défaut, **rien** — et c'est le cas fail-safe : sans écho, toute
///   capacité exprimée est [unhonored]. **En l'absence de signal on ne présume
///   jamais « honoré »** — même règle que `ZChatCorpusSelector.admits` sur une
///   source sans clé, et que `ZChatSource.isVerified`.
///
/// ## Ce constat CONSTATE — il ne filtre rien, ne lève rien (AD-10)
///
/// Que faire d'une capacité non honorée (masquer l'option, avertir, refuser le
/// tour comme le fait `ZChatActionDispatcher` avec
/// `ZUnsupportedOperationFailure`) est une décision d'hôte, pas de socle —
/// même partage que `ZChatCorpusAudit`.
library;

/// Résultat de la confrontation « capacités EXPRIMÉES ↔ capacités HONORÉES »
/// — immuable, produit par `ZChatGenerationSettings.auditCapabilities`.
///
/// Une clé **exprimée** est une clé pour laquelle la demande porte une valeur
/// (`true` **ou** `false` : demander « web coupé » exige d'être honoré autant
/// que « web actif » — un port qui ne sait pas couper le web ne doit pas
/// laisser croire qu'il l'a coupé).
class ZChatCapabilityAudit {
  /// Construit un constat. Les quatre listes sont figées.
  ZChatCapabilityAudit({
    required List<String> requested,
    required List<String> honored,
    required List<String> unhonored,
    required List<String> unrequested,
  })  : requested = List<String>.unmodifiable(requested),
        honored = List<String>.unmodifiable(honored),
        unhonored = List<String>.unmodifiable(unhonored),
        unrequested = List<String>.unmodifiable(unrequested);

  /// Clés **exprimées** par la demande (canoniques, ordonnées) — le champ typé
  /// `webSearch` y figure sous sa clé canonique, indistinctement du canal
  /// ouvert : l'audit ne dépend pas de l'orthographe choisie par l'hôte.
  final List<String> requested;

  /// Clés exprimées **et** présentes dans l'écho : la demande a été comprise.
  final List<String> honored;

  /// 🔴 Clés exprimées **absentes** de l'écho — le repli muet, rendu VISIBLE.
  ///
  /// Fail-safe : une clé dont l'exécuteur ne dit rien n'est pas « probablement
  /// passée », elle est **non honorée**. C'est la liste qu'une garde assertive
  /// interroge pour prouver qu'une capacité inconnue est détectée.
  final List<String> unhonored;

  /// Clés de l'écho que la demande n'a **jamais** exprimées : l'exécuteur
  /// prétend avoir honoré une demande qui n'existe pas. Ce n'est pas une
  /// violation de la demande ([isSatisfied] ne la compte pas), mais c'est le
  /// symptôme d'un **désaccord de schéma** entre l'hôte et son port — l'hôte
  /// choisit d'en faire un log, une assertion de dev, ou rien.
  final List<String> unrequested;

  /// `true` si **chaque** capacité exprimée a été honorée.
  ///
  /// Une demande sans capacité est satisfaite par construction : elle n'a
  /// rien promis, il n'y a rien à vérifier — même convention que
  /// `ZChatCorpusAudit.isSatisfied` sur une portée vide.
  bool get isSatisfied => unhonored.isEmpty;

  @override
  String toString() => 'ZChatCapabilityAudit(requested: ${requested.length}, '
      'honored: ${honored.length}, unhonored: ${unhonored.length}, '
      'unrequested: ${unrequested.length})';
}

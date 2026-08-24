/// Format de copie DÉCLARÉ PAR L'HÔTE pour le lecteur rich-text.
///
/// Le paquet ne connaît que le Delta neutre : chaque format exportable
/// (Markdown, HTML, texte à plat pour une messagerie…) est une paire
/// « clé + transformation » fournie par l'application. Le socle n'invente
/// **ni** format **ni** libellé : la clé identifie le format ET sert de clé
/// l10n pour son libellé de menu (résolue par le système de labels injecté,
/// repli = la clé elle-même).
library;

/// Transformation d'un Delta NEUTRE (`List<Map<String, dynamic>>`, ops Delta
/// JSON) vers la chaîne mise au presse-papier pour ce format.
///
/// Fournie par l'hôte ; le lecteur lui passe le Delta neutre du document
/// COURANT au moment du geste. La chaîne retournée est copiée telle quelle.
typedef ZMarkdownCopyTransform = String Function(
  List<Map<String, dynamic>> delta,
);

/// Un format proposé par le menu de copie du lecteur rich-text.
///
/// Déclaratif et immuable : l'hôte en fournit une liste (ordre = ordre du
/// menu) ; le lecteur la rend TELLE QUELLE — exactement ces formats, aucun
/// ajout du socle. Une liste vide ⇒ le geste de copie garde son comportement
/// direct (copie de la valeur encodée par le codec du lecteur, sans menu).
class ZMarkdownCopyFormat {
  /// Déclare un format de copie ([key] identifie et libelle, [transform]
  /// produit la charge copiée).
  const ZMarkdownCopyFormat({
    required this.key,
    required this.transform,
  });

  /// Clé du format : identité stable ET clé l10n du libellé de menu.
  ///
  /// Le libellé affiché est résolu par le système de labels injecté
  /// (`label(context, key, fallback: key)`) : sans traduction fournie, la
  /// clé elle-même s'affiche — aucun libellé n'est codé dans le paquet.
  final String key;

  /// Transformation Delta neutre → chaîne copiée pour ce format.
  final ZMarkdownCopyTransform transform;
}

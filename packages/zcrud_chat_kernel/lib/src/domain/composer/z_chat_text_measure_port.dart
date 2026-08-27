/// **La mesure du texte saisi** — un port, parce que compter dépend du
/// tokenizer, donc du fournisseur.
///
/// Domaine PUR (aucun Flutter, aucun libellé, aucune unité imposée).
///
/// ## Les trois règles normatives portées par ce fichier
///
/// 1. **Le socle ne compte pas : il demande.** Un jeton n'est pas un
///    caractère, ni un mot, ni un octet — sa définition appartient au modèle
///    qui va lire le texte. Un compteur écrit ici serait faux, et le
///    resterait silencieusement, sur tous les fournisseurs à la fois. Le socle
///    transporte donc un [ZChatTextMeasurePort] et n'embarque aucune
///    heuristique de découpage.
/// 2. **Sans port, rien n'est affiché** — et surtout pas un chiffre
///    approximatif. [ZChatUnavailableTextMeasure] rend `null` : un compteur
///    branché dessus reste muet, ce qui est exact, plutôt que faux.
/// 3. **La mesure ne refuse jamais rien.** [ZChatTextMeasurement.isOverLimit]
///    est un **constat**, pas un verrou : décider qu'un dépassement bloque
///    l'envoi, dégrade le modèle ou propose un achat est une décision
///    commerciale, qui appartient entièrement à l'hôte.
library;

/// Ce qu'un [ZChatTextMeasurePort] a mesuré : une quantité, l'unité dans
/// laquelle elle est exprimée, et le plafond éventuel.
///
/// Ce type ne porte **pas** de slot `extra` : il n'est ni persisté, ni
/// transporté vers un store — c'est une lecture instantanée, refaite à chaque
/// frappe.
class ZChatTextMeasurement {
  /// Construit une mesure. Une quantité négative — que seule une
  /// implémentation d'hôte fautive pourrait produire — est ramenée à `0`
  /// plutôt que propagée ; un plafond négatif est traité comme **absent**.
  ZChatTextMeasurement({required int units, this.unitKey, int? limit})
    : units = units < 0 ? 0 : units,
      limit = (limit != null && limit < 0) ? null : limit;

  /// La quantité mesurée, dans l'unité du port.
  final int units;

  /// Jeton **opaque** d'unité (jetons, caractères, mots…), tel que le port le
  /// nomme. `null` ⇒ non déclarée. Ce n'est **pas** un libellé d'affichage :
  /// le texte montré à l'utilisateur reste à la charge de l'hôte (FR-26).
  final String? unitKey;

  /// Plafond déclaré par le port, dans la même unité. `null` ⇒ aucun plafond
  /// connu — le socle n'en invente aucun.
  final int? limit;

  /// `true` si un plafond est connu.
  bool get hasLimit => limit != null;

  /// Ce qu'il reste avant le plafond, ou `null` si aucun plafond n'est connu.
  ///
  /// La valeur peut être **négative** : c'est la mesure du dépassement, rendue
  /// telle quelle. Le socle ne la borne pas, parce qu'un hôte peut vouloir
  /// dire de combien on dépasse.
  int? get remaining => limit == null ? null : limit! - units;

  /// `true` si la quantité dépasse strictement le plafond connu.
  ///
  /// **Un constat, jamais un refus** : le socle ne bloque aucun envoi de son
  /// propre chef.
  bool get isOverLimit => limit != null && units > limit!;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatTextMeasurement &&
          units == other.units &&
          unitKey == other.unitKey &&
          limit == other.limit;

  @override
  int get hashCode => Object.hash(units, unitKey, limit);

  @override
  String toString() => 'ZChatTextMeasurement($units $unitKey / $limit)';
}

/// Le port par lequel l'hôte **mesure** un texte de saisie.
///
/// L'appel est synchrone parce qu'il est rejoué à chaque frappe : une
/// implémentation qui doit interroger un service distant y répond avec sa
/// dernière valeur connue, ou avec `null` tant qu'elle n'en a pas.
abstract interface class ZChatTextMeasurePort {
  /// Mesure [text], ou rend `null` quand la mesure n'est **pas disponible**.
  ///
  /// `null` est un état de plein droit — pas une erreur, pas un `0` : il dit
  /// « je ne sais pas », et un compteur qui l'affiche doit ne rien afficher.
  ZChatTextMeasurement? measure(String text);
}

/// Port **inerte** : aucune mesure n'est disponible, jamais.
///
/// C'est le défaut d'un hôte qui n'a branché aucun tokenizer. Un compteur
/// monté dessus reste muet ; rien ne lève, rien n'est approximé.
class ZChatUnavailableTextMeasure implements ZChatTextMeasurePort {
  /// Construit le port inerte.
  const ZChatUnavailableTextMeasure();

  @override
  ZChatTextMeasurement? measure(String text) => null;
}

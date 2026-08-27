/// **Le compteur de saisie** — il rend une mesure, il n'en fabrique aucune.
///
/// ## Sans port, aucun chiffre
///
/// Compter des jetons dépend du tokenizer, donc du fournisseur : un compteur
/// écrit ici serait faux, et le resterait silencieusement. Une approximation
/// par nombre de caractères serait pire qu'un vide — elle serait **lue comme
/// la mesure du modèle**, et personne ne verrait l'écart.
///
/// Le compteur est donc entièrement adossé à `ZChatTextMeasurePort` :
///
/// * pas de port ⇒ **rien** n'est affiché ;
/// * port présent mais mesure indisponible (`measure` rend `null`) ⇒ **rien**
///   n'est affiché non plus, parce que « je ne sais pas » n'est pas `0`.
///
/// Il ne bloque rien non plus : un dépassement est un **constat** rendu par la
/// mesure, jamais un refus d'envoi.
///
/// ## Le rendu par défaut ne dit que des nombres
///
/// La quantité, et le plafond quand il est connu. Pas d'unité — le port la
/// nomme par un jeton opaque, pas par un libellé (invariant FR-26) — et pas de
/// couleur d'alerte : c'est [builder] qui laisse l'hôte dire les choses dans
/// sa langue et son thème.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../z_chat_controller.dart';
import 'z_chat_labels.dart';

/// Rendu d'hôte d'une mesure. Rendre `null` signifie « rien à montrer »
/// (invariant AD-4).
typedef ZChatComposerCounterBuilder =
    Widget? Function(BuildContext context, ZChatTextMeasurement measurement);

/// Affiche ce que le port de mesure rend, et rien d'autre.
class ZChatComposerCounter extends StatelessWidget {
  /// Construit le compteur.
  const ZChatComposerCounter({
    super.key,
    required this.controller,
    this.port,
    this.builder,
  });

  /// Le contrôleur dont la saisie est mesurée.
  final ZChatController controller;

  /// Le port de mesure. `null` — le défaut — signifie **aucun compteur** :
  /// ni chiffre, ni zéro, ni approximation.
  final ZChatTextMeasurePort? port;

  /// Rendu d'hôte.
  ///
  /// Trois cas : builder **absent** ⇒ le rendu par défaut, strictement
  /// numérique ; builder rendant un widget ⇒ celui-là ; builder rendant
  /// `null` ⇒ **rien** n'est affiché (invariant AD-4).
  final ZChatComposerCounterBuilder? builder;

  @override
  Widget build(BuildContext context) {
    final ZChatTextMeasurePort? measure = port;
    if (measure == null) return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.composer,
      // Feuille : une frappe reconstruit ce compteur, jamais le champ, jamais
      // les créneaux de l'hôte, jamais la liste des messages (invariant AD-2).
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        final ZChatTextMeasurement? m = measure.measure(value.text);
        if (m == null) return const SizedBox.shrink();
        // Trois cas, comme pour l'invite du composer : builder ABSENT ⇒ le
        // rendu par défaut ; builder rendant un widget ⇒ celui-là ; builder
        // rendant `null` ⇒ le silence, c'est un refus explicite d'afficher
        // (invariant AD-4), pas un repli sur le défaut.
        final ZChatComposerCounterBuilder? host = builder;
        if (host != null) {
          return host(context, m) ?? const SizedBox.shrink();
        }
        return Semantics(
          label: zChatLabel(context, kZChatLabelComposerCounter),
          child: Text(
            m.hasLimit ? '${m.units} / ${m.limit}' : '${m.units}',
            // Invariant AD-13 : jamais `TextAlign.left`.
            textAlign: TextAlign.start,
          ),
        );
      },
    );
  }
}

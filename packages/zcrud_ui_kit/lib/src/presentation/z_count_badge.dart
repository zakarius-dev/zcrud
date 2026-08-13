/// `ZCountBadge` — **pastille de comptage** réutilisable (invariants AD-13,
/// FR-26).
///
/// Une pastille dit *combien* : combien d'éléments dans la corbeille, combien
/// de pièces dans un onglet, combien de messages non lus. C'est un motif qui
/// se recopie mal — chaque recopie retrouve les mêmes trois pièges :
///
/// * le nombre n'est **annoncé** nulle part (un lecteur d'écran lit « 3 »,
///   sans dire trois quoi) ;
/// * la pastille collée sur une icône **rétrécit la cible tactile** en
///   dessous du seuil confortable ;
/// * la couleur est écrite en dur, et le mode sombre la rend illisible.
///
/// Cette pastille traite les trois : [semanticsLabel] nomme ce qui est compté,
/// la cible reste **≥ 48 dp** dès que la pastille est cliquable, et toutes les
/// couleurs sont **dérivées du `ColorScheme`** du thème — aucune valeur
/// littérale.
///
/// Deux formes d'emploi :
///
/// ```dart
/// // 1. Pastille seule (dans une ligne, à côté d'un libellé) :
/// ZCountBadge(count: 12, semanticsLabel: '12 éléments dans la corbeille')
///
/// // 2. Pastille POSÉE SUR un contenu (icône de barre, avatar…) :
/// ZCountBadge(
///   count: 12,
///   semanticsLabel: '12 éléments dans la corbeille',
///   child: const Icon(Icons.delete),
/// )
/// ```
///
/// **Neutre** : aucun gestionnaire d'état, aucun routeur. La pastille ne
/// compte rien elle-même — elle affiche le nombre qu'on lui donne.
library;

import 'package:flutter/material.dart';

/// Cible tactile minimale d'une pastille **cliquable** (Material / AD-13).
const double _kMinTouchTarget = 48;

/// Pastille affichant un **nombre**, seule ou posée sur un [child].
class ZCountBadge extends StatelessWidget {
  /// Construit la pastille. [count] est le nombre affiché ; [semanticsLabel]
  /// l'annonce lue par les technologies d'assistance (à défaut, le nombre est
  /// annoncé nu) ; [child] le contenu sur lequel poser la pastille ; [onTap]
  /// rend l'ensemble cliquable (la cible passe alors à 48 dp au minimum).
  const ZCountBadge({
    required this.count,
    this.semanticsLabel,
    this.child,
    this.onTap,
    this.tooltip,
    this.showZero = false,
    this.maxDisplayed = 99,
    super.key,
  });

  /// Nombre affiché. Négatif ou nul, la pastille disparaît — sauf [showZero].
  final int count;

  /// **Annonce** de la pastille pour les lecteurs d'écran, par exemple
  /// « 3 éléments dans la corbeille ».
  ///
  /// `null` (défaut) : le nombre est annoncé seul. C'est un repli, pas une
  /// cible — un nombre sans objet oblige l'usager à deviner ce qu'il compte.
  final String? semanticsLabel;

  /// Contenu **sur lequel** poser la pastille (icône, avatar…). `null`
  /// (défaut) : la pastille est rendue seule, à sa taille propre.
  ///
  /// La pastille est posée en haut **côté fin de ligne**
  /// (`PositionedDirectional.end`) : elle bascule d'elle-même en RTL.
  final Widget? child;

  /// Rend l'ensemble cliquable. `null` (défaut) : pastille décorative, aucun
  /// geste — c'est alors au parent (un bouton de barre, par exemple) de porter
  /// l'interaction et sa propre cible tactile.
  final VoidCallback? onTap;

  /// Infobulle du geste, quand [onTap] est fourni. Sans effet sinon.
  final String? tooltip;

  /// Afficher la pastille **à zéro** (défaut `false`).
  ///
  /// Le défaut suit l'usage : une pastille à zéro est du bruit, pas une
  /// information. `true` la maintient visible, pour les rares affichages où la
  /// disparition d'un repère est pire que sa valeur nulle.
  final bool showZero;

  /// Valeur au-delà de laquelle le nombre est **écrêté** à l'affichage
  /// (« 99+ » pour le défaut `99`). L'annonce a11y, elle, reste exacte : le
  /// nombre réel est dans [semanticsLabel] si vous le fournissez.
  final int maxDisplayed;

  /// `true` si la pastille a quelque chose à montrer.
  bool get _visible => count > 0 || (showZero && count >= 0);

  /// Texte affiché, écrêté à [maxDisplayed].
  String get _text => count > maxDisplayed ? '$maxDisplayed+' : '$count';

  @override
  Widget build(BuildContext context) {
    final content = child;
    if (!_visible) {
      // Rien à compter : le contenu porté reste rendu tel quel, et une
      // pastille seule s'efface (jamais de trou dans la mise en page).
      return content ?? const SizedBox.shrink();
    }
    final badge = _buildPill(context);
    final Widget body;
    if (content == null) {
      body = badge;
    } else {
      body = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          content,
          PositionedDirectional(
            top: -2,
            end: -6,
            child: badge,
          ),
        ],
      );
    }
    final tap = onTap;
    final label = semanticsLabel ?? _text;
    if (tap == null) {
      // Pastille décorative : un seul nœud sémantique, celui qui porte
      // l'annonce (le texte du nombre est masqué pour ne pas être lu deux
      // fois).
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: body),
      );
    }
    final tip = tooltip;
    Widget interactive = Semantics(
      container: true,
      button: true,
      label: label,
      child: InkWell(
        onTap: tap,
        customBorder: const CircleBorder(),
        child: ConstrainedBox(
          // Cible tactile confortable dès que la pastille est cliquable.
          constraints: const BoxConstraints(
            minWidth: _kMinTouchTarget,
            minHeight: _kMinTouchTarget,
          ),
          child: Center(child: ExcludeSemantics(child: body)),
        ),
      ),
    );
    if (tip != null) {
      interactive = Tooltip(message: tip, child: interactive);
    }
    return interactive;
  }

  /// La pastille elle-même : couleurs dérivées du `ColorScheme`, jamais de
  /// littéral (FR-26).
  Widget _buildPill(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        _text,
        textAlign: TextAlign.center,
        style: (theme.textTheme.labelSmall ?? const TextStyle())
            .copyWith(color: scheme.onError, fontWeight: FontWeight.w600),
      ),
    );
  }
}

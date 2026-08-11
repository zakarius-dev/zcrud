/// `ZStreakBadge` — badge flamme d'assiduité.
///
/// Widget pur (invariants AD-2/AD-15) : `StatelessWidget`, aucun
/// gestionnaire d'état, aucun moteur, aucune écriture SRS. Il affiche un
/// `ZStudyStreak` injecté — il ne le calcule jamais (`zAdvanceStreak` est
/// une fonction pure du kernel, appelée par l'hôte).
///
/// A11y / l10n / thème (invariant AD-13) :
/// - `Semantics(label:)` issu de `ZcrudLabels` — jamais un littéral ;
/// - couleur injectée par clé (`zResolveColorKeyOrSlot`), jamais `Colors.*` ;
/// - paire fond/premier plan respectée : `pair.color` en fond, `pair.onColor`
///   sur l'icône et le nombre — le patron canonique du paquet pour toute
///   surface colorée par clé. Peindre `pair.color` en premier plan sur un
///   fond non peint produit un contraste insuffisant au regard de WCAG AA ;
/// - variantes directionnelles uniquement (RTL) ;
/// - cible ≥ 48 dp ;
/// - statique : aucune animation, donc rien à désactiver sous Reduce Motion.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyStreak;

/// Badge affichant la série d'assiduité en cours (« flamme »).
class ZStreakBadge extends StatelessWidget {
  /// Construit le badge.
  ///
  /// - [streak] : streak injecté (jamais calculé ici) ;
  /// - [colorKeyName] : clé de couleur injectée (jamais un `Color` en dur).
  const ZStreakBadge({
    required this.streak,
    this.colorKeyName = 'primary',
    super.key,
  });

  /// Clé de widget — permet à un test de cibler le badge sans dépendre du texte.
  static const ValueKey<String> badgeKey = ValueKey<String>('zStreakBadge');

  /// Streak affiché (injecté).
  final ZStudyStreak streak;

  /// Clé de couleur de la flamme.
  final String colorKeyName;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKeyName, slotIndex: 0);

    // Libellé a11y issu de `ZcrudLabels` — jamais un littéral en dur.
    final semanticLabel = label(
      context,
      'zcrud.study.streak',
      fallback: 'série en cours',
    );

    return Semantics(
      key: badgeKey,
      label: semanticLabel,
      // La valeur est le nombre : le lecteur d'écran annonce « série en cours,
      // 7 » — la couleur n'est jamais le seul canal (invariant AD-13).
      value: '${streak.current}',
      // Sans exclusion, le `Text('${streak.current}')` ci-dessous fusionnerait
      // dans ce nœud sémantique, faisant annoncer le nombre deux fois
      // (concaténé au libellé, puis répété comme valeur).
      //
      // Rien de nécessaire n'est masqué : le nombre reste dans `value` (canal
      // a11y) et dans le `Text` (canal visuel) — c'est très exactement la
      // décomposition « libellé statique localisable + nombre dans un canal
      // séparé » que ce badge est censé incarner.
      excludeSemantics: true,
      child: ConstrainedBox(
        // Cible ≥ 48 dp (invariant AD-13).
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Container(
          // `ZColorPair` est une paire fond + premier plan : `pair.color` est
          // le rôle de fond (`*Container` du `ColorScheme`), `pair.onColor`
          // le premier plan lisible dessus. Peindre `pair.color` en premier
          // plan sur un fond non peint produirait un contraste insuffisant :
          // l'icône et le nombre sortiraient dans une teinte voisine de
          // `surface` sans le fond qui les rend lisibles.
          //
          // Le patron canonique — le seul de ce paquet : `pair.color` en
          // fond d'un `Container` décoré, `pair.onColor` sur tout ce qui se
          // pose dessus. Le contraste de la paire est garanti par Material 3.
          padding: theme.fieldPadding,
          decoration: BoxDecoration(
            color: pair.color,
            borderRadius: BorderRadius.all(theme.radiusS),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.local_fire_department,
                // Couleur injectée par clé (`pair.onColor`), jamais `Colors.*`.
                color: pair.onColor,
                // Icône décorative : le `Semantics` parent porte déjà le sens ;
                // la dupliquer ferait annoncer deux fois la même chose.
                semanticLabel: null,
              ),
              SizedBox(width: theme.gapS),
              // Le badge affiche `streak.current` en clair : le nombre doit
              // être visible à l'œil, pas seulement porté par
              // `Semantics(value:)` pour le lecteur d'écran.
              //
              // Interpolation pure : ce n'est pas un libellé, il n'y a donc
              // rien à traduire ici. Le sens est porté par le
              // `Semantics(label:)` issu de `ZcrudLabels`, la valeur par ce
              // nombre.
              Text(
                '${streak.current}',
                // Premier plan LISIBLE sur `pair.color` (cf. le fond ci-dessus).
                style: TextStyle(color: pair.onColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

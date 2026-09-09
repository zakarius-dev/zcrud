/// En-tête de session : titre, compteur, série d'assiduité — décrits, puis
/// rendus par une rangée de référence.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_session/zcrud_session.dart' show ZStreakBadge;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyStreak;

import '../z_study_session_reference.dart';
import '../z_study_session_slices.dart';

/// Décrit l'en-tête à afficher pour un instantané de progression donné.
///
/// Reçoit la progression **réelle** de la session : le libellé du compteur est
/// composé par l'hôte à partir d'elle, jamais deviné par l'écran.
typedef ZSessionHeaderSpecBuilder = ZSessionHeaderSpec Function(
  ZStudySessionProgress progress,
);

/// En-tête de session — un descripteur de VALEURS, jamais un widget.
///
/// [title] et [counter] sont des textes **déjà localisés par l'hôte** : cet
/// écran ne traduit rien et ne calcule aucun libellé. En particulier, le
/// compteur ne peut pas être dérivé ici — en régime SRS,
/// `remaining + reviewed != total` par conception (une carte ratée est
/// réinsérée dans la file), et seul l'hôte sait quelle formule il veut
/// afficher.
///
/// [streak] attend la série d'assiduité elle-même, pas un pourcentage : le
/// badge annonce `current` et ne calcule rien.
///
/// Chaque champ nul est **absent du rendu**, et une spécification entièrement
/// nulle ne monte aucune rangée : jamais une bande vide.
@immutable
class ZSessionHeaderSpec {
  /// Décrit un en-tête. Tout champ omis est absent du rendu.
  const ZSessionHeaderSpec({
    this.title,
    this.counter,
    this.streak,
    this.trailing,
  });

  /// Clé de la rangée rendue par [buildRow] — permet de la cibler sans
  /// dépendre de son contenu.
  static const ValueKey<String> rowKey =
      ValueKey<String>('zSessionHeaderRow');

  /// Titre de la session, déjà localisé.
  final String? title;

  /// Libellé du compteur, **composé par l'hôte** depuis la progression.
  final String? counter;

  /// Série d'assiduité en cours. `null` ⇒ aucun badge dans l'arbre.
  final ZStudyStreak? streak;

  /// Contenu libre en fin de rangée (une action, un menu…).
  final Widget? trailing;

  /// `true` quand rien n'est décrit — la rangée n'a alors rien à rendre.
  bool get isEmpty =>
      title == null && counter == null && streak == null && trailing == null;

  /// Rend la rangée d'en-tête décrite ici.
  ///
  /// Réutilisable seule : un hôte qui compose son propre en-tête peut appeler
  /// cette méthode pour obtenir la même rangée que l'écran de session.
  ///
  /// Une spécification vide ne rend rien d'occupant.
  Widget buildRow(BuildContext context) =>
      isEmpty ? const SizedBox.shrink() : _ZSessionHeaderRow(spec: this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSessionHeaderSpec &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          counter == other.counter &&
          streak == other.streak &&
          trailing == other.trailing;

  @override
  int get hashCode =>
      Object.hash(runtimeType, title, counter, streak, trailing);

  @override
  String toString() =>
      'ZSessionHeaderSpec(title: $title, counter: $counter, streak: $streak)';
}

/// La rangée d'en-tête de référence : titre, compteur, badge de série.
///
/// Cible ≥ 48 dp, variantes directionnelles uniquement, aucune couleur ni
/// aucun libellé posés ici — tout vient de la spécification ou du thème.
class _ZSessionHeaderRow extends StatelessWidget {
  const _ZSessionHeaderRow({required this.spec});

  final ZSessionHeaderSpec spec;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? title = spec.title;
    final String? counter = spec.counter;
    final ZStudyStreak? streak = spec.streak;
    final Widget? trailing = spec.trailing;

    return ConstrainedBox(
      key: ZSessionHeaderSpec.rowKey,
      // Plancher de cible tactile partagé avec le reste de l'écran de session
      // (invariant AD-13) — jamais une valeur posée ici.
      constraints: const BoxConstraints(
        minHeight: ZStudySessionReference.minTarget,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.gapM,
          vertical: theme.gapS,
        ),
        child: Row(
          children: <Widget>[
            // Sans titre, l'espace flexible reste pris : le compteur et le
            // badge gardent leur place en fin de rangée au lieu de se
            // recentrer sous une largeur qui n'a pas changé.
            if (title != null)
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.start,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              const Spacer(),
            if (counter != null) ...<Widget>[
              SizedBox(width: theme.gapM),
              Text(
                counter,
                textAlign: TextAlign.start,
                style: textTheme.labelLarge,
                maxLines: ZStudySessionReference.counterMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (streak != null) ...<Widget>[
              SizedBox(width: theme.gapM),
              ZStreakBadge(streak: streak),
            ],
            if (trailing != null) ...<Widget>[
              SizedBox(width: theme.gapM),
              trailing,
            ],
          ],
        ),
      ),
    );
  }
}

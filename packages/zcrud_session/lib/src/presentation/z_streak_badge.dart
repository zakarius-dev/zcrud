/// `ZStreakBadge` — badge **flamme** d'assiduité (SU-6, FR-SU10/FR-SU11 —
/// AC7/AC14).
///
/// **Widget PUR** (AD-2/AD-15) : `StatelessWidget`, aucun gestionnaire d'état,
/// aucun moteur, aucune écriture SRS (AD-33). Il **affiche** un `ZStudyStreak`
/// INJECTÉ — il ne le calcule jamais (`zAdvanceStreak` est une fonction pure du
/// kernel, appelée par l'hôte).
///
/// **A11y / l10n / thème (AD-13, NFR-SU3/4/5)** :
/// - `Semantics(label:)` **issu de `ZcrudLabels`** — ⚠️ **angle mort CONNU** : la
///   garde `z_widgets_hardcode_scan_test.dart` ne couvre **PAS**
///   `Semantics(label:)` (elle le déclare honnêtement). Ce puits est donc gardé
///   par le groupe **« AC14 — `Semantics(label:)` sur TOUTES les tuiles »** de
///   `test/presentation/z_session_mode_selector_test.dart`, qui **ÉNUMÈRE** les 3
///   options **et** ce badge (`ZStreakBadge.badgeKey`) — pas par le scan.
///   *(Ce dartdoc citait `z_streak_badge_test.dart` : un fichier qui n'a JAMAIS
///   existé. La garde, elle, est bien réelle — mais une référence morte est une
///   promesse invérifiable, et c'est ce qui fait qu'on croit un puits gardé. AC14
///   interdit la garde PARALLÈLE : on corrige le renvoi, on ne duplique pas.)*
/// - couleur **INJECTÉE** par clé (`zResolveColorKeyOrSlot`), jamais `Colors.*` ;
/// - **paire fond/premier plan respectée** : `pair.color` en FOND, `pair.onColor`
///   sur l'icône ET le nombre — le patron canonique du package
///   (`z_session_quality_breakdown.dart:174-192`). Peindre `pair.color` en
///   premier plan donne **1,23:1** (mesuré) contre les **4,5:1** de WCAG AA :
///   c'est ce qu'imposait AC7 et ce que la garde de contraste de
///   `test/presentation/z_session_mode_selector_test.dart` mesure désormais
///   RÉELLEMENT (elle énumère TOUS les `RichText` peints) ;
/// - variantes **directionnelles** uniquement (RTL) ;
/// - cible ≥ **48 dp** ;
/// - **STATIQUE** : aucune animation — donc **rien à désactiver** sous Reduce
///   Motion. 🚫 On n'ajoute **pas** d'animation « pour la conformité » (leçon
///   su-3 : une animation factice ne peut faire rougir aucun test).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyStreak;

/// Badge affichant la série d'assiduité en cours (« flamme »).
class ZStreakBadge extends StatelessWidget {
  /// Construit le badge.
  ///
  /// - [streak] : streak **INJECTÉ** (jamais calculé ici) ;
  /// - [colorKeyName] : clé de couleur INJECTÉE (jamais un `Color` en dur).
  const ZStreakBadge({
    required this.streak,
    this.colorKeyName = 'primary',
    super.key,
  });

  /// Clé de widget — permet à un test de cibler le badge sans dépendre du texte.
  static const ValueKey<String> badgeKey = ValueKey<String>('zStreakBadge');

  /// Streak affiché (INJECTÉ).
  final ZStudyStreak streak;

  /// Clé de couleur de la flamme.
  final String colorKeyName;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, colorKeyName, slotIndex: 0);

    // 🔴 Libellé A11y issu de `ZcrudLabels` — JAMAIS un littéral (NFR-SU4).
    // La garde de libellés ne voit pas `Semantics(label:)` : c'est le groupe
    // « AC14 — Semantics(label:) sur TOUTES les tuiles » de
    // `test/presentation/z_session_mode_selector_test.dart` qui tient cette
    // promesse (renvoi corrigé : `z_streak_badge_test.dart` n'existe pas).
    final semanticLabel = label(
      context,
      'zcrud.study.streak',
      fallback: 'série en cours',
    );

    return Semantics(
      key: badgeKey,
      label: semanticLabel,
      // La VALEUR est le nombre : le lecteur d'écran annonce « série en cours,
      // 7 » — la couleur n'est JAMAIS le seul canal (AD-13).
      value: '${streak.current}',
      // 🔴 Défaut MESURÉ (code-review su-6, D2 — balayage du MOTIF).
      //
      // Sans exclusion, le `Text('${streak.current}')` ci-dessous **fusionnait**
      // dans ce nœud. Arbre sémantique RÉEL, sondé :
      //   zStreakBadge -> label = « L10N_STREAK⏎3 », value = « 3 »
      // ⇒ TalkBack annonçait « série en cours 3, 3 » : le nombre CONCATÉNÉ au
      // libellé PUIS répété comme valeur. C'est le MAJEUR su-5/D1 (« Cartes, 8,
      // Cartes — valeur : 8 »), reproduit sur ce badge.
      //
      // Rien de nécessaire n'est masqué : le nombre reste dans `value` (canal
      // a11y) ET dans le `Text` (canal visuel) — c'est très exactement la
      // décomposition « libellé statique localisable + nombre dans un canal
      // séparé » que ce badge est censé incarner.
      excludeSemantics: true,
      child: ConstrainedBox(
        // Cible ≥ 48 dp (AD-13/NFR-SU3).
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Container(
          // 🔴 Contraste MESURÉ (code-review su-6, ÉCART-2 — MAJEUR).
          //
          // `ZColorPair` est une paire **fond + premier plan** : `pair.color`
          // est le rôle de FOND (`*Container` du `ColorScheme`), `pair.onColor`
          // le premier plan LISIBLE dessus (dartdoc du cœur —
          // `z_color_key_resolver.dart:216`). Ce badge peignait `pair.color`
          // — le FOND — en PREMIER PLAN, et ne peignait AUCUN fond : l'icône et
          // le nombre sortaient donc en `primaryContainer` sur `surface`, deux
          // teintes voisines par construction. Ratio RÉEL mesuré : **1,23:1**,
          // là où WCAG AA exige **4,5:1** — la flamme était pratiquement
          // invisible. Ce n'était pas un arbitrage de design : c'était un
          // MÉSUSAGE de l'API, que son voisin
          // `z_session_quality_breakdown.dart:174-192` utilise correctement.
          //
          // Le patron canonique — le SEUL de ce package : `pair.color` en fond
          // d'un `Container` décoré, `pair.onColor` sur tout ce qui se pose
          // dessus. Le contraste de la paire est garanti par Material 3.
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
                // 🔴 Couleur INJECTÉE par clé (`pair.onColor`), JAMAIS
                // `Colors.*` (NFR-SU5). Mon premier jet portait `Colors.red` —
                // sous un dartdoc affirmant « couleur INJECTÉE par clé, jamais
                // `Colors.*` ». La PROSE disait le contraire du CODE, et seul
                // `z_widgets_hardcode_scan_test.dart` l'a vu : la garde
                // auto-énumérante d'AC14 a fait EXACTEMENT son travail.
                color: pair.onColor,
                // Icône DÉCORATIVE : le `Semantics` parent porte déjà le sens ;
                // la dupliquer ferait annoncer deux fois la même chose.
                semanticLabel: null,
              ),
              SizedBox(width: theme.gapS),
              // 🔴 Le badge affiche `streak.current` — c'est la LETTRE d'AC7
              // (« un badge flamme affiche `streak.current` »).
              //
              // Mon premier jet affichait le littéral `'Série en cours'` : deux
              // défauts en un. (1) libellé utilisateur EN DUR (NFR-SU4), capté
              // par la garde ; (2) — bien plus grave, et qu'AUCUNE garde
              // n'aurait attrapé — le NOMBRE n'était affiché NULLE PART : il
              // n'existait que dans `Semantics(value:)`, donc annoncé au lecteur
              // d'écran et INVISIBLE à l'œil. Le badge « flamme » ne montrait
              // pas la flamme. Le libellé en dur DOUBLAIT en outre le
              // `Semantics(label:)` (annonce redondante).
              //
              // Interpolation PURE : ce n'est pas un libellé (le scanner le
              // sanctionne explicitement — `Text('$count')`), et il n'y a donc
              // rien à traduire ici : le SENS est porté par le `Semantics(label:)`
              // issu de `ZcrudLabels`, la VALEUR par ce nombre.
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

/// `zShowStreakToast` — la confirmation de flamme d'assiduité.
///
/// ## Le seam est réutilisé, jamais redéclaré
///
/// Le toast passe par `ZToasterScope.of(context).show(...)` — le port
/// `ZToaster` de `zcrud_ui_kit`. Redéclarer un port de toast local à
/// `zcrud_session` serait une violation de cette règle de réutilisation des
/// seams, et un `ScaffoldMessenger…showSnackBar` en dur en serait une autre :
/// une application qui substitue son toaster verrait la confirmation de
/// flamme lui échapper.
///
/// L'arête `zcrud_session → zcrud_ui_kit` est sûre : `zcrud_ui_kit →
/// zcrud_core` est sa seule arête sortante, donc le graphe reste acyclique
/// avec un cœur sans arête sortante, et aucune dépendance tierce n'entre.
///
/// Invariant AD-10 sans une ligne de code défensif : `ZToasterScope.of` a un
/// repli sûr (`const ZScaffoldMessengerToaster()`) — il ne lève jamais,
/// même sans scope monté.
///
/// ## Pas de spam
///
/// Seules les issues qui changent la flamme parlent
/// (`started`/`incremented`/`resetToOne`). `alreadyCountedToday` et
/// `skippedNotGraded` n'affichent aucun toast : sans cette règle, chaque
/// carte d'une session en déclencherait un.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStreakAdvance, ZStreakOutcome;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart'
    show ZToastSeverity, ZToasterScope;

/// Affiche la confirmation de flamme correspondant à [advance] — ou rien.
///
/// - `started` / `incremented` → toast de succès ;
/// - `resetToOne` → toast d'avertissement (la série a été rompue : ce n'est
///   pas une erreur, la répétition du jour compte déjà, `current == 1`) ;
/// - `alreadyCountedToday` / `skippedNotGraded` → aucun toast.
///
/// La sévérité est toujours un [ZToastSeverity] — jamais un `bool isError`.
///
/// Les libellés viennent de `ZcrudLabels` (`label(context, key, fallback:)`) :
/// zéro libellé en dur.
void zShowStreakToast(BuildContext context, ZStreakAdvance advance) {
  final severity = zStreakToastSeverityFor(advance.outcome);
  if (severity == null) return; // pas de spam : rien à annoncer.

  final message = _messageFor(context, advance);

  // Le seam : le toaster du scope, sinon le repli sûr — jamais un SnackBar.
  ZToasterScope.of(context).show(
    context,
    message: message,
    severity: severity,
  );
}

/// Sévérité du toast pour [outcome], ou `null` si aucun toast ne doit
/// s'afficher — fonction pure (testable sans widget).
///
/// Exposée pour que la règle « pas de spam » soit prouvable en isolation, et
/// énumérable : un sixième `ZStreakOutcome` ajouté demain force une
/// décision ici.
ZToastSeverity? zStreakToastSeverityFor(ZStreakOutcome outcome) =>
    switch (outcome) {
      ZStreakOutcome.started => ZToastSeverity.success,
      ZStreakOutcome.incremented => ZToastSeverity.success,
      ZStreakOutcome.resetToOne => ZToastSeverity.warning,
      // Silence volontaire : sans quoi chaque carte d'une session
      // déclencherait un toast.
      ZStreakOutcome.alreadyCountedToday => null,
      ZStreakOutcome.skippedNotGraded => null,
    };

/// Message l10n de [advance] (clé + repli).
///
/// ## Le nombre est composé hors de `label()`
///
/// `label(context, key, {fallback})` résout `scope → locale → table
/// anglaise du cœur → fallback` et rend la chaîne telle quelle : il n'existe
/// aucun mécanisme de substitution de paramètre ni de pluralisation. Écrire
/// `label(..., fallback: 'Série de $current jours')` ferait exister le
/// nombre uniquement dans le repli en dur, c'est-à-dire uniquement quand la
/// localisation échoue. Dès qu'une application fournit
/// `zcrud.study.streak.incremented`, `label()` rendrait « Série en cours »
/// et le nombre disparaîtrait silencieusement : aucune exception, aucun
/// test rouge, et l'apprenant d'une application localisée ne verrait plus
/// jamais sa série — alors que le compteur est précisément le contenu du
/// toast.
///
/// Le bon patron : `z_streak_badge.dart` porte un libellé statique et
/// localisable (`Semantics(label:)`) et le nombre dans un canal séparé
/// (`Semantics(value:)`). Un toast n'ayant qu'un seul canal (sa chaîne), la
/// décomposition équivalente est : libellé statique issu de `ZcrudLabels` +
/// nombre concaténé hors de `label()`. Le compteur survit alors à toute
/// traduction.
String _messageFor(BuildContext context, ZStreakAdvance advance) {
  final current = advance.streak.current;
  return switch (advance.outcome) {
    ZStreakOutcome.started => label(
        context,
        'zcrud.study.streak.started',
        fallback: 'Série démarrée',
      ),
    // Libellé statique (traduisible intégralement) + nombre hors de `label()`.
    ZStreakOutcome.incremented => _withCount(
        label(
          context,
          'zcrud.study.streak.incremented',
          fallback: 'Série en cours',
        ),
        current,
      ),
    ZStreakOutcome.resetToOne => label(
        context,
        'zcrud.study.streak.reset',
        fallback: 'Nouvelle série',
      ),
    // Inatteignable (filtré par `zStreakToastSeverityFor`), mais total :
    // aucun `default` muet, aucun throw (invariant AD-10).
    ZStreakOutcome.alreadyCountedToday ||
    ZStreakOutcome.skippedNotGraded =>
      '',
  };
}

/// Adjoint [count] à un libellé déjà localisé, sans jamais le traverser.
///
/// Le séparateur ne porte aucune lettre : il n'y a rien à traduire. Le sens
/// reste dans le libellé issu de `ZcrudLabels`, la valeur dans le nombre.
String _withCount(String text, int count) => '$text : $count';

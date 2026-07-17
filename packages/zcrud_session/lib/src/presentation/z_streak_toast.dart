/// `zShowStreakToast` — la confirmation de flamme (SU-6, FR-SU11 — AC6).
///
/// ## Le seam est RÉUTILISÉ, jamais redéclaré (D3)
///
/// Le toast passe par **`ZToasterScope.of(context).show(...)`** — le port
/// `ZToaster` de `zcrud_ui_kit`. **Redéclarer un port de toast local à
/// `zcrud_session` serait la violation** (spine : « seams réutilisés, jamais
/// redéclarés »), et un `ScaffoldMessenger…showSnackBar` en dur en serait une
/// autre : une app qui substitue son toaster (GetX, `toastification`) verrait la
/// flamme lui échapper.
///
/// L'arête `zcrud_session → zcrud_ui_kit` a été ajoutée pour ça (D3) : elle est
/// **sûre** — `zcrud_ui_kit → zcrud_core` est sa seule arête sortante ⇒ le graphe
/// reste **ACYCLIQUE** (53 arêtes) avec **CORE OUT=0**, et **aucune dépendance
/// tierce** n'entre.
///
/// **AD-10 sans une ligne de code défensif** : `ZToasterScope.of` a un **repli
/// sûr** (`const ZScaffoldMessengerToaster()`) — il ne throw **jamais**, même
/// sans scope monté.
///
/// ## 🔴 Pas de spam (AC6)
///
/// Seules les issues qui **changent** la flamme parlent
/// (`started`/`incremented`/`resetToOne`). `alreadyCountedToday` et
/// `skippedNotGraded` ⇒ **AUCUN** toast : sans cette règle, chaque carte d'une
/// session en déclencherait un.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStreakAdvance, ZStreakOutcome;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart'
    show ZToastSeverity, ZToasterScope;

/// Affiche la confirmation de flamme correspondant à [advance] — ou **rien**.
///
/// - `started` / `incremented` → toast **success** ;
/// - `resetToOne` → toast **warning** (la série a été rompue : ce n'est pas une
///   erreur, c'est un avertissement — la répétition du jour **compte** déjà,
///   `current == 1`) ;
/// - `alreadyCountedToday` / `skippedNotGraded` → **AUCUN** toast (AC6).
///
/// La sévérité est **toujours** un [ZToastSeverity] — jamais un `bool isError`
/// (NFR-U7/AC15).
///
/// Les libellés viennent de `ZcrudLabels` (`label(context, key, fallback:)`) :
/// **zéro libellé en dur** (NFR-SU4).
void zShowStreakToast(BuildContext context, ZStreakAdvance advance) {
  final severity = zStreakToastSeverityFor(advance.outcome);
  if (severity == null) return; // pas de spam : rien à annoncer.

  final message = _messageFor(context, advance);

  // 🔴 LE seam : le toaster du scope, sinon le repli sûr — jamais un SnackBar.
  ZToasterScope.of(context).show(
    context,
    message: message,
    severity: severity,
  );
}

/// Sévérité du toast pour [outcome], ou `null` si **aucun** toast ne doit
/// s'afficher — **fonction PURE** (testable sans widget).
///
/// Exposée pour que la règle « pas de spam » soit **prouvable en isolation**, et
/// **énumérable** : un 6ᵉ `ZStreakOutcome` ajouté demain force une décision ici.
ZToastSeverity? zStreakToastSeverityFor(ZStreakOutcome outcome) =>
    switch (outcome) {
      ZStreakOutcome.started => ZToastSeverity.success,
      ZStreakOutcome.incremented => ZToastSeverity.success,
      ZStreakOutcome.resetToOne => ZToastSeverity.warning,
      // 🔴 Silence VOLONTAIRE : sans quoi chaque carte d'une session
      // déclencherait un toast.
      ZStreakOutcome.alreadyCountedToday => null,
      ZStreakOutcome.skippedNotGraded => null,
    };

/// Message l10n de [advance] (clé + repli — patron SANCTIONNÉ).
///
/// ## 🔴 Le NOMBRE est composé HORS de `label()` (code-review su-6, D4)
///
/// `label(context, key, {fallback})` (`z_localizations.dart`) résout
/// `scope → locale → _enLabels → fallback` et **rend la chaîne telle quelle** :
/// il n'existe **aucun** mécanisme de substitution de paramètre ni de
/// pluralisation. Mon premier jet écrivait
/// `label(..., fallback: 'Série de $current jours')` : le nombre n'existait donc
/// que dans le **repli en dur**, c'est-à-dire **uniquement quand la localisation
/// échoue**. Dès qu'une app fournit `zcrud.study.streak.incremented` — la **raison
/// d'être** de la clé — `label()` rend « Série en cours » et **le nombre
/// disparaît silencieusement** : aucune exception, aucun test rouge, et
/// l'apprenant d'une app localisée ne voit plus jamais sa série, alors que
/// FR-SU11 fait du compteur *le* contenu du toast.
///
/// Le bon patron est **dans la même story** : `z_streak_badge.dart` porte un
/// libellé **statique et localisable** (`Semantics(label:)`) et le nombre dans un
/// **canal séparé** (`Semantics(value:)`). Un toast n'ayant qu'un seul canal (sa
/// chaîne), la décomposition équivalente est : libellé **statique** issu de
/// `ZcrudLabels` **+** nombre **concaténé hors** de `label()`. Le compteur
/// survit alors à **toute** traduction.
String _messageFor(BuildContext context, ZStreakAdvance advance) {
  final current = advance.streak.current;
  return switch (advance.outcome) {
    ZStreakOutcome.started => label(
        context,
        'zcrud.study.streak.started',
        fallback: 'Série démarrée',
      ),
    // 🔴 Libellé STATIQUE (traduisible intégralement) + nombre HORS de `label()`.
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
    // Inatteignable (filtré par `zStreakToastSeverityFor`), mais TOTAL : aucun
    // `default` muet, aucun throw (AD-10).
    ZStreakOutcome.alreadyCountedToday ||
    ZStreakOutcome.skippedNotGraded =>
      '',
  };
}

/// Adjoint [count] à un libellé **déjà localisé**, sans jamais le traverser.
///
/// Le séparateur ne porte **aucune lettre** : il n'y a rien à traduire (c'est le
/// critère même du scanner de libellés, `_isTranslatable`). Le SENS reste dans
/// le libellé issu de `ZcrudLabels`, la VALEUR dans le nombre.
String _withCount(String text, int count) => '$text : $count';

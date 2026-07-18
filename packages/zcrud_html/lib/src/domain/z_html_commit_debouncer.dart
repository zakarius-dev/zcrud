/// `ZHtmlCommitDebouncer` — mécanique temporelle PURE (Dart, sans WebView) du
/// champ HTML WYSIWYG (fp-4-3, AD-50/AD-2/SM-1).
///
/// 🔴 **Unité FALSIFIABLE de SM-1.** Le `State` de la WebView `html_editor_enhanced`
/// n'est pas montable en `flutter_test` (VM, pas de moteur WebView — cf. ET-5) :
/// toute la logique « débounce du commit hors-frappe » + « garde de re-sync hors
/// focus » est donc EXTRAITE ici, en Dart pur, injectable (ordonnanceur/horloge),
/// testable au caractère près.
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-2 / SM-1** : une frappe ne pousse **JAMAIS** de commit synchrone —
///   [onContentChanged] se contente de (re)programmer un commit différé. N frappes
///   rapides ⇒ **≤ 1** commit poussé dans la fenêtre (les précédents sont annulés).
/// - **AD-2 (re-sync guardée)** : une valeur EXTERNE entrante n'est acceptée
///   ([shouldAcceptExternal]) que **hors focus** — jamais pendant l'édition (aucun
///   écrasement de sélection/curseur).
/// - Le format porté est **HTML `String`** (la voie WYSIWYG ne force pas de Delta).
///
/// Mutants attendus ROUGES (discipline R3) : « push synchrone » (commit dans
/// [onContentChanged]) ; « re-sync en focus » ([shouldAcceptExternal] renvoyant
/// `true` alors que le champ a le focus).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Fenêtre de débounce par défaut du commit HTML (hors chemin chaud de frappe).
const Duration kZHtmlCommitDebounce = Duration(milliseconds: 400);

/// Ordonnanceur différé injectable — abstrait le `Timer` pour rendre le débounce
/// testable SANS temps réel (un faux ordonnanceur « tire » le commit à la demande).
abstract interface class ZDebounceScheduler {
  /// Programme [action] après [delay] et retourne une poignée d'annulation.
  Object schedule(Duration delay, void Function() action);

  /// Annule la programmation identifiée par [handle] (no-op si déjà tirée).
  void cancel(Object? handle);
}

/// Ordonnanceur de production basé sur [Timer].
class ZTimerDebounceScheduler implements ZDebounceScheduler {
  /// Construit l'ordonnanceur `Timer` par défaut.
  const ZTimerDebounceScheduler();

  @override
  Object schedule(Duration delay, void Function() action) =>
      Timer(delay, action);

  @override
  void cancel(Object? handle) => (handle as Timer?)?.cancel();
}

/// Débouncer de commit + garde de focus du champ HTML WYSIWYG.
///
/// Le `State` de la WebView délègue ici : [onContentChanged] à chaque `onChange`
/// Summernote, [onFocusChanged] aux `onFocus`/`onBlur`, [flush] au blur/dispose,
/// et [shouldAcceptExternal] pour décider si une valeur `ctx.value` entrante doit
/// être ré-injectée (`setText`) — jamais en focus.
class ZHtmlCommitDebouncer {
  /// Construit le débouncer. [onCommit] pousse la valeur HTML débouncée dans la
  /// tranche (`ctx.onChanged`). [debounce] est la fenêtre ; [scheduler] est
  /// injecté par les tests (défaut : [ZTimerDebounceScheduler]).
  ZHtmlCommitDebouncer({
    required void Function(String html) onCommit,
    Duration debounce = kZHtmlCommitDebounce,
    ZDebounceScheduler scheduler = const ZTimerDebounceScheduler(),
  })  : _onCommit = onCommit,
        _debounce = debounce,
        _scheduler = scheduler;

  final void Function(String html) _onCommit;
  final Duration _debounce;
  final ZDebounceScheduler _scheduler;

  Object? _handle;
  String? _pending;
  String? _lastSynced;
  bool _hasFocus = false;
  int _commitCount = 0;

  /// Nombre de commits EFFECTIVEMENT poussés (assertion SM-1 en test).
  @visibleForTesting
  int get debugCommitCount => _commitCount;

  /// `true` tant qu'un commit différé est en attente (témoin de test).
  @visibleForTesting
  bool get debugHasPending => _handle != null;

  /// `true` si le champ a le focus (l'édition est en cours).
  bool get isEditing => _hasFocus;

  /// Reçoit un changement de contenu (une frappe). **Ne pousse JAMAIS de commit
  /// synchrone** : (re)programme un commit différé, annulant le précédent.
  void onContentChanged(String html) {
    _pending = html;
    _scheduler.cancel(_handle);
    _handle = _scheduler.schedule(_debounce, _commitPending);
  }

  /// Met à jour l'état de focus. Au **blur** (`hasFocus == false`), pousse
  /// immédiatement le commit en attente (flush) — le contenu final ne se perd pas.
  void onFocusChanged({required bool hasFocus}) {
    _hasFocus = hasFocus;
    if (!hasFocus) flush();
  }

  /// Pousse immédiatement la valeur en attente (blur/dispose), sans attendre la
  /// fenêtre. No-op s'il n'y a rien à pousser ou si la valeur n'a pas changé.
  void flush() {
    _scheduler.cancel(_handle);
    _handle = null;
    _commitPending();
  }

  void _commitPending() {
    _handle = null;
    final String? value = _pending;
    _pending = null;
    if (value == null) return;
    if (value == _lastSynced) return; // pas de commit redondant.
    _lastSynced = value;
    _commitCount++;
    _onCommit(value);
  }

  /// Décide si une valeur EXTERNE ([value], venue de `ctx.value`) doit être
  /// ré-injectée dans l'éditeur (`setText`). **Jamais en focus** (AD-2 : priorité
  /// absolue à la saisie) ; jamais si elle est déjà synchronisée/en attente.
  bool shouldAcceptExternal(String value) {
    if (_hasFocus) return false; // édition en cours ⇒ aucun écrasement.
    if (value == _lastSynced) return false;
    if (value == _pending) return false;
    return true;
  }

  /// Enregistre [value] comme dernier contenu synchronisé (après un `setText`
  /// entrant accepté, ou pour amorcer le contenu initial). Évite un commit/rebond
  /// redondant sur cette même valeur.
  void markSynced(String value) {
    _lastSynced = value;
  }

  /// À appeler en `State.dispose`. **Non-perte à la destruction** : pousse
  /// d'abord l'éventuel commit débouncé EN ATTENTE ([flush]) — les dernières
  /// frappes (<fenêtre, débounce non écoulé) ne sont JAMAIS jetées même sans
  /// blur préalable (champ conditionnel masqué, dialog/route fermé) — puis
  /// nettoie. [flush] est idempotent (no-op si rien en attente / déjà annulé).
  void dispose() {
    flush();
    _handle = null;
    _pending = null;
  }
}

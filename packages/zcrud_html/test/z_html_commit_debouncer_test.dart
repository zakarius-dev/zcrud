/// 🎯 fp-4-3 (AC4) — SM-1 FALSIFIABLE : la mécanique de commit HTML est extraite
/// en [ZHtmlCommitDebouncer] (pur Dart, sans WebView — ET-5), testable au
/// caractère près. Ordonnanceur FAUX injecté (aucun temps réel).
///
/// 🔴 Contre-preuves R3 (mutants attendus ROUGES) documentées par test :
///  - « push synchrone » (commit dans `onContentChanged`) ⇒ `debugCommitCount`
///    devient > 0 AVANT `fire()` ⇒ rouge.
///  - « re-sync en focus » (`shouldAcceptExternal` renvoyant `true` en focus) ⇒
///    rouge.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_html/src/domain/z_html_commit_debouncer.dart';

/// Ordonnanceur FAUX : mémorise le dernier commit programmé et le tire à la
/// demande (`fire`). Une nouvelle programmation remplace la précédente (débounce).
class _FakeScheduler implements ZDebounceScheduler {
  void Function()? _pending;
  int scheduleCount = 0;

  bool get hasPending => _pending != null;

  @override
  Object schedule(Duration delay, void Function() action) {
    _pending = action;
    scheduleCount++;
    return action;
  }

  @override
  void cancel(Object? handle) {
    if (identical(_pending, handle)) _pending = null;
  }

  /// Tire le commit en attente (simule l'échéance de la fenêtre de débounce).
  void fire() {
    final void Function()? p = _pending;
    _pending = null;
    p?.call();
  }
}

void main() {
  group('🎯 AC4 — débounce du commit hors-frappe (SM-1)', () {
    test('🔴 N frappes rapides ⇒ ≤ 1 commit poussé (le DERNIER)', () {
      final scheduler = _FakeScheduler();
      final commits = <String>[];
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: commits.add,
        scheduler: scheduler,
      );

      for (var i = 1; i <= 100; i++) {
        debouncer.onContentChanged('<p>$i</p>');
      }
      // Aucune frappe n'a poussé de commit SYNCHRONE (mutant « push synchrone »
      // ⇒ ce compteur serait déjà > 0 ⇒ rouge).
      expect(debouncer.debugCommitCount, 0,
          reason: '🔴 aucune frappe ne doit pousser de commit synchrone');
      expect(scheduler.hasPending, isTrue);

      // Échéance de la fenêtre : UN SEUL commit, la dernière valeur.
      scheduler.fire();
      expect(commits, <String>['<p>100</p>'],
          reason: '🔴 ≤ 1 commit dans la fenêtre, valeur = dernière frappe');
      expect(debouncer.debugCommitCount, 1);
    });

    test('🔴 la 1ʳᵉ frappe ne pousse RIEN de synchrone (anti-mutant)', () {
      final scheduler = _FakeScheduler();
      final commits = <String>[];
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: commits.add,
        scheduler: scheduler,
      );

      debouncer.onContentChanged('<p>a</p>');
      expect(commits, isEmpty,
          reason: '🔴 push synchrone interdit — le mutant rougirait ici');
      expect(scheduler.hasPending, isTrue);

      scheduler.fire();
      expect(commits, <String>['<p>a</p>']);
    });

    test('commit redondant (valeur inchangée) NON poussé deux fois', () {
      final scheduler = _FakeScheduler();
      final commits = <String>[];
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: commits.add,
        scheduler: scheduler,
      );

      debouncer.onContentChanged('<p>x</p>');
      scheduler.fire();
      debouncer.onContentChanged('<p>x</p>'); // même valeur
      scheduler.fire();
      expect(commits, <String>['<p>x</p>'],
          reason: 'la même valeur ne re-commit pas');
    });

    test('🔴 dispose FLUSHE le commit débouncé en attente (non-perte, MED-1)',
        () {
      final scheduler = _FakeScheduler();
      final commits = <String>[];
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: commits.add,
        scheduler: scheduler,
      );

      // Frappe pendant l'édition, débounce NON écoulé (pas de fire), PAS de blur
      // (champ masqué / route fermée) : la valeur est en attente.
      debouncer.onFocusChanged(hasFocus: true);
      debouncer.onContentChanged('<p>dernier</p>');
      expect(commits, isEmpty, reason: 'rien de synchrone avant dispose');

      // dispose sans blur : le contenu final ne doit PAS être jeté (MED-1).
      // Mutant « dispose jette le pending » ⇒ commits == [] ⇒ rouge.
      debouncer.dispose();
      expect(commits, <String>['<p>dernier</p>'],
          reason: '🔴 dispose DOIT flusher le pending (non-perte de données)');
    });

    test('dispose est idempotent après flush (aucun double commit)', () {
      final scheduler = _FakeScheduler();
      final commits = <String>[];
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: commits.add,
        scheduler: scheduler,
      );

      debouncer.onContentChanged('<p>x</p>');
      scheduler.fire(); // committe déjà
      debouncer.dispose(); // rien en attente ⇒ pas de recommit
      expect(commits, <String>['<p>x</p>'],
          reason: 'dispose après flush ne re-commit pas');
    });

    test('flush au blur pousse immédiatement le contenu final', () {
      final scheduler = _FakeScheduler();
      final commits = <String>[];
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: commits.add,
        scheduler: scheduler,
      );

      debouncer.onFocusChanged(hasFocus: true);
      debouncer.onContentChanged('<p>final</p>');
      expect(commits, isEmpty, reason: 'toujours rien de synchrone');
      // Blur ⇒ flush immédiat, sans attendre fire().
      debouncer.onFocusChanged(hasFocus: false);
      expect(commits, <String>['<p>final</p>']);
      expect(scheduler.hasPending, isFalse);
    });
  });

  group('🎯 AC4 — re-sync guardée HORS focus (AD-2)', () {
    test('🔴 valeur externe ACCEPTÉE hors focus, REFUSÉE en focus (anti-mutant)',
        () {
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: (_) {},
        scheduler: _FakeScheduler(),
      );

      // Hors focus : une valeur externe DIFFÉRENTE est acceptée (re-sync).
      debouncer.onFocusChanged(hasFocus: false);
      expect(debouncer.shouldAcceptExternal('<p>externe</p>'), isTrue);

      // En focus : AUCUN écrasement de la saisie (mutant « re-sync en focus »
      // renverrait `true` ⇒ rouge).
      debouncer.onFocusChanged(hasFocus: true);
      expect(debouncer.shouldAcceptExternal('<p>autre</p>'), isFalse,
          reason: '🔴 jamais de re-sync pendant l\'édition (focus)');
    });

    test('valeur externe déjà synchronisée ⇒ refusée (no-op)', () {
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: (_) {},
        scheduler: _FakeScheduler(),
      );
      debouncer.markSynced('<p>same</p>');
      expect(debouncer.shouldAcceptExternal('<p>same</p>'), isFalse);
      expect(debouncer.shouldAcceptExternal('<p>diff</p>'), isTrue);
    });

    test('une valeur committée ne re-déclenche pas une re-sync (échO)', () {
      final scheduler = _FakeScheduler();
      final debouncer = ZHtmlCommitDebouncer(
        onCommit: (_) {},
        scheduler: scheduler,
      );
      debouncer.onContentChanged('<p>typed</p>');
      scheduler.fire(); // committe ⇒ markSynced interne
      // L'écho de `ctx.value` == valeur committée ne doit rien ré-injecter.
      expect(debouncer.shouldAcceptExternal('<p>typed</p>'), isFalse);
    });
  });
}

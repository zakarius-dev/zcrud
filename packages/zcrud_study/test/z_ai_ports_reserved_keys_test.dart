// Verrou AD-19.1 des requests de ports IA (ES-9.1, remédiation M-1 code-review).
//
// Les 3 request value-objects portent un `extra` LIBRE (paramètres app-specific
// neutres). AD-19.1 (garde machine uniforme) impose que les clés de sync
// RÉSERVÉES (`updated_at`/`is_deleted`) n'y survivent jamais — elles sont
// écartées À LA LECTURE via l'accesseur (slot `_extra` brut + `zSanitizeExtra`).
//
// 🔴 LOAD-BEARING (M-1) : ce test EXERCE l'accesseur. Neutraliser la garde en
// prod (`Map<String,dynamic> get extra => _extra;`, sans `zSanitizeExtra`) le fait
// ROUGIR — sans lui, le correctif reserved-keys de l'orchestrateur serait un
// « vœu » non vérifié (anti-pattern powerless, R12). `reserved_keys_gate`
// n'importe PAS `zcrud_study`, donc SEUL ce test package-local couvre ces DTOs.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  // extra brut fourni au constructeur : 2 clés de sync réservées + 1 légitime.
  const raw = <String, dynamic>{
    'updated_at': '2026-01-01T00:00:00Z',
    'is_deleted': true,
    'legit': 42,
  };

  void expectSanitized(Map<String, dynamic> extra) {
    // Clés de sync réservées ÉCARTÉES à la lecture (AD-19.1)…
    expect(extra.containsKey('updated_at'), isFalse,
        reason: 'updated_at (clé de sync réservée) doit être écartée de extra');
    expect(extra.containsKey('is_deleted'), isFalse,
        reason: 'is_deleted (clé de sync réservée) doit être écartée de extra');
    // …mais la clé app-specific légitime est PRÉSERVÉE (préservation exacte, R26).
    expect(extra['legit'], 42);
    expect(extra.length, 1);
  }

  test('ZFlashcardGenerationRequest.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(
      const ZFlashcardGenerationRequest(content: 'c', extra: raw).extra,
    );
  });

  test('ZAiExplanationRequest.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(
      const ZAiExplanationRequest(content: 'c', extra: raw).extra,
    );
  });

  test('ZNoteSummaryRequest.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(
      const ZNoteSummaryRequest(content: 'c', extra: raw).extra,
    );
  });
}

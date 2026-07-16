// Verrou AD-19.1 du request de génération de podcast (ES-9.3, LOAD-BEARING M-1).
//
// `ZPodcastGenerationRequest` porte un `extra` LIBRE (paramètres app-specific
// neutres). AD-19.1 (garde machine uniforme) impose que les clés de sync
// RÉSERVÉES (`updated_at`/`is_deleted`) n'y survivent jamais — elles sont
// écartées À LA LECTURE via l'accesseur (slot `_extra` brut + `zSanitizeExtra`).
//
// 🔴 LOAD-BEARING (M-1) : ce test EXERCE l'accesseur. Neutraliser la garde en
// prod (`Map<String,dynamic> get extra => _extra;`, sans `zSanitizeExtra`) le fait
// ROUGIR (R3-I3 : `updated_at` survit) — sans lui, la garde serait un « vœu »
// non vérifié (anti-pattern powerless, défaut exact du code-review ES-9.1).
// `reserved_keys_gate` n'importe PAS `zcrud_study`, donc SEUL ce test
// package-local couvre ce DTO. Runner R14 : `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  // extra brut fourni au constructeur : 2 clés de sync réservées + 1 légitime.
  const raw = <String, dynamic>{
    'updated_at': '2026-01-01T00:00:00Z',
    'is_deleted': true,
    'legit': 42,
  };

  test('ZPodcastGenerationRequest.extra écarte les clés de sync (AD-19.1)', () {
    final extra =
        const ZPodcastGenerationRequest(content: 'c', extra: raw).extra;
    // Clés de sync réservées ÉCARTÉES à la lecture (AD-19.1)…
    expect(extra.containsKey('updated_at'), isFalse,
        reason: 'updated_at (clé de sync réservée) doit être écartée de extra');
    expect(extra.containsKey('is_deleted'), isFalse,
        reason: 'is_deleted (clé de sync réservée) doit être écartée de extra');
    // …mais la clé app-specific légitime est PRÉSERVÉE (préservation exacte, R26).
    expect(extra['legit'], 42);
    expect(extra.length, 1);
  });

  test('== consomme l\'accesseur sanitisé (clé réservée ⇒ requests égaux)', () {
    const a = ZPodcastGenerationRequest(content: 'c', extra: raw);
    const b = ZPodcastGenerationRequest(
      content: 'c',
      extra: <String, dynamic>{'legit': 42},
    );
    // Deux requests ne différant que par des clés réservées sont ÉGAUX :
    // `==`/`hashCode` consomment l'accesseur sanitisé, pas le slot brut.
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}

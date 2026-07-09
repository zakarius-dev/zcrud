@Tags(<String>['serialization-compat'])
library;

// PREMIER test du slot `verify:serialization` (E2-10, AD-10) — E2-5 l'AMORCE
// (round-trip idempotent + désérialisation défensive sur le modèle de preuve).
// `scripts/ci/verify_serialization.dart` exécute `dart test --tags
// serialization-compat` et n'est donc plus un no-op vide. Le CORPUS complet
// (fixtures historiques, montée de version) reste E2-10 (anti-empiètement).
import 'package:test/test.dart';

import 'models/article.dart';

void main() {
  test('round-trip idempotent toMap→fromMap (serialization-compat)', () {
    final x = Article(
      id: 'z9',
      title: 'Compat',
      views: 3,
      status: ArticleStatus.archived,
      createdAt: DateTime(2020, 1, 2, 3, 4, 5),
      tags: const <String>['t'],
      author: const Author(name: 'A'),
    );
    expect(Article.fromMap(x.toMap()), equals(x));
  });

  test('désérialisation défensive : document historique tronqué survit', () {
    // Simule un document ancien : champs récents absents, enum hors domaine.
    final a = Article.fromMap(<String, dynamic>{
      'title': 'Ancien',
      'status': 'legacy-value-removed',
    });
    expect(a.title, 'Ancien');
    expect(a.status, ArticleStatus.draft); // repli, jamais de throw
    expect(a.views, 0);
    expect(a.author, isNull);
  });
}

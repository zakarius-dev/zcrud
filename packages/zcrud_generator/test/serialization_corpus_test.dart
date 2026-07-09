@Tags(<String>['serialization-compat'])
library;

/// CORPUS de rétro-compatibilité de sérialisation (E2-10, AD-10).
///
/// Exécuté par le slot de gate de merge `verify:serialization`
/// (`scripts/ci/verify_serialization.dart` → `dart test --tags
/// serialization-compat`). Complète — sans la dupliquer — l'amorce E2-5
/// (`serialization_compat_test.dart`, round-trip + 1 cas historique).
///
/// Deux voies exercées sur la MÊME source de vérité (`serialization_corpus`) :
/// - **voie codegen directe** (`Article.fromMap`) — AC2 ;
/// - **voie registre codegen** (`ZcrudRegistry.decode('article', …)`) — AC3.
/// Invariant universel des deux voies : le parent SURVIT toujours
/// (`returnsNormally`), + assertions ciblées de repli par famille.
///
/// Décision MEDIUM-1 (E2-6) : la voie ADAPTATEUR (`JsonSerializableAdapter`/
/// `ReflectableCodec`, dont le `fromMap` strict enregistré peut throw) est
/// DÉFÉRÉE à E5 (frontière repository / évolution additive du contrat gelé
/// `ZcrudRegistry` E2-3). Ici seule la voie CODEGEN est couverte — car son
/// `fromMap` généré est intrinsèquement défensif (AD-10 prouvé pour le chemin
/// canonique porté de lex_douane via le builder zcrud).
import 'package:test/test.dart';
import 'package:zcrud_core/edition.dart';

import 'models/article.dart';
import 'models/serialization_corpus.dart';

void main() {
  group('Corpus AD-10 — voie codegen directe (Article.fromMap)', () {
    // AC2 : invariant universel « le parent survit », itéré sur tout le corpus.
    for (final c in serializationCorpus) {
      test('[${c.family}] ${c.name} — le parent survit (returnsNormally)', () {
        expect(
          () => Article.fromMap(asTopLevelMap(c)),
          returnsNormally,
          reason: 'AD-10 : ${c.name} ne doit JAMAIS casser le parent',
        );
      });
    }

    // AC1 — assertions ciblées de repli, une par famille.

    test('(a) historique : champs récents absents → defaultValue', () {
      final a = Article.fromMap(asTopLevelMap(corpusCase(
          'historique_v_n_champ_ajoute_absent')));
      expect(a.id, 'a1');
      expect(a.title, 'Vieux'); // présent → conservé
      expect(a.subtitle, 'sub');
      expect(a.views, 0);
      expect(a.rating, 0.0);
      expect(a.published, isFalse);
      expect(a.status, ArticleStatus.draft);
      expect(a.createdAt, isNull);
      expect(a.tags, isEmpty);
      expect(a.author, isNull);
      expect(a.coauthors, isEmpty);
    });

    test('(b) tronqué : sous-objet author:{} → Author(name:"") (codegen '
        'défensif, PAS null) + coauthors non-Map filtrés', () {
      final a = Article.fromMap(
          asTopLevelMap(corpusCase('tronque_toplevel_et_sous_objet_vide')));
      expect(a.title, 'T');
      // Comportement OBSERVÉ : Author.fromMap est défensif → name:'' (pas null).
      expect(a.author, isNotNull);
      expect(a.author!.name, '');
      // coauthors: [{} → Author(''), 'bad' → null, 7 → null] → 1 conservé.
      expect(a.coauthors, hasLength(1));
      expect(a.coauthors.single.name, '');
    });

    test('(b) tronqué : author partiel {email} → name repli "", email '
        'conservé', () {
      final a = Article.fromMap(
          asTopLevelMap(corpusCase('sous_objet_author_sans_name')));
      expect(a.author, isNotNull);
      expect(a.author!.name, '');
      expect(a.author!.email, 'e@x.com');
    });

    test('(c) champs inconnus ignorés, champs connus décodés', () {
      final a = Article.fromMap(
          asTopLevelMap(corpusCase('futur_v_n1_champ_inconnu_ignore')));
      expect(a.title, 'X');
      expect(a.views, 5); // champ connu décodé normalement
      // Les clés __future_key__ / nested_future sont simplement ignorées.
    });

    test('(d) enums inconnus → repli draft, jamais de throw', () {
      for (final n in const ['enum_legacy_retire', 'enum_futur',
        'enum_non_string']) {
        final a = Article.fromMap(asTopLevelMap(corpusCase(n)));
        expect(a.status, ArticleStatus.draft, reason: n);
      }
    });

    test('(e) types faux : coercitions douces & replis', () {
      expect(Article.fromMap(asTopLevelMap(corpusCase('views_string_non_num')))
          .views, 0);
      expect(Article.fromMap(asTopLevelMap(corpusCase('views_string_num_coerce')))
          .views, 42); // coercition douce String→int
      expect(Article.fromMap(asTopLevelMap(corpusCase('rating_string_num_coerce')))
          .rating, 3.5);
      expect(Article.fromMap(asTopLevelMap(corpusCase('rating_string_non_num')))
          .rating, 0.0);
      expect(Article.fromMap(asTopLevelMap(corpusCase('tags_map_au_lieu_de_list')))
          .tags, isEmpty);
      expect(Article.fromMap(asTopLevelMap(corpusCase('coauthors_map_au_lieu_de_list')))
          .coauthors, isEmpty);
      expect(Article.fromMap(asTopLevelMap(corpusCase('published_non_bool')))
          .published, isFalse);
      expect(Article.fromMap(asTopLevelMap(corpusCase('author_non_map')))
          .author, isNull); // non-Map → _$asStringMap null → author null
      expect(Article.fromMap(asTopLevelMap(corpusCase('tags_liste_mixte')))
          .tags, <String>['a', 'b']); // whereType<String>
    });

    test('(f) clés non-String (régression H1) : coercition sans throw', () {
      // Clés int pures : coercées en '1'/'2', aucune 'name' → Author(name:'').
      final a1 = Article.fromMap(
          asTopLevelMap(corpusCase('author_cles_int_hive')));
      expect(a1.author, isNotNull);
      expect(a1.author!.name, '');
      // Clés mixtes : la clé valide 'name' est préservée malgré la clé int.
      final a2 = Article.fromMap(
          asTopLevelMap(corpusCase('author_cles_mixtes_avec_name')));
      expect(a2.author, isNotNull);
      expect(a2.author!.name, 'Bob');
    });

    test('(g) null partout → tous les champs prennent leur repli', () {
      final a = Article.fromMap(asTopLevelMap(corpusCase('null_partout')));
      expect(a.id, isNull);
      expect(a.title, ''); // requis → repli ''
      expect(a.subtitle, isNull);
      expect(a.views, 0);
      expect(a.rating, 0.0);
      expect(a.published, isFalse);
      expect(a.status, ArticleStatus.draft);
      expect(a.createdAt, isNull);
      expect(a.tags, isEmpty);
      expect(a.author, isNull);
      expect(a.coauthors, isEmpty);
    });

    test('sous-modèle Author.fromMap seul : défensif, name manquant → "" '
        '(comportement observé, non modifié)', () {
      expect(() => Author.fromMap(<String, dynamic>{}), returnsNormally);
      expect(Author.fromMap(<String, dynamic>{}).name, '');
      expect(Author.fromMap(<String, dynamic>{'name': 42}).name, '');
    });
  });

  group('Corpus AD-10 — voie registre codegen (ZcrudRegistry.decode)', () {
    // AC3 : la frontière registre est défensive POUR LES MODÈLES GÉNÉRÉS.
    late ZcrudRegistry registry;
    setUp(() {
      registry = ZcrudRegistry();
      registerArticle(registry);
    });

    for (final c in serializationCorpus) {
      test('[${c.family}] ${c.name} — decode() ne lève jamais', () {
        expect(
          () => registry.decode('article', asTopLevelMap(c)),
          returnsNormally,
          reason: 'AD-10 frontière registre codegen : ${c.name}',
        );
      });
    }

    test('decode renvoie bien un Article décodé défensivement', () {
      final decoded = registry.decode(
          'article', asTopLevelMap(corpusCase('null_partout')));
      expect(decoded, isA<Article>());
      expect((decoded as Article).title, '');
      expect(decoded.status, ArticleStatus.draft);
    });
  });
}

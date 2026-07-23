// CR-LEX-29 — `ZMindmap` était la SEULE entité du dépôt sans `copyWith`.
//
// Mesuré : `ZExam`, `ZStudyFolder`, `ZStudyDocument` en ont un, `ZMindmap`
// zéro. L'asymétrie n'était pas un parti pris cohérent — c'était une exception
// isolée, et elle tombait sur l'entité dont l'hôte a le plus besoin de
// préserver l'état existant.
//
// Conséquence chez lex, EN PRODUCTION : faute de `copyWith`, leur mapping aller
// reconstruisait la carte champ par champ, et perdait 3 champs sur 7 —
// `description`, `extension`, `extra` — à CHAQUE sauvegarde. `extra` est le
// slot AD-4 : celui qui porte les clés d'un AUTRE hôte.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Carte porteuse des trois champs que le mapping aller perdait.
ZMindmap _carteComplete() => ZMindmap(
      id: 'm1',
      folderId: 'f1',
      title: 'Titre',
      description: 'Une description',
      nodes: <ZMindmapNode>[
        ZMindmapNode(id: 'n1', label: 'Racine'),
      ],
      extension: _ExtensionHote.of(<String, dynamic>{'format_version': 2}),
      extra: <String, dynamic>{'cle_autre_hote': 'valeur'},
    );

void main() {
  group('🔴 CR-LEX-29 — les champs hors-arbre sont PRÉSERVÉS', () {
    test('changer le titre ne perd NI description NI extension NI extra', () {
      // C'est le geste exact que faisait l'hôte, et qui écrasait 3 champs.
      final ZMindmap avant = _carteComplete();
      final ZMindmap apres = avant.copyWithPreservingTree(title: 'Nouveau');

      expect(apres.title, 'Nouveau');
      expect(apres.description, 'Une description');
      expect(apres.extension, isNotNull);
      expect(apres.extra['cle_autre_hote'], 'valeur',
          reason: 'le slot d\'un AUTRE hôte ne doit pas être effacé');
    });

    test('l\'arbre traverse À L\'IDENTIQUE (invariant TreeOps préservé)', () {
      final ZMindmap avant = _carteComplete();
      final ZMindmap apres = avant.copyWithPreservingTree(title: 'X');
      expect(apres.nodes.length, avant.nodes.length);
      expect(apres.nodes.first.id, 'n1');
      expect(apres.nodes.first.label, 'Racine');
    });

    test('`nodes` n\'est PAS un paramètre — la mutation reste TreeOps', () {
      // Le motif documenté de l'absence de copyWith protégeait la cohérence de
      // l'arbre. Il reste valable : on ne l'a pas contourné, on l'a borné.
      // La signature elle-même l'atteste : aucun paramètre `nodes`. On vérifie
      // que l'arbre traverse intact, sans qu'aucun appelant puisse le remplacer.
      final ZMindmap c = _carteComplete().copyWithPreservingTree(title: 'X');
      expect(c.nodes.length, 1);
      expect(c.nodes.first.id, 'n1');
    });

    test('un round-trip par copyWith est STABLE sur trois cycles', () {
      var carte = _carteComplete();
      for (var cycle = 0; cycle < 3; cycle++) {
        carte = carte.copyWithPreservingTree(title: 'T$cycle');
        expect(carte.description, 'Une description', reason: 'cycle $cycle');
        expect(carte.extra['cle_autre_hote'], 'valeur', reason: 'cycle $cycle');
        expect(carte.extension, isNotNull, reason: 'cycle $cycle');
      }
    });
  });

  group('🔴 La sentinelle distingue « non fourni » de « mets à null »', () {
    test('sans argument, un champ NULLABLE est conservé', () {
      // Sans sentinelle, `copyWith()` effacerait `description` et `extension` —
      // le défaut même qu'il corrige.
      final ZMindmap c = _carteComplete().copyWithPreservingTree();
      expect(c.description, 'Une description');
      expect(c.extension, isNotNull);
    });

    test('`null` EXPLICITE efface bien', () {
      final ZMindmap c = _carteComplete()
          .copyWithPreservingTree(description: null, extension: null);
      expect(c.description, isNull);
      expect(c.extension, isNull);
    });

    test('les champs NON nullables sont conservés sans argument', () {
      final ZMindmap c = _carteComplete().copyWithPreservingTree();
      expect(c.id, 'm1');
      expect(c.folderId, 'f1');
      expect(c.title, 'Titre');
    });
  });

  group('Le dépouillement d\'`extra` reste appliqué', () {
    test('une clé RÉSERVÉE passée par copyWith est écartée', () {
      // Le constructeur re-dépouille : l'opération est idempotente, et un
      // copyWith ne peut pas servir de porte dérobée vers `extra`.
      final ZMindmap c = _carteComplete().copyWithPreservingTree(
        extra: <String, dynamic>{'title': 'pirate', 'ok': 1},
      );
      expect(c.extra.containsKey('title'), isFalse,
          reason: 'une clé connue ne doit pas entrer dans extra');
      expect(c.extra['ok'], 1);
    });

    test('AD-16 — les clés de sync n\'entrent pas dans `extra`', () {
      final ZMindmap c = _carteComplete().copyWithPreservingTree(
        extra: <String, dynamic>{'updated_at': 1, 'is_deleted': true},
      );
      expect(c.extra.containsKey('updated_at'), isFalse);
      expect(c.extra.containsKey('is_deleted'), isFalse);
    });

    test('`extra: null` retombe sur une map vide, jamais un crash', () {
      expect(
        () => _carteComplete().copyWithPreservingTree(extra: null),
        returnsNormally,
      );
    });
  });

  group('Le round-trip JSON survit (le chemin réel de l\'hôte)', () {
    test('copyWith puis toJson/fromJson conserve les trois champs', () {
      final ZMindmap apres =
          _carteComplete().copyWithPreservingTree(title: 'Nouveau');
      final ZMindmap relu = ZMindmap.fromJson(apres.toJson());
      expect(relu.title, 'Nouveau');
      expect(relu.description, 'Une description');
      expect(relu.extra['cle_autre_hote'], 'valeur');
      // CR-LEX-33 : préservée même sans décodeur.
      expect(relu.extension, isNotNull);
    });
  });
}

/// Extension typée d'un hôte, pour distinguer le cas typé du cas opaque.
class _ExtensionHote implements ZExtension {
  const _ExtensionHote(this.payload);

  static _ExtensionHote of(Map<String, dynamic> p) => _ExtensionHote(p);

  final Map<String, dynamic> payload;

  @override
  int get formatVersion => payload['format_version'] as int? ?? 0;

  @override
  Map<String, dynamic> toJson() => payload;
}

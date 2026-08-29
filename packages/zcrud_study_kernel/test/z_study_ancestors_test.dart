// Gardes de la projection `ancestorIds`.
//
// `parentId` est la vérité, `ancestorIds` une projection recalculable. Ce que
// ces gardes défendent :
// - un re-parentage recalcule TOUTE la descendance, pas seulement le nœud
//   déplacé (le défaut classique : la chaîne du nœud est corrigée, celle de
//   ses enfants reste périmée et les requêtes de sous-arbre mentent) ;
// - un cycle rend un `Left`, et le fait EN TEMPS BORNÉ. Une remontée non
//   bornée sur une donnée cyclique ne rougit pas : elle PEND, et un harnais
//   qui pend ne signale rien. Le test est donc borné par un `timeout`.

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Nœud minimal : identité + parent, comme n'importe quelle entité de
/// structure.
class _Noeud {
  const _Noeud(this.id, this.parentId);
  final String? id;
  final String? parentId;
}

ZResult<Map<String, List<String>>> _recalculer(List<_Noeud> noeuds) =>
    zRecomputeAncestorIds<_Noeud>(
      noeuds,
      idOf: (_Noeud n) => n.id,
      parentIdOf: (_Noeud n) => n.parentId,
    );

Map<String, List<String>> _droite(ZResult<Map<String, List<String>>> r) =>
    r.getOrElse(() => throw StateError('attendu Right, obtenu Left'));

void main() {
  group('zRecomputeAncestorIds — la projection suit la vérité', () {
    test('une chaîne est ordonnée RACINE D\'ABORD', () {
      final result = _droite(
        _recalculer(const <_Noeud>[
          _Noeud('a', null),
          _Noeud('b', 'a'),
          _Noeud('c', 'b'),
        ]),
      );
      expect(result['a'], isEmpty);
      expect(result['b'], equals(<String>['a']));
      expect(result['c'], equals(<String>['a', 'b']));
      expect(zDepthOf(result['c']!), equals(2));
    });

    test('un re-parentage recalcule aussi la DESCENDANCE', () {
      // `c` est sous `b`, `b` passe de `a` à `x` : la chaîne de `c` doit
      // changer aussi, sans qu'on ait touché à `c`.
      final avant = _droite(
        _recalculer(const <_Noeud>[
          _Noeud('x', null),
          _Noeud('a', null),
          _Noeud('b', 'a'),
          _Noeud('c', 'b'),
        ]),
      );
      expect(avant['c'], equals(<String>['a', 'b']));

      final apres = _droite(
        _recalculer(const <_Noeud>[
          _Noeud('x', null),
          _Noeud('a', null),
          _Noeud('b', 'x'),
          _Noeud('c', 'b'),
        ]),
      );
      expect(apres['b'], equals(<String>['x']));
      expect(
        apres['c'],
        equals(<String>['x', 'b']),
        reason: 'la descendance du nœud déplacé n\'a pas été recalculée',
      );
    });

    test('un parent absent de l\'ensemble termine la chaîne, sans échec', () {
      // Vue partielle d'un arbre : le parent connu est conservé, la remontée
      // s'arrête là. Refuser ici rendrait toute pagination inexploitable.
      final result = _droite(
        _recalculer(const <_Noeud>[_Noeud('b', 'inconnu')]),
      );
      expect(result['b'], equals(<String>['inconnu']));
    });

    test('un nœud éphémère (identité absente) est ignoré', () {
      final result = _droite(
        _recalculer(const <_Noeud>[_Noeud(null, 'a'), _Noeud('', 'a')]),
      );
      expect(result, isEmpty);
    });

    test('un nœud son propre parent ⇒ Left, en temps borné', () {
      final result = _recalculer(const <_Noeud>[_Noeud('a', 'a')]);
      expect(result.isLeft(), isTrue);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('un cycle à deux ⇒ Left, en temps borné', () {
      final result = _recalculer(const <_Noeud>[
        _Noeud('a', 'b'),
        _Noeud('b', 'a'),
      ]);
      expect(result.isLeft(), isTrue);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('un cycle long ⇒ Left, en temps borné', () {
      final noeuds = <_Noeud>[
        for (var i = 0; i < 200; i++) _Noeud('n$i', 'n${(i + 1) % 200}'),
      ];
      expect(_recalculer(noeuds).isLeft(), isTrue);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('un cycle NE contamine PAS le reste : le premier refus fait foi', () {
      // La primitive rend un échec global, jamais une map partielle : une
      // projection à moitié recalculée serait pire que pas de projection.
      final result = _recalculer(const <_Noeud>[
        _Noeud('sain', null),
        _Noeud('a', 'b'),
        _Noeud('b', 'a'),
      ]);
      expect(result.isRight(), isFalse);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('un ensemble vide rend une projection vide, pas un échec', () {
      expect(_droite(_recalculer(const <_Noeud>[])), isEmpty);
    });
  });

  group('La projection recalculée est celle que portent les entités', () {
    test('l\'accesseur `depth` d\'une entité suit `zDepthOf`', () {
      const org = ZStudyOrganization(
        id: 'o2',
        ancestorIds: <String>['root', 'o1'],
      );
      expect(org.depth, equals(zDepthOf(org.ancestorIds)));
      expect(org.depth, equals(2));
      expect(const ZStudyOrganization(id: 'root').depth, equals(0));
    });

    test('recalculer une population d\'entités rend leurs chaînes', () {
      const entites = <ZStudyOrganization>[
        ZStudyOrganization(id: 'root'),
        ZStudyOrganization(id: 'o1', parentId: 'root'),
        ZStudyOrganization(id: 'o2', parentId: 'o1'),
      ];
      final result = _droite(
        zRecomputeAncestorIds<ZStudyOrganization>(
          entites,
          idOf: (ZStudyOrganization e) => e.id,
          parentIdOf: (ZStudyOrganization e) => e.parentId,
        ),
      );
      expect(result['o2'], equals(<String>['root', 'o1']));
    });

    test('la même primitive vaut pour une autre famille de nœuds', () {
      // Généraliser le PROTOCOLE, pas le concept : périodes et organisations
      // n'ont rien à voir, elles se projettent pourtant identiquement.
      const periodes = <ZStudyPeriod>[
        ZStudyPeriod(id: 'annee'),
        ZStudyPeriod(id: 'trim1', parentId: 'annee'),
      ];
      final result = _droite(
        zRecomputeAncestorIds<ZStudyPeriod>(
          periodes,
          idOf: (ZStudyPeriod e) => e.id,
          parentIdOf: (ZStudyPeriod e) => e.parentId,
        ),
      );
      expect(result['trim1'], equals(<String>['annee']));
    });
  });
}

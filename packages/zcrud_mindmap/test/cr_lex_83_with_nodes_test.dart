@TestOn('vm')
library;

// CR-LEX-83 — `ZMindmap` n'offrait AUCUNE voie de remplacement de l'arbre qui
// préserve le reste.
//
// `copyWithPreservingTree` (livré pour CR-LEX-29) reprend `nodes` TEL QUEL :
// elle est inutilisable par un éditeur de carte, qui ne produit rien d'autre
// qu'une nouvelle forêt. L'hôte était donc renvoyé au constructeur nominal,
// c'est-à-dire au geste « champ par champ » que la dartdoc de
// `copyWithPreservingTree` désigne elle-même comme le défaut : mesuré chez
// l'hôte, quatre champs sur sept reconstruits, les trois autres ne survivant
// que par une couche aval qui les relisait.
//
// La classe d'erreur à garder n'est PAS « les 7 champs actuels sont
// préservés » — une garde qui les énumère à la main reproduirait exactement le
// défaut de l'hôte, et se tairait au huitième champ. Les gardes ci-dessous
// sont donc MACHINE : la première compare `toJson()` clé par clé sans jamais
// nommer un champ, la seconde fige la cardinalité de la sortie, la troisième
// lit la SOURCE et confronte les paramètres du constructeur nominal aux
// arguments réellement passés par `withNodes`. Un champ futur oublié rougit.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Carte dont **TOUS** les champs sont renseignés et **distincts des défauts**
/// du constructeur : `title` non vide, `description` non nulle, `extension`
/// non nulle, `extra` non vide, forêt non vide.
///
/// Une garde de préservation bâtie sur une instance par défaut serait inerte :
/// elle ne distinguerait pas « champ préservé » de « champ retombé sur son
/// défaut ».
ZMindmap _carteTousChampsRenseignes() => ZMindmap(
      id: 'm-83',
      folderId: 'f-83',
      title: 'Titre porteur',
      description: 'Description porteuse',
      nodes: <ZMindmapNode>[
        ZMindmapNode(id: 'ancien', label: 'Ancienne racine'),
      ],
      extension: const _ExtensionOpaque(<String, dynamic>{
        'format_version': 3,
        'charge_autre_hote': 'ne doit pas disparaitre',
      }),
      extra: <String, dynamic>{
        'cle_autre_hote': 'valeur',
        'compteur_autre_hote': 42,
      },
    );

/// Nouvelle forêt, telle que la rendrait `ZMindmapTreeOps`.
List<ZMindmapNode> _nouvelleForet() => ZMindmapTreeOps.addChild(
      <ZMindmapNode>[ZMindmapNode(id: 'r1', label: 'R1')],
      'r1',
      ZMindmapNode(id: 'c1', label: 'C1', level: 1),
    );

/// Source de l'entité — support des gardes qui lisent le code réel.
File _sourceZMindmap() {
  final f = File('lib/src/domain/z_mindmap.dart');
  if (!f.existsSync()) {
    fail('source introuvable depuis ${Directory.current.path} : '
        'lancer `flutter test` DEPUIS le dossier du paquet.');
  }
  return f;
}

void main() {
  group('🔴 CR-LEX-83 — `withNodes` remplace la forêt', () {
    test('la forêt rendue est bien la NOUVELLE, dans l\'ordre fourni', () {
      final ZMindmap avant = _carteTousChampsRenseignes();
      final List<ZMindmapNode> foret = _nouvelleForet();

      final ZMindmap apres = avant.withNodes(foret);

      expect(apres.nodes.length, foret.length);
      expect(
        apres.nodes.map((n) => n.id).toList(),
        foret.map((n) => n.id).toList(),
        reason: 'ordre et identité des racines préservés',
      );
      expect(apres.nodes.first.children.map((n) => n.id).toList(),
          foret.first.children.map((n) => n.id).toList(),
          reason: 'la descendance traverse aussi');
      expect(apres.nodes.any((n) => n.id == 'ancien'), isFalse,
          reason: 'l\'ancienne forêt a bien été REMPLACÉE, pas fusionnée');
    });

    test('une forêt VIDE est admise (vider la carte de ses racines)', () {
      final ZMindmap apres =
          _carteTousChampsRenseignes().withNodes(const <ZMindmapNode>[]);
      expect(apres.nodes, isEmpty);
      expect(apres.title, 'Titre porteur',
          reason: 'vider l\'arbre ne vide pas le reste');
    });

    test('la liste rendue est NON-MODIFIABLE, comme par le constructeur', () {
      // Normalisation identique au constructeur nominal : `List.unmodifiable`.
      final ZMindmap parConstructeur = _carteTousChampsRenseignes();
      final ZMindmap parWithNodes =
          parConstructeur.withNodes(<ZMindmapNode>[ZMindmapNode(id: 'r1')]);

      expect(
        () => parConstructeur.nodes.add(ZMindmapNode(id: 'x')),
        throwsUnsupportedError,
        reason: 'référence : le constructeur rend une liste non-modifiable',
      );
      expect(
        () => parWithNodes.nodes.add(ZMindmapNode(id: 'x')),
        throwsUnsupportedError,
        reason: '`withNodes` doit normaliser À L\'IDENTIQUE',
      );
    });

    test('la liste source reste DÉCOUPLÉE (copie défensive)', () {
      final List<ZMindmapNode> source = <ZMindmapNode>[
        ZMindmapNode(id: 'r1'),
      ];
      final ZMindmap apres = _carteTousChampsRenseignes().withNodes(source);
      source.add(ZMindmapNode(id: 'intrus'));

      expect(apres.nodes.length, 1,
          reason: 'muter la liste appelante ne doit pas muter l\'entité');
    });

    test('les `level` ne sont PAS renormalisés (comme le constructeur)', () {
      // `fromJson` renormalise parce qu'elle lit une donnée non fiable ; le
      // constructeur, non. `withNodes` s'aligne sur le CONSTRUCTEUR : elle
      // repose une forêt dont l'appelant assume la cohérence.
      final ZMindmap apres = _carteTousChampsRenseignes()
          .withNodes(<ZMindmapNode>[ZMindmapNode(id: 'r1', level: 7)]);
      expect(apres.nodes.first.level, 7);
    });
  });

  group('🔴 CR-LEX-83 — la préservation est prouvée par la MACHINE', () {
    test('`toJson()` est IDENTIQUE clé par clé, sauf la clé des nœuds', () {
      // Aucun champ n'est nommé ici : c'est ce qui rend la garde survivante à
      // l'ajout d'un huitième champ. Si un champ futur cesse d'être transmis
      // par `withNodes`, sa clé disparaît ou change, et ce test rougit.
      final ZMindmap avant = _carteTousChampsRenseignes();
      final ZMindmap apres = avant.withNodes(_nouvelleForet());

      final Map<String, dynamic> jAvant = avant.toJson();
      final Map<String, dynamic> jApres = apres.toJson();

      expect(jApres.keys.toSet(), jAvant.keys.toSet(),
          reason: 'aucune clé ne doit apparaître ni disparaître');

      const String cleNoeuds = 'nodes';
      for (final String cle in jAvant.keys) {
        if (cle == cleNoeuds) continue;
        expect(jApres[cle], jAvant[cle],
            reason: 'la clé `$cle` doit traverser À L\'IDENTIQUE');
      }
      expect(jApres[cleNoeuds], isNot(jAvant[cleNoeuds]),
          reason: 'la seule différence autorisée est bien survenue');
    });

    test('la CARDINALITÉ de `toJson()` est figée (filet du huitième champ)', () {
      // Six clés du cœur (id, folder_id, title, description, nodes, extension)
      // + deux clés étalées depuis `extra`. Si le cœur gagne un champ
      // sérialisé, ce nombre change : c'est le rappel machine qu'il faut
      // revisiter `withNodes` ET cette garde.
      final ZMindmap carte = _carteTousChampsRenseignes();
      expect(carte.toJson().keys.length, 8);
      expect(carte.withNodes(_nouvelleForet()).toJson().keys.length, 8);
    });

    test('le round-trip JSON après `withNodes` conserve tout', () {
      final ZMindmap apres =
          _carteTousChampsRenseignes().withNodes(_nouvelleForet());
      final ZMindmap relu = ZMindmap.fromJson(apres.toJson());

      expect(relu.toJson(), apres.toJson());
    });

    test(
        'SOURCE — `withNodes` passe TOUS les paramètres du constructeur '
        'nominal', () {
      // La garde `toJson` ne voit que les champs SÉRIALISÉS. Celle-ci voit le
      // contrat de construction lui-même : elle confronte les paramètres
      // nommés du constructeur nominal aux arguments réellement écrits dans le
      // corps de `withNodes`. Un champ futur non transmis rougit ICI même s'il
      // n'atteint jamais `toJson`.
      final String src = _sourceZMindmap().readAsStringSync();

      final Match? ctor = RegExp(
        r'ZMindmap\(\{(.*?)\}\)\s*:',
        dotAll: true,
      ).firstMatch(src);
      expect(ctor, isNotNull,
          reason: 'constructeur nominal `ZMindmap({...}) :` introuvable');

      final Set<String> parametres = RegExp(r'(\w+)\s*(?:=[^,]*)?,')
          .allMatches(ctor!.group(1)!)
          .map((m) => m.group(1)!)
          .where((p) => !const <String>{
                'required',
                'this',
                'const',
                'List',
                'Map',
                'String',
                'dynamic',
                'ZMindmapNode',
              }.contains(p))
          .toSet();
      expect(parametres.length, greaterThanOrEqualTo(7),
          reason: 'extraction des paramètres du constructeur ratée');

      final Match? corps = RegExp(
        r'ZMindmap withNodes\(List<ZMindmapNode> nodes\) \{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(src);
      expect(corps, isNotNull, reason: '`withNodes` introuvable dans la source');

      final Set<String> transmis = RegExp(r'(\w+)\s*:')
          .allMatches(corps!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();

      expect(parametres.difference(transmis), isEmpty,
          reason: 'champs du constructeur NON transmis par `withNodes` — '
              'c\'est exactement la perte silencieuse que la CR corrige');
    });
  });

  group('🔴 CR-LEX-83 — inertie du reste de l\'entité', () {
    test('`copyWithPreservingTree` reprend TOUJOURS l\'arbre tel quel', () {
      final ZMindmap avant = _carteTousChampsRenseignes();
      final ZMindmap apres = avant.copyWithPreservingTree(title: 'Autre');
      expect(apres.nodes.map((n) => n.id).toList(),
          avant.nodes.map((n) => n.id).toList());
      expect(apres.title, 'Autre');
      expect(apres.description, 'Description porteuse');
      expect(apres.extra['cle_autre_hote'], 'valeur');
    });

    test('SOURCE — `copyWithPreservingTree` n\'a PAS gagné de paramètre', () {
      // L'inertie est stricte : la voie ajoutée est `withNodes`, la voie
      // existante n'a pas changé de signature.
      final String src = _sourceZMindmap().readAsStringSync();
      final Match? sig = RegExp(
        r'ZMindmap copyWithPreservingTree\(\{(.*?)\}\)',
        dotAll: true,
      ).firstMatch(src);
      expect(sig, isNotNull);
      expect(sig!.group(1)!.contains('nodes'), isFalse,
          reason: 'la signature existante doit rester inchangée');
    });

    test('SOURCE — la dartdoc publiée ne nomme ni hôte, ni CR, ni version', () {
      final List<String> lignes = _sourceZMindmap().readAsLinesSync();
      final Iterable<String> dartdoc =
          lignes.where((l) => l.trimLeft().startsWith('///'));
      final RegExp interdits = RegExp(
        r'CR-[A-Z]+-\d+|\bv\d+\.\d+\.\d+|lex_douane|lex\b|iffd|dodlp|dlcfti',
        caseSensitive: false,
      );
      final List<String> fautives =
          dartdoc.where((l) => interdits.hasMatch(l)).toList();
      expect(fautives, isEmpty,
          reason: 'la dartdoc est un contrat publié, pas un journal : '
              '${fautives.join(" | ")}');
    });
  });
}

/// Extension opaque d'un appelant tiers : sert à prouver que le slot AD-4
/// traverse `withNodes` sans être touché.
class _ExtensionOpaque implements ZExtension {
  const _ExtensionOpaque(this.payload);

  final Map<String, dynamic> payload;

  @override
  int get formatVersion => payload['format_version'] as int? ?? 0;

  @override
  Map<String, dynamic> toJson() => payload;
}

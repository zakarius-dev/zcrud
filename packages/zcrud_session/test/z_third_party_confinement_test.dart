/// 🎯 AC10 (SU-4) + AC8 (SU-5) — les paquets **TIERS** sont **CONFINÉS à
/// `zcrud_session`** (NFR-SU7, AD-1/AD-8).
///
/// 🔴 **CE TEST EST LE SEUL EXÉCUTEUR DE LA CONTRAINTE.** Vérifié sur disque :
/// `scripts/dev/graph_proof.py` ne contient **aucune** allowlist de dépendance
/// tierce —
/// `grep -n "third\|tiers\|ALLOW\|confin\|syncfusion\|quill\|graphite" scripts/dev/graph_proof.py`
/// → **RC=1**. Le gate ne connaît que les arêtes inter-`zcrud_*` : il ne
/// détectera **JAMAIS** une fuite de `flutter_card_swiper` ni de `confetti` vers
/// un autre package. Sans ce fichier, NFR-SU7 est **déclarative et non tenue**.
///
/// ## 🔴 SU-5 — GÉNÉRALISÉ, jamais DUPLIQUÉ
///
/// su-4 avait livré ici une allowlist **DÉRIVÉE** et une contre-preuve
/// **mutante**, pour un paquet unique (`flutter_card_swiper`). su-5 ajoute
/// `confetti` : recopier ce fichier aurait créé une **garde parallèle**, qui
/// **diverge** avec le temps (leçon E10). Les consts `_pkg`/`_ownerPackage`/
/// `_bannedTypes` sont donc devenues une **TABLE de paquets confinés**
/// ([_confined]), et le fichier a été **renommé**
/// (`z_card_swiper_confinement_test.dart` → `z_third_party_confinement_test.dart`).
/// Un **3ᵉ** paquet tiers ne demandera qu'**une ligne** dans la table.
///
/// ⚠️ `importers hasLength(1)` est désormais **PAR PAQUET** : chacun a **SON**
/// fichier de confinement (le swiper et le confetti n'en partagent aucun).
///
/// ⚠️ **PORTÉE DÉCLARÉE HONNÊTEMENT** (leçon E10 : *« un garde ne prouve QUE ce
/// qu'il scanne »*). Ce test scanne :
///  1. **les `pubspec.yaml` de tous les `packages/*`** — la DÉCLARATION de la
///     dépendance (c'est l'arête de graphe elle-même) ;
///  2. **les sources `lib/**` de `zcrud_session`** — l'import et les signatures
///     publiques.
///
/// Ce qu'il **ne** scanne **pas** : les sources des autres packages. Un package
/// qui importerait le paquet **sans le déclarer** ne serait pas vu ici — mais il
/// ne compilerait pas, et c'est `melos run analyze` **repo-wide** qui le
/// couvre. On ne prétend donc pas prouver plus que ce qui est lu.
///
/// Patron : `zcrud_export/test/isolation_gates_test.dart` — **allowlist DÉRIVÉE
/// dynamiquement** (jamais une liste figée de fichiers), lecture **cwd-robuste**.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un paquet tiers **confiné** : sa contrainte, son fichier unique, ses types.
typedef _ConfinedPackage = ({
  /// Nom du paquet sur pub.dev (= préfixe `package:<name>/`).
  String pkg,

  /// Contrainte de version **ÉPINGLÉE** attendue dans le pubspec.
  String constraint,

  /// **Unique** fichier de `lib/` autorisé à l'importer (suffixe de chemin).
  String owningFile,

  /// Types du paquet qui ne doivent JAMAIS fuiter dans une signature publique.
  List<String> bannedTypes,

  /// Motif de contre-preuve R12 : un type du paquet **dont le nom est CONTENU**
  /// dans un type à NOUS (`CardSwiper` ⊂ `ZSessionCardSwiper`) — la garde doit
  /// distinguer les deux, sinon elle se dénoncerait elle-même.
  String probeType,

  /// Source témoin qui EST une vraie fuite de [probeType].
  String probeLeak,

  /// Source témoin qui n'en est PAS une (notre propre type).
  String probeOwn,
});

/// **TABLE des paquets tiers confinés** — l'unique endroit à éditer (SU-5).
///
/// Contre-métrique PRD de l'epic E-STUDY-UI : **trois** dépendances tierces au
/// total (`flutter_card_swiper`, `confetti`, `printing`) — les deux premières
/// sont ici, et `printing` vit dans `zcrud_export`.
const List<_ConfinedPackage> _confined = <_ConfinedPackage>[
  (
    pkg: 'flutter_card_swiper',
    constraint: '^7.2.0',
    owningFile: 'lib/src/presentation/z_session_card_swiper.dart',
    bannedTypes: <String>[
      'CardSwiper',
      'CardSwiperDirection',
      'CardSwiperController',
      'AllowedSwipeDirection',
      'CardSwiperOnSwipe',
      'NullableCardBuilder',
      'UndoDirection',
      'SwipeType',
    ],
    probeType: 'CardSwiper',
    probeLeak: 'Widget build() => CardSwiper(cardsCount: 1);',
    probeOwn: 'class ZSessionCardSwiper extends StatefulWidget {',
  ),
  (
    pkg: 'confetti',
    constraint: '^0.8.0',
    owningFile: 'lib/src/presentation/z_session_summary_view.dart',
    bannedTypes: <String>[
      'ConfettiWidget',
      'ConfettiController',
      'ConfettiControllerState',
      'BlastDirectionality',
      'ParticleStats',
      'ParticleStatsCallback',
    ],
    probeType: 'ConfettiController',
    probeLeak: 'final ConfettiController c = ConfettiController();',
    // Un type à NOUS dont le nom CONTIENT le leur : sans garde-mot, il se
    // dénoncerait lui-même.
    probeOwn: 'class ZConfettiControllerHolder extends StatelessWidget {',
  ),
];

/// Le SEUL package autorisé à déclarer ces paquets.
const String _ownerPackage = 'zcrud_session';

/// Racine du monorepo — **cwd-robuste** : le test tourne depuis
/// `packages/zcrud_session` (flutter test) ou depuis la racine (CI).
Directory _repoRoot() {
  for (final p in <String>['.', '../..']) {
    if (Directory('$p/packages').existsSync()) return Directory(p);
  }
  fail('racine du monorepo introuvable depuis ${Directory.current.path}');
}

Directory _ownerLib() {
  final root = _repoRoot().path;
  final d = Directory('$root/packages/$_ownerPackage/lib');
  if (!d.existsSync()) fail('lib/ de $_ownerPackage introuvable : ${d.path}');
  return d;
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Retire les commentaires **DART** (`//`, dartdoc) : ils **citent**
/// légitimement le nom du paquet et ses types (le dartdoc du swiper explique
/// tout le confinement).
///
/// 🔴 **NE JAMAIS l'appliquer à un `pubspec.yaml`** — cf. [_stripYamlComments].
String _stripComments(String src) => src
    .split('\n')
    .where((l) {
      final t = l.trim();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .map((l) {
      final i = l.indexOf('//');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// Retire les commentaires **YAML** (`#`) — dé-commentateur du bon LANGAGE.
///
/// 🔴 Défaut MESURÉ (code-review su-5, D2) : `_stripComments` (Dart) était
/// appliqué aux `pubspec.yaml`. Un `pubspec` ne connaît **pas** `//` : le
/// contenu commenté était donc scanné **comme du code**, ce qui rendait cette
/// garde — **la SEULE protection de NFR-SU7**, `graph_proof.py` ne voyant
/// AUCUNE fuite tierce — falsifiable **dans les deux sens** :
///
/// - **faux NÉGATIF** (le plus grave) : contrainte réelle desserrée à
///   `'>=0.8.0 <0.9.0'` + une ligne de doc `# Epingle : confetti: ^0.8.0` ⇒ le
///   test « la version est ÉPINGLÉE » restait **VERT**, satisfait par le SEUL
///   commentaire. Un `confetti 0.9.x` dont l'`assert(duration > 0)` ou le
///   `_continueAnimation` inconditionnel auraient changé passait sans rouge —
///   or ce pubspec porte précisément 20 lignes de prose sur `confetti`.
/// - **faux POSITIF** : une ligne de pure documentation
///   (`# ne jamais declarer confetti: ici`) dans un AUTRE pubspec faisait
///   **ROUGIR** la garde en accusant un package qui ne déclare rien. Leçon E10
///   retournée contre la garde : *une garde qui crie au loup finit désactivée*.
///
/// Le `#` d'un YAML ouvre un commentaire jusqu'à la fin de ligne. Le cas
/// `'#'` **entre quotes** n'existe dans aucun de nos pubspec (et un `#` en
/// valeur citée serait, au pire, tronqué — jamais un faux VERT sur une
/// déclaration, qui s'écrit toujours hors quotes).
String _stripYamlComments(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// Motif d'une **VRAIE déclaration** de dépendance en YAML : `<pkg>:` en début
/// de ligne (indenté sous `dependencies:`), jamais au fil d'une phrase.
///
/// Ancré (`^`/`multiLine`) : `contains('confetti:')` était satisfait par
/// n'importe quelle prose — cf. [_stripYamlComments].
RegExp _yamlDeclares(String pkg) =>
    RegExp('^\\s+${RegExp.escape(pkg)}:', multiLine: true);

/// Motif d'une contrainte **ÉPINGLÉE exactement** : `  <pkg>: ^x.y.z` seul sur
/// sa ligne — un `>=0.8.0 <0.9.0` ne peut plus s'y cacher.
RegExp _yamlPinned(String pkg, String constraint) => RegExp(
      '^\\s+${RegExp.escape(pkg)}:\\s*${RegExp.escape(constraint)}\\s*\$',
      multiLine: true,
    );

/// Motif d'un type **entier** (garde-mot) : `CardSwiper` ne doit pas matcher
/// `ZSessionCardSwiper`, ni `ConfettiController` matcher `MyConfettiController`.
RegExp _wholeType(String type) =>
    RegExp('(?<![A-Za-z0-9_])$type(?![A-Za-z0-9_])');

void main() {
  // 🔒 Contre-preuve R12 de la TABLE elle-même : une table vide (ou amputée)
  // rendrait TOUS les groupes ci-dessous verts sans rien prouver.
  test(
      '🔬 la table des paquets confinés est NON VIDE et couvre les 2 paquets '
      'tiers de l\'epic', () {
    expect(_confined, hasLength(2));
    expect(
      _confined.map((c) => c.pkg).toList(),
      <String>['flutter_card_swiper', 'confetti'],
      reason: '🔴 un paquet retiré de la table cesserait SILENCIEUSEMENT d\'être '
          'gardé — et NFR-SU7 redeviendrait déclarative',
    );
  });

  for (final entry in _confined) {
    final pkg = entry.pkg;

    group('🎯 `$pkg` — DÉCLARATION : un seul `pubspec.yaml` le connaît', () {
      test('🔴 `$pkg` n\'est déclaré QUE par `$_ownerPackage`', () {
        final packagesDir = Directory('${_repoRoot().path}/packages');
        final pubspecs = packagesDir
            .listSync()
            .whereType<Directory>()
            .map((d) => File('${d.path}/pubspec.yaml'))
            .where((f) => f.existsSync())
            .toList();
        // Contre-preuve R12 : un scan qui ne voit rien serait vert à tort.
        expect(pubspecs.length, greaterThan(5),
            reason: 'le scan ne voit que ${pubspecs.length} pubspec — il ne '
                'prouve rien');

        // 🔴 D2 — dé-commentateur YAML (`#`), et motif ANCRÉ : un `pubspec.yaml`
        // ne connaît pas `//`, et une ligne de prose citant le paquet n'est PAS
        // une déclaration.
        final declaring = <String>[
          for (final f in pubspecs)
            if (_yamlDeclares(pkg)
                .hasMatch(_stripYamlComments(f.readAsStringSync())))
              f.parent.path.split(Platform.pathSeparator).last,
        ];

        expect(
          declaring,
          <String>[_ownerPackage],
          reason: '🔴 NFR-SU7/AD-1 : `$pkg` doit être déclaré par le SEUL '
              '`$_ownerPackage`. En particulier JAMAIS par `zcrud_core` (CORE '
              'OUT=0) ni `zcrud_flashcard` (qui rend UNE carte et ignore aussi '
              'bien la pile où elle vit que la fin de session). Trouvé : '
              '$declaring',
        );
      });

      test('la version est ÉPINGLÉE à `${entry.constraint}`', () {
        // 🔴 D2 — dé-commentateur YAML + motif ANCRÉ sur la ligne ENTIÈRE : le
        // `contains('$pkg: ${entry.constraint}')` d'origine était satisfait par
        // un simple commentaire de doc, pendant que la contrainte RÉELLE
        // dérivait (faux négatif MESURÉ par la revue).
        final src = _stripYamlComments(
          File('${_repoRoot().path}/packages/$_ownerPackage/pubspec.yaml')
              .readAsStringSync(),
        );
        expect(_yamlPinned(pkg, entry.constraint).hasMatch(src), isTrue,
            reason: 'la contrainte a changé — les réglages imposés sont adossés '
                'au comportement LU dans cette version (pour `confetti` : '
                '`assert(duration > 0)`, `_continueAnimation` inconditionnel, '
                '`pauseEmissionOnLowFrameRate`) ; un changement doit être '
                'délibéré et re-vérifié');
      });
    });

    group('🎯 `$pkg` — IMPORT : allowlist DÉRIVÉE (jamais figée)', () {
      test('🔴 un SEUL fichier de `lib/` importe `$pkg`', () {
        final importers = <String>[
          for (final f in _dartFiles(_ownerLib()))
            if (_stripComments(f.readAsStringSync()).contains('package:$pkg/'))
              f.path,
        ];

        expect(
          importers,
          hasLength(1),
          reason: '🔴 `$pkg` doit rester confiné à UN fichier '
              '(`${entry.owningFile}`). Importeurs trouvés : $importers',
        );
        expect(
            importers.single.replaceAll(r'\', '/'), endsWith(entry.owningFile));
      });

      test('🔴 le barrel ne l\'importe ni ne le réexporte', () {
        final barrel = _stripComments(
          File('${_ownerLib().path}/$_ownerPackage.dart').readAsStringSync(),
        );
        expect(barrel.contains(pkg), isFalse,
            reason: '🔴 le barrel exposerait `$pkg` à TOUT consommateur de '
                '`$_ownerPackage` — le confinement serait fictif');
      });
    });

    group('🎯 `$pkg` — SIGNATURES : aucun type tiers dans l\'API publique', () {
      test('🔴 aucun type de `$pkg` hors du fichier qui l\'importe', () {
        // Allowlist DÉRIVÉE : les fichiers publics = tous les `.dart` de `lib/`
        // SAUF ceux qui importent le paquet. Jamais une liste figée.
        final all = _dartFiles(_ownerLib()).toList();
        final importers = all
            .where((f) =>
                _stripComments(f.readAsStringSync()).contains('package:$pkg/'))
            .map((f) => f.path)
            .toSet();
        final publicFiles =
            all.where((f) => !importers.contains(f.path)).toList();
        expect(publicFiles, isNotEmpty, reason: 'aucun fichier public scanné');

        final violations = <String>[];
        for (final f in publicFiles) {
          final src = _stripComments(f.readAsStringSync());
          for (final type in entry.bannedTypes) {
            // Garde-mot : ne pas confondre `CardSwiper` et `ZSessionCardSwiper`
            // (notre propre type, dont le nom CONTIENT le leur).
            if (_wholeType(type).hasMatch(src)) {
              violations.add('${f.path} → $type');
            }
          }
        }
        expect(
          violations,
          isEmpty,
          reason: '🔴 un type `$pkg` a fui hors de son fichier de '
              'confinement :\n${violations.join('\n')}',
        );
      });

      test(
          '🔬 contre-preuve R12 — la règle de signature SAIT rougir, et ne '
          'confond pas NOTRE type avec `${entry.probeType}`', () {
        final re = _wholeType(entry.probeType);
        // Le VRAI motif, exercé sur des sources témoins.
        expect(re.hasMatch(entry.probeLeak), isTrue,
            reason: 'une VRAIE fuite doit être vue');
        expect(
          re.hasMatch(entry.probeOwn),
          isFalse,
          reason: '🔴 sans le garde-mot, NOTRE type se dénoncerait lui-même et '
              'la garde serait désactivée sous les faux positifs',
        );
      });
    });
  }

  // 🔒 Contre-preuve R12 du dé-commentateur YAML (D2) — les DEUX mutations que
  // la revue a PROUVÉES doivent désormais rendre le BON verdict. Sans ce groupe,
  // le correctif serait lui-même décoratif : rien ne prouverait que la garde a
  // cessé d'être falsifiable par un commentaire.
  group('🔬 contre-preuve R12 — la garde YAML n\'est PAS falsifiable par un '
      'COMMENTAIRE (D2)', () {
    // Le pubspec témoin reproduit le terrain RÉEL : `zcrud_session/pubspec.yaml`
    // porte ~20 lignes de prose sur `confetti`, dont des lignes qui CITENT la
    // contrainte.
    const falsifiedPubspec = '''
name: zcrud_session
dependencies:
  # Epingle : confetti: ^0.8.0   <- prose qui CITE la contrainte
  confetti: '>=0.8.0 <0.9.0'
''';
    const documentingPubspec = '''
name: zcrud_flashcard
dependencies:
  # NOTE: ne jamais declarer confetti: ici (confine a zcrud_session).
  flutter:
    sdk: flutter
''';

    test(
        '🔴 faux NÉGATIF fermé — une contrainte DESSERRÉE ne peut plus se cacher '
        'derrière un commentaire qui cite l\'épinglage', () {
      final stripped = _stripYamlComments(falsifiedPubspec);
      // Le motif d'ORIGINE (`contains`) était satisfait par le seul commentaire.
      expect(falsifiedPubspec.contains('confetti: ^0.8.0'), isTrue,
          reason: 'témoin : c\'est bien le piège que la garde d\'origine ratait');
      // Le motif ANCRÉ, sur la source dé-commentée, voit la RÉALITÉ.
      expect(
        _yamlPinned('confetti', '^0.8.0').hasMatch(stripped),
        isFalse,
        reason: '🔴 la contrainte RÉELLE est `>=0.8.0 <0.9.0` : la garde DOIT '
            'rougir. Si elle reste verte, NFR-SU7 est de nouveau désarmée et un '
            '`confetti 0.9.x` (assert/`_continueAnimation` changés) passerait.',
      );
      // …et le pubspec RÉEL, lui, reste bien vu comme épinglé (pas de faux
      // positif du correctif lui-même).
      expect(
        _yamlPinned('confetti', '^0.8.0')
            .hasMatch(_stripYamlComments('dependencies:\n  confetti: ^0.8.0\n')),
        isTrue,
      );
    });

    test(
        '🔴 faux POSITIF fermé — une ligne de pure DOCUMENTATION ne déclare rien',
        () {
      expect(
        _yamlDeclares('confetti')
            .hasMatch(_stripYamlComments(documentingPubspec)),
        isFalse,
        reason: '🔴 accuser `zcrud_flashcard` de déclarer `confetti` sur un '
            'COMMENTAIRE est un diagnostic FAUX — et une garde qui crie au loup '
            'finit désactivée (leçon E10).',
      );
      // Contre-preuve de la contre-preuve : une VRAIE déclaration est bien vue.
      expect(
        _yamlDeclares('confetti')
            .hasMatch(_stripYamlComments('dependencies:\n  confetti: ^0.8.0\n')),
        isTrue,
        reason: 'une vraie déclaration DOIT être vue — sinon la garde est morte',
      );
    });

    test('🔬 `_stripYamlComments` retire bien `#` (et NON `//`, qui n\'existe '
        'pas en YAML)', () {
      expect(_stripYamlComments('  confetti: ^0.8.0  # commentaire').trim(),
          'confetti: ^0.8.0');
      expect(_stripYamlComments('# tout le contenu est commente').trim(), '');
    });
  });

  group('🔬 contre-preuve R12 — le garde-mot distingue les types VOISINS', () {
    test(
        '`CardSwiper` ne matche pas `CardSwiperController` (autre motif de la '
        'liste)', () {
      expect(_wholeType('CardSwiper').hasMatch('final CardSwiperController c;'),
          isFalse);
    });

    test('`ConfettiController` ne matche pas `ConfettiControllerState`', () {
      expect(
        _wholeType('ConfettiController')
            .hasMatch('ConfettiControllerState get state => _state;'),
        isFalse,
        reason: 'les deux sont bannis SÉPARÉMENT — les confondre rendrait les '
            'diagnostics faux',
      );
    });
  });
}

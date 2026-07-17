/// Garde de SOURCE UNIQUE de l'échelle de qualité (SU-1, AC2 — AD-46).
///
/// L'epic exige mot pour mot : « **un test échoue si une seconde source
/// d'échelle réapparaît** ». Les bornes `0..5` sont **possédées par
/// `ZSrsConfig`** (`minQuality`/`maxQuality`, `zcrud_flashcard`) ;
/// `ZQualityScale` en **DÉRIVE** (`fromConfig`). Ce test **lit la source** des
/// fichiers de [_scannedSources] et ROUGIT si un littéral de borne (`= 5`, `= 0`,
/// `max == 5`, `min == 0`…) réapparaît dans le **CODE** de la déclaration
/// d'échelle — c'est-à-dire si quelqu'un redéclare l'échelle au lieu de la dériver.
///
/// ## 🔴 SU-5 (D4) — la PORTÉE a été étendue, jamais dupliquée
///
/// Défaut MESURÉ par le code-review su-5 : `z_session_summary_view.dart` et
/// `z_session_feedback.dart` **CITAIENT cette garde** dans leur dartdoc
/// (« jamais le littéral `4` ; `z_quality_scale_single_source_test.dart` rougit
/// sur un littéral de borne ») alors qu'elle n'ouvrait **qu'un seul fichier en
/// dur** — `z_srs_quality_buttons.dart` (grep RC=1). La garde citée était un
/// **FANTÔME** pour ces deux fichiers.
///
/// Ça n'était pas cosmétique : `maxQuality` est **épinglé à 5** par `assert`
/// (`z_srs_config.dart`), donc écrire `masteredThreshold ?? 4` est
/// **strictement ISO-COMPORTEMENTAL** ⇒ toute la suite resterait **VERTE**, et
/// la citation du dartdoc rassurerait le reviewer suivant. C'est la **régression
/// exacte qui a produit le HIGH de su-1** (borne en dur réintroduite), redevenue
/// possible **sans filet**.
///
/// La portée est donc **étendue** (une LISTE de sources + les motifs du seuil de
/// maîtrise), **jamais** recopiée dans une garde parallèle qui divergerait
/// (leçon E10).
///
/// ## 🔴 SU-6 (D1/D2) — la PORTÉE de cette garde, déclarée SANS complaisance
///
/// Il existe **deux** gardes de seuil, une par package, et le code-review su-6 a
/// mesuré qu'elles se **contredisaient** en se déclarant « le même critère ».
/// Portées et mécaniques réelles :
///
/// | | Garde A — `zcrud_flashcard/test/z_mastered_threshold_single_source_test.dart` | Garde B — **ce fichier** (`zcrud_session`) |
/// |---|---|---|
/// | Périmètre | `lib/**` **récursif, auto-énumérant** | **liste FIGÉE** de 3 fichiers ([_scannedSources]) |
/// | Mécanique | recollage **par déclaration** (immunisé au wrap `dart format`) | **ligne à ligne** |
/// | `masteredThreshold ?? <littéral>` | interdit | interdit |
/// | `maxQuality - 1` / `scale.max - 1` hors propriétaire | interdit | **interdit depuis su-6/D1** |
///
/// ⇒ Sur **les motifs**, le critère est bien le même (c'est vérifiable :
/// les régex sont identiques). Sur le **périmètre** et la **mécanique**, elles
/// diffèrent, et cette différence est **assumée** : `Directory` est relatif au
/// package qui exécute le test, aucune ne peut lire l'autre (un chemin
/// `../zcrud_flashcard/...` casserait selon le cwd). Ce ne sont donc pas des
/// gardes parallèles (aucune ne duplique le travail de l'autre) — ce sont **deux
/// faces disjointes du même critère**.
///
/// ⚠️ **Angle mort DÉCLARÉ de cette face** : le scan étant ligne à ligne, une
/// redéclaration **coupée par `dart format`** sur plusieurs lignes lui
/// échapperait ; et un fichier de `zcrud_session/lib/**` **absent** de
/// [_scannedSources] n'est **pas** couvert. Tout fichier qui CITE cette garde
/// DOIT donc figurer dans la liste — c'est ce que verrouille la première
/// contre-preuve ci-dessous.
///
/// Une seconde source divergerait **silencieusement** du domaine : l'UI
/// afficherait des crans que le scheduler ne reconnaîtrait pas, sans erreur ni
/// test rouge ailleurs. D'où cette garde structurelle (INJ R3-I2).
///
/// ⚠️ Scan **hors dartdoc/commentaires** (patron `z_linear_no_srs_test.dart`) :
/// la prose DOIT pouvoir nommer l'échelle (« échelle SM-2 `0..5` ») sans
/// faux-positiver ; on interdit le littéral dans le CODE, pas le mot dans la doc.
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Motifs de **redéclaration d'échelle** interdits dans le code (AC2).
///
/// Chacun correspond à la forme AVANT SU-1 (`const ZQualityScale({this.min = 0,
/// this.max = 5}) : assert(min == 0 || min == 1), assert(max == 5)`) : leur
/// réapparition prouverait une seconde source de vérité.
const List<_ScalePattern> _bannedScaleLiterals = <_ScalePattern>[
  _ScalePattern('min = 0', 'défaut de borne basse en dur'),
  _ScalePattern('min = 1', 'défaut de borne basse en dur'),
  _ScalePattern('max = 5', 'défaut de borne haute en dur'),
  _ScalePattern('min == 0', 'assert de borne basse en dur'),
  _ScalePattern('min == 1', 'assert de borne basse en dur'),
  _ScalePattern('max == 5', 'assert de borne haute en dur'),
  _ScalePattern('this.min =', 'formal initialisant une borne littérale'),
  _ScalePattern('this.max =', 'formal initialisant une borne littérale'),
  // 🔴 SU-5/D4 — le seuil de maîtrise DOIT être CONSOMMÉ depuis son
  // propriétaire. Un `?? 4` est iso-comportemental tant que `maxQuality` vaut
  // 5 : SEULE une garde de source peut le voir. Motif RÉGEX ancré sur
  // l'identifiant, pour ne PAS faux-positiver sur le `?? 0` légitime d'un
  // compteur (`byQuality['$quality'] ?? 0`).
  _ScalePattern.regex(
    'masteredThreshold ?? <littéral>',
    'seuil de maîtrise en dur (doit être CONSOMMÉ depuis '
        '`ZSrsConfig.masteredThreshold` — AD-46)',
    r'masteredThreshold\s*\?\?\s*-?\d',
  ),
  // 🔴 SU-6/D2 — la RE-DÉRIVATION du seuil (`scale.max - 1`, `maxQuality - 1`).
  //
  // Ces deux motifs sont ceux de `zcrud_flashcard/test/
  // z_mastered_threshold_single_source_test.dart` : c'est **délibérément le
  // MÊME critère**, appliqué à l'autre package (cf. la note de portée en tête).
  //
  // Le code-review su-6 (D1) a mesuré que ce fichier **bénissait** encore
  // `?? scale.max - 1` (il figurait dans la liste `legitimate` d'une
  // contre-preuve, verrouillé `isEmpty`) alors que su-6/D2 avait **promu** le
  // seuil dans `ZSrsConfig.masteredThreshold` et **REFUSÉ par écrit** de le
  // re-dériver ailleurs. Les deux gardes rendaient donc des verdicts OPPOSÉS sur
  // la même forme, en se déclarant « le même critère » : la face `zcrud_session`
  // était verrouillée à ACCEPTER la seconde source que l'autre face interdisait
  // — et corriger l'une aurait cassé la contre-preuve de l'autre. Deux gardes
  // qui se neutralisent sont pires qu'aucune garde : elles rassurent.
  _ScalePattern.regex(
    'scale.max - 1',
    'dérivation du seuil RECOPIÉE depuis l\'échelle : consommer '
        '`ZSrsConfig.masteredThreshold` (AD-46, su-6/D2)',
    r'\bmax\s*-\s*1\b',
  ),
  _ScalePattern.regex(
    'maxQuality - 1',
    'dérivation du seuil RECOPIÉE hors de son propriétaire (AD-46)',
    r'maxQuality\s*-\s*1\b',
  ),
];

/// Motif interdit + raison lisible dans le message d'échec.
///
/// Deux formes : littérale ([_ScalePattern]) ou **régex** ([_ScalePattern.regex])
/// quand le motif doit être ancré sur un identifiant pour éviter les faux
/// positifs.
class _ScalePattern {
  const _ScalePattern(this.pattern, this.why) : _regexSource = null;

  const _ScalePattern.regex(this.pattern, this.why, String regexSource)
      : _regexSource = regexSource;

  /// Forme lisible du motif (message d'échec).
  final String pattern;
  final String why;

  /// Source de la régex, ou `null` ⇒ recherche littérale (`RegExp` n'est pas
  /// `const` : elle est construite à l'usage).
  final String? _regexSource;

  /// La ligne viole-t-elle ce motif ?
  bool matches(String line) {
    final source = _regexSource;
    return source == null
        ? line.contains(pattern)
        : RegExp(source).hasMatch(line);
  }
}

/// **Sources scannées** par la garde (D4) — l'unique endroit à éditer.
///
/// Les trois fichiers qui DÉRIVENT l'échelle ou le seuil de maîtrise. Tout
/// fichier qui CITE cette garde dans son dartdoc DOIT figurer ici — sinon la
/// citation est un fantôme.
const List<String> _scannedSources = <String>[
  'lib/src/presentation/z_srs_quality_buttons.dart',
  'lib/src/presentation/z_session_summary_view.dart',
  'lib/src/domain/z_session_feedback.dart',
];

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Exercé À LA FOIS par la garde (sur le code de prod) et par sa contre-preuve
/// (sur une source artificielle) : sans ce partage, la contre-preuve
/// recopierait la boucle et resterait verte alors même que le scan réel
/// deviendrait aveugle — elle prouverait le pouvoir des MOTIFS, jamais celui du
/// SCANNER.
List<String> scanForScaleLiterals(List<String> lines, String path) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // dartdoc/commentaire — la prose peut nommer l'échelle
    }
    for (final banned in _bannedScaleLiterals) {
      if (banned.matches(raw)) {
        violations.add('$path:${i + 1} → « ${banned.pattern} » '
            '(${banned.why}) dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

void main() {
  // 🔒 Contre-preuve R12 de la LISTE elle-même (D4) : une liste amputée rendrait
  // la garde verte en silence, exactement comme le fichier unique en dur qu'elle
  // remplace.
  test('🔬 la liste des sources scannées couvre les 3 fichiers qui DÉRIVENT '
      'l\'échelle ou le seuil (D4)', () {
    expect(_scannedSources, hasLength(3));
    expect(
      _scannedSources,
      containsAll(<String>[
        'lib/src/presentation/z_session_summary_view.dart',
        'lib/src/domain/z_session_feedback.dart',
      ]),
      reason: '🔴 ces deux fichiers CITENT cette garde dans leur dartdoc : '
          'l\'en retirer rendrait la citation FANTÔME et rouvrirait la '
          'régression du HIGH de su-1 (borne en dur) sans filet',
    );
  });

  for (final path in _scannedSources) {
    test(
      'AC2 — $path ne REDÉCLARE aucune borne d\'échelle ni de seuil '
      '(source unique : ZSrsConfig, AD-46)',
      () {
        final source = File(path);
        expect(source.existsSync(), isTrue,
            reason: 'source introuvable (cwd = ${Directory.current.path})');

        final lines = source.readAsLinesSync();
        // Contre-preuve R12 : le scan DOIT réellement voir du contenu — un scan
        // à vide passerait sinon en silence.
        expect(lines, isNotEmpty, reason: 'source vide — rien scanné');

        final violations = scanForScaleLiterals(lines, source.path);

        expect(
          violations,
          isEmpty,
          reason: 'SECONDE SOURCE D\'ÉCHELLE détectée : les bornes sont '
              'possédées par `ZSrsConfig.minQuality`/`maxQuality` et DOIVENT '
              'être dérivées via `ZQualityScale.fromConfig` ; le seuil de '
              'maîtrise DOIT être CONSOMMÉ depuis `ZSrsConfig.masteredThreshold` '
              '(son propriétaire AD-46 — su-6/D2), jamais re-dérivé ici '
              '(`scale.max - 1`) ni écrit en dur (`?? 4`). Une borne redéclarée '
              'ici divergerait silencieusement du domaine — et resterait VERTE '
              'tant que `maxQuality` vaut 5 :\n'
              '${violations.join('\n')}',
        );
      },
    );
  }

  test(
    'AC2 — la garde a bien du pouvoir : le SCANNER RÉEL détecte un littéral de '
    'borne (contre-preuve du scanner lui-même, pas d\'une copie)',
    () {
      // Prouve que le scanner N'EST PAS tautologique : sur une source
      // ARTIFICIELLE contenant la forme d'avant SU-1, `scanForScaleLiterals` —
      // la fonction que la garde ci-dessus exécute RÉELLEMENT — DOIT lever des
      // violations. Sans ceci, un scanner cassé (motifs jamais trouvés)
      // passerait vert pour toujours.
      const injected = <String>[
        '/// max = 5 en dartdoc — NE DOIT PAS être détecté (prose légitime)',
        'const ZQualityScale({this.min = 0, this.max = 5})',
        '    : assert(max == 5);',
      ];

      final violations = scanForScaleLiterals(injected, 'artificiel.dart');

      expect(violations, isNotEmpty,
          reason: 'le scanner ne détecte plus la forme redéclarée — garde morte');
      expect(violations.any((v) => v.startsWith('artificiel.dart:2')), isTrue,
          reason: 'la redéclaration des bornes par défaut n\'est plus détectée');
      expect(violations.any((v) => v.startsWith('artificiel.dart:3')), isTrue,
          reason: 'l\'assert de borne en dur n\'est plus détecté');
      // Et la prose de dartdoc reste bien ignorée (pas de faux positif L1).
      expect(violations.any((v) => v.startsWith('artificiel.dart:1')), isFalse,
          reason: 'faux positif sur du dartdoc — la prose doit rester libre');
    },
  );

  test(
    'AC2/D4 — le SCANNER RÉEL détecte le SEUIL DE MAÎTRISE en dur '
    '(`?? 4`), qui est ISO-COMPORTEMENTAL tant que maxQuality == 5',
    () {
      // 🔴 LA régression que D4 nomme : `scale.max - 1` « simplifié » en `4`.
      // Aucun test de comportement ne peut la voir (maxQuality est épinglé à 5)
      // — seule cette garde de source le peut.
      const injected = <String>[
        '/// défaut DÉRIVÉ `scale.max - 1`, jamais le littéral `4` — prose OK',
        '    final masteredThreshold = widget.masteredThreshold ?? 4;',
      ];

      final violations = scanForScaleLiterals(injected, 'artificiel.dart');

      expect(violations.any((v) => v.startsWith('artificiel.dart:2')), isTrue,
          reason: '🔴 le seuil de maîtrise en dur n\'est plus détecté : la '
              'dérivation AD-46 des fichiers su-5 n\'est de nouveau gardée par '
              'RIEN');
      expect(violations.any((v) => v.startsWith('artificiel.dart:1')), isFalse,
          reason: 'la prose doit pouvoir citer le littéral qu\'elle interdit');
    },
  );

  test(
    'AC2/D4 — contre-preuve du motif : le `?? 0` légitime d\'un COMPTEUR n\'est '
    'PAS un littéral de borne (pas de faux positif)',
    () {
      // Une garde qui crie au loup finit désactivée (E10) : `zMasteredCount`
      // lit `byQuality['$quality'] ?? 0` — un défaut de COMPTE, jamais une
      // borne. Et la forme SANCTIONNÉE réelle doit évidemment rester verte.
      //
      // 🔴 su-6/D1 : cette liste portait `?? scale.max - 1` et la verrouillait
      // VERTE (`isEmpty`) — c'est-à-dire qu'elle **exigeait** de la garde
      // qu'elle laisse passer la seconde source que su-6/D2 déclare avoir
      // REFUSÉE. La forme correcte est de CONSOMMER le propriétaire.
      const legitimate = <String>[
        "    count += byQuality['\$quality'] ?? 0;",
        '    final masteredThreshold =',
        '        widget.masteredThreshold ?? widget.config.masteredThreshold;',
        // Un `length - 1` d'index n'est PAS un seuil de maîtrise.
        '    final last = items.length - 1;',
      ];

      expect(scanForScaleLiterals(legitimate, 'artificiel.dart'), isEmpty,
          reason: '🔴 faux positif : la garde accuserait le code CORRECT');
    },
  );

  test(
    'AC9/su-6-D1 — le SCANNER RÉEL détecte la RE-DÉRIVATION du seuil '
    '(`?? scale.max - 1`), elle aussi ISO-COMPORTEMENTALE',
    () {
      // 🔴 LE scénario mesuré par le code-review su-6 (D1). `scale` EST en scope
      // dans `z_session_summary_view.dart.build` (`ZQualityScale.fromConfig`) :
      // la forme ci-dessous est écrivable telle quelle, à la place du
      // `?? widget.config.masteredThreshold` actuel.
      //
      // Elle recrée la SECONDE SOURCE que su-6/D2 a refusée — et comme
      // `maxQuality` est épinglé à 5, `scale.max - 1 == config.masteredThreshold
      // == 4` : AUCUN test de comportement ne peut rougir (les 26 tests de
      // `z_session_summary_view_test.dart` restent verts, mesuré en su-5).
      // Cette garde est donc la SEULE qui puisse la voir sur `zcrud_session`.
      const injected = <String>[
        '/// le seuil DÉRIVE de `scale.max - 1` — prose, NE DOIT PAS rougir',
        '    final masteredThreshold = widget.masteredThreshold ?? scale.max - 1;',
        '    final t = config.maxQuality - 1;',
      ];

      final violations = scanForScaleLiterals(injected, 'artificiel.dart');

      expect(violations.any((v) => v.startsWith('artificiel.dart:2')), isTrue,
          reason: '🔴 la re-dérivation du seuil depuis l\'échelle n\'est plus '
              'détectée : `zcrud_session` peut de nouveau redéclarer le seuil '
              'que `ZSrsConfig` possède (AD-46), sans qu\'aucun test ne rougisse');
      expect(violations.any((v) => v.startsWith('artificiel.dart:3')), isTrue,
          reason: '🔴 la dérivation recopiée (`maxQuality - 1`) n\'est plus '
              'détectée');
      expect(violations.any((v) => v.startsWith('artificiel.dart:1')), isFalse,
          reason: 'la prose doit pouvoir citer le motif qu\'elle interdit');
    },
  );
}

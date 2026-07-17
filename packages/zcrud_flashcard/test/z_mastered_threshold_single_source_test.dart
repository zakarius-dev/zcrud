/// Garde de SOURCE UNIQUE du **seuil de maîtrise** (SU-6, AC9 — AD-46, D2).
///
/// ## Pourquoi cette garde existe (et pourquoi AUCUN test de comportement ne
/// peut la remplacer)
///
/// Le seuil de maîtrise est **dérivé** : `ZSrsConfig.masteredThreshold =>
/// maxQuality - 1` (⇒ q4-5). Or `maxQuality` est **épinglé à `5`** par un
/// `assert` de `ZSrsConfig`. Donc écrire le littéral `4` — ou re-dériver
/// `maxQuality - 1` — ailleurs est **STRICTEMENT ISO-COMPORTEMENTAL** : la
/// seconde source rendrait **exactement** la même valeur, **toute la suite
/// resterait VERTE**, et le prochain reviewer lirait un dartdoc rassurant. C'est
/// **littéralement le HIGH de su-1** (borne en dur réintroduite), et su-5 a
/// documenté le mécanisme en détail.
///
/// ⇒ **Seule** une garde **structurelle** (qui lit les SOURCES) peut l'attraper.
///
/// ## Portée déclarée HONNÊTEMENT — et pourquoi elle est ICI
///
/// Cette garde (**Garde A**) couvre `zcrud_flashcard/lib/**` — le package
/// **propriétaire** du seuil (AD-46). Elle **ne prétend pas** couvrir
/// `zcrud_session` : `Directory` est relatif au package qui exécute le test, et
/// un chemin `../zcrud_session/...` casserait selon le cwd. La face
/// `zcrud_session` est gardée par `z_quality_scale_single_source_test.dart`
/// (**Garde B**).
///
/// ### 🔴 Ce que la version précédente de ce dartdoc affirmait — et qui était FAUX
///
/// Elle écrivait : « les deux gardes ont des portées disjointes **et le même
/// critère**. Aucune ne duplique l'autre. » Le code-review su-6 (D1) l'a
/// **réfuté sur disque** : Garde B **bénissait** `?? scale.max - 1` (motif
/// présent dans sa liste `legitimate`, **verrouillé `isEmpty`**) alors que la
/// ligne `:60` ci-dessous l'**interdit**. Les deux gardes rendaient donc des
/// verdicts **OPPOSÉS** sur la même forme — et écrire `?? scale.max - 1` dans
/// `z_session_summary_view.dart` (où `scale` est en scope) recréait la seconde
/// source que su-6/D2 déclare avoir refusée, avec **Garde B verte** (sa
/// contre-preuve l'exigeait), **Garde A aveugle** (autre package) et **zéro test
/// de comportement rouge** (iso-comportemental).
///
/// Une prose qui clôt l'enquête (« aucune ne duplique l'autre ») **arme** le
/// prochain défaut. Le critère est désormais réellement aligné (Garde B interdit
/// `max - 1`/`maxQuality - 1` depuis su-6/D1) — et les portées sont déclarées
/// **telles qu'elles sont**, différences comprises :
///
/// | | **Garde A** (ce fichier) | **Garde B** (`zcrud_session`) |
/// |---|---|---|
/// | Périmètre | `lib/**` **récursif, auto-énumérant** | **liste FIGÉE** de 3 fichiers |
/// | Mécanique | recollage **par déclaration** (immunisé au wrap `dart format`) | **ligne à ligne** (angle mort déclaré chez elle) |
/// | Motifs interdits | les 4 ci-dessous | **les mêmes** régex de seuil |
///
/// ⇒ **Ce n'est PAS une garde parallèle** (leçon E10) : les périmètres sont
/// **disjoints** — aucune ne peut lire les fichiers de l'autre, donc aucune ne
/// duplique le travail de l'autre. Ce sont **deux faces du même critère**, et
/// c'est vérifiable : les régex de seuil sont identiques des deux côtés.
///
/// ## AUTO-ÉNUMÉRANTE — tout nouveau fichier naît gardé (R16)
///
/// Le scan est **récursif** sur `lib/**` : les filtres FR-SU12 de su-6
/// (`z_flashcard_filters.dart`) et tout futur fichier sont captés **sans édition
/// de ce test**. Une liste figée aurait exactement le défaut FANTÔME que su-5 a
/// mesuré.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// **Le PROPRIÉTAIRE** du seuil — le seul fichier autorisé à le dériver (AD-46).
const String _ownerFile = 'lib/src/domain/z_srs_config.dart';

/// Motifs de **redéclaration du seuil de maîtrise** interdits hors [_ownerFile].
///
/// Chacun correspond à une forme RÉELLE de la régression :
/// - `maxQuality - 1` / `scale.max - 1` : la dérivation **recopiée** ailleurs ;
/// - `masteredThreshold ?? <littéral>` / `masteredThreshold = <littéral>` : le
///   seuil **en dur**, la forme exacte que su-5/D4 nomme.
final List<_ThresholdPattern> _bannedThresholdSources = <_ThresholdPattern>[
  _ThresholdPattern(
    'maxQuality - 1',
    'dérivation du seuil RECOPIÉE hors de son propriétaire (AD-46)',
    RegExp(r'maxQuality\s*-\s*1\b'),
  ),
  _ThresholdPattern(
    'scale.max - 1',
    'dérivation du seuil RECOPIÉE depuis l\'échelle (AD-46)',
    RegExp(r'\bmax\s*-\s*1\b'),
  ),
  _ThresholdPattern(
    'masteredThreshold ?? <littéral>',
    'seuil de maîtrise EN DUR (doit DÉRIVER de maxQuality — AD-46)',
    RegExp(r'masteredThreshold\s*\?\?\s*-?\d'),
  ),
  _ThresholdPattern(
    'masteredThreshold = <littéral>',
    'seuil de maîtrise EN DUR (doit DÉRIVER de maxQuality — AD-46)',
    RegExp(r'masteredThreshold\s*=\s*-?\d'),
  ),
];

/// Motif interdit + raison lisible dans le message d'échec.
class _ThresholdPattern {
  const _ThresholdPattern(this.pattern, this.why, this.regex);

  /// Forme lisible du motif (message d'échec).
  final String pattern;

  /// Pourquoi c'est un défaut.
  final String why;

  /// Régex ANCRÉE (jamais un `contains` nu : `- 1` faux-positiverait partout).
  final RegExp regex;

  /// La déclaration viole-t-elle ce motif ?
  bool matches(String text) => regex.hasMatch(text);
}

/// Énumère RÉCURSIVEMENT les `.dart` de `lib/**`, **hors code généré** et hors
/// [_ownerFile].
///
/// Les `*.g.dart` sont exclus : ils sont produits par le générateur (jamais
/// écrits à la main) et ne peuvent pas redéclarer un seuil métier.
List<String> _scannedFiles() {
  final dir = Directory('lib');
  expect(
    dir.existsSync(),
    isTrue,
    reason: 'répertoire lib/ introuvable (cwd = ${Directory.current.path})',
  );
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.dart'))
      .where((p) => !p.endsWith('.g.dart'))
      .where((p) => p != _ownerFile)
      .toList()
    ..sort();
}

/// Recolle les **déclarations** d'un source Dart (patron EXACT de
/// `z_widgets_purity_test.dart` / `z_widgets_hardcode_scan_test.dart`).
///
/// 🔴 **Indispensable** : `dart format` wrappe à 80 colonnes, et
/// `masteredThreshold ??\n    4` ne porte le motif sur **aucune ligne**. Un scan
/// ligne-à-ligne serait **structurellement aveugle** à la forme naturelle du
/// formateur — c'est le défaut D4 mesuré en su-3.
///
/// Les lignes de **commentaire/dartdoc** sont écartées : la prose DOIT pouvoir
/// nommer le motif qu'elle interdit (ce fichier-ci en est la preuve vivante).
List<({int line, String text})> _declarations(String path) {
  final lines = File(path).readAsLinesSync();
  final out = <({int line, String text})>[];
  final buffer = StringBuffer();
  var startLine = 0;
  var inBlockComment = false;

  void flush() {
    if (buffer.isNotEmpty) {
      out.add((line: startLine, text: buffer.toString()));
      buffer.clear();
    }
  }

  for (var i = 0; i < lines.length; i++) {
    var trimmed = lines[i].trim();

    if (inBlockComment) {
      if (trimmed.contains('*/')) {
        inBlockComment = false;
        trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
      } else {
        continue;
      }
    }
    if (trimmed.startsWith('/*')) {
      if (!trimmed.contains('*/')) {
        inBlockComment = true;
        continue;
      }
      trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
    }
    if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
    final slash = trimmed.indexOf('//');
    if (slash >= 0) trimmed = trimmed.substring(0, slash).trim();
    if (trimmed.isEmpty) continue;

    if (buffer.isEmpty) startLine = i + 1;
    // Recollage SANS espace (patron des gardes existantes).
    buffer.write(trimmed);

    if (trimmed.endsWith(';') || trimmed.endsWith('{') || trimmed.endsWith('}')) {
      flush();
    }
  }
  flush();
  return out;
}

/// **Le SCANNER RÉEL** — l'unique implémentation, exercée À LA FOIS par la garde
/// (sur le code de prod) et par ses contre-preuves (sur des sources
/// artificielles).
///
/// Sans ce partage, une contre-preuve recopierait la boucle et resterait verte
/// alors même que le scan réel deviendrait aveugle : elle prouverait le pouvoir
/// des MOTIFS, jamais celui du SCANNER (leçon D6 de su-3).
List<String> scanForThresholdSources(List<({int line, String text})> declarations,
    String path) {
  final violations = <String>[];
  for (final decl in declarations) {
    for (final banned in _bannedThresholdSources) {
      if (banned.matches(decl.text)) {
        violations.add('$path:${decl.line} → « ${banned.pattern} » '
            '(${banned.why}) dans « ${decl.text} »');
      }
    }
  }
  return violations;
}

void main() {
  group('AC9 — le seuil de maîtrise a UNE SEULE source (ZSrsConfig, AD-46)', () {
    test('🔬 méta-garde : le PROPRIÉTAIRE existe et dérive RÉELLEMENT le seuil',
        () {
      // Si le propriétaire cessait de dériver (ou disparaissait), la garde
      // ci-dessous resterait verte en interdisant… plus rien.
      final owner = File(_ownerFile);
      expect(owner.existsSync(), isTrue,
          reason: 'propriétaire introuvable (cwd = ${Directory.current.path})');

      final source = owner.readAsStringSync();
      expect(
        source.contains('int get masteredThreshold => maxQuality - 1;'),
        isTrue,
        reason: '🔴 `ZSrsConfig.masteredThreshold` ne DÉRIVE plus de `maxQuality` '
            '— la source unique du seuil a disparu (AD-46/D2)',
      );
    });

    test('🔬 méta-garde : le scan voit RÉELLEMENT des fichiers (jamais vert à '
        'vide)', () {
      final files = _scannedFiles();
      expect(files, isNotEmpty, reason: 'aucun fichier scanné — garde morte');
      // Le propriétaire est bien EXCLU (sinon la garde s'accuserait elle-même).
      expect(files, isNot(contains(_ownerFile)));
      // Et le scan atteint bien du CODE (pas seulement des lignes vides).
      final total = files.fold<int>(
        0,
        (sum, path) => sum + _declarations(path).length,
      );
      expect(total, greaterThan(100),
          reason: 'le recollage ne rend presque rien — scanner cassé');
    });

    test('🔴 AUCUN fichier de lib/** ne REDÉCLARE le seuil de maîtrise', () {
      final violations = <String>[];
      for (final path in _scannedFiles()) {
        violations.addAll(scanForThresholdSources(_declarations(path), path));
      }

      expect(
        violations,
        isEmpty,
        reason: 'SECONDE SOURCE DE SEUIL détectée : le seuil de maîtrise est '
            'possédé par `ZSrsConfig.masteredThreshold` (`=> maxQuality - 1`, '
            'AD-46) et DOIT être consommé, jamais redéclaré. ⚠️ Une seconde '
            'source est ISO-COMPORTEMENTALE tant que `maxQuality` vaut 5 : elle '
            'ne rougirait NULLE PART ailleurs :\n${violations.join('\n')}',
      );
    });
  });

  group('🔬 contre-preuve R12 — le SCANNER RÉEL sait rougir', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('z_threshold_probe'));
    tearDown(() => tmp.deleteSync(recursive: true));

    /// Exerce le **VRAI** `_declarations` + le **VRAI** scanner sur une source
    /// artificielle (jamais une ré-implémentation — leçon D6).
    List<String> scanOf(String source) {
      final f = File('${tmp.path}/probe.dart')..writeAsStringSync(source);
      return scanForThresholdSources(_declarations(f.path), 'artificiel.dart');
    }

    test('🔴 LE défaut nommé par D2 : `masteredThreshold ?? 4` est capté', () {
      expect(
        scanOf('final t = config.masteredThreshold ?? 4;'),
        isNotEmpty,
        reason: '🔴 si ceci ne rougit pas, la dérivation AD-46 n\'est gardée par '
            'RIEN (le défaut est ISO-COMPORTEMENTAL)',
      );
    });

    test('🔴 la dérivation RECOPIÉE (`maxQuality - 1`) hors du propriétaire est '
        'captée', () {
      expect(scanOf('final t = config.maxQuality - 1;'), isNotEmpty);
      expect(scanOf('final t = scale.max - 1;'), isNotEmpty);
    });

    test('🔴 une redéclaration COUPÉE PAR dart format est captée (le scan '
        'ligne-à-ligne y serait AVEUGLE)', () {
      // Sortie NATURELLE du formateur à 80 colonnes : AUCUNE ligne ne porte le
      // motif complet.
      const wrapped = '''
final threshold =
    someVeryLongConfigurationName.masteredThreshold ??
    4;
''';
      expect(
        wrapped.split('\n').any((l) => RegExp(r'masteredThreshold\s*\?\?\s*-?\d')
            .hasMatch(l)),
        isFalse,
        reason: 'aucune LIGNE ne porte le motif ⇒ un scan ligne-à-ligne serait '
            'STRUCTURELLEMENT aveugle sur cette forme',
      );
      expect(scanOf(wrapped), isNotEmpty,
          reason: 'le recollage par déclaration, lui, le voit');
    });

    test('🔒 la PROSE (dartdoc/commentaire) peut nommer le motif sans rougir — '
        'sinon la garde s\'accuserait elle-même', () {
      expect(scanOf('/// jamais le littéral 4 : dériver `maxQuality - 1`\n'
          'final x = 1;'), isEmpty);
      expect(scanOf('// masteredThreshold ?? 4 est INTERDIT\nfinal x = 1;'),
          isEmpty);
    });

    test('🔒 le code CORRECT ne rougit PAS (sinon la garde finit désactivée)',
        () {
      // La forme SANCTIONNÉE : consommer le propriétaire.
      expect(scanOf('final t = widget.config.masteredThreshold;'), isEmpty);
      expect(
        scanOf('final t = widget.masteredThreshold ?? widget.config.masteredThreshold;'),
        isEmpty,
      );
      // Et les formes légitimes voisines : un `?? 0` de COMPTEUR, un index.
      expect(scanOf("count += byQuality['\$q'] ?? 0;"), isEmpty);
      expect(scanOf('final last = items.length - 1;'), isEmpty,
          reason: '🔴 faux positif : `length - 1` n\'est pas un seuil de maîtrise');
    });
  });
}

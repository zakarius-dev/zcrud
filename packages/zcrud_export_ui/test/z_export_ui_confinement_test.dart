/// 🎯 AC7 (su-11) — les paquets TIERS de `zcrud_export_ui` (`printing`,
/// `flutter_math_fork`) sont **CONFINÉS** (NFR-SU10, AD-42/AD-8/AD-1).
///
/// 🔴 **CE TEST EST LA SEULE PROTECTION.** `scripts/dev/graph_proof.py` ne
/// connaît QUE les arêtes inter-`zcrud_*` (aucune allowlist tierce — prouvé
/// su-4/su-5) : il ne verra JAMAIS une fuite de `printing` ni de
/// `flutter_math_fork`. Sans ce fichier, le confinement est déclaratif.
///
/// Patron : `zcrud_session/test/z_third_party_confinement_test.dart` (su-5, D2/R12) —
/// dé-commentateur **YAML** (`#`) correct, motifs **ANCRÉS**, allowlist
/// **DÉRIVÉE**, garde-mot de type, contre-preuve **R12 mutante** par paquet.
///
/// ## Deux différences ASSUMÉES vs la garde de session (Dev Notes su-11) :
///  1. **`printing` a DEUX fichiers propriétaires** (share-service + preview) —
///     la garde autorise un ENSEMBLE de fichiers, pas exactement 1.
///  2. **`flutter_math_fork` a DEUX paquets déclarants légitimes** : son 1er home
///     `zcrud_markdown` (confiné à `z_latex_embed.dart`) ET ce 2ᵉ site
///     `zcrud_export_ui` (impl concrète du port). La garde vérifie donc que
///     l'ensemble des déclarants est EXACTEMENT `{zcrud_export_ui, zcrud_markdown}`
///     (un 3ᵉ déclarant — surtout `zcrud_core` — la ferait rougir). `printing`,
///     lui, n'est déclaré QUE par `zcrud_export_ui`.
///
/// ⚠️ **PORTÉE DÉCLARÉE HONNÊTEMENT** (leçon E10 : « un garde ne prouve QUE ce
/// qu'il scanne ») : ce test scanne (a) les `pubspec.yaml` de tous les
/// `packages/*` (la DÉCLARATION = l'arête), et (b) les sources `lib/**` de
/// `zcrud_export_ui` (import + signatures). Il ne scanne PAS les sources des
/// autres packages : un import non déclaré ne compilerait pas (`melos run
/// analyze` repo-wide le couvre).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un paquet tiers **confiné** à `zcrud_export_ui`.
typedef _Confined = ({
  /// Nom du paquet (= préfixe `package:<name>/`).
  String pkg,

  /// Contrainte de version ÉPINGLÉE attendue dans le pubspec de l'owner.
  String constraint,

  /// Paquets AUTORISÉS à déclarer ce paquet (owner seul pour `printing` ; owner
  /// + `zcrud_markdown` pour `flutter_math_fork` — 2ᵉ site assumé).
  List<String> allowedDeclarers,

  /// Fichiers de `lib/` de l'owner autorisés à l'importer (suffixes de chemin).
  List<String> owningFiles,

  /// Types du paquet qui ne doivent JAMAIS fuiter dans une signature publique.
  List<String> bannedTypes,

  /// 🔴 su-11 D3 — préfixes d'import de paquets **TRANSITIFS co-confinés** (ex.
  /// `printing` traîne `pdf` : `package:pdf/`). Aucun fichier de `lib/` HORS des
  /// [owningFiles] ne doit les importer. Vide si le paquet n'a pas de transitive
  /// à garder (`flutter_math_fork`).
  List<String> coConfinedImports,

  /// 🔴 su-11 D3 — types du paquet transitif co-confiné qui ne doivent pas fuiter
  /// en signature publique (ex. `pdf` : `Document`, `PdfColor`, `PdfPoint`).
  /// Scannés en POSITION DE SIGNATURE dans les fichiers propriétaires réexportés.
  List<String> coConfinedTypes,

  /// Type témoin (R12) présent dans [probeLeak] et absent (mot entier) de [probeOwn].
  String probeType,

  /// Source témoin qui EST une vraie fuite de [probeType].
  String probeLeak,

  /// Source témoin qui n'en est PAS une (notre propre type, nom voisin).
  String probeOwn,
});

/// Le SEUL package qui possède ces confinements.
const String _ownerPackage = 'zcrud_export_ui';

/// **TABLE des paquets tiers confinés** — l'unique endroit à éditer.
const List<_Confined> _confined = <_Confined>[
  (
    pkg: 'printing',
    constraint: '^5.15.0',
    allowedDeclarers: <String>['zcrud_export_ui'],
    owningFiles: <String>[
      'lib/src/data/z_pdf_share_service.dart',
      'lib/src/presentation/z_pdf_preview.dart',
    ],
    bannedTypes: <String>[
      'PdfPageFormat',
      'Printing',
      'PrintingInfo',
      'PdfPreview',
      'LayoutCallback',
      'OutputType',
      'PdfPreviewAction',
    ],
    // `printing` réexporte/traîne `pdf` (widgets `pw.*`) : co-confiné (D3).
    coConfinedImports: <String>['package:pdf/'],
    coConfinedTypes: <String>['Document', 'PdfColor', 'PdfPoint'],
    probeType: 'PdfPreview',
    // Un type À NOUS dont le nom CONTIENT le leur : `PdfPreview` ⊂ `ZPdfPreview`.
    probeLeak: 'Widget build() => PdfPreview(build: (_) => bytes);',
    probeOwn: 'class ZPdfPreview extends StatelessWidget {',
  ),
  (
    pkg: 'flutter_math_fork',
    constraint: '^0.7.4',
    // 2ᵉ site ASSUMÉ : zcrud_markdown (1er home) + zcrud_export_ui (impl port).
    allowedDeclarers: <String>['zcrud_export_ui', 'zcrud_markdown'],
    owningFiles: <String>[
      'lib/src/data/z_flutter_math_latex_rasterizer.dart',
    ],
    bannedTypes: <String>[
      'Math',
      'MathStyle',
      'TeXParser',
      'FlutterMathException',
      'MathOptions',
      'SelectableMath',
    ],
    // `flutter_math_fork` n'a pas de transitive à co-confiner.
    coConfinedImports: <String>[],
    coConfinedTypes: <String>[],
    probeType: 'Math',
    // `Math` ⊂ `ZFlutterMathLatexRasterizer` (nom voisin) : le garde-mot doit
    // distinguer les deux, sinon la garde se dénoncerait elle-même.
    probeLeak: 'Widget build() => Math.tex("x");',
    probeOwn: 'class ZFlutterMathLatexRasterizer implements ZLatexRasterizer {',
  ),
];

Directory _repoRoot() {
  for (final p in <String>['.', '../..']) {
    if (Directory('$p/packages').existsSync()) return Directory(p);
  }
  fail('racine du monorepo introuvable depuis ${Directory.current.path}');
}

Directory _ownerLib() {
  final d = Directory('${_repoRoot().path}/packages/$_ownerPackage/lib');
  if (!d.existsSync()) fail('lib/ de $_ownerPackage introuvable : ${d.path}');
  return d;
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Retire les commentaires **DART** (`//`, dartdoc) — ils citent légitimement le
/// paquet et ses types. 🔴 NE JAMAIS l'appliquer à un `pubspec.yaml` (YAML).
String _stripDart(String src) => src
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

/// Retire les commentaires **YAML** (`#`) — dé-commentateur du bon langage
/// (leçon su-5 D2 : `_stripDart` sur un pubspec le rendait falsifiable).
String _stripYaml(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

/// VRAIE déclaration `<pkg>:` en début de ligne (jamais au fil d'une phrase).
RegExp _yamlDeclares(String pkg) =>
    RegExp('^\\s+${RegExp.escape(pkg)}:', multiLine: true);

/// Contrainte ÉPINGLÉE exactement `  <pkg>: ^x.y.z` seule sur sa ligne.
RegExp _yamlPinned(String pkg, String constraint) => RegExp(
      '^\\s+${RegExp.escape(pkg)}:\\s*${RegExp.escape(constraint)}\\s*\$',
      multiLine: true,
    );

/// Type ENTIER (garde-mot) : `Math` ne matche pas `ZFlutterMathLatexRasterizer`.
RegExp _wholeType(String type) =>
    RegExp('(?<![A-Za-z0-9_])$type(?![A-Za-z0-9_])');

/// 🔴 su-11 D2/D3 — détecte un type tiers en **POSITION DE SIGNATURE PUBLIQUE**
/// dans un fichier propriétaire (RÉEXPORTÉ par le barrel), là où le type
/// FRANCHIT réellement la frontière du paquet : type de **retour** / de
/// **paramètre** / de **champ** d'un membre public, y compris en argument
/// **générique** (`Future<Type>`) et via un **préfixe** d'import (`pw.Type`).
///
/// EXCLUT les USAGES INTERNES qui ne franchissent PAS la frontière — accès
/// statique (`Printing.sharePdf`), constructeur (`PdfPreview(...)`), accès de
/// membre (`Math.tex`, `MathStyle.text`) : un type suivi de `.` ou `(` est une
/// expression, JAMAIS une déclaration. Le seul signal de déclaration est
/// `Type <identifiant>` (le nom du membre/param) ou `<Type>` (argument
/// générique). C'est l'angle mort prouvé par mutation su-11 (D2) : la garde de
/// signature d'origine EXCLUAIT ces fichiers, si bien qu'un
/// `PdfPageFormat probeLeakedFormat()` réexporté restait vert.
List<String> _signatureLeaks(String code, String type) {
  final t = RegExp.escape(type);
  // (a) DÉCLARATION `Type name` : le type (mot entier, éventuellement préfixé
  //     `pw.`) est suivi d'espaces puis d'un identifiant (nom de membre/param).
  //     `Printing.` / `Math.` / `PdfPreview(` échouent (suivis de `.`/`(`).
  final decl = RegExp('(?<![A-Za-z0-9_])$t(?![A-Za-z0-9_])\\s+[A-Za-z_\$]');
  // (b) ARGUMENT GÉNÉRIQUE `<Type>` / `<Type,` / `,Type>` / `<Type?>` (retour/
  //     champ typé — franchit la frontière sans nom collé au type).
  final generic =
      RegExp('[<,]\\s*(?<![A-Za-z0-9_.])$t(?![A-Za-z0-9_])\\s*[,>?]');
  return <String>[
    for (final line in code.split('\n'))
      if (decl.hasMatch(line) || generic.hasMatch(line)) line.trim(),
  ];
}

void main() {
  // 🔒 Contre-preuve R12 de la TABLE : une table vide/amputée rendrait tous les
  // groupes verts sans rien prouver.
  test('🔬 la table couvre EXACTEMENT les 2 paquets tiers du satellite', () {
    expect(_confined, hasLength(2));
    expect(
      _confined.map((c) => c.pkg).toList(),
      <String>['printing', 'flutter_math_fork'],
      reason: '🔴 un paquet retiré cesserait SILENCIEUSEMENT d\'être gardé',
    );
  });

  for (final entry in _confined) {
    final pkg = entry.pkg;

    group('🎯 `$pkg` — DÉCLARATION (pubspec, dé-commentateur YAML ANCRÉ)', () {
      test('🔴 `$pkg` déclaré EXACTEMENT par ${entry.allowedDeclarers}', () {
        final packagesDir = Directory('${_repoRoot().path}/packages');
        final pubspecs = packagesDir
            .listSync()
            .whereType<Directory>()
            .map((d) => File('${d.path}/pubspec.yaml'))
            .where((f) => f.existsSync())
            .toList();
        expect(pubspecs.length, greaterThan(5),
            reason: 'le scan ne voit que ${pubspecs.length} pubspec — vacant');

        final declaring = <String>[
          for (final f in pubspecs)
            if (_yamlDeclares(pkg).hasMatch(_stripYaml(f.readAsStringSync())))
              f.parent.path.split(Platform.pathSeparator).last,
        ]..sort();

        final expected = <String>[...entry.allowedDeclarers]..sort();
        expect(
          declaring,
          expected,
          reason: '🔴 NFR-SU10/AD-1 : `$pkg` doit être déclaré EXACTEMENT par '
              '$expected (JAMAIS par `zcrud_core` — CORE OUT=0). Trouvé : $declaring',
        );
        // L'owner DOIT en faire partie (le satellite le déclare bien).
        expect(declaring, contains(_ownerPackage));
      });

      test('la version est ÉPINGLÉE à `${entry.constraint}` chez l\'owner', () {
        final src = _stripYaml(
          File('${_repoRoot().path}/packages/$_ownerPackage/pubspec.yaml')
              .readAsStringSync(),
        );
        expect(_yamlPinned(pkg, entry.constraint).hasMatch(src), isTrue,
            reason: 'la contrainte de `$pkg` a changé — vérifier délibérément '
                '(compat xml/pdf pour `printing`, rendu pour `flutter_math_fork`)');
      });
    });

    group('🎯 `$pkg` — IMPORT confiné aux fichiers propriétaires (DÉRIVÉ)', () {
      test('🔴 seuls ${entry.owningFiles.length} fichier(s) de `lib/` l\'importent',
          () {
        final importers = <String>[
          for (final f in _dartFiles(_ownerLib()))
            if (_stripDart(f.readAsStringSync()).contains('package:$pkg/'))
              f.path.replaceAll(r'\', '/'),
        ];

        // Chaque importeur DOIT être un fichier propriétaire déclaré.
        for (final imp in importers) {
          expect(
            entry.owningFiles.any((o) => imp.endsWith(o)),
            isTrue,
            reason: '🔴 `$pkg` importé hors des fichiers propriétaires : $imp',
          );
        }
        // Chaque fichier propriétaire DOIT effectivement l'importer (sinon la
        // table ment / le fichier a disparu).
        for (final owning in entry.owningFiles) {
          expect(
            importers.any((imp) => imp.endsWith(owning)),
            isTrue,
            reason: '🔴 le fichier propriétaire `$owning` n\'importe plus `$pkg`',
          );
        }
        expect(importers, hasLength(entry.owningFiles.length),
            reason: 'importeurs = $importers');
      });

      test('🔴 le barrel n\'importe ni ne réexporte `$pkg`', () {
        final barrel = _stripDart(
          File('${_ownerLib().path}/$_ownerPackage.dart').readAsStringSync(),
        );
        expect(barrel.contains(pkg), isFalse,
            reason: '🔴 le barrel exposerait `$pkg` à tout consommateur');
      });
    });

    group('🎯 `$pkg` — SIGNATURES : aucun type tiers dans l\'API publique', () {
      test('🔴 aucun type de `$pkg` hors de ses fichiers propriétaires', () {
        final all = _dartFiles(_ownerLib()).toList();
        final importers = all
            .where((f) => _stripDart(f.readAsStringSync()).contains('package:$pkg/'))
            .map((f) => f.path)
            .toSet();
        final publicFiles = all.where((f) => !importers.contains(f.path)).toList();
        expect(publicFiles, isNotEmpty, reason: 'aucun fichier public scanné');

        final violations = <String>[];
        for (final f in publicFiles) {
          final src = _stripDart(f.readAsStringSync());
          for (final type in entry.bannedTypes) {
            if (_wholeType(type).hasMatch(src)) {
              violations.add('${f.path} → $type');
            }
          }
        }
        expect(violations, isEmpty,
            reason: '🔴 un type `$pkg` a fui :\n${violations.join('\n')}');
      });

      test('🔬 R12 — la règle SAIT rougir et ne confond pas NOTRE type voisin',
          () {
        final re = _wholeType(entry.probeType);
        expect(re.hasMatch(entry.probeLeak), isTrue,
            reason: 'une VRAIE fuite de ${entry.probeType} doit être vue');
        expect(re.hasMatch(entry.probeOwn), isFalse,
            reason: '🔴 sans garde-mot, NOTRE type se dénoncerait lui-même');
      });

      // 🔴 su-11 D2 — Ferme l'ANGLE MORT prouvé par mutation : les fichiers
      // propriétaires sont RÉEXPORTÉS par le barrel, donc un type tiers dans
      // LEUR signature publique FRANCHIT la frontière — mais le scan
      // `publicFiles` ci-dessus les EXCLUT (ils importent le paquet). On les
      // scanne ICI en POSITION DE SIGNATURE (retour/param/champ/générique), en
      // tolérant l'usage interne (`Type.` / `Type(`). Couvre AUSSI la transitive
      // co-confinée (`pdf`) via [coConfinedTypes] (D3).
      test('🔴 aucun type tiers en SIGNATURE des fichiers propriétaires RÉEXPORTÉS',
          () {
        final barrel = File('${_ownerLib().path}/$_ownerPackage.dart')
            .readAsStringSync();
        final scannedTypes = <String>[
          ...entry.bannedTypes,
          ...entry.coConfinedTypes,
        ];
        var scannedFiles = 0;
        final violations = <String>[];
        for (final owning in entry.owningFiles) {
          // Le fichier propriétaire n'est un risque de FUITE que s'il est
          // effectivement RÉEXPORTÉ par le barrel (sinon sa signature n'est pas
          // atteignable par un consommateur).
          final reexported = barrel.contains(owning.split('/').last);
          if (!reexported) continue;
          final f = File('${_repoRoot().path}/packages/$_ownerPackage/$owning');
          expect(f.existsSync(), isTrue,
              reason: '🔴 fichier propriétaire réexporté introuvable : $owning');
          scannedFiles++;
          final code = _stripDart(f.readAsStringSync());
          for (final type in scannedTypes) {
            for (final line in _signatureLeaks(code, type)) {
              violations.add('$owning → $type : $line');
            }
          }
        }
        expect(scannedFiles, greaterThan(0),
            reason: '🔴 aucun fichier propriétaire réexporté scanné — vacant');
        expect(violations, isEmpty,
            reason: '🔴 un type tiers fuite en signature publique (D2/D3) :\n'
                '${violations.join('\n')}');
      });

      test('🔬 R12 — le scan de SIGNATURE voit la fuite (mutation su-11 D2) et '
          'IGNORE l\'usage interne', () {
        final t = entry.probeType;
        // FUITES réelles (position de signature) — DOIVENT être vues.
        expect(_signatureLeaks('$t probeLeaked() => x;', t), isNotEmpty,
            reason: '🔴 fuite en RETOUR de membre public non vue (angle mort D2)');
        expect(_signatureLeaks('void f($t p) {}', t), isNotEmpty,
            reason: '🔴 fuite en PARAMÈTRE public non vue');
        expect(_signatureLeaks('Future<$t> g() async => x;', t), isNotEmpty,
            reason: '🔴 fuite en ARGUMENT GÉNÉRIQUE de retour non vue');
        expect(_signatureLeaks('pw.$t build() => d;', t), isNotEmpty,
            reason: '🔴 fuite PRÉFIXÉE (`pw.$t`) non vue');
        // USAGES INTERNES (ne franchissent PAS la frontière) — NE doivent PAS
        // être vus : le patron `publicFiles` d'origine les excluait en bloc.
        expect(_signatureLeaks('return $t.someStatic(b);', t), isEmpty,
            reason: '🔴 faux positif sur un accès statique interne `$t.`');
        expect(_signatureLeaks('child: $t(build: (_) => b),', t), isEmpty,
            reason: '🔴 faux positif sur un constructeur interne `$t(`');
      });
    });

    // 🔴 su-11 D3 — la transitive co-confinée (`pdf` derrière `printing`) ne
    // franchit pas non plus : aucun fichier de `lib/` HORS des fichiers
    // propriétaires ne l'importe. (La revendication « pdf ne franchit jamais »
    // du header n'était gardée par RIEN — seul `package:printing/` l'était.)
    if (entry.coConfinedImports.isNotEmpty) {
      group('🎯 `$pkg` — transitive co-confinée ${entry.coConfinedImports}', () {
        test('🔴 aucun import hors des fichiers propriétaires', () {
          for (final prefix in entry.coConfinedImports) {
            final importers = <String>[
              for (final f in _dartFiles(_ownerLib()))
                if (_stripDart(f.readAsStringSync()).contains(prefix))
                  f.path.replaceAll(r'\', '/'),
            ];
            for (final imp in importers) {
              expect(
                entry.owningFiles.any((o) => imp.endsWith(o)),
                isTrue,
                reason: '🔴 transitive `$prefix` importée hors fichier '
                    'propriétaire : $imp',
              );
            }
          }
        });
      });
    }
  }

  // 🔒 R12 du dé-commentateur YAML : les mutations que la revue su-5 a prouvées
  // doivent rendre le BON verdict aussi ici.
  group('🔬 R12 — la garde YAML n\'est pas falsifiable par un COMMENTAIRE', () {
    const falsified = '''
name: zcrud_export_ui
dependencies:
  # Epingle : printing: ^5.14.0   <- prose qui CITE la contrainte
  printing: '>=5.14.0 <6.0.0'
''';
    const documenting = '''
name: zcrud_core
dependencies:
  # NOTE: ne jamais declarer printing: ici (confine a zcrud_export_ui).
  flutter:
    sdk: flutter
''';

    test('faux NÉGATIF fermé — contrainte desserrée non masquée par un commentaire',
        () {
      final stripped = _stripYaml(falsified);
      expect(falsified.contains('printing: ^5.14.0'), isTrue,
          reason: 'témoin : le piège que la garde d\'origine (contains) ratait');
      expect(_yamlPinned('printing', '^5.14.0').hasMatch(stripped), isFalse,
          reason: '🔴 la contrainte RÉELLE est `>=5.14.0 <6.0.0` : DOIT rougir');
      expect(
        _yamlPinned('printing', '^5.14.0')
            .hasMatch(_stripYaml('dependencies:\n  printing: ^5.14.0\n')),
        isTrue,
      );
    });

    test('faux POSITIF fermé — une ligne de DOC ne déclare rien', () {
      expect(_yamlDeclares('printing').hasMatch(_stripYaml(documenting)), isFalse,
          reason: '🔴 accuser `zcrud_core` sur un commentaire est un diagnostic FAUX');
      expect(
        _yamlDeclares('printing')
            .hasMatch(_stripYaml('dependencies:\n  printing: ^5.14.0\n')),
        isTrue,
      );
    });

    test('🔬 `_stripYaml` retire `#` (et non `//`, absent du YAML)', () {
      expect(_stripYaml('  printing: ^5.14.0  # note').trim(), 'printing: ^5.14.0');
      expect(_stripYaml('# tout est commente').trim(), '');
    });
  });

  group('🔬 R12 — le garde-mot distingue les types voisins', () {
    test('`Math` ne matche pas `MathStyle` (autre motif de la liste)', () {
      expect(_wholeType('Math').hasMatch('final MathStyle s;'), isFalse);
    });
    test('`PdfPreview` ne matche pas `PdfPreviewAction`', () {
      expect(_wholeType('PdfPreview').hasMatch('PdfPreviewAction a;'), isFalse);
    });
  });
}

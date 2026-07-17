/// Garde de COMPOSITION UNIQUE des clés de section (SU-1, AC3 — AD-38).
///
/// L'epic exige un test qui rougit si « une clé est composée à la main
/// ailleurs ». `applyOrder` étant **TOTAL**, une clé composée à la main qui
/// diverge est **ignorée en silence** : aucun autre test du repo ne peut
/// attraper ce bug. Cette garde structurelle est le seul filet.
///
/// **Portée HONNÊTE et BORNÉE** (déclarée, pas sous-entendue) :
/// - couvre le **code de PRODUCTION** de `zcrud_study_kernel` (`lib/`) — qui
///   possède le foyer canonique `z_section_key.dart`, seul autorisé à composer —
///   **ET** celui de `zcrud_study` (`../zcrud_study/lib`), le package qui
///   **ÉCRIT** `sectionOrders` (cf. le patron documenté en
///   `z_study_tools_section_spec.dart`) et donc le **vrai lieu du risque** :
///   su-4/su-5 y composeront des clés. Une garde braquée sur le seul kernel
///   serait tendue sous le package qui n'en a pas besoin ;
/// - ne couvre **PAS** les tests (ils manipulent légitimement des clés opaques
///   littérales — c'est leur rôle de fixer le persisté), ni les apps
///   consommatrices (`sectionKey` y est un paramètre **reçu**, pas composé).
///
/// **État actuel** : `zcrud_study/lib` ne compose aujourd'hui **aucune** clé
/// (grep négatif — seules des mentions en dartdoc). La garde couvre l'**avenir**,
/// qui est sa seule raison d'être.
///
/// ⚠️ Scan hors dartdoc/commentaires (patron `z_linear_no_srs_test.dart`) : la
/// prose doit pouvoir montrer la forme `'type/sous-dossier'` en exemple.
/// Accès `dart:io` ⇒ `@TestOn('vm')`.
///
/// Runner : **`package:test`** (et non `flutter_test`) — `zcrud_study_kernel`
/// est un package **pur-Dart** (dev-dep `test: ^1.25.0`, aucun `flutter_test`),
/// comme tous ses tests existants (`apply_order_test.dart`…).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Fichier AUTORISÉ à composer une clé : l'unique foyer canonique (AD-38).
const String _canonicalHome = 'z_section_key.dart';

/// Racines de **code de production** scannées (cwd = `packages/zcrud_study_kernel`).
const List<String> _scannedLibRoots = <String>[
  'lib', // zcrud_study_kernel — possède le foyer canonique
  '../zcrud_study/lib', // zcrud_study — ÉCRIT sectionOrders (risque su-4/su-5)
];

/// Motifs de **composition manuelle** d'une clé de section.
///
/// Volontairement étroits : on cible la **composition** (interpolation d'un
/// `contentType`, concaténation d'un séparateur, indexation littérale de
/// `sectionOrders`), jamais la simple mention d'une variable.
const List<String> _bannedCompositionPatterns = <String>[
  r'$contentType/', // interpolation directe de la forme canonique
  r"+ '/' +", // concaténation d'un séparateur de section
  r'+ "/" +',
  r"sectionOrders['", // indexation par une clé littérale composée
  r'sectionOrders["',
  r"orderFor('", // lecture par clé littérale au lieu de zSectionKey(...)
  r'orderFor("',
];

/// **Scanner RÉEL de la garde** — l'unique implémentation du scan.
///
/// Retourne une violation lisible par ligne fautive de [lines]. Exercé À LA FOIS
/// par la garde (sur le code de prod) et par sa contre-preuve (sur une source
/// artificielle) : sans ce partage, une contre-preuve qui recopierait la boucle
/// resterait verte alors même que le scan réel deviendrait aveugle — elle
/// prouverait le pouvoir des MOTIFS, jamais celui du SCANNER.
List<String> scanForManualComposition(List<String> lines, String path) {
  final violations = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
      continue; // dartdoc/commentaire — la prose peut montrer la forme
    }
    for (final pattern in _bannedCompositionPatterns) {
      if (raw.contains(pattern)) {
        violations.add('$path:${i + 1} → « $pattern » dans « ${raw.trim()} »');
      }
    }
  }
  return violations;
}

/// Sources `.dart` de production sous [root] (hors code généré).
List<File> _productionSources(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .toList();
}

void main() {
  test(
    'AC3 — aucune clé de section n\'est composée à la main dans le code de prod '
    'de zcrud_study_kernel NI de zcrud_study (foyer unique : zSectionKey, AD-38)',
    () {
      final violations = <String>[];
      final scannedRoots = <String>[];

      for (final root in _scannedLibRoots) {
        final sources = _productionSources(root);
        // Contre-preuve R12 : chaque racine DOIT réellement livrer des fichiers
        // — un scan à vide (mauvais cwd, package déplacé/renommé) passerait
        // sinon vert pour toujours, et la garde mourrait en silence.
        expect(
          sources,
          isNotEmpty,
          reason: 'aucune source scannée sous « $root » — GARDE MORTE. '
              'cwd = ${Directory.current.path}. Le package a-t-il été déplacé ?',
        );
        scannedRoots.add(root);

        for (final source in sources) {
          // Le foyer canonique est le SEUL endroit où composer est légitime.
          if (source.path.endsWith(_canonicalHome)) continue;
          violations.addAll(
            scanForManualComposition(source.readAsLinesSync(), source.path),
          );
        }
      }

      // Le foyer canonique doit avoir été VU (sinon le scan regarde à côté).
      expect(
        _productionSources('lib')
            .any((f) => f.path.endsWith(_canonicalHome)),
        isTrue,
        reason: 'le foyer canonique lui-même n\'a pas été vu par le scan — '
            'la garde ne regarde pas au bon endroit',
      );
      expect(scannedRoots, _scannedLibRoots,
          reason: 'toutes les racines exigées par l\'AC3 doivent être scannées');

      expect(
        violations,
        isEmpty,
        reason: 'CLÉ DE SECTION COMPOSÉE À LA MAIN hors du foyer canonique '
            '`$_canonicalHome`. `applyOrder` est TOTAL : une clé divergente est '
            'ignorée SANS erreur ni test rouge, orphelinant silencieusement '
            'l\'ordre persisté (Prevents AD-38). Composer via '
            '`zSectionKey(contentType: …, subfolderId: …)` :\n'
            '${violations.join('\n')}',
      );
    },
  );

  test(
    'AC3 — la garde a bien du pouvoir : le SCANNER RÉEL détecte une composition '
    'manuelle (contre-preuve du scanner lui-même, pas d\'une copie)',
    () {
      // Prouve que le scanner N'EST PAS tautologique : sur une source
      // ARTIFICIELLE composant une clé à la main, `scanForManualComposition` —
      // la fonction que la garde ci-dessus exécute RÉELLEMENT — DOIT lever.
      const injected = <String>[
        "/// Exemple de dartdoc : '\$contentType/\$subfolderId' — NON détecté",
        "final key = '\$contentType/\$subfolderId';",
        "final o = order.sectionOrders['flashcards'];",
        'final legit = zSectionKey(contentType: t, subfolderId: s);',
      ];

      final violations = scanForManualComposition(injected, 'artificiel.dart');

      expect(violations.any((v) => v.startsWith('artificiel.dart:2')), isTrue,
          reason: 'interpolation manuelle non détectée — garde morte');
      expect(violations.any((v) => v.startsWith('artificiel.dart:3')), isTrue,
          reason: 'indexation littérale non détectée — garde morte');
      expect(violations.any((v) => v.startsWith('artificiel.dart:1')), isFalse,
          reason: 'faux positif sur du dartdoc — la prose doit rester libre');
      expect(violations.any((v) => v.startsWith('artificiel.dart:4')), isFalse,
          reason: 'faux positif sur l\'appel canonique — zSectionKey est la '
              'voie LÉGITIME, elle ne doit jamais être signalée');
    },
  );
}

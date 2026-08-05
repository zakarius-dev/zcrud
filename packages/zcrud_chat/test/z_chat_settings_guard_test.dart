/// Lot γ0/δ (CR-IFFD-72) — gardes de **SOURCE** des réglages.
///
/// Les gardes de comportement (`z_chat_settings_test.dart`) prouvent ce qui se
/// produit sur le chemin qu'elles montent. Elles sont **aveugles** à un second
/// chemin que personne ne monte — et c'est exactement ainsi qu'une « surface
/// B » s'installe. Ce fichier est le grep NÉGATIF, exécuté par une machine :
///
/// * **SET-F1** — ANTI-RÉINVENTION : les fichiers de réglages ne déclarent
///   **aucun** enum, aucune classe de palier. C'est le risque n°1 nommé par
///   CR-IFFD-72 (« reconstruire la moitié de `zcrud_chat_kernel` ») ;
/// * **SET-F2** — AUCUNE valeur métier : ni corpus, ni code, ni famille nommée ;
/// * **SET-F3** — le composer LIT les réglages au moment de l'envoi, et `send(`
///   n'est invoqué qu'à UN endroit ;
/// * **SET-F4** — un SEUL écrivain par tranche du contrôleur de réglages ;
/// * **SET-F5** — la priorité est écrite dans le bon ORDRE, et le niveau 2
///   n'est pas `ZcrudTheme.of` (qui rendrait le niveau 3 inatteignable) ;
/// * **SET-F6** — la surface publique de `ZChatSettingsController`, en ÉGALITÉ
///   d'ensemble (leçon G-CH1/G-U2) ;
/// * **SET-F7** — les clés du lot sont déclarées, repliées, et **consommées**.
@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_sources.dart';

const String _controllerFile =
    'lib/src/presentation/settings/z_chat_settings_controller.dart';
const String _sheetFile = 'lib/src/presentation/view/z_chat_settings_sheet.dart';
const String _composerFile = 'lib/src/presentation/view/z_chat_composer.dart';

/// Les clés introduites par ce lot.
const List<String> _kLotKeys = <String>[
  kZChatLabelSettings,
  kZChatLabelResponseLength,
  kZChatLabelLengthConcise,
  kZChatLabelLengthStandard,
  kZChatLabelLengthDetailed,
  kZChatLabelLengthBias,
  kZChatLabelBiasShorter,
  kZChatLabelBiasAsIs,
  kZChatLabelBiasLonger,
  kZChatLabelComputeBudget,
  kZChatLabelComputeBudgetLevel,
  kZChatLabelRevealThinking,
  kZChatLabelCorpusScope,
  kZChatLabelCorpusAll,
  kZChatLabelSettingAuto,
];

/// Corps de la classe [declaration] dans [file], dé-commenté.
List<String> _classBody(String file, String declaration) {
  final List<String> lines = stripped(libFile(file));
  final int start = lines.indexWhere(
    (String l) => RegExp('^$declaration\\b').hasMatch(l),
  );
  expect(start, greaterThanOrEqualTo(0),
      reason: '🔴 `$declaration` introuvable dans $file — garde VACUELLE');
  final List<String> body = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\}').hasMatch(lines[i])) break;
    body.add(lines[i]);
  }
  expect(body.length, greaterThan(20),
      reason: '🔴 corps quasi vide (${body.length} lignes) : découpeur cassé');
  return body;
}

/// Noms des membres **publics** déclarés au premier niveau de la classe.
///
/// Découpeur repris **verbatim** de G-CH1 (`z_chat_structure_guard_test.dart`),
/// y compris son correctif R3 : `\(` exact, pour qu'un CHAMP typé générique ne
/// se fasse pas passer pour une méthode et ne masque pas un vrai membre.
Set<String> _publicMembers(List<String> body, String owner) {
  final RegExp getter = RegExp(r'^\s{2}[\w<>?,\s.]*\bget\s+(\w+)\b');
  final RegExp field = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*\s(\w+)\s*[;=]');
  final RegExp method = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*\(');
  final Set<String> names = <String>{};
  for (final String l in body) {
    if (!RegExp(r'^\s{2}\S').hasMatch(l)) continue;
    final RegExpMatch? m =
        getter.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m == null) continue;
    final String name = m.group(1)!;
    if (name.startsWith('_')) continue;
    if (name == owner) continue; // le constructeur
    if (name == 'override') continue;
    names.add(name);
  }
  return names;
}

void main() {
  group('🔴 SET-F1 — ANTI-RÉINVENTION : aucun réglage n\'est REDÉCLARÉ ici', () {
    test('les deux fichiers du lot ne déclarent NI enum NI type de palier', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final String file in <String>[_controllerFile, _sheetFile]) {
        final List<String> lines = stripped(libFile(file));
        for (int i = 0; i < lines.length; i++) {
          scanned++;
          if (RegExp(r'^\s*enum\s+\w').hasMatch(lines[i])) {
            offenders.add('$file:${i + 1}: ${lines[i].trim()}');
          }
          // Une classe dont le nom évoque un axe DÉJÀ modélisé côté kernel :
          // c'est la forme exacte de la réinvention que la CR redoutait.
          if (RegExp(
            r'^\s*(abstract\s+)?class\s+\w*(Length|Effort|Bias|Thinking|Corpus'
            r'Scope|Verbosity)\w*',
          ).hasMatch(lines[i])) {
            offenders.add('$file:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(scanned, greaterThan(200),
          reason: '🔴 GARDE VACUELLE : seulement $scanned lignes scannées');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 RISQUE N°1 DE CR-IFFD-72 — « reconstruire la moitié de '
            '`zcrud_chat_kernel` ». Les quatre axes et la portée existent déjà '
            '(`ZChatResponseLength`, `ZChatLengthBias`, `ZChatComputeEffort`, '
            '`revealThinkingSteps`, `ZChatCorpusScope`) : on les RÉFÉRENCE.\n'
            '${offenders.join('\n')}',
      );
    });

    test('…et les types du KERNEL sont bien référencés (non-vacuité)', () {
      final String all = <String>[
        stripped(libFile(_controllerFile)).join('\n'),
        stripped(libFile(_sheetFile)).join('\n'),
      ].join('\n');
      for (final String type in <String>[
        'ZChatGenerationSettings',
        'ZChatResponseLength',
        'ZChatLengthBias',
        'ZChatComputeEffort',
        'ZChatCorpusScope',
      ]) {
        expect(all, contains(type),
            reason: '🔴 GARDE VACUELLE : `$type` n\'est plus référencé — la '
                'garde ci-dessus passerait sur des fichiers qui ne règlent '
                'plus rien');
      }
    });

    test('🔬 contre-preuve — le motif VOIT une redéclaration', () {
      final RegExp klass = RegExp(
        r'^\s*(abstract\s+)?class\s+\w*(Length|Effort|Bias|Thinking|Corpus'
        r'Scope|Verbosity)\w*',
      );
      expect(klass.hasMatch('class ZChatSheetResponseLength {'), isTrue);
      expect(klass.hasMatch('class ZChatCorpusScopeEditor {'), isTrue);
      expect(RegExp(r'^\s*enum\s+\w').hasMatch('enum _Verbosity { a, b }'),
          isTrue);
      // …et les formes CONFORMES ne sont pas accusées.
      expect(klass.hasMatch('class ZChatSettingsSheet extends StatelessWidget {'),
          isFalse);
      expect(klass.hasMatch('class ZChatCorpusOption {'), isFalse,
          reason: '🔴 FAUX POSITIF : le catalogue d\'HÔTE n\'est pas un axe '
              'de réglage redéclaré');
    });
  });

  group('🔴 SET-F2 — AUCUNE valeur métier dans le socle', () {
    test('ni corpus, ni code, ni famille nommée dans les fichiers du lot', () {
      // 🔴 Même liste que la garde jumelle du lot β
      // (`zcrud_chat_kernel/test/z_chat_corpus_scope_test.dart`) : les valeurs
      // appartiennent aux hôtes. Un terme métier ici imposerait la douane à
      // IFFD et à DODLP.
      const List<String> business = <String>[
        'douane',
        'cedeao',
        'gatt',
        'tarif',
        'tec_',
        'enablecodes',
        'enabletec',
        'valuation',
        'iffd',
      ];
      final List<String> offenders = <String>[];
      for (final String file in <String>[_controllerFile, _sheetFile]) {
        final List<String> lines = stripped(libFile(file));
        for (int i = 0; i < lines.length; i++) {
          final String low = lines[i].toLowerCase();
          for (final String term in business) {
            if (low.contains(term)) {
              offenders.add('$file:${i + 1} ($term): ${lines[i].trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 le catalogue de corpus est une donnée d\'HÔTE : le socle '
            'rend le MÉCANISME, jamais une valeur.\n${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve — le motif SAIT rougir sur un témoin', () {
      const String witness = "  const String k = 'codes-douane-cedeao';";
      expect(
        <String>['douane', 'cedeao'].any(witness.toLowerCase().contains),
        isTrue,
        reason: '🔴 le motif est aveugle à une valeur métier évidente',
      );
    });
  });

  group('🔴 SET-F3 — le composer soumet les réglages, par UN SEUL site', () {
    test('`_submit` LIT le contrôleur de réglages et le passe à `send(`', () {
      final List<String> lines = stripped(libFile(_composerFile));
      final int start = lines.indexWhere(
        (String l) => RegExp(r'^\s{2}void\s+_submit\s*\(').hasMatch(l),
      );
      expect(start, greaterThanOrEqualTo(0),
          reason: '🔴 `_submit` introuvable — garde VACUELLE');
      int end = lines.length;
      for (int i = start + 1; i < lines.length; i++) {
        if (RegExp(r'^\s{2}\S').hasMatch(lines[i]) &&
            !RegExp(r'^\s{2}[});]').hasMatch(lines[i])) {
          end = i;
          break;
        }
      }
      final String scope = lines.sublist(start, end).join('\n');
      expect(scope, contains('widget.settings'),
          reason: '🔴 le composer n\'a plus accès aux réglages : une feuille '
              'montée dans `tools` afficherait des réglages qui n\'atteignent '
              'jamais la requête — le défaut IFFD, à la lettre.');
      // 🔴 La VALEUR lue, pas le seul nom du paramètre : remplacer
      // `tools?.settings.value` par `null` laisserait `settings:` en place et
      // une garde ancrée sur le nom resterait VERTE — exactement la forme du
      // repli muet que ce lot ferme.
      expect(scope, contains('settings: tools?.settings.value'),
          reason: '🔴 les réglages ne sont plus PASSÉS à `send(`');
      expect(scope, contains('corpusScope: tools?.corpusScope.value'),
          reason: '🔴 la portée documentaire n\'est plus passée à `send(`');
    });

    test('`send(` n\'est invoqué qu\'à UN endroit du composer', () {
      final List<String> lines = stripped(libFile(_composerFile));
      final List<String> sites = <String>[
        for (int i = 0; i < lines.length; i++)
          if (RegExp(r'\.send\s*\(').hasMatch(lines[i])) '${i + 1}',
      ];
      expect(sites, hasLength(1),
          reason: '🔴 un SECOND site d\'envoi : c\'est ainsi qu\'IFFD a produit '
              'deux barres d\'actions divergentes. Sites : $sites');
    });

    test('AUCUN autre fichier de `lib/` ne construit de requête de génération',
        () {
      // Le raccord des réglages doit rester le site UNIQUE du contrôleur : un
      // second `withSettings`/`withCorpusScope` ailleurs serait un second
      // chemin de composition, donc une divergence possible.
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        final String path = e.key.replaceAll(r'\', '/');
        if (path.endsWith('lib/src/presentation/z_chat_controller.dart')) {
          continue;
        }
        for (int i = 0; i < e.value.length; i++) {
          if (RegExp(r'\.with(Settings|CorpusScope)\s*\(').hasMatch(e.value[i])) {
            offenders.add('$path:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 un SECOND site applique les réglages à la requête.\n'
              '${offenders.join('\n')}');
    });

    test('…et le contrôleur, lui, les applique BIEN (non-vacuité)', () {
      final String src = stripped(
        libFile('presentation/z_chat_controller.dart'),
      ).join('\n');
      expect(src, contains('withSettings('),
          reason: '🔴 GARDE VACUELLE : plus aucun raccord — les réglages '
              'n\'atteindraient plus jamais la requête');
      expect(src, contains('withCorpusScope('));
    });
  });

  group('🔴 SET-F4 — un SEUL écrivain par tranche de réglages', () {
    test('`_settings.value =` / `_corpusScope.value =` n\'apparaissent que '
        'dans `update` et `setCorpusScope`', () {
      final List<String> body = _classBody(
        _controllerFile,
        'class ZChatSettingsController',
      );
      final List<String> sites = <String>[];
      String current = '';
      for (final String l in body) {
        final RegExpMatch? decl = RegExp(
          r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*\(',
        ).firstMatch(l);
        if (decl != null) current = decl.group(1)!;
        if (RegExp(r'_(settings|corpusScope)\.value\s*=[^=]').hasMatch(l)) {
          sites.add('$current → ${l.trim()}');
        }
      }
      expect(sites, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : plus AUCUNE écriture — le contrôleur ne '
              'réglerait plus rien');
      expect(
        sites.map((String s) => s.split(' → ').first).toSet(),
        <String>{'update', 'setCorpusScope'},
        reason: '🔴 PLUSIEURS chemins écrivent dans une tranche de réglages. '
            'C\'est la classe de défaut que G-CH4/G10-P2 ferment sur la '
            'saisie ; elle vaut ici. Sites : $sites',
      );
    });
  });

  group('🔴 SET-F5 — la PRIORITÉ est écrite dans le bon ordre', () {
    test('paramètre, PUIS jeton d\'hôte, PUIS référence — et le jeton n\'est '
        'PAS `ZcrudTheme.of`', () {
      final String src = stripped(libFile(_sheetFile)).join('\n');
      for (final ({String param, String token, String ref}) chain
          in <({String param, String token, String ref})>[
        (
          param: 'padding',
          token: 'formPadding',
          ref: 'kZChatSettingsReferencePadding',
        ),
        (param: 'spacing', token: 'gapS', ref: 'kZChatSettingsReferenceGap'),
      ]) {
        final int p = src.indexOf('${chain.param} ??');
        final int t = src.indexOf(chain.token);
        final int r = src.indexOf('${chain.ref};');
        expect(p, greaterThanOrEqualTo(0), reason: 'paramètre ${chain.param}');
        expect(t, greaterThan(p),
            reason: '🔴 le JETON précède le PARAMÈTRE : un paramètre explicite '
                'ne pourrait plus rien régler (${chain.param})');
        expect(r, greaterThan(t),
            reason: '🔴 la RÉFÉRENCE précède le jeton : le thème de l\'hôte '
                'serait ignoré, ce que FR-26 interdit (${chain.param})');
      }
      expect(
        src.contains('ZcrudTheme.of('),
        isFalse,
        reason: '🔴 `ZcrudTheme.of` NE REND JAMAIS `null` (il retombe sur '
            '`ZcrudTheme.fallback(Theme.of(context))`). Le lire ici rendrait '
            'la RÉFÉRENCE du socle inatteignable — une garde vacante déguisée '
            'en gouvernance. Le jeton se lit sur `ZcrudScope.maybeOf`.',
      );
      expect(src, contains('ZcrudScope.maybeOf(context)?.theme'));
    });

    test('les deux références sont des ESPACEMENTS, jamais des couleurs', () {
      // L'exception FR-26 encadrée (patron `ZStudyCardReference`) vise des
      // valeurs de COULEUR relevées sur un legacy. Rien de tel ici : ces deux
      // constantes sont des `double`/`EdgeInsetsDirectional`, et la garde de
      // pureté (qui balaie tout `lib/`) le confirme déjà pour les couleurs.
      expect(kZChatSettingsReferenceGap, isA<double>());
      expect(kZChatSettingsReferencePadding, isA<EdgeInsetsDirectional>());
    });
  });

  group('🔴 SET-F6 — la surface publique de `ZChatSettingsController`, en '
      'ÉGALITÉ d\'ENSEMBLE', () {
    test('EXACTEMENT les membres attendus', () {
      final Set<String> publics = _publicMembers(
        _classBody(_controllerFile, 'class ZChatSettingsController'),
        'ZChatSettingsController',
      );
      expect(
        publics,
        <String>{
          // Lecture — les deux tranches.
          'settings',
          'corpusScope',
          'selectsCorpusKey',
          // Écriture — les deux écrivains, puis les gestes.
          'update',
          'setCorpusScope',
          'setResponseLength',
          'setLengthBias',
          'setComputeEffort',
          'setRevealThinkingSteps',
          'toggleCorpusKey',
          'reset',
          'dispose',
        },
        reason: '🔴 ÉGALITÉ D\'ENSEMBLE, pas « contient » (leçon G-CH1). Un '
            'membre ajouté qui ENVERRAIT — `sendWith()`, `applyTo(request)` — '
            'ferait de ce contrôleur un second site d\'envoi, à côté de '
            '`ZChatController.send`. L\'invariant « un verbe = un seul site '
            'd\'appel » vaut ici aussi.',
      );
    });

    test('🔬 contre-preuve — le découpeur VOIT un membre ajouté', () {
      const List<String> witness = <String>[
        '  final ValueNotifier<bool> _x = ValueNotifier<bool>(false);',
        '  ValueListenable<ZChatGenerationSettings> get settings => _settings;',
        '  void update(ZChatGenerationSettings value) => _s.value = value;',
        '  Future<void> sendWith(ZChatController c) async {',
      ];
      expect(
        _publicMembers(witness, 'ZChatSettingsController'),
        <String>{'settings', 'update', 'sendWith'},
        reason: '🔴 si `ValueNotifier` revient dans l\'ensemble le défaut R3 de '
            'G-CH1 est de retour ; si `sendWith` en disparaît, la garde ne voit '
            'plus le second site d\'envoi qu\'elle existe pour interdire.',
      );
    });
  });

  group('🔴 SET-F7 — les clés du lot sont déclarées, repliées et CONSOMMÉES',
      () {
    test('chaque clé est dans la liste ET dans la carte des replis', () {
      for (final String key in _kLotKeys) {
        expect(kZChatLabelKeys, contains(key), reason: 'clé non déclarée : $key');
        expect(kZChatLabelFallbacks[key], isNotNull,
            reason: '🔴 clé SANS repli : un hôte sans registre verrait le '
                'discriminant machine `$key` à l\'écran (HIGH-1)');
        expect(kZChatLabelFallbacks[key]!.trim(), isNotEmpty);
      }
      expect(_kLotKeys.toSet(), hasLength(_kLotKeys.length),
          reason: '🔴 deux clés identiques dans le lot');
    });

    test('la clé de palier porte le marqueur de COMPTE', () {
      expect(
        kZChatLabelFallbacks[kZChatLabelComputeBudgetLevel],
        contains(kZChatCountPlaceholder),
        reason: '🔴 sans marqueur, les cinq paliers `1..5` s\'afficheraient '
            'tous IDENTIQUES : cinq boutons indiscernables, dont un lecteur '
            'd\'écran annonce cinq fois la même chose.',
      );
    });

    test('🔴 le nom des constantes du budget de calcul évite le radical que '
        'G16 protège', () {
      // G16 n'autorise, pour `Effort`, que `ZChatComputeEffort` et
      // `computeEffort` — avec limites de mot. `kZChatLabelComputeEffort` en
      // serait une orthographe voisine : son `Effort` survit au retrait des
      // deux formes autorisées. Le second volet de G16 ne balaie pas encore ce
      // paquet ; cette garde-ci fait que l'élargir ne coûtera rien.
      for (final String name in <String>[
        'kZChatLabelComputeBudget',
        'kZChatLabelComputeBudgetLevel',
      ]) {
        expect(
          name.replaceAll(
            RegExp(r'\b(ZChatComputeEffort|computeEffort)\b'),
            '',
          ),
          isNot(contains('Effort')),
          reason: '🔴 `$name` heurterait G16 si sa portée s\'élargissait à '
              '`zcrud_chat` — et le contournement (renommer pour passer) est '
              'précisément ce que G16 existe pour empêcher.',
        );
      }
    });
  });
}

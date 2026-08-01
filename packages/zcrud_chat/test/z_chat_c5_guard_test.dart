/// Gardes de **SOURCE** de CHAT-5 — grep NÉGATIF outillé.
///
/// Les gardes de comportement (`z_chat_attachment_test.dart`,
/// `z_chat_export_test.dart`) prouvent ce que le code FAIT. Elles sont aveugles
/// à ce qu'il DUPLIQUE ou à ce qu'il fait ENTRER dans le graphe de dépendances.
/// Ce fichier est le balayage exhaustif, exécuté par une machine.
///
/// Trois invariants, tous nommés par le plan de portage :
/// * **aucun doublon** de `ZPdfShareService` ni de `ZChatAttachment` ;
/// * **aucune dépendance tierce**, ni directe, ni par un `zcrud_*` qui en tire ;
/// * **AD-13** sur la bande de pièces jointes (directionnalité, cible tactile).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

/// Racine du dépôt — le dossier qui porte `melos.yaml`.
///
/// 🔴 Remontée jusqu'au marqueur, JAMAIS un `../..` relatif : la convention du
/// dépôt est que `flutter test` tourne depuis le dossier du package, mais la CI
/// (`melos exec`) et un lancement depuis la racine n'ont pas le même répertoire
/// courant. Un chemin relatif rendrait la garde VACUELLE dans l'un des deux cas
/// — sans jamais rougir.
Directory repoRoot() {
  Directory dir = Directory(packageRoot().absolute.path);
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  fail('racine du dépôt (melos.yaml) introuvable depuis ${packageRoot().path}');
}

/// Tous les `.dart` de `packages/*/lib`, indexés par chemin **relatif** au dépôt.
Map<String, String> repoLibSources() {
  final Directory packages = Directory('${repoRoot().path}/packages');
  expect(packages.existsSync(), isTrue, reason: '🔴 `packages/` introuvable');
  final Map<String, String> out = <String, String>{};
  for (final FileSystemEntity pkg in packages.listSync()) {
    if (pkg is! Directory) continue;
    final Directory lib = Directory('${pkg.path}/lib');
    if (!lib.existsSync()) continue;
    for (final FileSystemEntity f in lib.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      out[f.path.substring(repoRoot().path.length + 1).replaceAll(r'\', '/')] =
          f.readAsStringSync();
    }
  }
  expect(out.length, greaterThan(50),
      reason: '🔴 GARDE VACUELLE : seulement ${out.length} sources balayées');
  return out;
}

/// Fichiers (relatifs) qui DÉCLARENT le type [name] au premier niveau.
List<String> declarationsOf(String name, Map<String, String> sources) {
  final RegExp decl = RegExp(
    '^(?:abstract |sealed |final |base |interface |mixin )*'
    'class\\s+$name\\b',
    multiLine: true,
  );
  return <String>[
    for (final MapEntry<String, String> e in sources.entries)
      if (decl.hasMatch(e.value)) e.key,
  ]..sort();
}

/// Les dépendances déclarées du pubspec de ce package.
List<String> declaredDependencies() {
  final List<String> lines =
      File('${packageRoot().path}/pubspec.yaml').readAsLinesSync();
  final int start = lines.indexWhere((String l) => l == 'dependencies:');
  expect(start, greaterThanOrEqualTo(0), reason: '🔴 bloc `dependencies:` absent');
  final List<String> deps = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    final String l = lines[i];
    if (l.isNotEmpty && !l.startsWith(' ') && !l.startsWith('#')) break;
    final RegExpMatch? m = RegExp(r'^  ([a-z_0-9]+):').firstMatch(l);
    if (m != null) deps.add(m.group(1)!);
  }
  expect(deps, isNotEmpty, reason: '🔴 GARDE VACUELLE : aucune dépendance lue');
  return deps;
}

void main() {
  group('🔴 G-C5-1 — AUCUN DOUBLON : le dépôt possède UNE seule déclaration',
      () {
    late final Map<String, String> sources = repoLibSources();

    test('`ZPdfShareService` n\'est déclaré QUE dans `zcrud_export_ui`', () {
      final List<String> sites = declarationsOf('ZPdfShareService', sources);
      expect(sites, <String>[
        'packages/zcrud_export_ui/lib/src/data/z_pdf_share_service.dart',
      ], reason: '🔴 UN SECOND service de partage. `ZPdfShareService` existe '
          'déjà (`Printing.sharePdf` / `Printing.layoutPdf`, API 100 % '
          '`Uint8List`) : le chat le CÂBLE par `ZChatExportSink`, il ne le '
          'réécrit pas. Sites vus : $sites');
      // 🔴 Non-vacuité : si le motif ne trouvait RIEN, l'égalité ci-dessus
      // aurait rougi — mais l'inverse (motif trop large) ne se verrait pas.
      expect(sites, hasLength(1));
    });

    test('aucune déclaration de partage/impression dans `zcrud_chat`', () {
      // Plus large que le seul nom : un doublon se renomme.
      final RegExp sharing = RegExp(
        r'\bclass\s+\w*(Share|Print)\w*Service\b|'
        r'\bPrinting\.\w+|'
        r"import\s+'package:printing/",
      );
      final List<String> offenders = <String>[
        for (final MapEntry<String, List<String>> e in strippedLib().entries)
          for (int i = 0; i < e.value.length; i++)
            if (sharing.hasMatch(e.value[i])) '${e.key}:${i + 1}',
      ];
      expect(offenders, isEmpty,
          reason: '🔴 un service de partage renommé reste un DOUBLON.\n'
              '${offenders.join('\n')}');
    });

    test('`ZChatAttachment` n\'est déclaré QUE dans le kernel', () {
      final List<String> sites = declarationsOf('ZChatAttachment', sources);
      expect(sites, <String>[
        'packages/zcrud_chat_kernel/lib/src/domain/z_chat_attachment.dart',
      ], reason: '🔴 le modèle de pièce jointe PERSISTÉE appartient au kernel '
          '(livré par CHAT-0). Le redéclarer ici créerait deux définitions du '
          'même fait, qui divergeraient au premier champ ajouté. Sites vus : '
          '$sites');
    });

    test('`ZPendingAttachment` n\'est PAS un `ZChatAttachment` déguisé', () {
      // 🔴 La règle « ne redéclare pas » n'interdit pas d'introduire un type
      // VOISIN — elle interdit d'en introduire un ÉQUIVALENT. La preuve doit
      // donc porter sur la SUBSTANCE, pas sur le nom : le type amont porte des
      // OCTETS et n'a ni identité ni URL, sans quoi c'est bien un doublon.
      final String src =
          stripped(libFile('attachment/z_pending_attachment.dart')).join('\n');
      expect(RegExp(r'final\s+Uint8List\s+bytes\b').hasMatch(src), isTrue,
          reason: '🔴 sans octets, ce type n\'a plus de raison d\'exister à '
              'côté de `ZChatAttachment` : ce SERAIT un doublon');
      for (final String forbidden in <String>[
        r'final\s+String\s+url\b',
        r'final\s+String\s+id\b',
        r'\btoJson\s*\(',
      ]) {
        expect(RegExp(forbidden).hasMatch(src), isFalse,
            reason: '🔴 `$forbidden` dans le type AMONT : il devient un clone '
                'de l\'entité persistée du kernel');
      }
    });

    test('🔬 contre-preuve — le détecteur de déclaration VOIT ses témoins', () {
      const Map<String, String> witnesses = <String, String>{
        'a.dart': 'class ZPdfShareService {\n}\n',
        'b.dart': 'abstract class ZPdfShareService {\n}\n',
        'c.dart': 'sealed class ZPdfShareService {}\n',
      };
      expect(declarationsOf('ZPdfShareService', witnesses),
          <String>['a.dart', 'b.dart', 'c.dart']);
      // …et une simple MENTION n'est pas une déclaration (une garde qui crie
      // au loup finit désactivée : tout ce fichier de ports en parle en prose).
      expect(
        declarationsOf('ZPdfShareService', <String, String>{
          'd.dart': 'final ZPdfShareService s = const ZPdfShareService();',
          'e.dart': '/// délègue à `ZPdfShareService` (zcrud_export_ui).',
        }),
        isEmpty,
      );
    });
  });

  group('🔴 G-C5-2 — AUCUNE dépendance tierce, même INDIRECTE (AD-1/AD-57)',
      () {
    /// 🔴 **DÉFAUT DE GARDE TROUVÉ, et corrigé ici.** `z_chat_purity_test.dart`
    /// n'exige que « `flutter` ou un paquet `zcrud_*` ». Or `zcrud_export`
    /// tire **Syncfusion** et `zcrud_export_ui` tire **`printing`** : ajouter
    /// `zcrud_export_ui: ^0.29.0` au pubspec aurait fait entrer un moteur PDF
    /// complet dans `zcrud_chat` **en restant VERT** sur la garde existante —
    /// le préfixe `zcrud_` ne dit RIEN de ce que le paquet traîne derrière lui.
    /// La cible n'est donc pas baissée mais RESSERRÉE : la liste des arêtes
    /// sortantes est close, en ÉGALITÉ d'ensemble.
    const Set<String> allowedEdges = <String>{
      'flutter',
      'zcrud_chat_kernel',
      'zcrud_core',
    };

    test('les arêtes sortantes sont EXACTEMENT les trois admises', () {
      expect(declaredDependencies().toSet(), allowedEdges,
          reason: '🔴 ÉGALITÉ D\'ENSEMBLE. `zcrud_export` (Syncfusion), '
              '`zcrud_export_ui` (`printing`) et `zcrud_markdown` (Quill) '
              'portent le préfixe `zcrud_` et passeraient la garde de pureté '
              'existante — en tirant un moteur PDF ou un éditeur riche chez '
              'TOUT consommateur du chat. Le PDF et le partage passent par '
              '`ZChatPdfComposer` / `ZChatExportSink`.');
    });

    test('aucune SOURCE n\'importe un paquet zcrud hors des trois admises', () {
      // Une dépendance non déclarée mais importée compilerait par transitivité
      // du workspace melos, et le pubspec resterait innocent.
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (final String l in e.value) {
          final RegExpMatch? m = RegExp(
            """(?:import|export)\\s+['"]package:(zcrud_\\w+)/""",
          ).firstMatch(l.trimLeft());
          if (m == null) continue;
          if (!allowedEdges.contains(m.group(1))) {
            offenders.add('${e.key} → ${l.trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 import d\'un paquet zcrud non déclaré.\n'
              '${offenders.join('\n')}');
    });

    test('aucune mention de Syncfusion / printing / pdf en CODE', () {
      final RegExp thirdParty = RegExp(
        r"""['"]package:(syncfusion\w*|printing|pdf|image_picker|"""
        r"""file_picker|intl)/""",
      );
      final List<String> offenders = <String>[
        for (final MapEntry<String, List<String>> e in strippedLib().entries)
          for (int i = 0; i < e.value.length; i++)
            if (thirdParty.hasMatch(e.value[i])) '${e.key}:${i + 1}',
      ];
      expect(offenders, isEmpty,
          reason: '🔴 AD-57 : ni moteur PDF, ni sélecteur natif, ni `intl` '
              'dans ce package.\n${offenders.join('\n')}');
    });

    test('🔬 contre-preuve — le motif tiers voit ses témoins et épargne les '
        'formes conformes', () {
      final RegExp thirdParty = RegExp(
        r"""['"]package:(syncfusion\w*|printing|pdf|image_picker|"""
        r"""file_picker|intl)/""",
      );
      for (final String witness in <String>[
        "import 'package:printing/printing.dart';",
        "import 'package:syncfusion_flutter_pdf/pdf.dart';",
        "import 'package:image_picker/image_picker.dart';",
        "import 'package:intl/intl.dart';",
      ]) {
        expect(thirdParty.hasMatch(witness), isTrue,
            reason: '🔴 le motif est aveugle à `$witness`');
      }
      for (final String ok in <String>[
        "import 'package:zcrud_core/domain.dart';",
        '/// délègue à `ZPdfShareService` (`zcrud_export_ui`).',
        "  final String mime = 'application/pdf';",
      ]) {
        expect(thirdParty.hasMatch(ok), isFalse,
            reason: '🔴 FAUX POSITIF sur `$ok`');
      }
    });
  });

  group('🔴 G-C5-3 — la BANDE de pièces jointes respecte AD-13 (SOURCE)', () {
    const String strip = 'lib/src/presentation/view/z_chat_attachment_strip.dart';

    test('elle existe et vit dans le régime « rendu »', () {
      // 🔴 Non-vacuité : toutes les gardes ci-dessous seraient muettes sur un
      // fichier absent, et `z_chat_purity_test.dart` cesserait de le couvrir
      // s'il sortait de `presentation/view/`.
      expect(libFile(strip).existsSync(), isTrue);
    });

    test('la cible tactile est ADOSSÉE à la constante partagée, pas recopiée',
        () {
      final String src = stripped(libFile(strip)).join('\n');
      expect(src, contains('kZChatMinTapTarget'),
          reason: '🔴 un `48.0` recopié divergerait le jour où la constante '
              'bouge — et personne ne le verrait');
      expect(RegExp(r'minHeight:\s*\d').hasMatch(src), isFalse,
          reason: '🔴 contrainte tactile en LITTÉRAL');
    });

    test('aucune forme non directionnelle (AD-13)', () {
      // Redondant avec `z_chat_purity_test.dart` par construction, mais ancré
      // sur CE fichier : si la partition de la garde de pureté évoluait, la
      // bande resterait couverte.
      final String src = stripped(libFile(strip)).join('\n');
      for (final String forbidden in <String>[
        r'EdgeInsets\.only\(\s*(left|right):',
        r'Alignment\.center(Left|Right)\b',
        r'TextAlign\.(left|right)\b',
        r'Positioned\(\s*(left|right):',
      ]) {
        expect(RegExp(forbidden).hasMatch(src), isFalse,
            reason: '🔴 `$forbidden` — la bande serait à l\'envers en RTL');
      }
      // …et les variantes DIRECTIONNELLES sont bien présentes (non-vacuité).
      expect(src, contains('EdgeInsetsDirectional'));
      expect(src, contains('AlignmentDirectional'));
    });

    test('la liste est VIRTUALISÉE', () {
      expect(stripped(libFile(strip)).join('\n'), contains('ListView.builder('),
          reason: '🔴 cinq pièces aujourd\'hui, mais la borne est un PARAMÈTRE : '
              'une liste eager monterait tout ce qu\'un hôte y met');
    });
  });

  group('🔴 G-C5-4 — la couture d\'export ne fuit AUCUN type tiers', () {
    test('les signatures des ports sont 100 % neutres', () {
      final String ports =
          stripped(libFile('export/z_chat_export_ports.dart')).join('\n');
      // La leçon de `zcrud_export_ui` : c'est l'ABSORPTION du type tiers qui
      // rend le confinement vérifiable. Ici il n'y a rien à absorber — mais la
      // garde doit interdire qu'on en fasse entrer un par la signature.
      for (final String leak in <String>[
        'PdfPageFormat',
        'PdfDocument',
        'pw.',
        'SfPdf',
      ]) {
        expect(ports.contains(leak), isFalse,
            reason: '🔴 `$leak` traverse la couture : le confinement est rompu');
      }
      expect(ports, contains('Uint8List'),
          reason: '🔴 GARDE VACUELLE : la couture ne transporte plus d\'octets');
    });

    test('le service NE met RIEN en page — il délègue', () {
      final String svc =
          stripped(libFile('export/z_chat_export_service.dart')).join('\n');
      expect(svc, contains('composer.compose('),
          reason: '🔴 GARDE VACUELLE : plus aucune délégation au compositeur');
      for (final String engine in <String>[
        'PdfDocument',
        'Document()',
        'PdfPage',
      ]) {
        expect(svc.contains(engine), isFalse,
            reason: '🔴 `$engine` : le socle s\'est mis à mettre en page');
      }
    });
  });
}

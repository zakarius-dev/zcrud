/// Lot « mode Tile + sélecteur de modèle » (arbitrage owner 2026-08-07) —
/// garde de **RE-EXPRESSION À ARBRE IDENTIQUE** (CR-LEX-78).
///
/// L'arbitrage 1 exige que les cinq familles standard de `ZChatSettingsSheet`
/// soient re-exprimées en interne sur le modèle `ZChatSettingsEntry` — **sans
/// que la feuille par défaut ne change d'un widget** : l'API publique actuelle
/// continue de compiler ET de rendre à l'identique.
///
/// ## Comment la garde tient sa promesse
///
/// 1. **AVANT** la re-expression, l'arbre de la feuille par défaut (état
///    exerçant sélections, deux niveaux de corpus, préréglages, capacités,
///    en-tête) a été **sérialisé** ([zChatSerializeTree]) et son empreinte
///    SHA-256 relevée : c'est [kZChatSettingsTreeSha256].
/// 2. **APRÈS**, le même montage doit produire la même empreinte — widget par
///    widget, libellé par libellé, style par style (graisse/soulignement CR-74
///    inclus, via le `TextStyle` des `RichText`).
/// 3. **NON-VACUITÉ** : un second volet prouve que le sérialiseur DISTINGUE —
///    la même feuille avec une seule tuile substituée produit une empreinte
///    différente. Une garde d'égalité qui accepterait tout serait le défaut
///    n°1 des 19 gardes vacantes démasquées cette semaine.
///
/// En cas de rouge, la sérialisation COMPLÈTE est écrite dans le répertoire
/// temporaire du test pour diff humain.
library;

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

/// L'arbre de la feuille PAR DÉFAUT, sérialisé et relevé AVANT la
/// re-expression (base 484 verte) — fichier de référence versionné.
///
/// 🔴 **Régénéré au lot CR-IFFD-75** (2026-08-07, base 510 verte) : correctif
/// de défaut SANCTIONNÉ — dégagement directionnel des deux actions de
/// l'en-tête (« RéinitialiserFermer » mesuré sur appareil) et repères du
/// budget rendus `Flexible` (débordement de 58 px mesuré à 280 dp). Le diff
/// avec l'étalon précédent a été vérifié à la main : LIMITÉ à ces deux sites
/// (Flexible + Padding autour des actions ; Flexible autour des trois
/// repères), aucun libellé, style ni nœud sémantique ne bouge.
///
/// ⚠️ Chemin RELATIF au dossier du package : c'est la convention du dépôt
/// (`flutter test` DOIT être lancé depuis `packages/zcrud_chat`, jamais depuis
/// la racine — cf. CLAUDE.md, mesuré le 2026-08-01).
const String kZChatSettingsTreeReferencePath =
    'test/support/z_chat_settings_tree_reference.txt';

/// Sérialise le sous-arbre de widgets sous [root] : type, libellés, marges,
/// contraintes, styles de texte (graisse + décoration — les canaux CR-74),
/// drapeaux sémantiques. Déterministe sous `flutter_test`.
String zChatSerializeTree(WidgetTester tester, Finder root) {
  final StringBuffer out = StringBuffer();
  void visit(Element element, int depth) {
    final Widget w = element.widget;
    final StringBuffer line = StringBuffer('${'  ' * depth}${w.runtimeType}');
    if (w is Text) line.write(' text=${w.data}');
    if (w is RichText) {
      final TextStyle? s = w.text.style;
      line.write(
        ' rich=${w.text.toPlainText()}'
        ' w=${s?.fontWeight} d=${s?.decoration} i=${s?.fontStyle}',
      );
    }
    if (w is Padding) line.write(' p=${w.padding}');
    if (w is SizedBox) line.write(' sz=${w.width}x${w.height}');
    if (w is ConstrainedBox) line.write(' c=${w.constraints}');
    if (w is Align) {
      line.write(' a=${w.alignment} wf=${w.widthFactor} hf=${w.heightFactor}');
    }
    if (w is Semantics) {
      final SemanticsProperties p = w.properties;
      line.write(
        ' sem[label=${p.label} sel=${p.selected} btn=${p.button}'
        ' en=${p.enabled} cont=${w.container}]',
      );
    }
    if (w is Wrap) line.write(' sp=${w.spacing}/${w.runSpacing}');
    out.writeln(line);
    element.visitChildren((Element child) => visit(child, depth + 1));
  }

  visit(tester.element(root), 0);
  return out.toString();
}

// ── Montage de RÉFÉRENCE — exerce les huit tuiles et les états choisis ──────

const List<ZChatCorpusOption> _catalogue = <ZChatCorpusOption>[
  ZChatCorpusOption(
    key: 'corpus-alpha',
    label: 'Alpha',
    children: <ZChatCorpusOption>[
      ZChatCorpusOption(key: 'corpus-alpha-un', label: 'Alpha-Un'),
      ZChatCorpusOption(
        key: 'corpus-alpha-deux',
        label: 'Alpha-Deux',
        enabled: false,
      ),
    ],
  ),
  ZChatCorpusOption(key: 'corpus-beta', label: 'Bêta'),
];

const List<ZChatSettingsPreset> _presets = <ZChatSettingsPreset>[
  ZChatSettingsPreset(
    id: 'p1',
    label: 'Préréglage Un',
    settings: ZChatGenerationSettings(
      responseLength: ZChatResponseLength.detailed,
    ),
  ),
];

const List<ZChatSettingsHostOption> _capacites = <ZChatSettingsHostOption>[
  ZChatSettingsHostOption(key: 'cap-hote', label: 'Capacité hôte'),
];

ZChatSettingsController _referenceController() {
  final ZChatSettingsController c = ZChatSettingsController();
  c.setResponseLength(ZChatResponseLength.concise);
  c.setComputeEffort(ZChatComputeEffort(2));
  c.setRevealThinkingSteps(true);
  c.toggleCorpusKey('corpus-alpha');
  c.toggleCorpusKey('corpus-alpha-un');
  return c;
}

/// Montage public — consommé aussi par l'outil de capture de l'étalon.
Widget referenceSheetForCapture(ZChatSettingsController c) => harness(
  // Le CONTENEUR appartient à l'hôte (F11) : la feuille complète dépasse le
  // viewport du testeur, l'hôte du montage la fait défiler.
  SingleChildScrollView(
    child: ZChatSettingsSheet(
      controller: c,
      corpusCatalog: _catalogue,
      presetCatalog: _presets,
      capabilityCatalog: _capacites,
      onClose: () {},
    ),
  ),
);

void main() {
  group('🔴 RX — re-expression des 5 familles à ARBRE IDENTIQUE (CR-LEX-78)',
      () {
    testWidgets(
        'RX-1 — la feuille PAR DÉFAUT rend, widget pour widget, l\'arbre '
        'relevé AVANT la re-expression', (WidgetTester tester) async {
      final ZChatSettingsController c = _referenceController();
      addTearDown(c.dispose);
      await tester.pumpWidget(referenceSheetForCapture(c));
      final String tree =
          zChatSerializeTree(tester, find.byType(ZChatSettingsSheet));
      final File reference = File(kZChatSettingsTreeReferencePath);
      expect(reference.existsSync(), isTrue,
          reason: '🔴 le fichier de référence de l\'arbre AVANT re-expression '
              'a disparu : la garde RX-1 n\'a plus d\'étalon.');
      final String expected = reference.readAsStringSync();
      if (tree != expected) {
        final File dump = File(
          '${Directory.systemTemp.path}/zchat_settings_tree_actual.txt',
        )..writeAsStringSync(tree);
        fail(
          '🔴 l\'arbre de la feuille PAR DÉFAUT a changé : la re-expression '
          'n\'est plus à l\'identique (ou une évolution ultérieure a modifié '
          'le rendu d\'un hôte passif). Étalon : ${reference.path} — arbre '
          'réel : ${dump.path} (diff humain possible).',
        );
      }
    });

    testWidgets(
        'RX-2 — NON-VACUITÉ : le sérialiseur DISTINGUE une feuille dont une '
        'seule tuile diffère', (WidgetTester tester) async {
      final ZChatSettingsController c = _referenceController();
      addTearDown(c.dispose);
      await tester.pumpWidget(referenceSheetForCapture(c));
      final String before =
          zChatSerializeTree(tester, find.byType(ZChatSettingsSheet));
      final ZChatSettingsController c2 = _referenceController();
      addTearDown(c2.dispose);
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: ZChatSettingsSheet(
            controller: c2,
            corpusCatalog: _catalogue,
            presetCatalog: _presets,
            capabilityCatalog: _capacites,
            onClose: () {},
            // Une SEULE tuile substituée : l'empreinte doit bouger.
            revealThinkingBuilder: (BuildContext _, ZChatSettingsSlot _) =>
                const SizedBox(width: 1, height: 1),
            ),
          ),
        ),
      );
      final String after =
          zChatSerializeTree(tester, find.byType(ZChatSettingsSheet));
      expect(before == after, isFalse,
          reason: '🔴 le sérialiseur ne distingue pas une tuile substituée : '
              'la garde RX-1 serait VACANTE.');
    });
  });
}

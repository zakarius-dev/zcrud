/// La **condition d'application** de la teinte d'un artefact : par défaut
/// l'état, sur déclaration la nature.
///
/// Ce que ce fichier prouve, garde par garde :
/// * **T1 — INERTIE** : sans le drapeau, rien ne bouge. Un artefact absent
///   rend la couleur AMBIANTE, un artefact présent rend son accent. Les deux
///   couleurs sont lues sur le `RenderParagraph` que l'`Icon` peint
///   réellement, jamais sur la propriété du widget.
/// * **T2 — EFFET** : drapeau posé, un artefact ABSENT porte son accent, et
///   deux natures différentes rendent deux couleurs différentes.
/// * **T3 — L'ANNONCE NE BOUGE PAS** : drapeau posé sur un artefact vide, le
///   glyphe est teint ET l'annonce dit toujours « aucun contenu ». C'est la
///   garde qui protège la raison d'être du canal : forcer la présence pour
///   teindre ferait annoncer « déjà généré » un artefact vide.
/// * **T4 — CONTRASTE** : la correction de lisibilité s'applique AUSSI à la
///   teinte d'un artefact absent. Le rapport est recalculé ici par une
///   implémentation indépendante de celle du socle.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

// ── Instruments ──────────────────────────────────────────────────────────

const IconData _iconA = IconData(0xE930);
const IconData _iconB = IconData(0xE931);

/// Deux teintes SOMBRES : elles tiennent déjà le plancher de contraste sur la
/// surface claire du harnais, donc la correction les rend INCHANGÉES — ce qui
/// autorise des égalités EXACTES sur ce qui est peint, sans jamais rappeler la
/// fonction de correction (qui rendrait la garde tautologique).
const Color _darkA = Color(0xFF004D40);
const Color _darkB = Color(0xFF311B92);

/// Une teinte vive qui NE tient PAS le plancher sur une surface claire : c'est
/// le témoin de T4. Si elle le tenait, la garde mesurerait du vide.
const Color _vif = Color(0xFFFF9800);

String _fb(String key) => kZChatLabelFallbacks[key]!;

/// La couleur **réellement peinte** sur le glyphe de [icon].
///
/// 🔴 Lue sur le `RenderParagraph` que l'`Icon` monte — pas sur `Icon.color`.
/// Un artefact non teinté passe `color: null` et la couleur ambiante n'est
/// résolue qu'au moment de peindre : une garde qui lirait la propriété du
/// widget rendrait `null` et ne verrait donc RIEN de ce que l'utilisateur voit.
Color? _painted(WidgetTester tester, IconData icon) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == icon,
        description: 'Icon($icon)',
      ),
      matching: find.byType(RichText),
    ),
  );
  return paragraph.text.style?.color;
}

/// Luminance relative WCAG 2.x — implémentation **indépendante** de celle du
/// socle : c'est ce qui empêche T4 d'être tautologique.
double _luminance(Color c) {
  double lin(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Ce qu'une montée rend au test : les couleurs ambiantes et la surface
/// résolues DANS l'arbre, pour que les assertions soient absolues.
class _Rig {
  const _Rig({required this.ambient, required this.surface});

  /// La couleur d'icône ambiante — celle que peint un glyphe non teinté.
  final Color? ambient;

  /// La surface contre laquelle le socle mesure tout contraste.
  final Color? surface;
}

/// Monte [artifacts] sur un message d'assistant et rend les valeurs ambiantes.
Future<_Rig> _mount(
  WidgetTester tester,
  List<ZChatArtifactSpec> artifacts,
) async {
  final rig = buildController(
    initialMessages: <ZChatMessage>[
      assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
    ],
  );
  addTearDown(rig.controller.dispose);
  Color? ambient;
  Color? surface;
  await tester.pumpWidget(
    harness(
      Builder(
        builder: (BuildContext context) {
          ambient = IconTheme.of(context).color;
          surface = ZcrudTheme.of(context).surfaceColor;
          return ZChatNotebookView(
            controller: rig.controller,
            artifacts: artifacts,
          );
        },
      ),
    ),
  );
  return _Rig(ambient: ambient, surface: surface);
}

/// Un artefact déclaré : [present] gouverne sa présence, [alwaysAccented] la
/// condition d'application de sa teinte. Le verbe « créer » est là pour que
/// l'entrée soit RENDUE même absente — sans lui, un artefact ni présent ni
/// actionnable n'entre pas dans l'arbre.
ZChatArtifactSpec _spec({
  required String key,
  required IconData icon,
  required Color accent,
  required bool present,
  bool alwaysAccented = false,
}) => ZChatArtifactSpec(
  key: key,
  icon: icon,
  label: key,
  accent: accent,
  alwaysAccented: alwaysAccented,
  presence: (ZChatMessage _) => present,
  actions: <ZChatArtifactAction>[
    ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
    ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
  ],
);

void main() {
  group('🔴 CR126-T1 — INERTIE : sans le drapeau, la teinte reste l\'ÉTAT', () {
    testWidgets('artefact absent ⇒ couleur AMBIANTE peinte ; artefact présent '
        '⇒ son accent peint', (WidgetTester tester) async {
      final _Rig rig = await _mount(tester, <ZChatArtifactSpec>[
        _spec(
          key: kZChatCapabilityMindmap,
          icon: _iconA,
          accent: _darkA,
          present: true,
        ),
        _spec(
          key: kZChatCapabilityFlashcards,
          icon: _iconB,
          accent: _darkB,
          present: false,
        ),
      ]);

      // Anti-vacuité : l'ambiante doit différer des deux accents, sinon
      // « absent = ambiant » et « absent = accent » seraient indiscernables.
      final Color? ambient = rig.ambient;
      expect(ambient, isNotNull);
      expect(ambient, isNot(_darkA));
      expect(ambient, isNot(_darkB));

      // Présent : l'accent, exactement (il tient déjà le plancher).
      expect(_painted(tester, _iconA), _darkA);
      // Absent : l'AMBIANTE, et surtout PAS l'accent déclaré.
      expect(_painted(tester, _iconB), ambient);
      expect(_painted(tester, _iconB), isNot(_darkB));
    });
  });

  group('🔴 CR126-T2 — EFFET : drapeau posé, la teinte dit la NATURE', () {
    testWidgets('deux artefacts ABSENTS portent CHACUN son accent, et les deux '
        'couleurs diffèrent', (WidgetTester tester) async {
      final _Rig rig = await _mount(tester, <ZChatArtifactSpec>[
        _spec(
          key: kZChatCapabilityMindmap,
          icon: _iconA,
          accent: _darkA,
          present: false,
          alwaysAccented: true,
        ),
        _spec(
          key: kZChatCapabilityFlashcards,
          icon: _iconB,
          accent: _darkB,
          present: false,
          alwaysAccented: true,
        ),
      ]);

      final Color? peintA = _painted(tester, _iconA);
      final Color? peintB = _painted(tester, _iconB);

      // Chaque nature porte SON accent — égalité exacte, les deux teintes
      // tenant déjà le plancher sur cette surface.
      expect(peintA, _darkA);
      expect(peintB, _darkB);
      // Et elles ne se confondent pas : c'est tout l'intérêt du canal — neuf
      // pictogrammes de même couleur se distinguent moins vite que neuf
      // couleurs.
      expect(peintA, isNot(peintB));
      // Ni l'une ni l'autre n'est retombée sur l'ambiante.
      expect(peintA, isNot(rig.ambient));
      expect(peintB, isNot(rig.ambient));
    });
  });

  group('🔴 CR126-T3 — L\'ANNONCE NE BOUGE PAS', () {
    testWidgets('drapeau posé sur un artefact VIDE : le glyphe est teint, et '
        'l\'annonce dit toujours « aucun contenu »', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _mount(tester, <ZChatArtifactSpec>[
        _spec(
          key: kZChatCapabilityMindmap,
          icon: _iconA,
          accent: _darkA,
          present: false,
          alwaysAccented: true,
        ),
      ]);

      // Anti-vacuité : la garde ne vaut que si la teinte A RÉELLEMENT bougé.
      // Sans cette assertion, elle resterait verte sur un canal inerte, et ne
      // prouverait rien de la séparation des deux canaux.
      expect(
        _painted(tester, _iconA),
        _darkA,
        reason: '🔴 le canal doit avoir teint un artefact ABSENT — sinon la '
            'garde ci-dessous ne mesure pas la séparation qu\'elle prétend '
            'protéger',
      );

      final SemanticsNode? node = findSemantics(
        tester,
        (SemanticsNode n) => n.label == kZChatCapabilityMindmap,
      );
      expect(node, isNotNull);
      expect(
        node!.value,
        contains(_fb(kZChatLabelArtifactEmpty)),
        reason: '🔴 un artefact vide s\'annonce VIDE, teinté ou non',
      );
      expect(
        node.value,
        isNot(contains(_fb(kZChatLabelGenerated))),
        reason: '🔴 teindre en forçant la présence ferait annoncer « déjà '
            'généré » un artefact SANS CONTENU — un mensonge au lecteur '
            'd\'écran. C\'est exactement ce que ce second canal évite.',
      );
      handle.dispose();
    });
  });

  group('🔴 CR126-T4 — CONTRASTE : la correction vaut AUSSI pour un absent', () {
    testWidgets('un artefact ABSENT teinté d\'une couleur trop claire est '
        'relevé au plancher, comme un artefact présent', (
      WidgetTester tester,
    ) async {
      final _Rig rig = await _mount(tester, <ZChatArtifactSpec>[
        _spec(
          key: kZChatCapabilityMindmap,
          icon: _iconA,
          accent: _vif,
          present: false,
          alwaysAccented: true,
        ),
      ]);

      final Color? surface = rig.surface;
      expect(surface, isNotNull);
      // Anti-vacuité : le témoin doit RÉELLEMENT être sous le plancher sur
      // cette surface, sinon la garde mesurerait du vide.
      expect(
        _ratio(_vif, surface!),
        lessThan(3),
        reason: '🔴 témoin mal choisi : cette teinte tient déjà le plancher, '
            'la garde ne mesurerait rien',
      );

      final Color? peint = _painted(tester, _iconA);
      expect(peint, isNotNull);
      // La teinte peinte n'est PAS la teinte brute…
      expect(peint, isNot(_vif));
      // …et elle tient le plancher §1.4.11 contre la surface réellement
      // résolue par le rendu. Rapport recalculé ici, sans jamais rappeler la
      // fonction de correction du socle.
      expect(_ratio(peint!, surface), greaterThanOrEqualTo(3));
    });
  });
}

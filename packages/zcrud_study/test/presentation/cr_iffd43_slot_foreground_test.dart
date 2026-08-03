// **CR-IFFD-43** — les slots d'hôte reçoivent le PREMIER PLAN voulu, y compris
// quand ils se stylent DEPUIS LE THÈME.
//
// 🔴 **L'angle mort que ces gardes visent explicitement, et qui a déjà coûté.**
// Sous l'injection du défaut exact, la suite CR-IFFD-41 était restée VERTE —
// 30/30 — parce que ses gardes montaient un `Text` **nu** et une `Icon` **nue**,
// deux chemins qui HÉRITENT et que le duo `DefaultTextStyle.merge` /
// `IconTheme.merge` couvrait déjà. Le contenu réellement cassé est celui qui
// suit la **bonne pratique** : `Theme.of(context).textTheme.titleSmall`,
// `Theme.of(context).iconTheme.color` — les rôles de `TextTheme` étant
// `inherit: false`, ils court-circuitent entièrement le `DefaultTextStyle`
// ambiant.
//
// Chaque garde principale monte donc un slot **stylé depuis le thème**, mesure
// la couleur **réellement peinte** sur le `RenderParagraph` (texte) ou sur le
// `RichText` interne de l'`Icon` (glyphe), et fait précéder la mesure d'un
// **contrôle de non-vacuité** : si la couleur ambiante valait déjà la couleur
// voulue, l'assertion ne prouverait rien.
//
// 🔴 **Piège du builder à DEUX appelants.** `_content` de `ZFlashcardListView`
// est invoqué par la question ET par l'aperçu de réponse. Un builder de test qui
// renverrait un widget à clé fixe ne mesurerait qu'un seul des deux sites tout
// en paraissant les couvrir : la clé est donc DÉRIVÉE DU TEXTE, et les deux
// sites sont assérés séparément.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Champ de recherche',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',
  readOnlyBadge: 'Lecture seule',
);

/// Thème d'essai.
///
/// 🔴 `zcrudTheme: true` installe un `ZcrudTheme` dont le `labelColor` est
/// **DÉRIVÉ** du schéma (`tertiary` — FR-26, aucun littéral). Sans lui, le repli
/// `ZcrudTheme.fallback` fixe `labelColor = textTheme.bodyMedium.color`,
/// c'est-à-dire **exactement la couleur ambiante** : le premier plan voulu par
/// la tuile serait alors indiscernable de celui qu'un slot cassé peindrait, et
/// la garde serait VACUELLE tout en paraissant verte.
ThemeData _theme({bool zcrudTheme = false}) {
  final ThemeData base = ThemeData(brightness: Brightness.light);
  if (!zcrudTheme) return base;
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      ZcrudTheme(labelColor: base.colorScheme.tertiary),
    ],
  );
}

Widget _harness(Widget child, {bool zcrudTheme = false}) => MaterialApp(
      theme: _theme(zcrudTheme: zcrudTheme),
      home: Scaffold(
        body: SizedBox(width: 1200, height: 800, child: child),
      ),
    );

/// Couleur RÉELLEMENT peinte du texte porté par [key] — jamais une intention
/// déclarée, jamais la présence d'un widget d'enveloppe.
Color? _textColor(WidgetTester tester, Key key) =>
    (tester.renderObject(find.byKey(key)) as RenderParagraph).text.style?.color;

/// Couleur RÉELLEMENT peinte du GLYPHE de l'`Icon` portée par [key] — mesurée
/// sur le `RichText` que l'`Icon` construit, et non sur `IconTheme.of(...)` :
/// un socle pourrait poser le bon `IconTheme` et néanmoins peindre autre chose.
Color? _glyphColor(WidgetTester tester, Key key) => (tester.renderObject(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(RichText),
              ),
            ) as RenderParagraph)
        .text
        .style
        ?.color;

// ---------------------------------------------------------------------------
// SITE 1 — `ZCountBadge.icon` (z_subfolder_item_chrome.dart)
// ---------------------------------------------------------------------------

const ValueKey<String> _kThemedIcon = ValueKey<String>('themed-icon');
const ValueKey<String> _kBareIcon = ValueKey<String>('bare-icon');

/// Icône d'hôte stylée **depuis le thème** — le chemin que le duo d'enveloppes
/// n'atteignait pas.
Widget _themedIcon() => Builder(
      builder: (BuildContext context) => Icon(
        Icons.style_outlined,
        key: _kThemedIcon,
        color: Theme.of(context).iconTheme.color,
      ),
    );

/// Icône d'hôte NUE — le chemin qui héritait déjà, et dont le rendu ne doit
/// **strictement pas** bouger.
Widget _bareIcon() => const Icon(Icons.style_outlined, key: _kBareIcon);

Future<void> _pumpBadge(WidgetTester tester, Widget icon) async {
  await tester.pumpWidget(
    _harness(
      Align(
        child: ZCountBadge(count: 3, icon: icon, semanticLabel: '3 cartes'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// La couleur que le badge VEUT imposer, telle que le widget la calcule.
Color _badgeForeground(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ZCountBadge)))
        .colorScheme
        .onSecondaryContainer;

// ---------------------------------------------------------------------------
// SITE 2 — slot AD-40 de `ZFlashcardListView` (z_flashcard_list_view.dart)
// ---------------------------------------------------------------------------

const String _kQuestion = 'QUESTION-SLOT';
const String _kAnswer = 'ANSWER-SLOT';

ValueKey<String> _slotKey(String text) => ValueKey<String>('slot:$text');

/// Slot AD-40 stylé **depuis le thème** (`textTheme.titleSmall`), à clé
/// DÉRIVÉE DU TEXTE : question et aperçu sont donc mesurables séparément.
Widget _themedSlot(BuildContext context, String text) => Text(
      text,
      key: _slotKey(text),
      style: Theme.of(context).textTheme.titleSmall,
    );

/// Slot AD-40 NU — hérite du `DefaultTextStyle`, rendu attendu INCHANGÉ.
Widget _bareSlot(BuildContext context, String text) =>
    Text(text, key: _slotKey(text));

Future<void> _pumpList(
  WidgetTester tester,
  ZFlashcardTileContentBuilder? builder,
) async {
  await tester.pumpWidget(
    _harness(
      zcrudTheme: true,
      ZFlashcardListView(
        cards: const <ZFlashcard>[
          ZFlashcard(id: 'c1', question: _kQuestion, answer: _kAnswer),
        ],
        labels: _labels,
        contentBuilder: builder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Le premier plan que la tuile VEUT imposer — calculé par la MÊME voie que le
/// widget (`ZcrudTheme.labelColor ?? scheme.onSurfaceVariant`), et lu AU-DESSUS
/// de la tuile : sous `ZForegroundOverride`, le `TextTheme` dont le repli de
/// `ZcrudTheme` dérive est justement réécrit.
Color _tileForeground(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(ZFlashcardListView));
  return ZcrudTheme.of(context).labelColor ??
      Theme.of(context).colorScheme.onSurfaceVariant;
}

void main() {
  group('CR-IFFD-43 · site 1 — `ZCountBadge.icon` (slot d\'hôte)', () {
    testWidgets(
        '🔴 une icône stylée depuis `Theme.of(c).iconTheme.color` est peinte '
        'dans le premier plan VOULU', (tester) async {
      // (a) NON-VACUITÉ : hors du badge, ce même chemin peint AUTRE CHOSE.
      //     Sans ce relevé, l'assertion (b) pourrait être vraie par accident.
      await tester.pumpWidget(_harness(Align(child: _themedIcon())));
      await tester.pumpAndSettle();
      final Color ambient = _glyphColor(tester, _kThemedIcon)!;

      await _pumpBadge(tester, _themedIcon());
      final Color wanted = _badgeForeground(tester);
      expect(
        ambient,
        isNot(wanted),
        reason: 'garde de non-vacuité : la couleur ambiante ne doit pas déjà '
            'valoir le premier plan voulu par le badge',
      );

      // (b) DANS le badge, la couleur PEINTE est celle du badge.
      expect(
        _glyphColor(tester, _kThemedIcon),
        wanted,
        reason: '🔴 CR-IFFD-42 rejouée : un `IconTheme.merge` n\'atteint que '
            'l\'icône qui HÉRITE ; celle qui lit `Theme.of(c).iconTheme` garde '
            'la couleur ambiante. Il faut `ZForegroundOverride`.',
      );
    });

    testWidgets(
        '🔴 NON-RÉGRESSION : une icône NUE rend EXACTEMENT comme avant '
        '(couleur ET taille)', (tester) async {
      await _pumpBadge(tester, _bareIcon());
      final Color wanted = _badgeForeground(tester);
      expect(_glyphColor(tester, _kBareIcon), wanted);

      // La taille imposée par le badge doit rester celle-là même qu'il calcule
      // (le duo d'enveloppes la posait via `IconTheme.merge(size:)`).
      final double wantedSize =
          IconTheme.of(tester.element(find.byKey(_kBareIcon))).size!;
      expect(
        tester.widget<Icon>(find.byKey(_kBareIcon)).size ?? wantedSize,
        wantedSize,
      );
      final RenderParagraph glyph = tester.renderObject(
        find.descendant(
          of: find.byKey(_kBareIcon),
          matching: find.byType(RichText),
        ),
      ) as RenderParagraph;
      expect(glyph.text.style?.fontSize, wantedSize);
    });
  });

  group('CR-IFFD-43 · site 2 — slot AD-40 de `ZFlashcardListView`', () {
    testWidgets(
        '🔴 un slot stylé depuis `textTheme.titleSmall` est peint dans le '
        'premier plan VOULU — question ET aperçu de réponse', (tester) async {
      // (a) NON-VACUITÉ : le même chemin, hors de la tuile, peint autre chose.
      await tester.pumpWidget(
        _harness(
          zcrudTheme: true,
          Align(
            child: Builder(
              builder: (BuildContext c) => _themedSlot(c, _kQuestion),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Color ambient = _textColor(tester, _slotKey(_kQuestion))!;

      await _pumpList(tester, _themedSlot);
      final Color wanted = _tileForeground(tester);
      expect(
        ambient,
        isNot(wanted),
        reason: 'garde de non-vacuité : la couleur ambiante ne doit pas déjà '
            'valoir le premier plan voulu par la tuile',
      );

      // (b) LES DEUX sites du slot — le builder est invoqué par la question ET
      //     par l'aperçu ; une clé fixe n'en aurait mesuré qu'un.
      expect(find.byKey(_slotKey(_kQuestion)), findsOneWidget);
      expect(find.byKey(_slotKey(_kAnswer)), findsOneWidget);
      expect(
        _textColor(tester, _slotKey(_kQuestion)),
        wanted,
        reason: '🔴 slot QUESTION : `DefaultTextStyle.merge` n\'atteint pas un '
            'texte stylé depuis `textTheme` (rôles `inherit: false`).',
      );
      expect(
        _textColor(tester, _slotKey(_kAnswer)),
        wanted,
        reason: '🔴 slot APERÇU DE RÉPONSE : même défaut, second site.',
      );
    });

    testWidgets(
        '🔴 NON-RÉGRESSION : un slot NU rend EXACTEMENT comme avant '
        '(question ET aperçu)', (tester) async {
      await _pumpList(tester, _bareSlot);
      final Color wanted = _tileForeground(tester);
      expect(_textColor(tester, _slotKey(_kQuestion)), wanted);
      expect(_textColor(tester, _slotKey(_kAnswer)), wanted);
    });

    testWidgets(
        'SANS slot injecté, le texte brut par défaut reste peint dans le '
        'premier plan voulu', (tester) async {
      // Le repli AD-40 (`Text` nu construit par la tuile elle-même) est le
      // troisième chemin : il ne doit pas non plus régresser.
      await _pumpList(tester, null);
      final Color wanted = _tileForeground(tester);
      final RenderParagraph p =
          tester.renderObject(find.text(_kQuestion)) as RenderParagraph;
      expect(p.text.style?.color, wanted);
    });
  });
}

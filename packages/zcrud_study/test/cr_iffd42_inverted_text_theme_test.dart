/// **CR-IFFD-42** — dans la barre de fratrie, l'inversion doit atteindre le
/// contenu stylé depuis `Theme.of(context).textTheme.*`.
///
/// 🔴 **Pourquoi CR-IFFD-41 était verte alors que l'hôte voyait du texte blanc
/// sur fond clair.** Ses gardes d'inversion montaient un `Text` **nu** (le
/// contenu par défaut du socle) et une `Icon` **nue** — deux chemins qui
/// HÉRITENT, donc deux chemins que `DefaultTextStyle.merge` +
/// `IconTheme.merge` couvraient déjà. Le chemin réellement cassé était celui de
/// l'hôte : `Text(x, style: Theme.of(context).textTheme.titleSmall)`, dont le
/// style porte sa propre couleur (`inherit: false`) et ignore purement et
/// simplement le `DefaultTextStyle` ambiant.
///
/// C'est l'exemple type de la garde qui « mesure bien, mais mesure à côté ». Ce
/// fichier monte donc l'`itemBuilder` **tel que l'hôte l'écrit** et mesure la
/// couleur RÉELLEMENT peinte.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Préréglage d'inversion — jamais un hex : un rôle, pas une couleur.
const ZcrudTheme _kInverted = ZcrudTheme(
  subfolderSelectedEmphasis: ZSubfolderSelectedEmphasis.inverted,
);

Widget Function(Widget) _scoped(ZcrudTheme theme) =>
    (Widget child) => ZcrudScope(theme: theme, child: child);

/// `itemBuilder` écrit **comme la documentation Material le recommande** :
/// typographie héritée du thème de l'application. C'est le chemin que le défaut
/// punissait.
Widget _hostItem(BuildContext context, ZSubfolderRef ref, bool selected) =>
    Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.folder, key: ValueKey<String>('ic:${ref.id}')),
        Text(
          ref.label,
          key: ValueKey<String>('styled:${ref.id}'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        TextButton(
          key: ValueKey<String>('btn:${ref.id}'),
          onPressed: null,
          child: Text('B:${ref.id}'),
        ),
      ],
    );

ZSubfolderNavSpec _spec(ZSubfolderItemBuilder builder) =>
    navSpec(itemBuilder: builder);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
  await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(
      tester.element(find.byKey(ZSubfolderSelectorBar.sheetKey)),
    ).colorScheme;

/// Finder PORTÉ à l'item [id] de la feuille.
///
/// ⚠️ Indispensable : le DÉCLENCHEUR invoque le **même** `itemBuilder` (avec
/// `selected: true`) et peint donc les mêmes clés. Une mesure non portée lirait
/// l'un pour l'autre — et resterait verte si l'item de la feuille n'était pas
/// inversé du tout.
Finder _in(String id, Key key) => find.descendant(
  of: find.descendant(
    of: find.byKey(ZSubfolderSelectorBar.sheetKey),
    matching: find.byKey(ZSubfolderSelectorBar.itemKey(id)),
  ),
  matching: find.byKey(key),
);

Color? _paintedColor(WidgetTester tester, Finder f) =>
    (tester.renderObject(f) as RenderParagraph).text.style?.color;

Color? _styledColor(WidgetTester tester, String id) =>
    _paintedColor(tester, _in(id, ValueKey<String>('styled:$id')));

Color? _glyphColor(WidgetTester tester, String id) => _paintedColor(
  tester,
  find.descendant(
    of: _in(id, ValueKey<String>('ic:$id')),
    matching: find.byType(RichText),
  ),
);

Color? _buttonColor(WidgetTester tester, String id) => _paintedColor(
  tester,
  find.descendant(
    of: _in(id, ValueKey<String>('btn:$id')),
    matching: find.text('B:$id'),
  ),
);

double _contrast(Color a, Color b) =>
    (a.computeLuminance() - b.computeLuminance()).abs();

/// Fond RÉELLEMENT peint derrière l'item [id].
Color? _itemBackground(WidgetTester tester, String id) {
  for (final Container c in tester.widgetList<Container>(
    find.descendant(
      of: find.descendant(
        of: find.byKey(ZSubfolderSelectorBar.sheetKey),
        matching: find.byKey(ZSubfolderSelectorBar.itemKey(id)),
      ),
      matching: find.byType(Container),
    ),
  )) {
    final Decoration? d = c.decoration;
    if (d is BoxDecoration && d.shape != BoxShape.circle && d.color != null) {
      return d.color;
    }
  }
  return null;
}

void main() {
  group('CR-IFFD-42 — le contenu stylé depuis `textTheme` est LISIBLE', () {
    testWidgets('🔴 `Theme.of(context).textTheme.titleSmall` est peint en '
        '`onInverseSurface` sur l\'élément courant', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(_hostItem),
        wrap: _scoped(_kInverted),
      );
      await _open(tester);

      final ColorScheme scheme = _scheme(tester);
      final Color? fg = _styledColor(tester, 'sf1');

      expect(fg, scheme.onInverseSurface);
      // CONTRÔLE NÉGATIF — l'item NON courant garde la couleur ambiante. Sans
      // lui, un socle qui inverserait tout le monde serait indiscernable, et la
      // garde ne dirait rien de la SÉLECTION.
      expect(_styledColor(tester, 'sf0'), isNot(scheme.onInverseSurface));
      // …et le contraste est RÉEL sur le fond effectivement peint.
      final Color? bg = _itemBackground(tester, 'sf1');
      expect(bg, scheme.inverseSurface);
      expect(_contrast(bg!, fg!), greaterThan(0.5));
    });

    testWidgets('le GLYPHE de l\'hôte est inversé lui aussi (non-régression '
        'CR-IFFD-41)', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(_hostItem),
        wrap: _scoped(_kInverted),
      );
      await _open(tester);

      final ColorScheme scheme = _scheme(tester);
      expect(_glyphColor(tester, 'sf1'), scheme.onInverseSurface);
      expect(_glyphColor(tester, 'sf0'), isNot(scheme.onInverseSurface));
    });

    testWidgets('EFFET DE BORD NON PRODUIT : le bouton de l\'hôte garde sa '
        'couleur de `ColorScheme`', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(_hostItem),
        wrap: _scoped(_kInverted),
      );
      await _open(tester);

      // Mesuré, pas supposé : l'enveloppe ne substitue PAS le `ColorScheme`,
      // donc un bouton dans la zone inversée rend exactement comme ailleurs.
      // C'est la limite documentée de la forme retenue.
      expect(_buttonColor(tester, 'sf1'), _buttonColor(tester, 'sf0'));
    });
  });

  group('CR-IFFD-42 — neutralité : sans inversion, rendu strictement '
      'inchangé', () {
    testWidgets('sans préréglage, le texte stylé de l\'hôte garde EXACTEMENT '
        'la couleur ambiante', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(_hostItem),
      );
      await _open(tester);

      final ColorScheme scheme = _scheme(tester);
      // L'emphase par défaut reste le SURLIGNAGE historique : fond teinté,
      // premier plan HÉRITÉ. Une enveloppe d'inversion posée par défaut
      // rougirait ici.
      expect(_itemBackground(tester, 'sf1'), scheme.secondaryContainer);
      expect(_styledColor(tester, 'sf1'), isNot(scheme.onInverseSurface));
      // …et STRICTEMENT identique à un item non courant : « inchangé » se
      // mesure par égalité, pas par « différent de l'inversion ».
      expect(_styledColor(tester, 'sf1'), _styledColor(tester, 'sf0'));
    });

    testWidgets('sans préréglage, aucune `ZInvertedSurface` dans l\'arbre', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        initialSelectedSubfolderId: 'sf1',
        nav: _spec(_hostItem),
      );
      await _open(tester);

      // « Absent de l'arbre » est la seule forme d'inchangé démontrable.
      expect(find.byType(ZInvertedSurface), findsNothing);
    });
  });
}

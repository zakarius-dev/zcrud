/// 🎯 Gardes PORTEUSES de l'ornement de TÊTE TEINTÉ du présentateur
/// (`ZSmartSelectPresenter` → `zResolveTintedAdornment` du cœur).
///
/// **La régression défendue** : la tuile du présentateur gardait une icône de
/// tête grise et nue là où la décoration native pastille et teinte le même
/// ornement dès que le résolveur de teinte et les jetons
/// `adornmentIconBackground*` sont déclarés — enrôler le présentateur perdait
/// donc la tête teintée.
///
/// 🔴 Anti-vacuité : l'étalon prouve que SANS déclaration rien ne bouge au
/// pixel (opt-in strict) ; les gardes actives prouvent la pastille ET la
/// normalisation de contraste (couleur illisible injectée → corrigée) ; la
/// gouvernance existante (orphelin, lecture seule vide) est mesurée AVEC la
/// pastille active ; le grep négatif prouve l'absence de duplication.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const List<ZFieldChoice> _abc = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Alpha'),
  ZFieldChoice(value: 'b', label: 'Bravo'),
  ZFieldChoice(value: 'c', label: 'Charlie'),
];

/// Libellé de la table `en` de repli du cœur pour la clé `choiceUnresolved`.
const String _enOrphanLabel = 'Option unavailable';

/// Couleur ILLISIBLE sur la surface claire par défaut — si elle ressort brute,
/// la normalisation du cœur a été contournée (ou dupliquée à côté).
const Color _jaune = Color(0xFFFFFF00);

ZGradientSpec? _jauneResolver(ColorScheme scheme, String key) =>
    key == zFieldTypeTintKey(EditionFieldType.select)
        ? const ZGradientSpec(
            gradient: LinearGradient(colors: [_jaune, _jaune]),
            onGradient: Color(0xFF000000),
          )
        : null;

const ZcrudTheme _pillTokens = ZcrudTheme(
  adornmentIconBackgroundAlpha: 0.12,
  adornmentIconBackgroundRadius: Radius.circular(8),
  adornmentIconSize: 18,
);

ZFieldSpec _spec({bool readOnly = false}) => ZFieldSpec(
      name: 'f',
      type: EditionFieldType.select,
      label: 'Mon champ',
      choices: _abc,
      leading: const ZFieldAdornment.icon('date'),
      readOnly: readOnly,
    );

Widget _host({
  required Widget child,
  ZGradientResolver? resolver,
  ZcrudTheme? theme,
}) {
  return MaterialApp(
    home: ZcrudScope(
      selectPresenter: const ZSmartSelectPresenter(),
      gradientResolver: resolver,
      theme: theme,
      child: Scaffold(body: child),
    ),
  );
}

Widget _selectField({Object? value, bool readOnly = false}) =>
    ZSelectFieldWidget(
      field: _spec(readOnly: readOnly),
      value: value,
      onChanged: (_) {},
    );

/// Le déclencheur du présentateur (`ListTile` sous `Card`).
final Finder _trigger = find
    .descendant(of: find.byType(Card), matching: find.byType(ListTile))
    .first;

/// La pastille de tête : le `DecoratedBox` du cœur, fond teinté atténué.
Finder get _pill => find.descendant(
      of: _trigger,
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color != null),
    );

/// Remonte jusqu'au dossier portant `melos.yaml` (convention du dépôt : jamais
/// un `../` relatif nu, le répertoire courant dépend du lanceur).
Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('🎯 ÉTALON — opt-in strict, tuile inchangée sans déclaration', () {
    testWidgets(
        'sans résolveur ni jetons : l\'ornement de tête est l\'Icon NUE '
        '(aucune couleur, aucune taille imposée, aucune pastille)',
        (tester) async {
      await tester.pumpWidget(_host(child: _selectField(value: 'a')));
      await tester.pumpAndSettle();
      final tile = tester.widget<ListTile>(_trigger);
      expect(tile.leading, isA<UnconstrainedBox>(),
          reason: 'le slot de tête est non contraint (placement de la tuile)');
      expect((tile.leading! as UnconstrainedBox).child, isA<Icon>(),
          reason: 'sans déclaration, la tête reste l\'icône telle quelle — '
              'aucune pastille intercalée');
      final icon = (tile.leading! as UnconstrainedBox).child! as Icon;
      expect(icon.color, isNull, reason: 'aucune teinte inventée');
      expect(icon.size, isNull, reason: 'aucune dimension imposée');
      // Au pixel : l'icône nue garde sa taille intrinsèque par défaut.
      expect(
        tester.getSize(
          find.descendant(
            of: _trigger,
            matching: find.byIcon(Icons.event_outlined),
          ),
        ),
        const Size(24, 24),
        reason: 'taille intrinsèque par défaut du glyphe — aucun pixel ne '
            'bouge sans déclaration',
      );
      expect(_pill, findsNothing, reason: 'aucune pastille sans jetons');
    });
  });

  group('🎯 CONTRAT — tête teintée et pastillée via le point d\'entrée du cœur',
      () {
    testWidgets(
        'teinte + jetons : pastille (teinte atténuée, rayon, insets '
        'directionnels), glyphe teinté NORMALISÉ (le jaune illisible injecté '
        'n\'est jamais rendu brut) et dimensionné', (tester) async {
      await tester.pumpWidget(_host(
        child: _selectField(value: 'a'),
        resolver: _jauneResolver,
        theme: _pillTokens,
      ));
      await tester.pumpAndSettle();
      final tile = tester.widget<ListTile>(_trigger);
      expect(tile.leading, isA<UnconstrainedBox>(),
          reason: 'le slot de tête est non contraint (placement de la tuile)');
      final head = (tile.leading! as UnconstrainedBox).child;
      expect(head, isA<Center>(),
          reason: 'la pastille épouse le glyphe (même structure que la '
              'décoration native)');
      final box = (head! as Center).child! as DecoratedBox;
      final deco = box.decoration as BoxDecoration;
      final padding = box.child! as Padding;
      final icon = padding.child! as Icon;

      // Normalisation : la couleur servie était illisible — elle est corrigée
      // par le cœur, jamais rendue brute, et tient le plancher non-texte.
      final Color tint = icon.color!;
      expect(tint, isNot(_jaune),
          reason: 'une couleur illisible n\'est JAMAIS rendue brute');
      final surface = ThemeData().colorScheme.surfaceContainerHighest;
      expect(zContrastRatio(tint, surface),
          greaterThanOrEqualTo(kZNonTextMinContrast),
          reason: 'plancher non-texte tenu contre la surface du champ');

      expect(deco.color, tint.withValues(alpha: 0.12),
          reason: 'le fond de pastille est la MÊME teinte, atténuée — une '
              'seule chaîne de résolution');
      expect(deco.borderRadius, const BorderRadius.all(Radius.circular(8)));
      expect(padding.padding, const EdgeInsetsDirectional.all(7),
          reason: 'insets DIRECTIONNELS (AD-13)');
      expect(icon.size, 18);

      // Ordre de composition : la pastille n'écrase pas la VALEUR de la tuile.
      expect(
        find.descendant(of: _trigger, matching: find.text('Alpha')),
        findsOneWidget,
        reason: 'le sous-titre (valeur) reste rendu, pastille active',
      );
    });

    testWidgets(
        'gouvernance orphelin : la valeur hors catalogue reste SIGNALÉE, '
        'pastille active — la tête teintée n\'écrase aucun signal',
        (tester) async {
      await tester.pumpWidget(_host(
        child: _selectField(value: 'zzz-disparu'),
        resolver: _jauneResolver,
        theme: _pillTokens,
      ));
      await tester.pumpAndSettle();
      // La mention d'indisponibilité EST rendue dans le déclencheur…
      expect(
        find.descendant(of: _trigger, matching: find.text(_enOrphanLabel)),
        findsOneWidget,
        reason: 'l\'ornement de tête ne supplante pas le signal d\'orphelin',
      );
      // …le placeholder de l'état vide NE l'est PAS…
      expect(find.text('Select'), findsNothing);
      // …ET la pastille est bien montée en même temps (les deux coexistent).
      expect(_pill, findsWidgets,
          reason: 'la pastille et le signal d\'orphelin coexistent');
    });

    testWidgets(
        'gouvernance lecture seule vide : la tuile DISPARAÎT, teinte et '
        'jetons posés — le court-circuit précède le slot de tête',
        (tester) async {
      await tester.pumpWidget(_host(
        child: _selectField(readOnly: true),
        resolver: _jauneResolver,
        theme: _pillTokens,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing,
          reason: 'lecture seule sans valeur ⇒ tuile absente, pastille ou '
              'pas (parité de référence conservée)');
    });
  });

  group('🚧 GARDE DE SOURCE — aucune duplication de la chaîne du cœur', () {
    test(
        'le présentateur consomme `zResolveTintedAdornment` et ne recopie ni '
        'la normalisation, ni la résolution d\'icône, ni une table locale',
        () {
      final src = File(
        '${_repoRoot().path}/packages/zcrud_select/lib/src/presentation/'
        'z_smart_select_presenter.dart',
      ).readAsStringSync();
      expect(src.contains('zResolveTintedAdornment('), isTrue,
          reason: 'la tête de tuile passe par le point d\'entrée du cœur');
      // Grep négatif : la chaîne de teinte vit dans le cœur, une seule fois.
      // (les mentions en commentaire `//` sont exclues du corpus mesuré)
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final banni in <String>[
        'zReadableTintOn',
        'zContrastRatio',
        'zResolveAdornmentIcon',
        'zFieldTypeTintKey',
        'Map<String, IconData>',
      ]) {
        expect(code.contains(banni), isFalse,
            reason: '« $banni » dans le présentateur = duplication de la '
                'chaîne du cœur');
      }
    });
  });
}

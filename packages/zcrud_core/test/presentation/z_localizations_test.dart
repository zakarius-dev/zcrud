// AC3 : delegate l10n GÉNÉRIQUE (aucune ressource métier) + composition `label`.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Termes MÉTIER interdits dans les libellés du cœur (liste sentinelle FR-23).
const _businessTerms = <String>[
  'douane',
  'étude',
  'etude',
  'flashcard',
  'mindmap',
  'declaration',
  'déclaration',
  'tarif',
  'facture',
];

const _delegate = ZcrudLocalizationsDelegate();

Future<ZcrudLocalizations> _load(Locale locale) => _delegate.load(locale);

void main() {
  test('isSupported en/fr = true, autres = false (AC3)', () {
    expect(_delegate.isSupported(const Locale('en')), isTrue);
    expect(_delegate.isSupported(const Locale('fr')), isTrue);
    expect(_delegate.isSupported(const Locale('de')), isFalse);
  });

  test('shouldReload = false (AC3)', () {
    expect(_delegate.shouldReload(const ZcrudLocalizationsDelegate()), isFalse);
  });

  test('load(fr)/load(en) : libellés génériques non vides et localisés (AC3)',
      () async {
    final fr = await _load(const Locale('fr'));
    final en = await _load(const Locale('en'));
    for (final key in <String>['save', 'cancel', 'delete', 'required',
      'invalidValue', 'loading', 'empty']) {
      expect(fr.resolve(key), isNotEmpty, reason: 'fr[$key] vide');
      expect(en.resolve(key), isNotEmpty, reason: 'en[$key] vide');
    }
    // Localisation effective : FR ≠ EN sur un libellé de référence.
    expect(fr.resolve('save'), isNot(en.resolve('save')));
    expect(fr.resolve('save'), 'Enregistrer');
    expect(en.resolve('save'), 'Save');
  });

  test('resolve(clé inconnue) = la clé, jamais de throw (AC3)', () async {
    final fr = await _load(const Locale('fr'));
    expect(fr.resolve('__inexistant__'), '__inexistant__');
    expect(fr.maybeResolve('__inexistant__'), isNull);
  });

  test('ZÉRO terme métier dans les tables du delegate (AC3)', () async {
    // L-4 : itère la TABLE RÉELLE du delegate (clés effectivement livrées via
    // `ZcrudLocalizations.keys`) au lieu d'une liste de clés dupliquée — une
    // future clé à terme métier ajoutée à `_enLabels`/`_frLabels` ne peut plus
    // échapper à la sentinelle.
    for (final locale in ZcrudLocalizationsDelegate.supportedLocales) {
      final loc = await _load(locale);
      final keys = loc.keys.toList();
      expect(keys, isNotEmpty, reason: 'table [$locale] vide (delegate vide ?)');
      for (final key in keys) {
        final value = loc.resolve(key).toLowerCase();
        final lowerKey = key.toLowerCase();
        for (final term in _businessTerms) {
          expect(value.contains(term), isFalse,
              reason: '[$locale] valeur "$value" contient le terme métier "$term"');
          expect(lowerKey.contains(term), isFalse,
              reason: '[$locale] clé "$key" contient le terme métier "$term"');
        }
      }
    }
  });

  testWidgets('label(context,key) : delegate monté → libellé locale-aware (AC3/AC4)',
      (tester) async {
    late String resolved;
    late String unknown;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('fr'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          ZcrudLocalizationsDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            child: Builder(builder: (context) {
              resolved = label(context, 'save');
              unknown = label(context, '__nope__', fallback: 'X');
              return const SizedBox();
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(resolved, 'Enregistrer');
    expect(unknown, 'X');
  });

  testWidgets('label(context,key) SANS delegate monté → repli `en` intégré, '
      'pas la clé brute (L-1)', (tester) async {
    late String resolved;
    late String unknown;
    // Aucun ZcrudLocalizationsDelegate monté : le repli `en` de
    // `ZcrudLocalizations.of` doit être honoré par `label()`.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          child: Builder(builder: (context) {
            resolved = label(context, 'save');
            unknown = label(context, '__nope__', fallback: 'X');
            return const SizedBox();
          }),
        ),
      ),
    );
    await tester.pump();
    // Repli `en` intégré : 'save' → 'Save' (et surtout PAS la clé brute 'save').
    expect(resolved, 'Save');
    expect(resolved, isNot('save'));
    // Clé inconnue : dernier recours = fallback fourni.
    expect(unknown, 'X');
  });
}

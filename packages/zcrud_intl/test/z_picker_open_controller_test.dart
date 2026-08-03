// ZDisplayState (CR-IFFD-38) — `openController` sur les DEUX sélecteurs intl :
// `ZCountryPickerField` (via `ZCountryFieldWidget`) et `ZOptionPickerField`
// (via `ZCurrencyField`). Les pickers sont **internes** : on les mesure donc à
// travers les champs exportés, ce qui garde les gardes sur la surface que
// l'hôte utilise réellement.
//
// Ce qui est mesuré (et pourquoi) :
//  - SANS contrôleur, comportement **strictement inchangé** ;
//  - commander l'ouverture **ouvre réellement l'ARBRE RENDU** (la liste existe),
//    jamais « un champ a changé » ;
//  - toute fermeture décidée par le composant (sélection, `readOnly`) **revient
//    dans le contrôleur** — sinon l'hôte croit le sélecteur ouvert ;
//  - RTL **réel** (délégué de localisations, pas un `Directionality` posé sous
//    `MaterialApp` : ce dernier ne prouverait rien pour une surface flottante) ;
//  - cible ≥ 48 dp **bornée par le haut** + **contrôle négatif** (sans quoi la
//    garde mesurerait un plancher imposé par le parent ou le SDK) ;
//  - aucun contrôleur créé dans `build` (clause 4 du patron, mordante ici).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

ZCountryCatalog _countries() => ZCountryCatalog.fromList(const <ZCountryInfo>[
      ZCountryInfo(isoCode: 'NE', name: 'Niger', dialCode: '+227', flagEmoji: '🇳🇪'),
      ZCountryInfo(isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
    ]);

ZCurrencyCatalog _currencies() =>
    ZCurrencyCatalog.fromList(const <ZCurrencyInfo>[
      ZCurrencyInfo(code: 'XOF', name: 'Franc CFA', symbol: 'CFA', decimalDigits: 0),
      ZCurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', decimalDigits: 2),
    ]);

ZFieldSpec _spec({bool readOnly = false}) => ZFieldSpec(
      name: 'f',
      type: EditionFieldType.text,
      label: 'Champ',
      readOnly: readOnly,
    );

// ───────────────────────────── RTL réel ─────────────────────────────
// Un `Directionality` posé sous `MaterialApp` ne descend PAS dans une surface
// rendue par l'`Overlay`. On impose donc la direction par le canal que TOUTE
// surface hérite : les `WidgetsLocalizations`.
class _RtlWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _RtlWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;
}

class _RtlDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RtlDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) async =>
      const _RtlWidgetsLocalizations();

  @override
  bool shouldReload(_RtlDelegate old) => false;
}

// ─────────────────────── hôte possédant le contrôleur ───────────────────────

/// Hôte conforme au patron : le contrôleur est créé dans un CHAMP du `State`
/// (donc hors `build`), possédé et disposé par le mixin.
class _Host extends StatefulWidget {
  const _Host({
    required this.child,
    this.rtl = false,
    this.withController = true,
    this.negativeControl = false,
  });

  /// Construit le champ testé à partir du contrôleur (ou de `null`).
  final Widget Function(ZToggleController? open) child;
  final bool rtl;
  final bool withController;

  /// Ajoute un `Text` nu à côté du champ : s'il mesure < 48 dp, c'est la preuve
  /// que le harnais n'impose AUCUN plancher de hauteur (contrôle négatif).
  final bool negativeControl;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ZDisplayStateOwnerMixin<_Host> {
  late final ZToggleController? open = widget.withController
      ? ZToggleController(owner: this, debugLabel: 'open')
      : null;

  @override
  Widget build(BuildContext context) => MaterialApp(
        localizationsDelegates: widget.rtl
            ? <LocalizationsDelegate<Object>>[
                const _RtlDelegate(),
                DefaultMaterialLocalizations.delegate,
              ]
            : null,
        home: ZcrudScope(
          child: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                widget.child(open),
                if (widget.negativeControl)
                  const Text('t', key: Key('negative-control')),
              ],
            ),
          ),
        ),
      );
}

/// Monte le champ PAYS et renvoie l'état de l'hôte (pour commander).
Future<_HostState> _pumpCountry(
  WidgetTester t, {
  bool withController = true,
  bool readOnly = false,
  bool rtl = false,
  bool negativeControl = false,
  ValueChanged<Object?>? onChanged,
  String? value,
  bool settle = true,
}) async {
  final cat = _countries();
  await t.pumpWidget(_Host(
    rtl: rtl,
    withController: withController,
    negativeControl: negativeControl,
    child: (open) => ZCountryFieldWidget(
      ctx: ZFieldWidgetContext(
        field: _spec(readOnly: readOnly),
        value: value,
        onChanged: onChanged ?? (_) {},
      ),
      catalog: cat,
      openController: open,
    ),
  ));
  if (settle) await t.pumpAndSettle();
  return t.state<_HostState>(find.byType(_Host));
}

/// Monte le champ DEVISE (picker générique) et renvoie l'état de l'hôte.
Future<_HostState> _pumpCurrency(
  WidgetTester t, {
  bool withController = true,
  bool readOnly = false,
  ValueChanged<Object?>? onChanged,
  bool settle = true,
}) async {
  final cat = _currencies();
  await t.pumpWidget(_Host(
    withController: withController,
    child: (open) => ZCurrencyField(
      ctx: ZFieldWidgetContext(
        field: _spec(readOnly: readOnly),
        value: null,
        onChanged: onChanged ?? (_) {},
      ),
      catalog: cat,
      openController: open,
    ),
  ));
  if (settle) await t.pumpAndSettle();
  return t.state<_HostState>(find.byType(_Host));
}

final Finder _countryList = find.byKey(const Key('z-country-item-FR'));
final Finder _currencyList = find.byKey(const Key('z-currency-item-EUR'));
final Finder _countryTrigger = find.byKey(const Key('z-country-picker-trigger'));
final Finder _currencyTrigger = find.byKey(const Key('z-currency-trigger'));

void main() {
  group('rétro-compat — SANS contrôleur, comportement strictement inchangé', () {
    testWidgets('pays : tap ouvre, re-tap ferme (aucun contrôleur fourni)',
        (t) async {
      await _pumpCountry(t, withController: false);
      expect(_countryList, findsNothing);
      await t.tap(_countryTrigger);
      await t.pump();
      expect(_countryList, findsOneWidget, reason: 'le tap doit déplier');
      await t.tap(_countryTrigger);
      await t.pump();
      expect(_countryList, findsNothing, reason: 're-tap doit replier');
    });

    testWidgets('devise : tap ouvre, re-tap ferme (aucun contrôleur fourni)',
        (t) async {
      await _pumpCurrency(t, withController: false);
      expect(_currencyList, findsNothing);
      await t.tap(_currencyTrigger);
      await t.pump();
      expect(_currencyList, findsOneWidget);
      await t.tap(_currencyTrigger);
      await t.pump();
      expect(_currencyList, findsNothing);
    });
  });

  group('la commande AGIT sur l\'arbre rendu', () {
    testWidgets('pays : set() déplie RÉELLEMENT, clear() replie', (t) async {
      final host = await _pumpCountry(t);
      expect(_countryList, findsNothing);

      host.open!.set();
      await t.pump();
      expect(_countryList, findsOneWidget,
          reason: 'commander l\'ouverture doit monter la liste dans l\'arbre');

      host.open!.clear();
      await t.pump();
      expect(_countryList, findsNothing,
          reason: 'commander la fermeture doit démonter la liste');
    });

    testWidgets('devise : set() déplie RÉELLEMENT, clear() replie', (t) async {
      final host = await _pumpCurrency(t);
      expect(_currencyList, findsNothing);
      host.open!.set();
      await t.pump();
      expect(_currencyList, findsOneWidget);
      host.open!.clear();
      await t.pump();
      expect(_currencyList, findsNothing);
    });

    testWidgets('le tap utilisateur REMONTE dans le contrôleur (source unique)',
        (t) async {
      final host = await _pumpCountry(t);
      expect(host.open!.value, isFalse);
      await t.tap(_countryTrigger);
      await t.pump();
      expect(host.open!.value, isTrue,
          reason: 'le contrôleur est LA source de vérité, pas un miroir tardif');
      expect(_countryList, findsOneWidget);
    });
  });

  group('toute fermeture décidée par le composant revient dans le contrôleur',
      () {
    testWidgets('pays : la sélection ferme ET notifie l\'hôte', (t) async {
      Object? slice;
      final host = await _pumpCountry(t, onChanged: (v) => slice = v);
      host.open!.set();
      await t.pump();
      expect(_countryList, findsOneWidget);

      await t.tap(_countryList);
      await t.pump();

      expect(slice, 'FR', reason: 'la notification sortante est CONSERVÉE');
      expect(_countryList, findsNothing, reason: 'la sélection referme');
      expect(host.open!.value, isFalse,
          reason: 'sans ce retour, l\'hôte croirait le sélecteur encore ouvert');
    });

    testWidgets('devise : la sélection ferme ET notifie l\'hôte', (t) async {
      Object? slice;
      final host = await _pumpCurrency(t, onChanged: (v) => slice = v);
      host.open!.set();
      await t.pump();
      await t.tap(_currencyList);
      await t.pump();
      expect(slice, 'EUR');
      expect(_currencyList, findsNothing);
      expect(host.open!.value, isFalse);
    });

    testWidgets(
        'readOnly : une ouverture commandée ne déplie pas ET le contrôleur '
        'est REMIS à false (l\'hôte n\'est pas trompé)', (t) async {
      final host = await _pumpCountry(t, readOnly: true);
      host.open!.set();
      expect(host.open!.value, isTrue);

      await t.pumpAndSettle();

      expect(_countryList, findsNothing,
          reason: 'readOnly prime : le panneau ne se déplie jamais');
      expect(host.open!.value, isFalse,
          reason: 'le refus doit être RENDU au contrôleur, pas avalé');
    });
  });

  // 🔴 R3 : `ZDisplayStateBinding.bind()` sort tôt si le contrôleur est
  // `identical` au courant — `bind(null)` en `initState` est donc un NO-OP, et
  // le premier `didUpdateWidget` RÉPARE silencieusement la liaison. Une garde
  // qui commande après un `pumpAndSettle` ne voit donc RIEN : elle mesure la
  // liaison d'après-rebuild. Les gardes ci-dessous commandent sur la PREMIÈRE
  // frame — c'est le cas d'usage « restauration d'état » du brief.
  group('branchement dès `initState`, AVANT tout rebuild', () {
    testWidgets('pays : consommé au montage, commande vive sur la 1re frame',
        (t) async {
      final host = await _pumpCountry(t, settle: false);
      expect(host.open!.consumerCount, 1,
          reason: 'le picker doit se brancher en initState, pas au 1er rebuild');
      host.open!.set();
      await t.pump();
      expect(_countryList, findsOneWidget,
          reason: 'une commande émise avant tout rebuild doit déjà agir');
    });

    testWidgets('devise : consommé au montage, commande vive sur la 1re frame',
        (t) async {
      final host = await _pumpCurrency(t, settle: false);
      expect(host.open!.consumerCount, 1,
          reason: 'le picker doit se brancher en initState, pas au 1er rebuild');
      host.open!.set();
      await t.pump();
      expect(_currencyList, findsOneWidget,
          reason: 'une commande émise avant tout rebuild doit déjà agir');
    });
  });

  group('AD-13 — RTL réel et cibles bornées', () {
    testWidgets('RTL (délégué de localisations) : le chevron passe au DÉBUT',
        (t) async {
      // On mesure la GÉOMÉTRIE de la ligne du trigger (chevron vs centre de la
      // cible), pas une chaîne : un littéral emoji peut se dénormaliser à
      // l'écriture du fichier et rendre la garde inerte (constaté ici).

      // Contrôle positif : en LTR le chevron est dans la MOITIÉ DE FIN.
      await _pumpCountry(t, value: 'FR');
      final double midLtr = t.getCenter(_countryTrigger).dx;
      final double chevronLtr = t.getCenter(find.byIcon(Icons.arrow_drop_down)).dx;
      expect(chevronLtr, greaterThan(midLtr),
          reason: 'contrôle positif LTR : chevron en fin de ligne');

      await _pumpCountry(t, value: 'FR', rtl: true);
      expect(
        Directionality.of(t.element(_countryTrigger)),
        TextDirection.rtl,
        reason: 'la direction doit venir des Localizations — canal hérité par '
            'TOUTE surface, y compris une surface flottante de l\'Overlay',
      );
      final double midRtl = t.getCenter(_countryTrigger).dx;
      final double chevronRtl = t.getCenter(find.byIcon(Icons.arrow_drop_down)).dx;
      expect(chevronRtl, lessThan(midRtl),
          reason: 'RTL : la ligne est MIROIR, le chevron passe au début');
    });

    testWidgets('cible ≥ 48 dp, BORNÉE par le haut, avec contrôle négatif',
        (t) async {
      await _pumpCountry(t, negativeControl: true);
      final double h = t.getSize(_countryTrigger).height;
      expect(h, greaterThanOrEqualTo(48.0), reason: 'AD-13 : cible ≥ 48 dp');
      expect(h, lessThan(96.0),
          reason: 'borne haute : sans elle, un parent étirant le champ à la '
              'hauteur de l\'écran rendrait la garde toujours verte');

      // Contrôle négatif : le harnais n'impose aucun plancher de 48 dp.
      expect(t.getSize(find.byKey(const Key('negative-control'))).height,
          lessThan(48.0),
          reason: 'si ce Text mesurait ≥48 dp, la garde ci-dessus mesurerait '
              'le parent, pas notre contrainte');
    });
  });

  group('possession du contrôleur (clause 4 du patron)', () {
    testWidgets('rebuilds répétés : UN SEUL consommateur, commande toujours vive',
        (t) async {
      final host = await _pumpCountry(t);
      for (int i = 0; i < 5; i++) {
        // `markNeedsBuild` plutôt que `setState` : ce dernier est `@protected`
        // et `dart analyze` (joué par le gate repo-wide) le refuse là où
        // `flutter analyze` le tolère.
        t.element(find.byType(_Host)).markNeedsBuild();
        await t.pump();
      }
      expect(host.open!.consumerCount, 1,
          reason: 'le champ ne doit ni se rebrancher ni se dupliquer au rebuild');
      host.open!.set();
      await t.pump();
      expect(_countryList, findsOneWidget,
          reason: 'après 5 rebuilds la commande doit rester VIVE (non inerte)');
    });

    testWidgets('un contrôleur créé DANS build est refusé (borne temporelle)',
        (t) async {
      await t.pumpWidget(const _BadHost());
      await t.pump();
      expect(t.takeException(), isNull, reason: 'la 1re frame est légitime');

      t.element(find.byType(_BadHost)).markNeedsBuild();
      await t.pump();
      expect(t.takeException(), isA<FlutterError>(),
          reason: 'créer le contrôleur dans build le rendrait inerte au rebuild '
              '— la borne doit MORDRE');
    });
  });
}

/// Hôte FAUTIF : crée son contrôleur dans `build` — le mixin doit le refuser.
class _BadHost extends StatefulWidget {
  const _BadHost();

  @override
  State<_BadHost> createState() => _BadHostState();
}

class _BadHostState extends State<_BadHost>
    with ZDisplayStateOwnerMixin<_BadHost> {
  @override
  Widget build(BuildContext context) {
    // Le contrôleur est bien PASSÉ au champ (donc consommé) : la garde mesure
    // la borne temporelle, pas la clause « jamais consommé ».
    final ZToggleController open =
        ZToggleController(owner: this, debugLabel: 'créé-dans-build');
    return MaterialApp(
      home: ZcrudScope(
        child: Scaffold(
          body: ZCountryFieldWidget(
            ctx: ZFieldWidgetContext(
              field: _spec(),
              value: null,
              onChanged: (_) {},
            ),
            catalog: _countries(),
            openController: open,
          ),
        ),
      ),
    );
  }
}

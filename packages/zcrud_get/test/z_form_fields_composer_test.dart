// fp-2-2 — `registerZcrudFormFields` : point de composition UNIQUE du binding
// (AD-55). Tests PORTEURS via le VRAI dispatcher `ZFieldWidget` : on monte un
// `ZcrudScope(widgetRegistry:)` + `ZFormController` + `DynamicEdition` réel et
// on vérifie que chaque `kind` ATTEINT son widget satellite à travers
// `tryBuilderFor(field.type.name)` — présence ≠ association (R3).
//
// Oracle de mutation (R3, non-tautologie) : le MÊME arbre, registre VIDE
// (composeur non appelé), rend `ZUnsupportedFieldWidget` — donc si l'association
// `kind → widget` casse, l'assertion positive rougit (elle verrait
// `ZUnsupportedFieldWidget` au lieu du widget satellite).
//
// Exclusivité html ⇄ markdown (AD-50) : double composition et double câblage
// d'un `kind` déjà pris throw `ZDuplicateRegistrationError`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_intl/zcrud_intl.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

// Catalogue pays de test (évite toute lecture d'asset — cf. tests intl).
ZCountryCatalog _fakeCatalog() => ZCountryCatalog.fromList(const <ZCountryInfo>[
      ZCountryInfo(
          isoCode: 'TG', name: 'Togo', dialCode: '+228', flagEmoji: '🇹🇬'),
      ZCountryInfo(
          isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
    ]);

ZFieldSpec _field(String name, EditionFieldType type) =>
    ZFieldSpec(name: name, type: type, label: name);

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

// Monte le champ [field] sous un vrai `ZcrudScope` + `DynamicEdition` : le
// dispatcher `ZFieldWidget` résout le builder via `registry.tryBuilderFor`.
Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZWidgetRegistry? registry,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            widgetRegistry: registry,
            child: Scaffold(
              body: DynamicEdition(
                controller: controller,
                fields: <ZFieldSpec>[field],
              ),
            ),
          ),
        ),
      ),
    );

// Démonte l'arbre pour annuler le Timer de clignotement du curseur (éditeur
// Quill inline) avant la fin du test.
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

// Oracle : (kind d'`EditionFieldType`, type de widget satellite attendu).
const List<(EditionFieldType, Type)> _cases = <(EditionFieldType, Type)>[
  (EditionFieldType.markdown, ZMarkdownField),
  (EditionFieldType.inlineMarkdown, ZMarkdownField),
  (EditionFieldType.richText, ZMarkdownField),
  (EditionFieldType.phoneNumber, ZPhoneFieldWidget),
  (EditionFieldType.country, ZCountryFieldWidget),
  (EditionFieldType.address, ZAddressFieldWidget),
  (EditionFieldType.location, ZGeoFieldWidget),
];

void main() {
  group('AC1/AC3/AC4/AC5 — chaque kind atteint son widget via le VRAI dispatcher',
      () {
    for (final (type, widgetType) in _cases) {
      testWidgets('${type.name} → $widgetType (association bout-en-bout)',
          (t) async {
        final registry = ZWidgetRegistry();
        // Le composeur APPELLE les registrars/builders des satellites.
        registerZcrudFormFields(registry, countryCatalog: _fakeCatalog());

        final c = _controller('f');
        await t.pumpWidget(_app(c, _field('f', type), registry: registry));
        await t.pump();

        expect(find.byType(widgetType), findsOneWidget,
            reason:
                '${type.name} doit être servi par $widgetType via tryBuilderFor');
        // Preuve d'ASSOCIATION (≠ simple présence) : pas de repli.
        expect(find.byType(ZUnsupportedFieldWidget), findsNothing);

        await _settle(t);
      });
    }
  });

  group('R3 — oracle de mutation : registre vide (composeur non appelé)', () {
    // Si l'association `kind → widget` du composeur disparaissait, l'arbre
    // ci-dessus rendrait EXACTEMENT ceci → les tests positifs rougiraient.
    for (final (type, widgetType) in _cases) {
      testWidgets('${type.name} sans composeur → ZUnsupportedFieldWidget',
          (t) async {
        final c = _controller('f');
        await t.pumpWidget(
          _app(c, _field('f', type), registry: ZWidgetRegistry()),
        );
        await t.pump();

        expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
        expect(find.byType(widgetType), findsNothing);

        await _settle(t);
      });
    }
  });

  group('AC6 — exclusivité html ⇄ markdown & double composition (AD-50)', () {
    test('double composition sur le même registre → ZDuplicateRegistrationError',
        () {
      final r = ZWidgetRegistry();
      registerZcrudFormFields(r, countryCatalog: _fakeCatalog());
      expect(
        () => registerZcrudFormFields(r, countryCatalog: _fakeCatalog()),
        throwsA(isA<ZDuplicateRegistrationError>()),
        reason:
            'recomposer collisionne sur markdown/phoneNumber/… (jamais last-wins)',
      );
    });

    test(
        'double câblage html via additionalRegistrars → ZDuplicateRegistrationError',
        () {
      // Choix documenté : `zcrud_html` n'est PAS une dépendance du binding (il
      // entre par le seam opt-in au site d'appel). On prouve donc l'exclusivité
      // AD-50 avec le `registerZHtmlFields` de `zcrud_markdown` (voie
      // HTML-via-Delta, DÉJÀ une dépendance), qui revendique `html`/`inlineHtml`
      // exactement comme le ferait le WYSIWYG de `zcrud_html`. Deux voies html
      // ⇒ collision sur `html` — comportement identique quel que soit le paquet
      // html opt-in. Une SEULE voie html + markdown par défaut = kinds disjoints,
      // donc pas de collision (voie opt-in légitime).
      final r = ZWidgetRegistry();
      expect(
        () => registerZcrudFormFields(
          r,
          countryCatalog: _fakeCatalog(),
          additionalRegistrars: <void Function(ZWidgetRegistry)>[
            registerZHtmlFields, // 1re voie html (opt-in) — OK isolément
            registerZHtmlFields, // 2e voie html → collision html/inlineHtml
          ],
        ),
        throwsA(isA<ZDuplicateRegistrationError>()),
        reason: 'câbler deux voies html revendiquant le même kind throw (AD-50)',
      );
    });

    testWidgets('opt-in html unique + markdown par défaut coexistent (kinds disjoints)',
        (t) async {
      final r = ZWidgetRegistry();
      registerZcrudFormFields(
        r,
        countryCatalog: _fakeCatalog(),
        additionalRegistrars: <void Function(ZWidgetRegistry)>[
          registerZHtmlFields,
        ],
      );
      // markdown (défaut) ET html (opt-in) enrôlés sans collision.
      expect(r.isRegistered('markdown'), isTrue);
      expect(r.isRegistered('html'), isTrue);

      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.markdown), registry: r),
      );
      await t.pump();
      expect(find.byType(ZMarkdownField), findsOneWidget);
      await _settle(t);
    });
  });

  group('AD-4 — le registre est fourni par l\'appelant (jamais interne)', () {
    test('le composeur opère sur l\'instance passée, ne la construit pas', () {
      final r = ZWidgetRegistry();
      expect(r.isRegistered('location'), isFalse);
      registerZcrudFormFields(r, countryCatalog: _fakeCatalog());
      // La MÊME instance a été enrôlée (aucun registre statique interne).
      expect(r.isRegistered('location'), isTrue);
      expect(r.isRegistered('phoneNumber'), isTrue);
      expect(r.isRegistered('country'), isTrue);
      expect(r.isRegistered('address'), isTrue);
      // `geoArea` n'est PAS câblé par défaut (opt-in `wireGeoArea`).
      expect(r.isRegistered('geoArea'), isFalse);
    });

    test('wireGeoArea:true enrôle aussi le kind geoArea', () {
      final r = ZWidgetRegistry();
      registerZcrudFormFields(r,
          countryCatalog: _fakeCatalog(), wireGeoArea: true);
      expect(r.isRegistered('geoArea'), isTrue);
    });
  });
}

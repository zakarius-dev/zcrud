library;

// Le registre de thèmes doit rester OUVERT (invariant AD-4) : un hôte ou un
// paquet tiers enregistre son thème sans modifier ce dépôt. La garde le
// prouve en enregistrant réellement un thème inconnu — et vérifie qu'aucun
// `enum` ni `sealed` n'a repris la main sur l'identité d'un thème.

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_themes/zcrud_themes.dart';

void main() {
  tearDown(() => ZThemeCatalog.unregister('mesure'));

  test('Classic est enregistré et porte une CLÉ de libellé', () {
    expect(ZThemeCatalog.byId('classic'), ZThemeCatalog.classic);
    expect(ZThemeCatalog.classic.labelKey, 'zcrud.theme.classic');
    // Une clé, jamais un mot d'une langue : le libellé se traduit chez l'hôte.
    expect(ZThemeCatalog.classic.labelKey, startsWith('zcrud.'));
  });

  test('le registre accepte un thème qu\'il ne connaissait pas', () {
    expect(ZThemeCatalog.byId('mesure'), isNull);
    const ZThemeSpec spec =
        ZThemeSpec(id: 'mesure', labelKey: 'app.theme.mesure');
    ZThemeCatalog.register(spec);
    expect(ZThemeCatalog.byId('mesure'), spec);
    expect(ZThemeCatalog.specs, contains(spec));
    expect(ZThemeCatalog.specs, contains(ZThemeCatalog.classic));
  });

  test('un identifiant inconnu rend null, jamais une exception (AD-10)', () {
    expect(ZThemeCatalog.byId('inexistant'), isNull);
    expect(ZThemeCatalog.byId(''), isNull);
  });

  test('la liste rendue est immuable', () {
    expect(
      () => ZThemeCatalog.specs.add(
          const ZThemeSpec(id: 'x', labelKey: 'x')),
      throwsUnsupportedError,
    );
  });

  test('le thème Classic pointe la même identité que le registre', () {
    expect(ZClassicTheme.spec, ZThemeCatalog.classic);
  });
}

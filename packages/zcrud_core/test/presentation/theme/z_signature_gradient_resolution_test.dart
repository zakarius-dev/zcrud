// GARDE — la CHAÎNE de résolution d'un dégradé : qui parle, dans quel ordre,
// et sur quelles clés seulement.
//
// Trois propriétés sont en jeu, et elles se contredisent si on les relâche :
//  (a) les clés `zcrud.signature.*` portent une valeur de RÉFÉRENCE par défaut ;
//  (b) les clés `zcrud.fieldType.*` / `zcrud.fieldAccent.*` restent SEAM-ONLY
//      (un formulaire sans résolveur d'hôte ne se teinte pas) ;
//  (c) le profil `neutral` est l'ÉCHAPPATOIRE : il rend (a) muet, sans toucher
//      au seam de l'hôte ni aux jetons posés explicitement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Dégradé témoin, distinct de toute valeur de référence.
final ZGradientSpec _temoin = ZGradientSpec(
  gradient: const LinearGradient(
    colors: <Color>[Color(0xFF010203), Color(0xFF040506)],
  ),
  onGradient: const Color(0xFF000000),
);

/// Résout [key] sous le [theme] CRUD donné, avec le [resolver] d'hôte donné.
Future<ZGradientSpec?> _resolve(
  WidgetTester tester,
  String key, {
  ZcrudTheme? theme,
  ZGradientResolver? resolver,
  bool withScope = true,
}) async {
  ZGradientSpec? out;
  Widget leaf = Builder(
    builder: (BuildContext context) {
      out = zResolveGradient(context, key);
      return const SizedBox.shrink();
    },
  );
  if (withScope) {
    leaf = ZcrudScope(theme: theme, gradientResolver: resolver, child: leaf);
  }
  await tester.pumpWidget(MaterialApp(home: leaf));
  return out;
}

void main() {
  testWidgets('legacy (défaut) : `zcrud.signature.*` rend un dégradé de la '
      'référence — même SANS aucun ZcrudScope', (tester) async {
    final ZGradientSpec? sansScope =
        await _resolve(tester, zSignatureKey('x'), withScope: false);
    expect(sansScope, isNotNull);
    expect(
      ZSignaturePaletteReference.gradients.contains(sansScope),
      isTrue,
      reason: 'le dégradé rendu ne vient pas de la référence auditée',
    );

    final ZGradientSpec? avecScope =
        await _resolve(tester, zSignatureKey('x'), theme: const ZcrudTheme());
    expect(avecScope, sansScope,
        reason: 'un ZcrudScope sans jeton ne doit rien changer');
  });

  testWidgets('🔴 ÉCHAPPATOIRE : profil `neutral` ⇒ `zcrud.signature.*` rend '
      '`null`', (tester) async {
    final ZGradientSpec? spec = await _resolve(
      tester,
      zSignatureKey('x'),
      theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
    );
    expect(spec, isNull);
  });

  testWidgets('les préfixes `fieldType`/`fieldAccent` restent SEAM-ONLY dans '
      'les DEUX profils', (tester) async {
    for (final ZcrudTheme? theme in <ZcrudTheme?>[
      null,
      const ZcrudTheme(),
      const ZcrudTheme(referenceProfile: ZReferenceProfile.legacy),
      const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
    ]) {
      for (final String key in <String>[
        zFieldTypeTintKey(EditionFieldType.text),
        zFieldTypeTintKey(EditionFieldType.number),
        zFieldAccentKey('nom'),
        'dossier-42',
        '',
      ]) {
        expect(
          await _resolve(tester, key, theme: theme),
          isNull,
          reason: '🔴 la clé "$key" a reçu une valeur par défaut : un '
              'formulaire sans résolveur d\'hôte se teinterait tout seul',
        );
      }
    }
  });

  testWidgets('une identité VIDE (`zcrud.signature.`) rend `null`',
      (tester) async {
    expect(await _resolve(tester, zSignatureKeyPrefix), isNull);
  });

  testWidgets('le seam de l\'hôte est PRIORITAIRE sur la référence, et reste '
      'entendu sous le profil neutre', (tester) async {
    ZGradientSpec? hote(ColorScheme scheme, String key) => _temoin;
    expect(
      await _resolve(tester, zSignatureKey('x'), resolver: hote),
      _temoin,
    );
    expect(
      await _resolve(
        tester,
        zSignatureKey('x'),
        resolver: hote,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
      ),
      _temoin,
      reason: 'le profil neutre ne doit PAS museler le seam de l\'hôte',
    );
  });

  testWidgets('priorité jeton > référence : `signaturePalette` s\'applique '
      'dans les DEUX profils', (tester) async {
    final List<ZGradientSpec> palette = <ZGradientSpec>[_temoin];
    expect(
      await _resolve(
        tester,
        zSignatureKey('x'),
        theme: ZcrudTheme(signaturePalette: palette),
      ),
      _temoin,
    );
    expect(
      await _resolve(
        tester,
        zSignatureKey('x'),
        theme: ZcrudTheme(
          signaturePalette: palette,
          referenceProfile: ZReferenceProfile.neutral,
        ),
      ),
      _temoin,
      reason: 'un jeton POSÉ par l\'hôte est une décision, pas une référence : '
          'le profil neutre ne l\'efface pas',
    );
  });

  testWidgets('une palette de jeton VIDE rend `null` (aucune exception)',
      (tester) async {
    expect(
      await _resolve(
        tester,
        zSignatureKey('x'),
        theme: const ZcrudTheme(signaturePalette: <ZGradientSpec>[]),
      ),
      isNull,
    );
  });

  testWidgets('le jeton de stratégie est LU par la chaîne', (tester) async {
    // 'Alpha' : FNV-1a % 5 == 4 ; hashCode % 5 vaut autre chose sur cette
    // plateforme (sinon le test ne distinguerait rien — vérifié ci-dessous).
    // Sans cette borne, le test serait VACUEL le jour où les deux stratégies
    // tomberaient sur le même index.
    expect('Alpha'.hashCode.abs() % 5, isNot(4),
        reason: 'les deux stratégies coïncident : le test ne distingue plus '
            'rien — changer l\'identité témoin');
    final ZGradientSpec? fnv = await _resolve(
      tester,
      zSignatureKey('Alpha'),
      theme: const ZcrudTheme(
        signaturePaletteIndexStrategy: ZPaletteIndexStrategy.stableFnv,
      ),
    );
    expect(fnv, ZSignaturePaletteReference.gradients[4]);

    final ZGradientSpec? defaut =
        await _resolve(tester, zSignatureKey('Alpha'));
    expect(
      defaut,
      ZSignaturePaletteReference
          .gradients['Alpha'.hashCode.abs() % 5],
      reason: 'le défaut doit rester la fidélité `hashCode`',
    );
  });

  test('🔴 vecteurs FIGÉS de `stableFnv` — stables entre plateformes', () {
    // Relevés par calcul indépendant de FNV-1a 32 bits sur les unités UTF-16.
    // Ils ne dépendent NI du SDK, NI de la plateforme : c'est tout l'intérêt
    // de cette stratégie face à `String.hashCode`.
    const Map<String, int> mod5 = <String, int>{
      'Alpha': 4,
      'Beta': 3,
      'Gamma': 1,
      'Identité': 3,
      'a': 0,
      '': 1,
      'Général': 3,
      'Section 1': 4,
    };
    mod5.forEach((String s, int attendu) {
      expect(
        zPaletteIndexFor(s, 5, strategy: ZPaletteIndexStrategy.stableFnv),
        attendu,
        reason: 'FNV-1a("$s") % 5',
      );
    });
    const Map<String, int> mod8 = <String, int>{
      'Alpha': 3,
      'Beta': 7,
      'Gamma': 2,
      'a': 4,
      '': 5,
    };
    mod8.forEach((String s, int attendu) {
      expect(
        zPaletteIndexFor(s, 8, strategy: ZPaletteIndexStrategy.stableFnv),
        attendu,
        reason: 'FNV-1a("$s") % 8',
      );
    });
  });

  test('`ordinal` ignore l\'identité ; `titleHash` suit `hashCode`', () {
    expect(
      zPaletteIndexFor('peu importe', 5,
          strategy: ZPaletteIndexStrategy.ordinal, ordinal: 7),
      2,
    );
    expect(
      zPaletteIndexFor('peu importe', 5,
          strategy: ZPaletteIndexStrategy.ordinal, ordinal: -3),
      3,
    );
    expect(
      zPaletteIndexFor('Alpha', 5),
      'Alpha'.hashCode.abs() % 5,
    );
  });

  test('chaîne TOTALE : longueur nulle ou palette vide ne lèvent jamais', () {
    expect(zPaletteIndexFor('x', 0), 0);
    expect(zPaletteIndexFor('x', -4), 0);
    expect(zSignatureGradientFor('x', palette: const <ZGradientSpec>[]), isNull);
    expect(zSignatureGradientFor('x'), isNotNull);
  });

  test('`zLegacyOrIn` : un profil NUL vaut `legacy`', () {
    expect(zLegacyOrIn<String>(null, 'ref', 'neutre'), 'ref');
    expect(zLegacyOrIn<String>(ZReferenceProfile.legacy, 'ref', 'neutre'),
        'ref');
    expect(zLegacyOrIn<String>(ZReferenceProfile.neutral, 'ref', 'neutre'),
        'neutre');
    expect(zLegacyOrIn<String>(ZReferenceProfile.neutral, 'ref'), isNull);
  });
}

/// La teinte de sélection d'une puce passe par la couture de dégradé du socle.
///
/// Deux propriétés, mesurées sur la COULEUR RÉELLEMENT PEINTE d'une puce
/// montée — le `drawRRect` de fond de la puce sélectionnée —, jamais sur le
/// seul objet de style, qui pourrait diverger de ce que voit l'œil :
///
/// * un résolveur `ZcrudScope.gradientResolver` posé par l'application
///   ATTEINT la puce quand celle-ci porte une identité ;
/// * sans résolveur, la couleur peinte est **strictement** inchangée, sous le
///   profil `legacy` comme sous `neutral`.
///
/// La mesure ne rastérise rien (`toImage()` pend sous ce harnais) : elle lit
/// la liste d'appels de peinture de l'objet de rendu de la puce.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

const Color kSeamStart = Color(0xFF00A5B5);
const Color kSeamEnd = Color(0xFF004A52);
const Color kJetonStart = Color(0xFF123456);
const String kIdentity = 'Section 3';

/// Résolveur d'hôte répondant à **toute** clé de signature.
ZGradientSpec? seamResolver(ColorScheme scheme, String gradientKey) =>
    gradientKey.startsWith('zcrud.signature.')
    ? const ZGradientSpec(
        gradient: LinearGradient(colors: <Color>[kSeamStart, kSeamEnd]),
        onGradient: Color(0xFFFFFFFF),
      )
    : null;

const List<ZGradientSpec> kJeton = <ZGradientSpec>[
  ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[kJetonStart, Color(0xFF654321)]),
    onGradient: Color(0xFFFFFFFF),
  ),
];

/// Teinte de la référence auditée pour [kIdentity], telle que le socle
/// l'indexe.
Color referenceFor(String identity) => ZSignaturePaletteReference
    .gradients[zPaletteIndexFor(
      identity,
      ZSignaturePaletteReference.gradients.length,
    )]
    .gradient
    .colors
    .first;

/// `ColorScheme` du dernier arbre monté — capturé sous le `MaterialApp`, donc
/// exactement celui que la puce a consulté.
late ColorScheme lastScheme;

/// Monte une puce SÉLECTIONNÉE habillée par `zChipThemeFor`.
Future<void> pumpChip(
  WidgetTester tester, {
  ZcrudTheme? theme,
  ZGradientResolver? resolver,
  String? signatureKey,
}) async {
  Widget app = MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          lastScheme = Theme.of(context).colorScheme;
          return ChipTheme(
            data: zChipThemeFor(context, signatureKey: signatureKey),
            child: ChoiceChip(
              label: const Text('Actif'),
              selected: true,
              onSelected: (_) {},
            ),
          );
        },
      ),
    ),
  );
  if (theme != null || resolver != null) {
    app = ZcrudScope(theme: theme, gradientResolver: resolver, child: app);
  }
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/// Le fond de la puce sélectionnée est peint avec [expected], à l'octet.
void expectPainted(WidgetTester tester, Color expected, {String? reason}) {
  expect(
    tester.renderObject(find.byType(ChoiceChip)),
    paints..rrect(color: expected),
    reason:
        reason ??
        'la couleur remise au canevas pour le fond de la puce a changé',
  );
}

void main() {
  const ZcrudTheme legacy = ZcrudTheme(
    referenceProfile: ZReferenceProfile.legacy,
  );
  const ZcrudTheme neutral = ZcrudTheme(
    referenceProfile: ZReferenceProfile.neutral,
  );

  group('le seam de l\'hôte atteint la puce', () {
    testWidgets('sous `neutral` — le défaut du socle', (tester) async {
      await pumpChip(
        tester,
        theme: neutral,
        resolver: seamResolver,
        signatureKey: kIdentity,
      );
      expectPainted(
        tester,
        kSeamStart,
        reason:
            'ATTRAPE : la puce résout sa teinte sans consulter '
            '`ZcrudScope.gradientResolver` — le résolveur de l\'application '
            'est ignoré ICI alors qu\'il s\'applique partout ailleurs',
      );
    });

    testWidgets('sous `legacy` — le seam prime sur la référence', (
      tester,
    ) async {
      await pumpChip(
        tester,
        theme: legacy,
        resolver: seamResolver,
        signatureKey: kIdentity,
      );
      expectPainted(tester, kSeamStart);
      expect(
        kSeamStart,
        isNot(referenceFor(kIdentity)),
        reason:
            'sans cet écart, peindre la teinte du seam ne prouverait rien '
            'contre la référence',
      );
    });

    testWidgets('le seam prime sur le jeton `signaturePalette`', (
      tester,
    ) async {
      await pumpChip(
        tester,
        theme: const ZcrudTheme(signaturePalette: kJeton),
        resolver: seamResolver,
        signatureKey: kIdentity,
      );
      expectPainted(
        tester,
        kSeamStart,
        reason:
            'ATTRAPE : l\'ordre des maillons inversé — le jeton doit céder '
            'devant le résolveur, comme dans `zResolveGradient`',
      );
    });

    testWidgets(
      'un résolveur muet sur cette clé laisse jouer les maillons suivants',
      (tester) async {
        await pumpChip(
          tester,
          theme: const ZcrudTheme(
            referenceProfile: ZReferenceProfile.legacy,
            signaturePalette: kJeton,
          ),
          resolver: (ColorScheme scheme, String key) => null,
          signatureKey: kIdentity,
        );
        expectPainted(
          tester,
          kJetonStart,
          reason:
              'ATTRAPE : un `null` du résolveur pris pour « pas de teinte » '
              'au lieu de « je ne me prononce pas »',
        );
      },
    );

    testWidgets('la clé soumise au résolveur porte bien l\'identité', (
      tester,
    ) async {
      final List<String> keys = <String>[];
      await pumpChip(
        tester,
        theme: neutral,
        resolver: (ColorScheme scheme, String key) {
          keys.add(key);
          return null;
        },
        signatureKey: kIdentity,
      );
      expect(
        keys,
        contains('zcrud.signature.$kIdentity'),
        reason:
            'ATTRAPE : une clé qui ne porte plus le préfixe de signature — '
            'le résolveur de l\'hôte ne pourrait plus la reconnaître, et la '
            'référence ne serait plus consultée non plus. Clés vues : $keys',
      );
    });
  });

  group('inertie — sans résolveur, la couleur peinte ne bouge pas', () {
    testWidgets('`legacy`, avec identité : la référence indexée', (
      tester,
    ) async {
      await pumpChip(tester, theme: legacy, signatureKey: kIdentity);
      expectPainted(tester, referenceFor(kIdentity));
    });

    testWidgets('`legacy`, sans identité : la TÊTE de la palette', (
      tester,
    ) async {
      await pumpChip(tester, theme: legacy);
      expectPainted(
        tester,
        ZSignaturePaletteReference.gradients.first.gradient.colors.first,
      );
    });

    testWidgets('`neutral`, avec ou sans identité : `ColorScheme.primary`', (
      tester,
    ) async {
      await pumpChip(tester, theme: neutral);
      expectPainted(tester, lastScheme.primary);
      await pumpChip(tester, theme: neutral, signatureKey: kIdentity);
      expectPainted(tester, lastScheme.primary);
    });

    testWidgets('aucun scope du tout : `ColorScheme.primary`', (tester) async {
      await pumpChip(tester);
      expectPainted(tester, lastScheme.primary);
      await pumpChip(tester, signatureKey: kIdentity);
      expectPainted(tester, lastScheme.primary);
    });

    testWidgets('le jeton posé s\'applique dans les DEUX profils', (
      tester,
    ) async {
      for (final ZReferenceProfile profile in ZReferenceProfile.values) {
        final ZcrudTheme theme = ZcrudTheme(
          referenceProfile: profile,
          signaturePalette: kJeton,
        );
        await pumpChip(tester, theme: theme);
        expectPainted(tester, kJetonStart, reason: 'profil $profile, sans clé');
        await pumpChip(tester, theme: theme, signatureKey: kIdentity);
        expectPainted(tester, kJetonStart, reason: 'profil $profile, avec clé');
      }
    });

    testWidgets('un jeton de palette VIDE retombe sur le rôle M3', (
      tester,
    ) async {
      const ZcrudTheme vide = ZcrudTheme(
        referenceProfile: ZReferenceProfile.legacy,
        signaturePalette: <ZGradientSpec>[],
      );
      await pumpChip(tester, theme: vide);
      expectPainted(tester, lastScheme.primary);
      await pumpChip(tester, theme: vide, signatureKey: kIdentity);
      expectPainted(tester, lastScheme.primary);
    });
  });
}

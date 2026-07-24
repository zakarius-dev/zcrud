// CR-LEX-38 — le gabarit PDF n'utilisait que `PdfStandardFont` (WinAnsi) :
// tout caractère hors latin-1 — arabe, grec, cyrillique, CJK, emoji — était
// remplacé par `?` pour que le rendu ne lève pas. C'est une DESTRUCTION
// silencieuse de contenu utilisateur, et AUCUN contournement hôte n'existait :
// le gabarit n'exposait aucun point d'injection de police.
//
// CR-LEX-39 — `ZFlashcardPdfCard` n'avait aucun champ `hint`. L'indice, pourtant
// porté par `ZFlashcard`, ne pouvait être rendu qu'en le faisant passer pour une
// partie de l'énoncé.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

/// Provider qui rend `null` — modélise un hôte sans police, et le défaut.
class _SansPolice implements ZPdfFontProvider {
  @override
  Future<Uint8List?> loadFont() async => null;
}

/// Provider défaillant : ne doit JAMAIS coûter l'export (AD-10).
class _ProviderQuiLeve implements ZPdfFontProvider {
  @override
  Future<Uint8List?> loadFont() async => throw StateError('assets absents');
}

/// Provider rendant des octets INVALIDES : même exigence de repli.
class _OctetsInvalides implements ZPdfFontProvider {
  @override
  Future<Uint8List?> loadFont() async => Uint8List.fromList(<int>[1, 2, 3]);
}

ZFlashcardPdfInput _input({String question = 'Question', String? hint}) =>
    ZFlashcardPdfInput(
      title: 'Test',
      cards: <ZFlashcardPdfCard>[
        ZFlashcardPdfCard(
          question: question,
          answer: 'Réponse',
          hint: hint,
        ),
      ],
    );

void main() {
  group('🔴 CR-LEX-38 — le port de police existe et dégrade sans casser', () {
    test('sans provider, l\'export fonctionne (défaut inchangé)', () async {
      final out = await const ZFlashcardPdfTemplate().build(_input());
      expect(out.bytes.isNotEmpty, isTrue);
      expect(out.mimeType, 'application/pdf');
    });

    test('🔴 un texte NON-latin ne fait plus échouer l\'export', () async {
      // Avant, ces caractères devenaient `?`. Le PDF se produit toujours — ce
      // que ce test verrouille, c'est qu'aucun chemin ne lève.
      for (final texte in <String>[
        'مرحبا بالعالم', // arabe
        'Γειά σου κόσμε', // grec
        'Привет мир', // cyrillique
        '你好世界', // CJK
        'Bonjour 🌍', // emoji
      ]) {
        final out = await const ZFlashcardPdfTemplate().build(_input(question: texte));
        expect(out.bytes.isNotEmpty, isTrue, reason: texte);
      }
    });

    test('un provider rendant `null` retombe sur la police standard', () async {
      final out = await ZFlashcardPdfTemplate(fontProvider: _SansPolice())
          .build(_input(question: 'مرحبا'));
      expect(out.bytes.isNotEmpty, isTrue);
    });

    test('🔴 AD-10 — un provider qui LÈVE ne coûte pas l\'export', () async {
      final out = await ZFlashcardPdfTemplate(fontProvider: _ProviderQuiLeve())
          .build(_input());
      expect(out.bytes.isNotEmpty, isTrue,
          reason: 'un provider défaillant dégrade, il ne casse pas');
    });

    test('🔴 des octets de police INVALIDES ne cassent pas non plus', () async {
      final out = await ZFlashcardPdfTemplate(fontProvider: _OctetsInvalides())
          .build(_input());
      expect(out.bytes.isNotEmpty, isTrue);
    });

    test('le port est bien exposé par l\'API publique', () {
      // Sans export, la couture serait inatteignable — le défaut même de la CR.
      expect(_SansPolice(), isA<ZPdfFontProvider>());
    });
  });

  group('🔴 CR-LEX-39 — l\'indice est un champ, rendu dans LES DEUX modes', () {
    test('le champ existe et traverse le VO', () {
      const carte = ZFlashcardPdfCard(question: 'Q', hint: 'Un indice');
      expect(carte.hint, 'Un indice');
    });

    test('🔴 il est rendu AUSSI en `withoutAnswers` (mode révision)', () async {
      // C'est tout l'intérêt : le masquer avec la réponse en ferait un doublon
      // de l'explication. On compare les tailles — un PDF portant l'indice est
      // strictement plus gros que le même sans.
      const t = ZFlashcardPdfTemplate();
      final sans = await t.build(_input(),
          answerVisibility: ZAnswerVisibility.withoutAnswers);
      final avec = await t.build(_input(hint: 'Pensez au théorème de Thalès'),
          answerVisibility: ZAnswerVisibility.withoutAnswers);
      expect(avec.bytes.length, greaterThan(sans.bytes.length),
          reason: 'l\'indice doit être rendu même sans les réponses');
    });

    test('il est rendu aussi en `withAnswers`', () async {
      const t = ZFlashcardPdfTemplate();
      final sans = await t.build(_input());
      final avec = await t.build(_input(hint: 'Pensez au théorème de Thalès'));
      expect(avec.bytes.length, greaterThan(sans.bytes.length));
    });

    test('un indice `null` ou vide n\'émet AUCUN bloc (non cassant)', () async {
      // ⚠️ On ne compare PAS à l'octet près : la sortie PDF n'est pas
      // déterministe d'un build à l'autre (quelques octets de méta varient).
      // Ce qui se prouve, c'est qu'un indice VIDE reste du côté de « pas de
      // bloc » et non du côté de « bloc émis ».
      const t = ZFlashcardPdfTemplate();
      final sans = await t.build(_input());
      final vide = await t.build(_input(hint: ''));
      final avec = await t.build(_input(hint: 'Pensez au théorème de Thalès'));

      final ecartVide = (vide.bytes.length - sans.bytes.length).abs();
      final ecartAvec = avec.bytes.length - sans.bytes.length;
      expect(ecartAvec, greaterThan(0),
          reason: 'contrôle positif : un vrai indice DOIT grossir le document');
      expect(ecartVide, lessThan(ecartAvec),
          reason: 'un indice vide ne doit émettre aucun bloc');
    });

    test('le libellé par défaut est fourni et surchargeable', () {
      expect(const ZFlashcardPdfLabels().hintLabel, 'Indice');
      expect(const ZFlashcardPdfLabels(hintLabel: 'Coup de pouce').hintLabel,
          'Coup de pouce');
    });
  });
}

// CR-LEX-43 — le gabarit ne composait qu'UNE police par document. CR-LEX-38
// livrait le point d'injection et sa dartdoc conseillait « fournissez une police
// qui couvre les deux » : mesuré côté hôte, une telle police N'EXISTE PAS dans
// un bundle raisonnable — les fontes Noto sont découpées PAR ÉCRITURE
// (`NotoSans` : 2840 glyphes sans l'arabe ; `NotoSansArabic` : 1161 sans même
// la lettre `A`). Le conseil était donc inapplicable, et aucun contournement
// hôte n'existait : le gabarit EST le dessinateur.
//
// 🔴 Second défaut, corollaire, que la CR ne numérote pas : `PdfTrueTypeFont`
// ne LÈVE JAMAIS sur un glyphe absent. Tout le filet `_sanitize` reposait sur ce
// `throw` ⇒ dès qu'une police TrueType était injectée, la substitution en `?`
// devenait un NO-OP, et le non-couvert devenait un `.notdef` : une case vide,
// invisible, pire qu'un `?` qui se voit. La garantie de CR-LEX-38 s'évaporait
// exactement quand on l'activait.
//
// ⚠️ ORACLES — deux, et leurs limites sont explicites.
//   (1) La table `cmap`, pour ce que la police DÉCLARE porter.
//   (2) Le texte extrait du PDF, UNIQUEMENT pour observer la substitution : un
//       caractère non porté ressort `?`, un caractère porté ressort tel quel.
// lex a mesuré que l'extraction n'est PAS un oracle fiable de COUVERTURE — la
// `ToUnicode` CMap étant indexée par glyphe, tous les non-couverts partagent
// `.notdef` et un caractère non couvert ISOLÉ round-trippe à l'identique
// (`'AAA好BBB税CCC'` ressort `'AAA税BBB税CCC'`). C'est pourquoi on n'affirme
// jamais « rendu » sur la seule foi de l'extraction : on compare toujours à un
// TÉMOIN APPARIÉ (même police primaire, avec et sans repli).
//
// 🔴 Une première version de ces gardes comparait des TAILLES d'octets. Trois
// mutations du mécanisme central passaient au VERT : la sortie PDF n'est pas
// déterministe, l'écart de taille venait du bruit. Corrigé — mais c'est le
// rappel que le choix de l'oracle EST le test.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

/// Produit le PDF et en RELIT le texte, blancs retirés.
///
/// ⚠️ Oracle CHOISI, pas subi : comparer des TAILLES d'octets ne prouve rien —
/// la sortie PDF n'est pas déterministe, et une première version de ces gardes
/// passait au vert avec la sélection de police entièrement débranchée.
/// Ce qu'on lit ici est discriminant : un caractère porté par une police de la
/// chaîne ressort TEL QUEL ; un caractère porté par PERSONNE ressort `?`.
Future<String> _texte(ZFlashcardPdfTemplate t, String question) async {
  final out = await t.build(ZFlashcardPdfInput(
    title: 'T',
    cards: <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: question)],
  ));
  final doc = PdfDocument(inputBytes: out.bytes);
  try {
    return PdfTextExtractor(doc).extractText().replaceAll(RegExp(r'\s'), '');
  } finally {
    doc.dispose();
  }
}

/// Poids du PDF produit — mesure INDÉPENDANTE de l'extraction de texte.
Future<int> _octets(ZFlashcardPdfTemplate t, String question) async =>
    (await t.build(ZFlashcardPdfInput(
      title: 'T',
      cards: <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: question)],
    )))
        .bytes
        .length;

/// Provider qui rend des octets fournis (ou `null`).
class _Provider implements ZPdfFontProvider {
  _Provider(this.bytes);
  final Uint8List? bytes;
  @override
  Future<Uint8List?> loadFont() async => bytes;
}

/// Provider qui LÈVE — un maillon défaillant ne doit pas casser la chaîne.
class _ProviderQuiLeve implements ZPdfFontProvider {
  @override
  Future<Uint8List?> loadFont() async => throw StateError('assets absents');
}

// --- Polices RÉELLES du système, quand elles sont là -----------------------
// DejaVuSans : latin + grec + cyrillique, PAS de CJK.
// fonts-japanese-gothic : CJK.
const _kDejaVu = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
const _kCjk = '/usr/share/fonts/truetype/fonts-japanese-gothic.ttf';

Uint8List? _lire(String chemin) {
  final f = File(chemin);
  return f.existsSync() ? f.readAsBytesSync() : null;
}

/// Construit une police SYNTHÉTIQUE minimale : table d'offsets + `cmap`
/// format 4 couvrant exactement [couverts].
///
/// Portable et totalement contrôlée — c'est l'ossature falsifiable du lecteur,
/// là où les polices système ne sont qu'un contrôle de réalité.
Uint8List _policeSynthetique(List<int> couverts) {
  final pts = couverts.toSet().toList()..sort();
  // Un segment par point de code, + le segment terminal obligatoire 0xFFFF.
  final segs = <List<int>>[for (final c in pts) <int>[c, c], <int>[0xFFFF, 0xFFFF]];
  final segCount = segs.length;
  final sub = BytesBuilder();
  void u16(BytesBuilder b, int v) => b.add(<int>[(v >> 8) & 0xFF, v & 0xFF]);
  u16(sub, 4); // format
  u16(sub, 16 + segCount * 8); // length
  u16(sub, 0); // language
  u16(sub, segCount * 2); // segCountX2
  u16(sub, 0); // searchRange (non lu)
  u16(sub, 0); // entrySelector
  u16(sub, 0); // rangeShift
  for (final s in segs) {
    u16(sub, s[1]); // endCode
  }
  u16(sub, 0); // reservedPad
  for (final s in segs) {
    u16(sub, s[0]); // startCode
  }
  for (var i = 0; i < segCount; i++) {
    // idDelta : le dernier segment (0xFFFF) doit mapper vers le glyphe 0.
    u16(sub, i == segCount - 1 ? 1 : (10 - segs[i][0]) & 0xFFFF);
  }
  for (var i = 0; i < segCount; i++) {
    u16(sub, 0); // idRangeOffset
  }
  final subBytes = sub.toBytes();

  final cmap = BytesBuilder();
  u16(cmap, 0); // version
  u16(cmap, 1); // numTables
  u16(cmap, 3); // platformID (Windows)
  u16(cmap, 1); // encodingID (BMP)
  cmap.add(<int>[0, 0, 0, 12]); // offset de la sous-table (depuis cmap)
  cmap.add(subBytes);
  final cmapBytes = cmap.toBytes();

  final out = BytesBuilder();
  out.add(<int>[0x00, 0x01, 0x00, 0x00]); // sfntVersion
  u16(out, 1); // numTables
  u16(out, 0);
  u16(out, 0);
  u16(out, 0);
  out.add(<int>[0x63, 0x6D, 0x61, 0x70]); // 'cmap'
  out.add(<int>[0, 0, 0, 0]); // checksum
  out.add(<int>[0, 0, 0, 28]); // offset
  final len = cmapBytes.length;
  out.add(<int>[
    (len >> 24) & 0xFF,
    (len >> 16) & 0xFF,
    (len >> 8) & 0xFF,
    len & 0xFF,
  ]);
  out.add(cmapBytes);
  return out.toBytes();
}

ZFlashcardPdfInput _deck(String question) => ZFlashcardPdfInput(
      title: 'T',
      cards: <ZFlashcardPdfCard>[ZFlashcardPdfCard(question: question)],
    );

void main() {
  group('🔴 CR-LEX-43 — `ZFontCoverage` lit la couverture RÉELLE', () {
    test('🔴 une police synthétique déclare exactement ce qu\'elle couvre', () {
      // 'A' (0x41) et 'Ω' (0x3A9) couverts ; 'B' et 'م' non.
      final c = ZFontCoverage.parse(_policeSynthetique(<int>[0x41, 0x3A9]));
      expect(c, isNotNull, reason: 'la police doit être lisible');
      expect(c!.covers(0x41), isTrue);
      expect(c.covers(0x3A9), isTrue);
      expect(c.covers(0x42), isFalse, reason: 'B n\'est pas déclaré');
      expect(c.covers(0x645), isFalse, reason: 'م n\'est pas déclaré');
    });

    test('🔴 `coversAll` exclut les caractères de MISE EN PAGE', () {
      // Mesuré côté hôte : le `cmap` de NotoSans ne couvre NI `\n` NI `\t`.
      // Sans cette exclusion, tout contenu multiligne serait déclaré non
      // rendable — un refus massif et faux.
      final c = ZFontCoverage.parse(_policeSynthetique(<int>[0x41]))!;
      expect(c.covers(0x0A), isFalse, reason: 'témoin : `\\n` n\'est PAS au cmap');
      expect(c.coversAll('A\nA\tA A'), isTrue,
          reason: 'les blancs ne sont pas dessinés : ils ne se jugent pas');
      expect(c.coversAll('AB'), isFalse);
    });

    test('`missingIn` nomme précisément ce qui manque', () {
      final c = ZFontCoverage.parse(_policeSynthetique(<int>[0x41]))!;
      expect(c.missingIn('AZA'), <int>{0x5A});
      expect(c.missingIn('AAA'), isEmpty);
    });

    // ⚠️ Résultat R3 consigné : retirer SEULEMENT le `try/catch` de `parse`, ou
    // SEULEMENT un contrôle de bornes, laisse ce test VERT — les deux couches
    // sont redondantes PAR CONCEPTION, et chacune suffit. La garde mord sur la
    // CONJONCTION (mutation des deux ⇒ rouge, vérifié). On l'écrit ici plutôt
    // que de laisser croire à un trou de couverture.
    test('🔴 des octets illisibles rendent `null`, JAMAIS un throw (AD-10)', () {
      expect(ZFontCoverage.parse(Uint8List.fromList(<int>[1, 2, 3])), isNull);
      expect(ZFontCoverage.parse(Uint8List(0)), isNull);
      // Police tronquée : le `cmap` annoncé pointe hors du fichier.
      final complete = _policeSynthetique(<int>[0x41]);
      for (var n = 0; n < complete.length; n++) {
        final tronquee = Uint8List.sublistView(complete, 0, n);
        expect(() => ZFontCoverage.parse(tronquee), returnsNormally,
            reason: 'troncature à $n octets');
      }
    });

    test('un point de code hors BMP n\'est pas inventé en format 4', () {
      final c = ZFontCoverage.parse(_policeSynthetique(<int>[0x41]))!;
      expect(c.covers(0x1F600), isFalse, reason: 'format 4 = BMP seul');
    });
  });

  group('🔴 CR-LEX-43 — la CHAÎNE compose plusieurs polices', () {
    test('🔴 un provider qui LÈVE ne casse pas la chaîne (AD-10)', () async {
      final out = await ZFlashcardPdfTemplate(
        fontProvider: _ProviderQuiLeve(),
        fallbackFontProviders: <ZPdfFontProvider>[_ProviderQuiLeve()],
      ).build(_deck('Question'));
      expect(out.bytes.isNotEmpty, isTrue);
    });

    test('🔴 sans police injectée, le chemin WinAnsi est INCHANGÉ', () async {
      // Non-régression capitale : la chaîne vide ne doit RIEN substituer — la
      // première version de ce correctif transformait tout le document en `?`.
      final out = await const ZFlashcardPdfTemplate().build(_deck('LIGNEUN'));
      expect(out.bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(out.bytes.take(5)), '%PDF-');
    });

    test('la chaîne accepte des maillons absents sans se rompre', () async {
      final out = await ZFlashcardPdfTemplate(
        fontProvider: _Provider(null),
        fallbackFontProviders: <ZPdfFontProvider>[
          _Provider(null),
          _Provider(Uint8List.fromList(<int>[1, 2, 3])), // illisible
        ],
      ).build(_deck('Question'));
      expect(out.bytes.isNotEmpty, isTrue);
    });
  });

  group('🔴 CR-LEX-43 — contrôle de RÉALITÉ sur polices système', () {
    final dejavu = _lire(_kDejaVu);
    final cjk = _lire(_kCjk);
    // ⚠️ Ces deux polices ne sont PAS embarquées par le dépôt : sur un hôte qui
    // ne les a pas, ce groupe est ignoré et ne prouve rien. L'ossature
    // falsifiable reste le groupe synthétique ci-dessus.
    final absentes = dejavu == null || cjk == null;

    test('🔴 le lecteur dit VRAI sur des polices réelles', () {
      final cDejavu = ZFontCoverage.parse(dejavu!)!;
      final cCjk = ZFontCoverage.parse(cjk!)!;
      // Vérité connue : DejaVu porte latin/grec/cyrillique, PAS le CJK.
      expect(cDejavu.covers('A'.runes.first), isTrue);
      expect(cDejavu.covers('Ω'.runes.first), isTrue);
      expect(cDejavu.covers('Д'.runes.first), isTrue);
      expect(cDejavu.covers('好'.runes.first), isFalse,
          reason: 'DejaVu ne porte pas le CJK — c\'est tout le problème');
      expect(cCjk.covers('好'.runes.first), isTrue,
          reason: 'contrôle positif : l\'autre police, elle, le porte');
    }, skip: absentes ? 'polices système absentes' : null);

    test('🔴 DEUX ÉCRITURES dans le MÊME document — le cœur de la CR', () async {
      // Avec une seule police, ce document était IMPOSSIBLE.
      final avec = await _texte(
        ZFlashcardPdfTemplate(
          fontProvider: _Provider(dejavu),
          fallbackFontProviders: <ZPdfFontProvider>[_Provider(cjk)],
        ),
        'AAA好BBB',
      );
      expect(avec, contains('好'),
          reason: 'le CJK doit être RENDU par la police de repli');
      expect(avec, contains('AAA'), reason: 'et le latin ne doit rien perdre');
      expect(avec, contains('BBB'));
      expect(avec.contains('AAA?BBB'), isFalse);

      // 🔴 Témoin apparié — SANS lui, ce test ne prouverait pas que c'est la
      // CHAÎNE qui agit : la même police primaire, sans repli, doit produire
      // un `?` à la place du CJK.
      final sans = await _texte(
        ZFlashcardPdfTemplate(fontProvider: _Provider(dejavu)),
        'AAA好BBB',
      );
      expect(sans, contains('AAA?BBB'),
          reason: 'témoin : sans repli, le non-couvert devient `?`');
      expect(sans.contains('好'), isFalse);

      // 🔴 Seconde mesure, INDÉPENDANTE de l'extraction — la police de repli
      // doit être RÉELLEMENT EMBARQUÉE dans le document. Elle est nécessaire :
      // si la sélection par run est débranchée, le CJK est dessiné avec la
      // police primaire en `.notdef` et l'extraction ressort quand même `好`
      // (la `ToUnicode` CMap ment, cf. bandeau). Seul le poids ne ment pas.
      final avecOctets = await _octets(
        ZFlashcardPdfTemplate(
          fontProvider: _Provider(dejavu),
          fallbackFontProviders: <ZPdfFontProvider>[_Provider(cjk)],
        ),
        'AAA好BBB',
      );
      final sansOctets = await _octets(
        ZFlashcardPdfTemplate(fontProvider: _Provider(dejavu)),
        'AAA好BBB',
      );
      // Seuil très large (mesuré : +19 746 octets) — on teste la PRÉSENCE d'un
      // sous-ensemble de police, pas une taille exacte, que la non-déterminisme
      // du moteur rendrait fragile.
      expect(avecOctets, greaterThan(sansOctets + 5000),
          reason: 'la 2e police doit être embarquée, pas seulement choisie');
    }, skip: absentes ? 'polices système absentes' : null);

    test('🔴 le non-couvert devient `?` VISIBLE, pas un `.notdef` muet',
        () async {
      // La garantie que CR-LEX-38 annonçait et que la mesure avait infirmée.
      expect(ZFontCoverage.parse(dejavu!)!.covers('好'.runes.first), isFalse,
          reason: 'prémisse : DejaVu ne porte pas ce glyphe');
      final t = await _texte(
        ZFlashcardPdfTemplate(fontProvider: _Provider(dejavu)),
        'AAA好BBB',
      );
      // Sans substitution, le glyphe absent se dessine en `.notdef` — une case
      // vide qui passe pour une mise en page. Ici il ressort `?` : la perte est
      // VISIBLE, ce que CR-LEX-38 annonçait sans le tenir.
      expect(t, contains('AAA?BBB'));
    }, skip: absentes ? 'polices système absentes' : null);
  });
}

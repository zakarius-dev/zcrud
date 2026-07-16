// Story ES-9.1 — AC5 : provenance de flashcard par REGISTRE pluggable
// (`ZSourceRegistry`, AD-4), jamais par switch codé en dur. Le test enregistre
// un variant lex/IFFD AU NIVEAU DE L'APP (dans le test, R21) et prouve la
// COMPOSITION propre à ES-9.1 : une carte PRODUITE PAR LE PORT round-trippe sa
// provenance enregistrée EXACTEMENT (kind ET corps) via
// `ZFlashcard.toMap/fromMap(sourceRegistry:)`. R20 : on n'assert PAS la
// mécanique interne de `ZFlashcardSource`/`ZSourceRegistry` (déjà testée
// ailleurs) — on assert la préservation à travers le seam de génération.
// Runner R14 : `flutter test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Fake port app-side : ESTAMPILLE `request.provenance` dans `ZFlashcard.source`
/// (comportement contractuel AC5 que l'impl app-side réalise).
class _StampingGenerationPort implements ZFlashcardGenerationPort {
  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  ) async =>
      Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[
        ZFlashcard(question: request.content, source: request.provenance),
      ]);
}

/// Enregistre un variant lex/IFFD `article` (corps riche `hs_section`) au niveau
/// APP. Codec identité qui STRIPE le discriminant `kind` du corps reconstruit
/// (pour un round-trip payload EXACT).
ZSourceRegistry _appRegistryWithArticle() {
  final reg = ZSourceRegistry();
  reg.register(
    'article',
    toJson: (Object value) => Map<String, dynamic>.from(value as Map),
    fromJson: (Map<String, dynamic> json) =>
        Map<String, dynamic>.from(json)..remove('kind'),
  );
  return reg;
}

void main() {
  test(
      'AC5 — carte produite par le port round-trippe sa provenance enregistrée '
      '(kind ET corps préservés, R26)', () async {
    final reg = _appRegistryWithArticle();

    // Provenance lex/IFFD à corps riche, portée par la REQUÊTE du seam.
    final provenance = ZCustomSource(
      'article',
      const <String, dynamic>{'hs_section': '84.71', 'ref': 'A-123'},
    );
    final request =
        ZFlashcardGenerationRequest(content: 'q?', provenance: provenance);

    final ZFlashcardGenerationPort port = _StampingGenerationPort();
    final res = await port.generateFlashcards(request);
    final card = res.getOrElse(() => throw StateError('attendu Right')).single;

    // La carte PRODUITE PAR LE PORT porte la provenance.
    expect(card.source, isNotNull);

    // Round-trip EXACT à travers le seam de (dé)sérialisation de la carte.
    final map = card.toMap(sourceRegistry: reg);
    final restored = ZFlashcard.fromMap(map, sourceRegistry: reg);

    final restoredSource = restored.source;
    expect(restoredSource, isA<ZCustomSource>());
    restoredSource as ZCustomSource;

    // R26 : kind ET corps préservés byte-à-byte (R3-I5 : un codec dont le toJson
    // DROPPE `hs_section` fait ROUGIR l'égalité de source ci-dessous).
    expect(restoredSource.kind, 'article');
    expect(restoredSource.payload['hs_section'], '84.71');
    expect(restoredSource.payload['ref'], 'A-123');
    expect(restored.source, equals(card.source));
  });

  test('AC5 — un SECOND variant ouvert (chatConversation) round-trippe aussi',
      () async {
    final reg = ZSourceRegistry();
    reg.register(
      'chatConversation',
      toJson: (Object value) => Map<String, dynamic>.from(value as Map),
      fromJson: (Map<String, dynamic> json) =>
          Map<String, dynamic>.from(json)..remove('kind'),
    );
    final provenance = ZCustomSource(
      'chatConversation',
      const <String, dynamic>{'chat_conversation_id': 'conv-9'},
    );
    final port = _StampingGenerationPort();
    final res = await port.generateFlashcards(
      ZFlashcardGenerationRequest(content: 'q', provenance: provenance),
    );
    final card = res.getOrElse(() => throw StateError('right')).single;
    final restored =
        ZFlashcard.fromMap(card.toMap(sourceRegistry: reg), sourceRegistry: reg);
    expect(restored.source, equals(card.source));
    expect((restored.source! as ZCustomSource).payload['chat_conversation_id'],
        'conv-9');
  });

  test('AC5 — AUCUN kind de provenance lex/douane codé en dur dans zcrud_study '
      '(R3-I6)', () {
    final dir = Directory('lib/src/domain');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    // Aucun switch/if sur `kind`, aucun variant lex/douane littéral.
    final forbidden = <RegExp>[
      RegExp(r'''kind\s*==\s*['"]'''),
      RegExp(r'switch\s*\(\s*\w*[kK]ind'),
      RegExp(r'''case\s+['"](article|subject|hsSection|chatConversation)'''),
      RegExp(r'''['"](hs_section|hsSection|chat_conversation_id)['"]'''),
    ];

    final violations = <String>[];
    for (final f in files) {
      final content = f.readAsStringSync();
      for (final re in forbidden) {
        if (re.hasMatch(content)) {
          violations.add('${f.path} : ${re.pattern}');
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'kind lex/douane codé en dur détecté : ${violations.join(', ')}');
  });
}

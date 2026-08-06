/// Harnais du **lot 1 « étude »** — faux seams, sonde de rebuild, montage.
///
/// 🔒 Vit sous `test/` : les scanners de `lib/src/presentation/**`
/// (`z_widgets_purity_test.dart`, `z_widgets_hardcode_scan_test.dart`) ne le
/// voient pas, et n'ont pas à le voir — c'est du **harnais**, pas de la
/// production.
library;

import 'package:dartz/dartz.dart' show Left, Right;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester, addTearDown;
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardType, ZRepetitionInfo;

/// Dossier de démonstration du harnais (identité **opaque**, jamais rendue).
const String kHarnessFolderId = 'harnessStudyFolder';

/// Faux `ZSessionReviewer` — **compte** les écritures SRS et sait échouer.
///
/// 🔴 Le compteur est le point du harnais : une assertion « zéro écriture SRS »
/// n'a de valeur que si le **contrôle positif** (store sain ⇒ compteur à 1)
/// prouve que la voie est réellement câblée. Sans lui, un `0` pourrait tout
/// aussi bien signifier « aucun seam branché ».
class FakeSessionReviewer {
  /// Construit un faux seam. [failure] non nul ⇒ **chaque** appel rend un
  /// `Left` (le compteur reste à 0 : un échec n'est pas une écriture).
  FakeSessionReviewer({this.failure});

  /// Échec typé à rendre, ou `null` pour un seam sain.
  final ZFailure? failure;

  /// Nombre d'écritures SRS **abouties**.
  int writes = 0;

  /// Qualités reçues, dans l'ordre — permet d'assérer *quelle* note est passée.
  final List<int> qualities = <int>[];

  /// Identités de carte reçues, dans l'ordre — permet d'assérer *quelle* carte
  /// a été notée (le cœur du piège ① : une note qui tombe à côté).
  final List<String> gradedIds = <String>[];

  /// Le seam lui-même, à passer en `reviewer:`.
  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    final ZFailure? f = failure;
    if (f != null) return Left<ZFailure, ZRepetitionInfo>(f);
    writes += 1;
    qualities.add(quality);
    gradedIds.add(flashcardId);
    return Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(
        flashcardId: flashcardId,
        folderId: folderId,
        repetitions: 1,
        lastQuality: quality,
      ),
    );
  }
}

/// Journal de rebuild **granulaire** : compte les builds par nom de sonde.
class RebuildLog {
  final Map<String, int> _counts = <String, int>{};

  /// Incrémente le compteur de [name].
  void bump(String name) => _counts[name] = (_counts[name] ?? 0) + 1;

  /// Nombre de builds enregistrés pour [name] (0 si jamais construit).
  int countOf(String name) => _counts[name] ?? 0;

  /// Remet tous les compteurs à zéro.
  void reset() => _counts.clear();
}

/// Sonde de rebuild : incrémente [name] à CHAQUE build de ce nœud, puis rend
/// [child].
///
/// Placée aux points d'intégration (pile, carte, compteurs) : si l'hôte
/// reconstruit globalement (violation SM-1), le compteur bouge ; sinon il reste
/// à son plancher.
class RebuildProbe extends StatelessWidget {
  /// Construit une sonde nommée.
  const RebuildProbe({
    required this.name,
    required this.log,
    required this.child,
    super.key,
  });

  /// Nom du compteur.
  final String name;

  /// Journal cible.
  final RebuildLog log;

  /// Sous-arbre rendu tel quel.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    log.bump(name);
    return child;
  }
}

/// Fabrique une carte RÉDIGÉE (question ouverte ⇒ champ de saisie présent).
ZFlashcard writtenCard(String id, {String answer = 'ok'}) => ZFlashcard(
      id: id,
      folderId: kHarnessFolderId,
      type: ZFlashcardType.openQuestion,
      question: 'Question $id.',
      answer: answer,
    );

/// Fabrique [n] cartes rédigées `c0…c{n-1}`.
List<ZFlashcard> writtenCards(int n) =>
    <ZFlashcard>[for (var i = 0; i < n; i++) writtenCard('c$i', answer: 'r$i')];

/// Monte [child] dans un `MaterialApp` + `Scaffold`.
///
/// 🔴 Le `Scaffold` n'est pas décoratif : `ZFlashcardAnswerInput` contient un
/// `TextFormField`, et `TextField` **exige** un ancêtre `Material`. Sans lui, le
/// montage lève « No Material widget found » — mesuré au premier jet de ce
/// harnais. C'est aussi la forme réelle d'un hôte (`ZStudySessionScaffold` pose
/// un `ZPageScaffold`, donc un `Scaffold`).
Widget wrapForTest(Widget child, {TextDirection? textDirection}) => MaterialApp(
      home: Scaffold(
        body: textDirection == null
            ? child
            : Directionality(textDirection: textDirection, child: child),
      ),
    );

/// Étire la fenêtre de test — la pile (flex 3) et la saisie (flex 2) se
/// partagent la hauteur, et la surface de saisie déborderait de la fenêtre par
/// défaut (600×800), rendant ses boutons non tapables.
///
/// Patron **exact** du harnais de l'assemblage de référence
/// (`example/test/support/pump_helpers.dart`) — y compris la multiplication par
/// le `devicePixelRatio`, sans laquelle la taille demandée est divisée par lui.
void useTallSurface(WidgetTester tester, {double height = 6000}) {
  tester.view.physicalSize = Size(
    1200 * tester.view.devicePixelRatio,
    height * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetPhysicalSize);
}

// Harnais golden DISCRIMINANT ES-5.1 (AC4 + AC5).
//
// AC4 : golden de référence de l'apparence DÉCOMPOSÉE (en-têtes+compteurs,
//       cartes d'items, état vide de la section notes).
// AC5 : POUVOIR DISCRIMINANT — le golden RÉGRESSE si la décomposition casse.
//   (a) byte-diff : fusion (m1) / permutation (m2) / altération (m3) produisent
//       des OCTETS différents du canonique (`isNot(equals)`).
//   (b) comptage structurel : N sections → N sous-arbres ; fusion → N-1.
//
// Un `matchesGoldenFile` seul est INSUFFISANT (un monolithe aux mêmes pixels
// passerait) : (a)+(b) ferment la faille. Powerless rejetés — surface pleine
// (1000×1600, cf. kByteCaptureSize), tolérance de diff NULLE (comparateur local
// exact), rendu NON constant (contenu Ahem dépendant de l'ordre/longueur).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import '_fixtures.dart';

void main() {
  group('AC4 — golden de référence (apparence décomposée fidèle)', () {
    testWidgets('canonique correspond au golden committé', (tester) async {
      await pumpSectionedLayout(tester, sections: canonicalSections());

      await expectLater(
        find.byType(ZSectionedStudyLayout),
        matchesGoldenFile('goldens/study_tools_sectioned.png'),
      );
    });
  });

  group('AC5(a) — byte-diff : la décomposition cassée change le rendu', () {
    testWidgets('m1 fusion → octets ≠ canonique', (tester) async {
      final canonical = await captureBytes(tester, canonicalSections());
      final fused = await captureBytes(tester, fusedSections());

      // Retrait de la section notes → moins de sous-arbres → rendu distinct.
      expect(fused, isNot(equals(canonical)));
    });

    testWidgets('m2 permutation → octets ≠ canonique', (tester) async {
      final canonical = await captureBytes(tester, canonicalSections());
      final permuted = await captureBytes(tester, permutedSections());

      // L'ordre visuel SUIT l'ordre d'entrée : permuter deux sections change
      // le rendu (aucun tri implicite ne le neutralise).
      expect(permuted, isNot(equals(canonical)));
    });

    testWidgets('m3 altération (état vide) → octets ≠ canonique',
        (tester) async {
      final canonical = await captureBytes(tester, canonicalSections());
      final altered = await captureBytes(tester, alteredEmptySections());

      // Altérer l'apparence de la section vide (son emptyState) change le rendu
      // — l'état vide est bien rendu (jamais un SizedBox silencieux).
      expect(altered, isNot(equals(canonical)));
    });
  });

  group('AC5(b) — décomposition COMPTABLE (structurelle, pas cosmétique)', () {
    testWidgets('N sections → N sous-arbres keyés section:*', (tester) async {
      await pumpSectionedLayout(tester, sections: canonicalSections());

      // 4 sections canoniques → 4 frontières de widget distinctes.
      expect(sectionSubtrees(), findsNWidgets(4));
    });

    testWidgets('fusion → N-1 sous-arbres', (tester) async {
      await pumpSectionedLayout(tester, sections: fusedSections());

      // Retrait de la section notes → 3 sous-arbres (N-1).
      expect(sectionSubtrees(), findsNWidgets(3));
    });
  });
}

// NB : l'axe du rail flashcards (`Axis.horizontal`) est CONSTANT entre le
// canonique et chaque mutant — la SEULE différence testée reste la mutation
// (fusion / permutation / altération), préservant le pouvoir discriminant.

/// m1 — RETRAIT-FUSION : la section notes (vide) est RETIRÉE, ne laissant que
/// les 3 sections peuplées (3 sous-arbres au lieu de 4). Le comptage structurel
/// N→N-1 régresse et le byte-diff diffère du canonique.
List<ZStudyToolsSectionSpec> fusedSections() {
  return [
    populatedSection('flashcards', 'Flashcards', 3, axis: Axis.horizontal),
    populatedSection('documents', 'Documents', 2),
    populatedSection('mindmaps', 'Mindmaps', 2),
  ];
}

/// m2 — PERMUTATION : documents et mindmaps échangés (ordre ≠ canonique).
List<ZStudyToolsSectionSpec> permutedSections() {
  return [
    populatedSection('flashcards', 'Flashcards', 3, axis: Axis.horizontal),
    populatedSection('mindmaps', 'Mindmaps', 2),
    emptySection('notes', 'Notes'),
    populatedSection('documents', 'Documents', 2),
  ];
}

/// m3 — ALTÉRATION : la section vide notes reçoit un emptyState d'apparence
/// DIFFÉRENTE (dépend du rendu réel de l'état vide, cf. R3-I3).
List<ZStudyToolsSectionSpec> alteredEmptySections() {
  return [
    populatedSection('flashcards', 'Flashcards', 3, axis: Axis.horizontal),
    populatedSection('documents', 'Documents', 2),
    emptySection('notes', 'Notes', emptyLabel: 'ALTERED-EMPTY-STATE'),
    populatedSection('mindmaps', 'Mindmaps', 2),
  ];
}

/// Test de **surface publique positive** (ES-1.2, D3, AC6, T7).
///
/// Importe **UNIQUEMENT** `package:zcrud_flashcard/zcrud_flashcard.dart` et
/// référence les symboles historiques E9/ES-1.1 (y compris les symboles
/// **générés** `registerZStudyFolder`/`registerZStudySessionConfig`).
///
/// Ce test compile ⇒ la surface historique est intacte malgré le narrowing
/// `hide` du réexport kernel (D3) : si un futur `hide` mord sur un symbole
/// historique, ce fichier **échoue à la compilation** (filet de
/// non-régression, pas seulement à l'exécution).
///
/// ⚠️ Ce test est **POSITIF UNIQUEMENT** : il est structurellement **incapable**
/// de détecter une **fuite** (un nouvel utilitaire kernel oublié dans le `hide`).
/// Le versant **NÉGATIF** — outillé — vit dans `z_kernel_surface_guard_test.dart`
/// (finding L4 du code-review ES-1.2) : il croise les symboles publics réels du
/// barrel kernel avec le `hide` + une allowlist, et **échoue** sur tout symbole
/// non classé. Les deux tests sont complémentaires : celui-ci garde la surface
/// historique, l'autre garde la frontière.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  test('surface historique E9/ES-1.1 intacte malgré le hide ES-1.2', () {
    // Entités canoniques (E9).
    const flashcard = ZFlashcard(question: 'Question ?');
    expect(flashcard.question, 'Question ?');

    // Remontés au kernel (ES-1.1) — toujours publics via zcrud_flashcard.
    const folder = ZStudyFolder(title: 'Dossier');
    expect(folder.title, 'Dossier');

    expect(ZReviewMode.values, isNotEmpty);

    const config = ZStudySessionConfig(mode: ZReviewMode.spaced);
    const selector = ZStudySessionSelector(config);
    expect(selector.matches(flashcard), isTrue);

    // Port neutre `ZSessionCandidate` (ES-1.1) — ZFlashcard l'implémente.
    final ZSessionCandidate candidate = flashcard;
    expect(candidate.typeKey, ZFlashcardType.openQuestion.name);

    // Primitive pure de hiérarchie (ES-1.1).
    final placement = validatePlacement(parentId: null);
    expect(placement.isRight(), isTrue);

    // Symboles GÉNÉRÉS (part '*.g.dart') — la raison même du choix `hide`
    // plutôt que `show` (D3) : ils doivent rester publics sans être énumérés.
    final registerFolder = registerZStudyFolder;
    final registerConfig = registerZStudySessionConfig;
    expect(registerFolder, isNotNull);
    expect(registerConfig, isNotNull);
  });
}

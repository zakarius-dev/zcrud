# zcrud_export_ui

Destinations d'export **plateforme** pour zcrud : `zcrud_export` reste pur
(bytes en entrée, bytes en sortie), ce paquet porte tout ce qui a besoin
d'une vraie plateforme (rendu hors écran, partage, impression).

## Aperçu {#apercu}

`zcrud_export_ui` est un satellite feuille : aucun paquet zcrud n'en dépend,
et ses seules arêtes sortantes sont `zcrud_export` et `zcrud_core` (invariant
[AD-1](../../docs/site/concepts/invariants.md#ad-1)). Il fournit deux
maillons plateforme que `zcrud_export` — package pur — ne peut pas porter :

- **la rastérisation LaTeX concrète** ([ZFlutterMathLatexRasterizer]),
  implémentation du port pur `ZLatexRasterizer` déclaré dans `zcrud_export`,
  via `flutter_math_fork` (rendu hors écran → PNG) ;
- **l'aperçu, l'impression et le partage** de bytes PDF déjà rendus
  ([ZPdfPreview], [ZPdfShareService]), via `printing`.

L'API publique reste **100 % `Uint8List`** : aucun type de `printing`, `pdf`
ou `flutter_math_fork` (`PdfPageFormat`, `Math`…) ne franchit la frontière du
paquet — un test de confinement le garantit.

**Utilisez ce paquet** dès que votre application doit rendre une formule
LaTeX en image, ou prévisualiser/imprimer/partager un PDF déjà produit par
`zcrud_export`/`zcrud_export_pdf`. **N'utilisez pas ce paquet** pour produire
les bytes eux-mêmes (`zcrud_export`/`zcrud_export_pdf`) : celui-ci ne fait
que consommer des bytes déjà mis en page.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_export/zcrud_export.dart';
import 'package:zcrud_export_ui/zcrud_export_ui.dart';

Future<void> exportAndShareFlashcards(ZFlashcardPdfInput input) async {
  // 1. Rendu des bytes PDF avec le gabarit PUR + le rasteriseur concret.
  final rasterizer = ZFlutterMathLatexRasterizer();
  final template = ZFlashcardPdfTemplate(rasterizer: rasterizer);
  final file = await template.build(
    input,
    answerVisibility: ZAnswerVisibility.withAnswers,
  );

  // 2. Partage des bytes (plateforme).
  await ZPdfShareService().share(file.bytes, fileName: file.fileName);
  // ou intégration dans l'arbre : ZPdfPreview(bytes: file.bytes)
}
```

## Concepts clés {#concepts-cles}

- **Isolation plateforme (invariant [AD-8](../../docs/site/concepts/invariants.md#ad-8))** —
  sur le patron des autres satellites d'implémentation, l'API publique ne
  manipule que des types neutres ; les types tiers (`Math`, `PdfPageFormat`…)
  sont absorbés à l'intérieur de `lib/src/` et jamais réexportés.
- **Défensif (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  un LaTeX vide, invalide, ou toute erreur de rendu, rend `null` — jamais un
  throw. Le gabarit PDF appelant retombe alors sur le texte brut de la
  formule.
- **Accessibilité (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  `ZPdfPreview` porte un `Semantics` explicite (« aperçu du document PDF » par
  défaut, injectable) ; les actions imprimer/partager restent celles,
  natives, de `printing`.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZFlutterMathLatexRasterizer` | Implémentation concrète de `ZLatexRasterizer` : rend une formule LaTeX en PNG hors écran. |
| `ZPdfShareService` | Partage et impression système de bytes PDF déjà rendus. |
| `ZPdfPreview` | Widget d'aperçu PDF avec actions imprimer/partager intégrées. |
| `ZExportUiApi` | Marqueur de version de l'API publique du paquet. |

## Cas limites et invariants {#cas-limites}

- `rasterize` rend `null` pour un LaTeX vide, invalide, ou en cas d'erreur de
  rendu — jamais d'exception propagée à l'appelant.
- L'arbre de rendu hors écran utilisé par le rasteriseur est toujours
  démonté après capture, y compris en cas d'erreur — aucune fuite de cycle
  de vie.
- Les fontes KaTeX sont embarquées par `flutter_math_fork` lui-même ; aucun
  asset à déclarer côté application hôte.

## Voir aussi {#voir-aussi}

- [zcrud_export](../zcrud_export/README.md) — façade d'export neutre dont ce
  paquet consomme les bytes.
- [zcrud_export_pdf](../zcrud_export_pdf/README.md) — le port pur
  `ZLatexRasterizer` et le gabarit PDF flashcards implémentés ici.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.

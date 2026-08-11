# zcrud_document

Document d'étude de zcrud — contenu partageable, état de lecture personnel
et annotations accessibles, avec une bascule Flutter pour la présentation
d'annotation (invariant AD-13, WCAG).

## Aperçu {#apercu}

`zcrud_document` est le paquet **satellite** de la capacité document, au
sens du patron [kernel/satellite](../../docs/site/concepts/architecture-hexagonale.md#le-patron-kernel-satellite) :
il dépend de `zcrud_study_kernel` pour le dossier et la palette de couleurs,
et porte le modèle spécifique au document — son contenu, son état de
lecture personnel et ses annotations.

Ce paquet fournit :

- le **document d'étude** — `ZStudyDocument`, le contenu partageable
  (nom de fichier, chemin de stockage, statut d'ingestion, taille) ;
- l'**état de lecture personnel** — `ZDocumentReadingState` (page courante,
  préférences de viewer, pages maîtrisées), séparé par construction du
  contenu partageable : partager un document n'emporte jamais la
  progression de lecture d'autrui ;
- les **préférences de lecture** — `ZDocumentViewerPrefs` (zoom borné, sens,
  disposition) en enums pur-Dart, sans dépendance à une bibliothèque de
  rendu concrète ;
- l'**annotation partageable** — `ZDocumentAnnotation` (surlignage ou note
  ancrée), son rectangle d'ancrage borné `[0,1]` `ZAnnotationBounds` ;
- la **présentation accessible** de la toolbar et du panneau d'annotation
  (`ZAnnotationToolbar`, `ZAnnotationPanel`), et la coquille de viewer
  neutre `ZDocumentViewerChrome` — aucune n'importe de moteur de rendu PDF.

**Utilisez ce paquet** pour porter le modèle document d'une application
d'étude, ou pour composer une UI d'annotation accessible au-dessus d'un
viewer de votre choix. **N'utilisez pas ce paquet** si vous avez seulement
besoin du dossier ou de la sélection de session — passez directement par
`zcrud_study_kernel`.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  // Contenu partageable : round-trip sans perte, tel que le fera un store.
  const document = ZStudyDocument(
    folderId: 'folder-1',
    fileName: 'Cours de droit douanier.pdf',
  );
  final Map<String, dynamic> persisted = document.toMap();
  final ZStudyDocument relu = ZStudyDocument.fromMap(persisted);
  assert(relu.fileName == document.fileName);
  assert(relu.formatKey == 'pdf'); // dérivé de fileName, jamais stocké.

  // État de lecture personnel : jamais colocalisé avec le document.
  final state = ZDocumentReadingState.fromMap(const <String, dynamic>{
    'doc_id': document.id,
    'current_page': 12,
  });
  assert(state.currentPage == 12);
}
```

## Concepts clés {#concepts-cles}

- **Contenu partageable vs état personnel, séparés par construction** —
  `ZStudyDocument` (contenu) et `ZDocumentReadingState` (lecture) ne sont
  jamais imbriqués l'un dans l'autre : aucune clé de lecture n'apparaît dans
  les spécifications de champ du document. Partager ou dupliquer un document
  n'emporte donc jamais la progression de lecture d'autrui.
- **Désérialisation totale, jamais levée (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  chaque `fromMap`/`fromJson` de ce paquet rend un résultat même sur une
  entrée vide, corrompue ou de mauvais type : une page hors domaine retombe
  sur `1`, un zoom non fini ou négatif retombe sur le défaut, un rectangle
  d'ancrage corrompu retombe sur `(0,0,0,0)`.
- **Aucune clé de synchronisation dans les entités (invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9))** —
  ni `ZStudyDocument`, ni `ZDocumentReadingState`, ni `ZDocumentAnnotation`
  ne déclarent `updatedAt`/`isDeleted` inline ; l'autorité Last-Write-Wins et
  le soft-delete vivent hors-entité (`ZSyncMeta`).
- **Accessibilité WCAG native (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  la toolbar et le panneau d'annotation ne signalent jamais un état par la
  seule couleur : chaque swatch porte un libellé sémantique distinct et un
  marqueur structurel non-coloré, avec un contraste dérivé du `ColorScheme`
  courant.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Document** | |
| `ZStudyDocument` | Document d'étude — contenu partageable (nom, statut, taille). |
| `ZDocumentStatus` | Cycle de vie du document (upload → validation → prêt). |
| **Lecture personnelle** | |
| `ZDocumentReadingState` | État de lecture personnel, clé par identifiant de document. |
| `ZDocumentViewerPrefs` / `ZDocumentScrollDirection` / `ZDocumentPageLayout` | Préférences de lecture (zoom borné, sens, disposition). |
| `ZDocumentLearningInfo` / `ZDocPageQuality` | Maîtrise par page, colocalisée dans l'état de lecture. |
| **Annotation** | |
| `ZDocumentAnnotation` / `ZDocumentAnnotationKind` | Annotation partageable (surlignage / note ancrée). |
| `ZAnnotationBounds` | Rectangle d'ancrage borné `[0,1]` d'une annotation. |
| **Présentation** | |
| `ZAnnotationToolbar` / `ZAnnotationToolController` | Barre d'outils accessible (kind + palette) et son état réactif isolé. |
| `ZAnnotationPanel` | Liste accessible et paresseuse des annotations d'un document. |
| `ZDocumentViewerChrome` / `ZDocumentPageNavigation` / `ZDocumentViewerLoadState` | Coquille de viewer indépendante de tout moteur de rendu. |

## Cas limites et invariants {#cas-limites}

- **La pagination est 1-based partout** — `ZDocumentReadingState.currentPage`
  et `ZDocumentAnnotation.page` retombent sur `1` (jamais `0` ni négatif) à
  la désérialisation comme à la copie ; `ZDocumentLearningInfo` ignore
  silencieusement toute entrée dont la page est hors domaine.
- **`pageCount` distingue « inconnu » de « zéro page »** — une valeur `<= 0`
  retombe sur `null`, jamais sur `0` : un document a toujours au moins une
  page, ou son nombre de pages n'est simplement pas encore connu.
- **`colorKey` est brute dans l'entité, bornée à l'affichage** — l'entité ne
  clampe jamais la couleur d'une annotation contre une palette : la
  résolution `colorKey → Color` est un seam de présentation
  (`remapColorKey`, `zcrud_study_kernel`), jamais du domaine.
- **`ZAnnotationToolController` n'expose aucune `Color`** — le contrôleur ne
  connaît que des `colorKey` opaques ; la résolution vers une couleur
  concrète est injectée via `ZcrudScope.colorKeyResolver`.
- **Le domaine reste pur-Dart, la présentation seule requiert Flutter** — le
  sous-dossier `lib/src/domain/` n'importe aucun SDK Flutter et tourne sous
  `flutter test` comme sous `dart test` ; seul `lib/src/presentation/`
  compose des widgets.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_document.md`](../../docs/site/paquets/zcrud_document.md)
- [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md) — couches, ports et patron kernel/satellite.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_study_kernel` — le kernel dont ce paquet porte le dossier, la palette et le port de référence document.
- `zcrud_core` — `ZResult`/`ZFailure`, `ZcrudTheme`, résolution de libellés et de couleurs.

## Licence {#licence}

MIT — voir la racine du dépôt.

# zcrud_media

Satellite **média** de zcrud — câble le contrat cœur `ZFilePicker`/`ZFileSource`
derrière une API neutre, et fournit des affordances riches (drop-zone,
ouverture au tap, vignette vidéo).

## Aperçu {#apercu}

`zcrud_media` fournit deux capacités distinctes, toutes deux dérivées du
contrat existant `ZFilePicker`/`ZFileSource` de `zcrud_core` :

- **`ZMediaFilePicker`** — implémentation neutre de `ZFilePicker`, à
  injecter dans `ZcrudScope.filePicker`. Sert l'acquisition des types
  natifs `image`/`file`/`document` que le cœur route vers `ZAppFileField`.
  L'acquisition (galerie, caméra, sélecteur de documents, recadrage) est
  déléguée à des seams injectables — plugins réels par défaut, doublures de
  test dans les tests.
- **Widgets média riches** (`registerZMediaFieldWidgets`) — enregistre trois
  builders dans un `ZWidgetRegistry`, sous des `kind` alignés sur
  `EditionFieldType.mediaImage`/`mediaFile`/`mediaVideo`. Ces types sont un
  chemin **distinct** des types natifs `image`/`file`/`document` — jamais un
  override.

Aucun type de plugin (`image_picker`, `file_picker`, `image_cropper`,
`video_thumbnail`, `open_file`, `dotted_border`) n'apparaît dans le barrel ni
dans une signature publique : ces dépendances sont confinées à
l'implémentation.

**Utilisez ce paquet** pour l'acquisition et l'affichage de fichiers média
(image, document, vidéo) dans un formulaire zcrud. **N'utilisez pas ce
paquet** si votre application n'acquiert aucun média : le contrat
`ZFilePicker` a un défaut zéro-dépendance dans `zcrud_core`.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_media/zcrud_media.dart';

Widget buildApp(Widget child) {
  final picker = ZMediaFilePicker(); // seams/crop optionnellement injectés
  final registry = ZWidgetRegistry();
  registerZMediaFieldWidgets(registry, picker: picker);
  return ZcrudScope(filePicker: picker, widgetRegistry: registry, child: child);
}
```

## Concepts clés {#concepts-cles}

- **Deux voies de dispatch distinctes** — les types natifs `image`/`file`/
  `document` sont routés par le cœur vers `ZAppFileField` ; les types riches
  `mediaImage`/`mediaFile`/`mediaVideo` sont routés vers le
  `ZWidgetRegistry`, résolus uniquement si `registerZMediaFieldWidgets` a été
  appelé au bootstrap. Sans enrôlement, ces derniers dégradent proprement en
  `ZUnsupportedFieldWidget` (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10)).
- **Value-in-slice (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  le widget riche lit `ctx.value` et écrit via `ctx.onChanged` dans la
  frontière de rebuild du dispatcher ; aucune souscription élargie.
- **Vignettes vidéo mémoïsées** — le `Future` de génération native est
  calculé une seule fois par chemin de fichier et réutilisé à chaque
  rebuild, jamais régénéré tant que le chemin ne change pas.
- **Recadrage opt-in, rétrocompatible** — `ZMediaCropOptions` est
  **désactivé par défaut** : sans opt-in explicite, le flux d'acquisition
  d'image reste strictement inchangé.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZMediaFilePicker` | Implémentation neutre de `ZFilePicker`, à injecter dans `ZcrudScope.filePicker`. |
| `registerZMediaFieldWidgets` | Enrôle les trois widgets riches dans un `ZWidgetRegistry`. |
| `ZMediaFieldWidget` / `ZMediaFieldMode` | Widget riche (drop-zone/ouverture/vignette) et son mode de rendu. |
| `mediaImageFieldKind` / `mediaFileFieldKind` / `mediaVideoFieldKind` | `kind` alignés sur `EditionFieldType` pour l'enrôlement dans le registre. |
| `ZImagePickSeam` / `ZFilePickSeam` / `ZImageCropSeam` / `ZDocumentScanSeam` / `ZVideoThumbnailSeam` / `ZFileOpenSeam` | Seams d'acquisition injectables, neutres en signature. |
| `ZMediaCropOptions` | Options neutres de recadrage post-pick, désactivées par défaut. |

## Cas limites et invariants {#cas-limites}

- Toute annulation, permission refusée ou échec de plugin produit un
  résultat défini (liste vide, `null` ou `false`) — jamais un throw
  traversant (invariant AD-10).
- Aucune implémentation de numérisation de document n'est fournie par
  défaut : `ZDocumentScanSeam` reste `null` sauf injection explicite par
  l'hôte, auquel cas `pick(source: scan)` rend une liste vide.
- **Limite connue sur la vidéo** : la drop-zone du mode vidéo acquiert via
  la galerie d'images (aucun chemin `pickVideo` dans le contrat cœur). Le
  champ vidéo gère pleinement la vignette d'un `AppFile` vidéo préexistant ;
  l'acquisition vidéo directe reste un axe d'évolution du contrat cœur.
- Un recadrage annulé par l'utilisateur conserve l'original, jamais une
  perte de fichier.

## Voir aussi {#voir-aussi}

- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.

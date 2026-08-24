---
title: zcrud_media
description: Acquisition et affichage de fichiers média pour zcrud — picker neutre et widgets riches.
---

# zcrud_media

## Rôle

`zcrud_media` implémente le contrat cœur `ZFilePicker` (`ZMediaFilePicker`)
et fournit trois widgets d'édition riches (image, fichier, vidéo) enregistrés
dans le `ZWidgetRegistry`. Les dépendances de plugin (`image_picker`,
`file_picker`, `image_cropper`, `video_thumbnail`, `open_file`) restent
confinées à l'implémentation.

## Quand l'utiliser

- Pour acquérir des images, documents ou vidéos avec galerie/caméra/sélecteur
  de documents, sans réécrire la logique de picker.
- Pour un champ média riche avec drop-zone, ouverture au tap et vignette
  vidéo, servi via le registre de widgets.

## Quand ne pas l'utiliser

- Si l'application n'acquiert aucun média : le contrat `ZFilePicker` a un
  défaut zéro-dépendance dans `zcrud_core`.

## Types clés

| Type | Rôle |
|---|---|
| `ZMediaFilePicker` | Implémentation neutre de `ZFilePicker`. |
| `registerZMediaFieldWidgets` | Enrôle les widgets média riches dans un `ZWidgetRegistry`. |
| `ZMediaFieldWidget` | Widget riche : drop-zone, ouverture, vignette vidéo. |
| `ZMediaCropOptions` | Options neutres de recadrage post-pick, désactivées par défaut. |
| `ZImagePickSeam` / `ZFilePickSeam` / `ZDocumentScanSeam` / `ZImageCropSeam` / `ZVideoThumbnailSeam` / `ZFileOpenSeam` | Les six seams d'acquisition **injectables** derrière `ZMediaFilePicker` : aucune signature ne porte de type plateforme (`XFile`, `PlatformFile`, `File`…), seulement des `AppFile`, chemins et `Uint8List`. Un test injecte un fake déterministe au lieu du plugin réel. Chacun garantit un **résultat défini** — liste vide, `null` ou `false` — sur annulation, permission refusée ou plugin défaillant, jamais une exception traversante ([AD-10](../concepts/invariants.md#ad-10)). |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_media/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.

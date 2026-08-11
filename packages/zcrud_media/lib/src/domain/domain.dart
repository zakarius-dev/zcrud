// Couche DOMAINE (pure) du satellite `zcrud_media`.
//
// Matérialise la couche `domain` de l'hexagone. Le contrat
// `ZFilePicker`/`ZFileSource` vit dans zcrud_core (réutilisé, jamais
// redéclaré) ; les seams d'acquisition propres à ce paquet
// (`ZImagePickSeam`, `ZFilePickSeam`, `ZImageCropSeam`, `ZDocumentScanSeam`,
// `ZVideoThumbnailSeam`, `ZFileOpenSeam`) vivent dans
// `z_media_seams.dart`, à côté de ce fichier. Aucune dépendance hors
// {flutter, zcrud_core}. Fichier documenté sans symbole.

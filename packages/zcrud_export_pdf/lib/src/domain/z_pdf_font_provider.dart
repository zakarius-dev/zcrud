/// Port **neutre** de fourniture de police PDF (CR-LEX-38).
///
/// ## Le défaut qu'il ferme
///
/// Le gabarit PDF n'utilisait que `PdfStandardFont` — des polices **WinAnsi**,
/// qui ne portent que le latin-1. Tout caractère hors de ce jeu (arabe, grec,
/// cyrillique, CJK, emoji) était remplacé par `?` afin que le rendu ne lève
/// pas. **C'est une destruction silencieuse de contenu utilisateur** : la carte
/// exportée ne contient plus le texte, et rien ne le signale.
///
/// Et **aucun contournement hôte n'existait** : le gabarit n'exposait aucun
/// point d'injection, donc une app disposant déjà de polices Unicode (Noto,
/// DejaVu) ne pouvait rien en faire.
///
/// ## Pourquoi un PORT plutôt qu'une police embarquée
///
/// Embarquer une police Unicode ferait grossir le paquet de plusieurs Mo pour
/// **tous** les consommateurs, y compris ceux qui n'exportent que du latin. Le
/// port suit exactement le patron de `ZLatexRasterizer` : **l'hôte fournit les
/// octets, le paquet n'embarque rien**.
library;

import 'dart:typed_data';

/// Fournit les octets d'une police **TrueType** au gabarit PDF.
///
/// L'implémentation vit **hors** de ce paquet (l'app charge sa police depuis
/// ses assets). Retourner `null` — ou lever — laisse le gabarit retomber sur la
/// police standard : le rendu **fonctionne toujours**, il redevient simplement
/// borné au latin-1 (AD-10 : jamais de throw propagé).
///
/// ```dart
/// class NotoProvider implements ZPdfFontProvider {
///   @override
///   Future<Uint8List?> loadFont() async =>
///       (await rootBundle.load('assets/NotoSans-Regular.ttf'))
///           .buffer.asUint8List();
/// }
/// ```
///
/// ⚠️ **Une seule police pour tout le document.** Le gabarit ne compose pas
/// plusieurs fontes : si votre corpus mêle arabe et CJK, fournissez une police
/// qui couvre les deux (ou acceptez que l'autre dégrade). Le dire ici plutôt
/// que de le faire découvrir à l'export.
abstract interface class ZPdfFontProvider {
  /// Octets d'une police TrueType, ou `null` pour retomber sur la police
  /// standard. **Ne doit jamais lever** — une exception est traitée comme
  /// `null` par le gabarit.
  Future<Uint8List?> loadFont();
}

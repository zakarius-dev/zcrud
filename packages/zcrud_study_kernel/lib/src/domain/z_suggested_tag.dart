/// `ZSuggestedTag` — DTO éphémère d'un tag **proposé** par un port IA (ES-2.3,
/// FR-S6, AC2 — décision D2).
///
/// origine: lex_core (module « Étude ») — `SuggestedTag` (`{title, colorKey}`,
/// DTO **sans id**, produit par l'endpoint d'insight). L'utilisateur **accepte**
/// une suggestion → elle devient un [ZFlashcardTag] (avec `id`, matérialisé au
/// repository — ES-8.1). Jamais persistée top-level : c'est un **value object**.
///
/// ⇒ **NON-`ZEntity`, NON-`ZExtensible`, PAS d'`id`, PAS d'`extra`/`extension`**
/// — exactement le régime de `ZChoice` / `ZDocumentViewerPrefs`. Sa `fromMap`
/// **délègue nuement** au `_$…FromMap` généré (AUTORISÉ car NON-`ZExtensible` :
/// le générateur ne rejette la délégation nue **que** pour les `ZExtensible`).
///
/// **Généré par `@ZcrudModel` (AD-3)** : `melos run generate` émet
/// `z_suggested_tag.g.dart` portant `_$ZSuggestedTagFromMap`, l'extension
/// `ZSuggestedTagZcrud` (`toMap`/`copyWith`), `$ZSuggestedTagFieldSpecs` et
/// `registerZSuggestedTag(ZcrudRegistry)`. Le codegen offre un round-trip
/// **défensif** gratuit (`title`/`color_key` absents → `''`, jamais de throw —
/// AD-10, y compris `ZSuggestedTag.fromMap(const {})`).
///
/// **`colorKey` BRUT (D4)** : stocké VERBATIM, **aucun clamp** dans le value
/// object (la borne est palette-dépendante ; la palette est injectée — voir
/// `remapColorKey`). L'app re-borne À L'AFFICHAGE via
/// `remapColorKey(palette, rawColorKey: t.colorKey, seedTitle: t.title)`.
///
/// **AD-19 (D8)** : aucun `updatedAt`/`isDeleted` (ni sous ces noms, ni
/// `updated_at`/`is_deleted`) — un value object n'est pas persisté top-level.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_suggested_tag.g.dart';

/// Proposition de tag par un port IA (value object immuable — AC2).
@ZcrudModel(kind: 'suggested_tag', fieldRename: ZFieldRename.snake)
class ZSuggestedTag {
  /// Construit une suggestion (constructeur `const` — source du `copyWith`
  /// généré). Aucun `assert` (AD-10 : le décodeur généré l'appelle avec des
  /// valeurs brutes).
  const ZSuggestedTag({this.title = '', this.colorKey = ''});

  /// Reconstruit depuis une map persistée — **délègue nuement** au `fromMap`
  /// généré défensif (`title`/`color_key` absents ou non-`String` → `''`, jamais
  /// de throw). Délégation nue AUTORISÉE : `ZSuggestedTag` n'est pas `ZExtensible`
  /// (patron `ZChoice`).
  factory ZSuggestedTag.fromMap(Map<String, dynamic> map) =>
      _$ZSuggestedTagFromMap(map);

  /// Libellé proposé du tag (défaut `''` si absent — AC2).
  @ZcrudField(label: 'Tag proposé')
  final String title;

  /// Clé de couleur proposée, **BRUTE** (persistée `color_key`, snake_case ;
  /// défaut `''`). **Aucun clamp** ici (D4) : la borne est palette-dépendante,
  /// résolue à l'affichage par `remapColorKey`.
  @ZcrudField()
  final String colorKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSuggestedTag &&
          title == other.title &&
          colorKey == other.colorKey;

  @override
  int get hashCode => Object.hash(title, colorKey);
}

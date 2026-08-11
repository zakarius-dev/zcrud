/// `ZSuggestedTag` — DTO éphémère d'un tag proposé par un port IA.
///
/// Un tag suggéré n'est jamais persisté top-level : c'est un value object.
/// Quand l'utilisateur accepte une suggestion, elle devient un
/// [ZFlashcardTag] (avec un identifiant, matérialisé au repository).
///
/// Ni `ZEntity`, ni `ZExtensible` : pas d'identifiant, pas de canaux
/// `extra`/`extension`. Sa `fromMap` délègue nuement au décodeur généré, ce
/// qui n'est permis que pour les types non-`ZExtensible` (le générateur
/// rejette la délégation nue pour tout type `ZExtensible`).
///
/// Généré par `@ZcrudModel` (invariant AD-3) : `melos run generate` émet le
/// fichier compagnon portant le décodeur défensif, l'extension `toMap`/
/// `copyWith`, les spécifications de champ et l'enregistrement au registre.
/// Le codegen offre un round-trip défensif gratuit (`title`/`color_key`
/// absents → `''`, jamais de `throw` — invariant AD-10, y compris sur une
/// map vide).
///
/// `colorKey` est stockée **brute**, verbatim, sans aucun clamp dans le
/// value object : la borne est palette-dépendante, la palette étant
/// injectée (voir `remapColorKey`). L'application re-borne à l'affichage via
/// `remapColorKey(palette, rawColorKey: t.colorKey, seedTitle: t.title)`.
///
/// Aucune clé de synchronisation (mise à jour, suppression) — sous aucun
/// nom : un value object n'est pas persisté top-level (invariant AD-9).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'z_suggested_tag.g.dart';

/// Proposition de tag par un port IA (value object immuable).
@ZcrudModel(kind: 'suggested_tag', fieldRename: ZFieldRename.snake)
class ZSuggestedTag {
  /// Construit une suggestion (constructeur `const` — source du `copyWith`
  /// généré). Aucun `assert` (invariant AD-10 : le décodeur généré l'appelle
  /// avec des valeurs brutes).
  const ZSuggestedTag({this.title = '', this.colorKey = ''});

  /// Reconstruit depuis une map persistée — délègue nuement au `fromMap`
  /// généré défensif (`title`/`color_key` absents ou non-`String` → `''`,
  /// jamais de `throw`). Délégation nue permise : `ZSuggestedTag` n'est pas
  /// `ZExtensible`.
  factory ZSuggestedTag.fromMap(Map<String, dynamic> map) =>
      _$ZSuggestedTagFromMap(map);

  /// Libellé proposé du tag (défaut `''` si absent).
  @ZcrudField(label: 'Tag proposé')
  final String title;

  /// Clé de couleur proposée, brute (persistée `color_key`, snake_case ;
  /// défaut `''`). Aucun clamp ici : la borne est palette-dépendante,
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

/// Annotation **marqueur** excluant explicitement un champ d'instance de la
/// (dé)sérialisation générée.
///
/// Le générateur `zcrud_generator` ne sérialise que les champs porteurs de
/// `@ZcrudField` (ou `@ZcrudId`). Un champ **non annoté** dont le type n'est pas
/// sérialisable — ni scalaire supporté, ni `enum`, ni classe `@ZcrudModel` — est
/// un **échec de build** : sans ce refus, un champ métier disparaîtrait du
/// document persisté sans le moindre signal. `@ZcrudIgnore` est la façon
/// d'assumer cette exclusion, une fois, au point de déclaration.
///
/// Le champ marqué reste **totalement absent** du code émis : il n'apparaît ni
/// dans `toMap()`, ni dans le décodeur, ni dans le `ZFieldSpec[]`, ni dans
/// l'ensemble des clés persistées. Marquer un champ, c'est déclarer : **cette
/// donnée n'est pas écrite par le codegen**. Si elle doit tout de même vivre
/// dans le document, c'est à l'auteur du modèle de l'écrire par un canal
/// manuel (`fromMap`/`toMap` de domaine, slot `extra`) — sinon elle est
/// abandonnée, explicitement.
///
/// ```dart
/// @ZcrudModel(kind: 'article')
/// class Article {
///   const Article({required this.title, this.renderer});
///
///   factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);
///
///   @ZcrudField()
///   final String title;
///
///   /// Collaborateur d'exécution : hors persistance, donc exclu.
///   @ZcrudIgnore()
///   final ArticleRenderer? renderer;
/// }
/// ```
///
/// ## Champs qui n'ont PAS besoin du marqueur
///
/// Le générateur exempte de lui-même les champs pour lesquels un autre signal
/// existe déjà :
///
/// - les champs **privés** (`_xxx`) — détail de stockage, jamais persistable
///   sous son propre nom ;
/// - sur une classe `ZExtensible`, les slots du contrat AD-4 (`extension`,
///   `extra`) — canaux hors-codegen par contrat d'architecture, déjà gardés
///   par le contrat de factory de domaine et le garde d'extensibilité ;
/// - les champs **statiques**, qui n'ont jamais été sérialisés.
///
/// ## Cas limites
///
/// - `@ZcrudIgnore` **lève l'échec de build** ; il n'ajoute jamais rien au code
///   émis. Marquer un champ dont le type était déjà sérialisable ne change donc
///   rien au résultat, mais rend l'intention lisible.
/// - `@ZcrudIgnore` combiné à `@ZcrudField` **ou** `@ZcrudId` sur le même champ
///   est une contradiction — une déclaration exclut le champ de la persistance,
///   l'autre l'y inscrit — et le build la **refuse explicitement** plutôt que
///   de trancher en silence. Retirer l'une des deux annotations.
/// - Le champ exclu doit rester constructible sans la persistance : le décodeur
///   généré ne lui fournira aucune valeur.
///
/// Classe `const` pur-données, sans paramètre.
///
/// Voir aussi : [ZcrudField], [ZcrudModel].
class ZcrudIgnore {
  /// Construit le marqueur `const`.
  const ZcrudIgnore();
}

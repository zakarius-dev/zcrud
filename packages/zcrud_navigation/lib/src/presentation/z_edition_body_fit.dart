/// **Comment le corps veut être placé** dans le chrome d'édition.
///
/// ## Pourquoi une DÉCLARATION, et pas une reconnaissance de type
///
/// Une alternative consisterait à faire **reconnaître** le corps par le socle
/// (« si le body est tel type de widget connu, alors… »). Cette option est
/// **rejetée**, pour la même raison que `ZSheetFrameMode.unlessChrome` est
/// résolu dans `presentEdition` par déclaration explicite plutôt que par
/// inspection : reconnaître un type précis **échoue en silence** sur un corps
/// enveloppé (`Padding(child: MonEdition(...))`, un `Builder`, un widget
/// applicatif qui en contient un), **se trompe** sur un corps du même type
/// monté en `shrinkWrap`, et crée une dépendance de **connaissance** du socle
/// vers le catalogue de widgets du cœur. C'est donc l'**appelant** qui
/// déclare.
///
/// ## Ce que chaque valeur produit, PAR MODE
///
/// Les trois modes ne se déduisent pas l'un de l'autre — chacun a été **mesuré**
/// séparément :
///
/// | mode     | [intrinsic] (défaut)                            | [scrollable]                          |
/// |----------|--------------------------------------------------|---------------------------------------|
/// | `page`   | `SliverToBoxAdapter(body)` — hauteur NON bornée   | `NestedScrollView(header, body)`      |
/// | `dialog` | `Flexible(body)`                                 | `Flexible(body)` — **identique**      |
/// | `sheet`  | `Flexible(SingleChildScrollView(body))`          | `Flexible(body)`                      |
///
/// * `dialog` est **déjà correct** en [intrinsic] : `Flexible` donne au corps
///   une hauteur **bornée**. Mesuré : un corps `ListView` y monte sans aucune
///   exception. Les deux valeurs y produisent donc le même arbre — par
///   **mesure**, pas par symétrie supposée.
/// * `page` et `sheet` donnent tous deux au corps une hauteur **infinie** en
///   [intrinsic] (`SliverToBoxAdapter` / `SingleChildScrollView`) : un corps qui
///   défile lui-même y lève `Vertical viewport was given unbounded height`, puis
///   une cascade de `RenderBox was not laid out` — l'écran blanc de la CR.
///
/// ## Pourquoi [intrinsic] reste le DÉFAUT
///
/// Parce que [scrollable] **n'est pas gratuit** pour un corps qui ne défile pas
/// — mesuré, pas supposé :
/// * en `page`, un `NestedScrollView` remplace le `CustomScrollView` : arbre
///   différent, et un corps non scrollable n'y a plus de viewport propre ;
/// * en `sheet`, le `SingleChildScrollView` **disparaît** : un corps long non
///   scrollable ne défilerait plus du tout — il déborderait.
///
/// Un défaut robuste aurait donc changé le rendu d'hôtes qui vont bien. La règle
/// du dépôt (« l'hôte déclare ») et la mesure convergent : le défaut reste
/// [intrinsic], et le piège est **signalé** par une garde de développement
/// actionnable au lieu d'un écran blanc (invariant AD-10).
library;

/// Déclare **comment le corps du chrome d'édition veut être placé**.
///
/// Passé à `ZEditionScaffold.bodyFit` (ou à `presentEdition(bodyFit:)`).
/// Non-`sealed`, non-exhaustif à l'usage : toute lecture retombe sur
/// [intrinsic] par **repli terminal** (invariants AD-10/AD-4).
enum ZEditionBodyFit {
  /// Le corps a une **hauteur intrinsèque** : il se mesure à son contenu et ne
  /// défile pas lui-même. C'est le **défaut**, et le comportement historique
  /// — inchangé, à l'octet près.
  intrinsic,

  /// Le corps **défile lui-même** (`ListView`, `SingleChildScrollView`,
  /// `DynamicEdition` par défaut, `ZStepperEdition`…) et veut **garder son
  /// propre défilement**.
  ///
  /// L'appelant n'a **rien** à changer à son corps : il ne passe **pas** en
  /// `shrinkWrap: true` + `NeverScrollableScrollPhysics()`. C'est le
  /// **contenant** qui lui donne une hauteur bornée — la bonne réponse Flutter.
  scrollable,
}

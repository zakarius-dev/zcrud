/// [ZPageAppBarMode] — mode de l'app-bar du page-shell.
///
/// Le mode est un **enum** (jamais un couple de `bool floating/pinned`)
/// pilotant le rendu:
/// * [fixed]: app-bar Material classique (`Scaffold.appBar`), **sans repli**;
/// * [floating]: `SliverAppBar(floating: true)` — se replie au défilement puis
///   **réapparaît** dès qu'on remonte;
/// * [pinned]: `SliverAppBar(pinned: true)` — **reste visible** en haut;
/// * [floatingPinned]: `SliverAppBar(floating: true, pinned: true)` — reste
///   visible et réagit au défilement.
library;

/// Mode déclaratif de l'app-bar (fixe vs sliver repliable).
enum ZPageAppBarMode {
  /// App-bar fixe (Material classique), sans repli.
  fixed,

  /// Sliver flottante: se replie puis réapparaît au scroll.
  floating,

  /// Sliver épinglée: reste visible en tête.
  pinned,

  /// Sliver flottante **et** épinglée.
  floatingPinned,
}

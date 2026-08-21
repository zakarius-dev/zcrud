/// `ZColorCycle` — la primitive RÉUTILISABLE « une teinte qui parcourt une
/// palette en boucle », c'est-à-dire le signal visuel d'une **tâche en cours**.
///
/// ## Une primitive de présentation, sans domaine
///
/// Elle vit à côté des autres primitives de présentation réutilisables
/// ([ZForegroundOverride], [zReadableTintOn], [ZInvertedSurface]), et **ne
/// connaît ni le chat, ni les artefacts, ni le notebook** : elle reçoit une
/// palette, un tempo, et rend la teinte courante à un builder. Le même signal
/// sert donc partout où quelque chose se génère — flashcards, carte mentale,
/// résumé, session d'étude — sans qu'aucun de ces modules ait à la réécrire.
/// Un nom ou une API qui parleraient d'« occupation d'artefact » la
/// re-coupleraient à un module.
///
/// ## FR-26 — aucune couleur, aucun tempo INVENTÉ ici
///
/// [ZColorCycle.palette] et [ZColorCycle.period] sont **requis** : ce fichier
/// ne porte ni littéral de couleur ni durée de référence. La palette et le
/// tempo appartiennent à la table de référence du module appelant (chez le
/// chat : `ZChatNotebookReference.busyPalette` et `busyCycleDuration`,
/// eux-mêmes remplaçables par jeton et par paramètre). Le socle anime ; il ne
/// décide pas de la couleur.
///
/// ## AD-13 — « Réduire les animations » : l'état RESTE, seule l'animation
/// part
///
/// Sous `MediaQuery.disableAnimations`, **aucun `AnimationController` n'est
/// créé** — pas un contrôleur de durée nulle qui continuerait de battre. Mais
/// le builder reçoit alors la **première teinte de la palette**, fixe : un
/// état qui disparaîtrait quand on réduit les animations serait un défaut
/// d'accessibilité, pas une simplification. Le canal non chromatique (une
/// annonce sémantique) reste à la charge de l'appelant — une information ne
/// repose jamais sur la seule couleur.
///
/// ## AD-2 — granularité
///
/// Le cycle est un `AnimatedBuilder` **local** : il ne reconstruit que ce que
/// [ZColorCycle.builder] produit. Ni l'appelant, ni ses voisins, ni le
/// [ZColorCycle.child] passé en paramètre (transmis tel quel au builder) ne
/// sont reconstruits à chaque frame.
///
/// ## Cycle de vie
///
/// Le contrôleur n'existe que si [ZColorCycle.active] est vrai, que la
/// palette porte **au moins deux** teintes et que le tempo est strictement
/// positif. Une animation qui tournerait sur un écran au repos est un défaut
/// de batterie que rien ne signalerait ; ici, `active: false` n'en crée
/// aucun, et repasser à `false` libère celui qui tournait.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'z_readable_tint.dart';

/// Rend la teinte courante d'un [ZColorCycle].
///
/// [color] est `null` quand aucune teinte n'est due (palette vide et aucune
/// teinte de repos) : l'appelant peint alors sa couleur ambiante. [child] est
/// le sous-arbre stable transmis par [ZColorCycle.child] — le passer au lieu
/// de le reconstruire est ce qui garde l'animation granulaire (AD-2).
typedef ZColorCycleBuilder =
    Widget Function(BuildContext context, Color? color, Widget? child);

/// La teinte de [palette] à l'avancement [progress], en **boucle**.
///
/// La palette est parcourue par segments égaux, et la dernière teinte revient
/// à la première : une palette de `n` teintes compte donc `n` segments, pas
/// `n - 1`. C'est ce qui rend le cycle continu — sans le segment de retour,
/// chaque tour ferait un saut visible.
///
/// Chaîne **totale** (invariant AD-10) : ne lève jamais. Une palette vide rend
/// `null`, un [progress] non fini rend la première teinte, et un [progress]
/// hors de `[0, 1[` est ramené par modulo (les avancements négatifs compris).
Color? zColorCycleAt(List<Color> palette, double progress) {
  if (palette.isEmpty) return null;
  final int n = palette.length;
  if (n == 1 || !progress.isFinite) return palette.first;
  double t = progress % 1.0;
  if (t < 0) t += 1.0;
  final double scaled = t * n;
  final int index = scaled.floor().clamp(0, n - 1);
  final double local = (scaled - index).clamp(0.0, 1.0);
  return Color.lerp(palette[index], palette[(index + 1) % n], local) ??
      palette[index];
}

/// Fait parcourir [palette] en boucle et confie la teinte courante à
/// [builder].
///
/// ```dart
/// ZColorCycle(
///   palette: MonModule.busyPalette,      // la table de référence du module
///   period: MonModule.busyCycleDuration, // son tempo
///   active: enCours,                     // une lecture d'état de l'hôte
///   idle: teinteAuRepos,                 // rendue quand `active` est faux
///   surface: theme.surfaceColor,         // plancher de contraste (facultatif)
///   builder: (BuildContext c, Color? couleur, Widget? _) =>
///       Icon(Icons.map_outlined, color: couleur),
/// )
/// ```
///
/// Ce que la primitive **ne fait pas** : annoncer l'état. Une couleur qui
/// bouge n'est pas lisible au lecteur d'écran ni pour qui ne distingue pas les
/// teintes ; le canal textuel reste la responsabilité de l'appelant
/// (invariant AD-13).
class ZColorCycle extends StatefulWidget {
  /// Construit un cycle de teintes.
  ///
  /// [palette] et [period] sont requis **par principe** : le socle n'invente
  /// ni couleur ni tempo (FR-26). [active] à `false` rend [idle] sans créer
  /// le moindre contrôleur.
  const ZColorCycle({
    required this.palette,
    required this.period,
    required this.builder,
    this.active = true,
    this.idle,
    this.surface,
    this.minContrast = kZNonTextMinContrast,
    this.child,
    super.key,
  });

  /// Les teintes parcourues, dans l'ordre, **en boucle**.
  ///
  /// Vide signifie aucune teinte : [builder] reçoit alors [idle] (ou `null`).
  /// Une seule teinte signifie une teinte **fixe** — rien à animer, donc aucun
  /// contrôleur.
  final List<Color> palette;

  /// Durée d'un **tour complet** de [palette].
  ///
  /// 🔴 C'est le tour, et non le segment, qui est le tempo : une palette plus
  /// courte défile ainsi au même rythme d'ensemble qu'une longue, au lieu de
  /// clignoter. Une durée nulle ou négative désactive l'animation (repli
  /// fermant, AD-10) sans rien casser.
  final Duration period;

  /// Rend la teinte courante.
  final ZColorCycleBuilder builder;

  /// Le cycle est-il en cours ? `false` rend [idle], sans contrôleur.
  final bool active;

  /// Teinte rendue **hors cycle**. `null` signifie « couleur ambiante », que
  /// [builder] est libre d'interpréter.
  final Color? idle;

  /// Surface contre laquelle la lisibilité est mesurée.
  ///
  /// Non nulle, chaque teinte rendue (celles de [palette] **comme** [idle])
  /// passe par [zReadableTintOn] avant d'atteindre [builder] : une palette
  /// héritée d'un legacy peut être sous le plancher de contraste, et
  /// l'appliquer brute reproduirait ce défaut. `null` rend les teintes
  /// **inchangées** — c'est le choix explicite d'un appelant qui mesure
  /// ailleurs.
  final Color? surface;

  /// Plancher de contraste appliqué quand [surface] est fournie. Défaut :
  /// [kZNonTextMinContrast] (§1.4.11, objets graphiques).
  final double minContrast;

  /// Sous-arbre **stable** transmis tel quel à [builder] : ce qui ne dépend
  /// pas de la teinte n'a pas à être reconstruit à chaque frame (AD-2).
  final Widget? child;

  @override
  State<ZColorCycle> createState() => _ZColorCycleState();
}

class _ZColorCycleState extends State<ZColorCycle>
    with TickerProviderStateMixin {
  /// `null` tant qu'aucune animation n'est due — c'est l'invariant de cycle de
  /// vie : rien ne tourne au repos.
  AnimationController? _cycle;

  bool _reduceMotion = false;
  bool _wired = false;

  bool get _shouldRun =>
      widget.active &&
      !_reduceMotion &&
      widget.palette.length > 1 &&
      widget.period > Duration.zero;

  void _wire() {
    if (_shouldRun) {
      final AnimationController? running = _cycle;
      // Un contrôleur déjà en vol au bon tempo n'est pas recréé : le cycle ne
      // repart pas du début parce que l'appelant s'est reconstruit (AD-2).
      if (running != null && running.duration == widget.period) return;
      running?.dispose();
      _cycle = AnimationController(vsync: this, duration: widget.period)
        ..repeat();
      return;
    }
    _cycle?.dispose();
    _cycle = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_wired && reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    _wired = true;
    _wire();
  }

  @override
  void didUpdateWidget(covariant ZColorCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active ||
        oldWidget.period != widget.period ||
        !listEquals(oldWidget.palette, widget.palette)) {
      _wire();
    }
  }

  @override
  void dispose() {
    _cycle?.dispose();
    super.dispose();
  }

  /// La teinte réellement remise au builder — portée au plancher de contraste
  /// quand une surface est connue.
  Color? _paint(Color? raw) {
    final Color? surface = widget.surface;
    if (raw == null || surface == null) return raw;
    return zReadableTintOn(
      raw,
      surface: surface,
      minContrast: widget.minContrast,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.builder(context, _paint(widget.idle), widget.child);
    }
    final AnimationController? cycle = _cycle;
    if (cycle == null) {
      // Actif mais sans contrôleur : « Réduire les animations », palette d'une
      // seule teinte, ou tempo nul. L'état RESTE VISIBLE — première teinte de
      // la palette, figée — au lieu de disparaître (AD-13).
      final Color? resting = zColorCycleAt(widget.palette, 0) ?? widget.idle;
      return widget.builder(context, _paint(resting), widget.child);
    }
    return AnimatedBuilder(
      animation: cycle,
      // Seul ce builder est rejoué à chaque frame.
      builder: (BuildContext context, Widget? child) => widget.builder(
        context,
        _paint(zColorCycleAt(widget.palette, cycle.value)),
        child,
      ),
      child: widget.child,
    );
  }
}

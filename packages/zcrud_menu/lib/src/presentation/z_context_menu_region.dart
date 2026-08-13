/// [ZContextMenuRegion] — le menu ouvert par le **geste contextuel** : clic
/// droit sur pointeur, appui long sur tactile.
///
/// ## Le geste s'AJOUTE, il ne remplace jamais l'affordance visible
///
/// Un chemin offert au seul clic droit est **inatteignable** au clavier et aux
/// lecteurs d'écran (invariant AD-13). Cette région ne rend donc aucun
/// déclencheur et n'en retire aucun : elle enveloppe un contenu déjà
/// actionnable et lui ajoute un raccourci. C'est à l'appelant de conserver, à
/// côté, un déclencheur visible (`ZActionMenu`) ou des boutons — et c'est ce
/// que fait l'écran CRUD assemblé.
///
/// ## Le rendu reste celui du renderer ambiant
///
/// La surface ouverte est celle de [ZMenuRenderer.openAt], résolu par la chaîne
/// totale `paramètre → ZMenuScope → repli`. Un hôte qui a branché son propre
/// paquet de menus le voit servir aussi le geste contextuel, sans rien
/// déclarer de plus.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_menu_entry.dart';
import '../domain/z_menu_trigger.dart';
import 'z_menu_renderer.dart';
import 'z_menu_request.dart';
import 'z_menu_scope.dart';

/// Enveloppe un contenu d'un geste contextuel ouvrant un menu d'entrées.
class ZContextMenuRegion extends StatelessWidget {
  /// Construit la région.
  ///
  /// [entries] : entrées candidates, ordre PRÉSERVÉ. La règle d'absence
  /// (invariant AD-4) leur est appliquée ici, avant tout renderer.
  ///
  /// [trigger] : description du déclencheur — non rendue par cette région
  /// (elle n'en pose aucun), mais transmise au renderer : son
  /// [ZMenuTrigger.semanticLabel] nomme la surface ouverte.
  ///
  /// [child] : le contenu enveloppé, dont les gestes propres (tap, glissement)
  /// restent intacts.
  ///
  /// [secondaryTap] : ouvre au **clic droit** (pointeur). Défaut `true`.
  ///
  /// [longPress] : ouvre à l'**appui long** (tactile). Défaut `true`. À passer
  /// `false` quand l'appui long appartient déjà à une autre fonction du
  /// contenu — une copie de cellule, par exemple : deux fonctions sur le même
  /// geste, c'est la première qui gagne l'arène, pas celle que l'utilisateur
  /// visait.
  ///
  /// [contentBuilder] : présentation INJECTÉE du contenu (`null` ⇒ celle du
  /// renderer).
  ///
  /// [renderer] : surcharge PONCTUELLE, prioritaire sur [ZMenuScope].
  const ZContextMenuRegion({
    required this.entries,
    required this.trigger,
    required this.child,
    this.secondaryTap = true,
    this.longPress = true,
    this.contentBuilder,
    this.renderer,
    super.key,
  });

  /// Entrées candidates (celles ni actionnables ni désactivées sont ABSENTES).
  final List<ZMenuEntry> entries;

  /// Description du déclencheur (nom accessible de la surface).
  final ZMenuTrigger trigger;

  /// Contenu enveloppé.
  final Widget child;

  /// Ouverture au clic droit (pointeur).
  final bool secondaryTap;

  /// Ouverture à l'appui long (tactile).
  final bool longPress;

  /// Présentation INJECTÉE du contenu (`null` ⇒ celle du renderer).
  final ZMenuContentBuilder? contentBuilder;

  /// Surcharge ponctuelle du renderer (prioritaire sur le scope).
  final ZMenuRenderer? renderer;

  /// Ouvre la surface à [globalPosition], par le renderer ambiant.
  ///
  /// Rien à montrer ⇒ rien ne s'ouvre (invariant AD-10) : un geste contextuel
  /// sur une ligne sans action offerte ne produit **aucune** surface vide.
  Future<void> _open(BuildContext context, Offset globalPosition) {
    final visible = zVisibleMenuEntries(entries);
    if (visible.isEmpty && contentBuilder == null) return Future<void>.value();
    return zResolveMenuRenderer(context, override: renderer).openAt(
      context,
      ZMenuRequest(
        trigger: trigger,
        entries: visible,
        contentBuilder: contentBuilder,
        // MÊME voie de sélection que le déclencheur visible : le geste
        // contextuel ne peut pas exécuter une entrée qu'un tap n'exécuterait
        // pas.
        select: zMenuSelectFor(visible),
      ),
      globalPosition,
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        // `deferToChild` : les gestes propres du contenu (tap sur la ligne,
        // boutons) gardent la priorité — la région n'intercepte que ce que le
        // contenu ne réclame pas.
        behavior: HitTestBehavior.deferToChild,
        onSecondaryTapUp:
            secondaryTap ? (details) => _open(context, details.globalPosition) : null,
        onLongPressStart:
            longPress ? (details) => _open(context, details.globalPosition) : null,
        child: child,
      );
}

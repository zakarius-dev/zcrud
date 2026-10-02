/// Surface, fermeture et recentrage des menus flottants du chat.
///
/// Le paquet n'importe pas Material. Le fond vient des jetons de thème
/// (`surfaceColor`, puis le fond du composer). La fermeture au geste
/// arrière et à Échap est la même pour les trois menus.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Largeur maximale d'une surface de menu, pour qu'un libellé long replie
/// au lieu de déborder l'écran.
const double kZChatMenuMaxWidth = 320;

/// Fond de menu : jeton de surface, filet du composer s'il est posé.
class ZChatMenuSurface extends StatelessWidget {
  /// Construit la surface autour de [child].
  const ZChatMenuSurface({required this.child, super.key});

  /// Contenu du menu, déjà borné par son appelant.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final Color? fill = theme.surfaceColor ?? theme.chatComposerFill;
    final Color? border = theme.chatComposerBorderColor;
    final Radius radius = theme.chatComposerRadius ?? theme.radiusM;
    final Color? ink = theme.labelColor;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kZChatMenuMaxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.all(radius),
          border: border == null
              ? null
              : Border.all(
                  color: border,
                  width:
                      theme.chatComposerBorderWidth ?? theme.inputBorderWidth,
                ),
          boxShadow: ink == null
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: ink.withValues(alpha: 0.12),
                    blurRadius: theme.gapM,
                    offset: Offset(0, theme.gapS / 2),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.gapS),
          child: child,
        ),
      ),
    );
  }
}

/// Intercepte le retour arrière et Échap pendant qu'un menu est ouvert.
class ZChatOverlayDismiss extends StatelessWidget {
  /// Construit l'intercepteur.
  const ZChatOverlayDismiss({
    required this.open,
    required this.onClose,
    required this.child,
    super.key,
  });

  /// `true` : le retour ferme le menu au lieu de quitter la route.
  final bool open;

  /// Fermeture du menu.
  final VoidCallback onClose;

  /// Sous-arbre (déclencheur et portail).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        if (open) const SingleActivator(LogicalKeyboardKey.escape): onClose,
      },
      child: PopScope(
        canPop: !open,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop && open) onClose();
        },
        child: child,
      ),
    );
  }
}

/// Décale la boîte suiveuse pour que [child] reste dans l'écran.
///
/// Le décalage est l'`offset` du [CompositedTransformFollower] : une
/// translation du contenu sortirait le menu de la boîte qui reçoit les
/// touchers, et le tap fermerait le menu sans choisir. La mesure retire le
/// décalage courant avant le calcul suivant, sinon elle oscille.
class ZChatClampShift extends StatefulWidget {
  /// Construit le recentrage. [targetAnchor] et [followerAnchor] sont ceux
  /// du menu (déjà résolus dans la direction du contexte).
  const ZChatClampShift({
    required this.link,
    required this.targetAnchor,
    required this.followerAnchor,
    required this.child,
    this.showWhenUnlinked = true,
    super.key,
  });

  /// Lien vers le déclencheur.
  final LayerLink link;

  /// Coin du déclencheur.
  final Alignment targetAnchor;

  /// Coin du menu collé à [targetAnchor].
  final Alignment followerAnchor;

  /// `false` : rien n'est peint tant que la cible n'est pas liée.
  final bool showWhenUnlinked;

  /// Menu à maintenir visible.
  final Widget child;

  @override
  State<ZChatClampShift> createState() => _ZChatClampShiftState();
}

class _ZChatClampShiftState extends State<ZChatClampShift> {
  final GlobalKey _boxKey = GlobalKey();
  final ValueNotifier<Offset> _shift = ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _shift.dispose();
    super.dispose();
  }

  void _measure() {
    final BuildContext? target = _boxKey.currentContext;
    final RenderObject? object = target?.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) return;
    final Offset painted = object.localToGlobal(Offset.zero);
    final Offset natural = painted - _shift.value;
    final Size size = object.size;
    final Size screen = MediaQuery.sizeOf(target!);
    double dx = 0;
    double dy = 0;
    if (natural.dx < 0) dx = -natural.dx;
    final double right = natural.dx + size.width;
    if (right > screen.width) dx += screen.width - right;
    if (natural.dx + dx < 0) dx = -natural.dx;
    if (natural.dy < 0) dy = -natural.dy;
    final double bottom = natural.dy + size.height;
    if (bottom > screen.height) dy += screen.height - bottom;
    if (natural.dy + dy < 0) dy = -natural.dy;
    final Offset next = Offset(dx, dy);
    if (next != _shift.value) _shift.value = next;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    return ValueListenableBuilder<Offset>(
      valueListenable: _shift,
      builder: (BuildContext context, Offset shift, Widget? _) {
        return CompositedTransformFollower(
          link: widget.link,
          targetAnchor: widget.targetAnchor,
          followerAnchor: widget.followerAnchor,
          showWhenUnlinked: widget.showWhenUnlinked,
          offset: shift,
          child: KeyedSubtree(key: _boxKey, child: widget.child),
        );
      },
    );
  }
}

/// Surface, fermeture et recentrage des menus flottants du chat.
///
/// Le paquet n'importe pas Material. Le fond vient des jetons de thème
/// (`surfaceColor`, puis le fond du composer). La fermeture au geste
/// arrière et à Échap est la même pour les trois menus.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: border == null ? null : Border.all(color: border),
      ),
      child: child,
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

/// Décale [child] pour qu'il reste dans l'écran.
///
/// La translation courante est retirée avant le calcul suivant : sans cela
/// la mesure oscille.
class ZChatClampShift extends StatefulWidget {
  /// Construit le recentrage.
  const ZChatClampShift({required this.child, super.key});

  /// Menu à maintenir visible.
  final Widget child;

  @override
  State<ZChatClampShift> createState() => _ZChatClampShiftState();
}

class _ZChatClampShiftState extends State<ZChatClampShift> {
  final ValueNotifier<Offset> _shift = ValueNotifier<Offset>(Offset.zero);
  final GlobalKey _boxKey = GlobalKey();

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
      builder: (BuildContext context, Offset shift, Widget? _) =>
          Transform.translate(
            offset: shift,
            child: KeyedSubtree(key: _boxKey, child: widget.child),
          ),
    );
  }
}

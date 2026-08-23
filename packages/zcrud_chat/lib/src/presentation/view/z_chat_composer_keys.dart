/// La politique de **raccourci clavier** du composer.
///
/// ## Ce que la touche Entrée fait
///
/// Par défaut, dans un composer multiligne :
///
/// * **Entrée** soumet la saisie ;
/// * **Maj+Entrée** insère une nouvelle ligne ;
/// * **Ctrl+Entrée** insère une nouvelle ligne ;
/// * sur une plateforme **tactile**, Entrée insère une nouvelle ligne et ne
///   soumet jamais — un clavier virtuel n'a pas de modificateur, une
///   convention qui l'exige y rendrait la nouvelle ligne inatteignable.
///
/// La politique est déclarable : [ZChatComposerSubmitKey.modifierSubmits]
/// inverse la convention, [ZChatComposerSubmitKey.none] la retire, et
/// [ZChatComposerSubmitPolicy.desktopAndWebOnly] gouverne le filtrage par
/// plateforme.
///
/// ## Ce que la soumission n'est pas
///
/// Le raccourci n'ouvre **aucun** chemin d'envoi : il invoque la fermeture
/// `ZChatComposerSlot.submit` — le même site que le bouton d'envoi.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, immutable, kIsWeb;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart'
    show
        DoNothingAndStopPropagationTextIntent,
        Intent,
        ShortcutActivator,
        SingleActivator;

/// Ce que la touche Entrée fait dans le champ du composer.
enum ZChatComposerSubmitKey {
  /// Entrée soumet ; Maj+Entrée et Ctrl+Entrée insèrent une nouvelle ligne.
  enterSubmits,

  /// Entrée insère une nouvelle ligne ; Maj+Entrée et Ctrl+Entrée soumettent.
  modifierSubmits,

  /// Aucun raccourci : seul le créneau d'envoi soumet, et la touche Entrée
  /// se comporte comme dans n'importe quel champ multiligne.
  none,
}

/// L'intention de soumission du composer.
///
/// Une intention nommée, jamais un appel direct : c'est ce qui permet à un
/// hôte d'intercaler ses propres `Actions` au-dessus du composer sans
/// remplacer le champ.
class ZChatComposerSubmitIntent extends Intent {
  /// Construit l'intention.
  const ZChatComposerSubmitIntent();
}

/// La politique de raccourci clavier d'un composer.
///
/// Défaut : Entrée soumet, Maj+Entrée et Ctrl+Entrée insèrent une nouvelle
/// ligne, et rien de tout cela ne s'applique sur une plateforme tactile.
@immutable
class ZChatComposerSubmitPolicy {
  /// Construit une politique.
  const ZChatComposerSubmitPolicy({
    this.submitKey = ZChatComposerSubmitKey.enterSubmits,
    this.desktopAndWebOnly = true,
  });

  /// La politique par défaut du socle.
  static const ZChatComposerSubmitPolicy standard = ZChatComposerSubmitPolicy();

  /// Aucun raccourci clavier — seul le créneau d'envoi soumet.
  static const ZChatComposerSubmitPolicy disabled = ZChatComposerSubmitPolicy(
    submitKey: ZChatComposerSubmitKey.none,
  );

  /// Ce que la touche Entrée fait, avant filtrage par plateforme.
  final ZChatComposerSubmitKey submitKey;

  /// `true` signifie que [submitKey] ne s'applique que sur les plateformes de
  /// bureau et sur le Web ; `false` l'applique partout, y compris sur mobile.
  ///
  /// Le filtrage porte sur la **plateforme**, jamais sur la largeur de
  /// l'écran : une fenêtre étroite sur un bureau garde un clavier physique.
  final bool desktopAndWebOnly;

  /// La politique **effective** ici.
  ///
  /// [platform] et [isWeb] ne sont là que pour la mesure : sans argument, la
  /// plateforme courante et `kIsWeb` sont lus.
  ZChatComposerSubmitKey resolve({TargetPlatform? platform, bool? isWeb}) {
    if (submitKey == ZChatComposerSubmitKey.none) {
      return ZChatComposerSubmitKey.none;
    }
    if (!desktopAndWebOnly) return submitKey;
    if (isWeb ?? kIsWeb) return submitKey;
    switch (platform ?? defaultTargetPlatform) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return submitKey;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return ZChatComposerSubmitKey.none;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ZChatComposerSubmitPolicy &&
      other.submitKey == submitKey &&
      other.desktopAndWebOnly == desktopAndWebOnly;

  @override
  int get hashCode => Object.hash(submitKey, desktopAndWebOnly);
}

/// La table de raccourcis d'une politique **déjà résolue**.
///
/// Les combinaisons destinées à insérer une nouvelle ligne sont liées à
/// `DoNothingAndStopPropagationTextIntent` : la touche n'est pas consommée et
/// atteint la saisie de texte, qui insère la ligne — ce paquet n'écrit jamais
/// lui-même dans la saisie de l'utilisateur.
Map<ShortcutActivator, Intent> zChatComposerSubmitShortcuts(
  ZChatComposerSubmitKey key,
) {
  const ZChatComposerSubmitIntent submit = ZChatComposerSubmitIntent();
  const DoNothingAndStopPropagationTextIntent newline =
      DoNothingAndStopPropagationTextIntent();
  switch (key) {
    case ZChatComposerSubmitKey.none:
      return const <ShortcutActivator, Intent>{};
    case ZChatComposerSubmitKey.enterSubmits:
      return const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): submit,
        SingleActivator(LogicalKeyboardKey.enter, shift: true): newline,
        SingleActivator(LogicalKeyboardKey.enter, control: true): newline,
      };
    case ZChatComposerSubmitKey.modifierSubmits:
      return const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): newline,
        SingleActivator(LogicalKeyboardKey.enter, shift: true): submit,
        SingleActivator(LogicalKeyboardKey.enter, control: true): submit,
      };
  }
}

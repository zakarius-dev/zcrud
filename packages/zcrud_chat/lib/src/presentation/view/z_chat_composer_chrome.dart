/// **Lot K2 (chantier composer-lex)** — la chaîne de résolution du chrome du
/// composer, **paramètre > jeton > référence**, et les créneaux par défaut en
/// widgets **purs** (aucun `material`, aucune couleur inventée).
///
/// ## 🔴 Trois niveaux, champ par champ — jamais deux
///
/// ```
/// paramètre  ZChatComposerChrome.<champ>     ← l'hôte, ici et maintenant
///     ▼ (si null)
/// jeton      ZcrudScope.theme.<…>            ← l'hôte, pour toute sa surface
///     ▼ (si null / scope absent)
/// référence  ZChatComposerReference.<…>      ← lex_douane, mesuré
/// ```
///
/// ⚠️ Le niveau 2 lit `ZcrudScope.maybeOf(context)?.theme` et **non**
/// `ZcrudTheme.of(context)` — la leçon de `ZChatSettingsSheet` : `of()` ne rend
/// jamais `null` (repli Material), ce qui rendrait le niveau 3 inatteignable, et
/// une référence que rien ne peut atteindre est une garde vacante déguisée.
///
/// ## 🔴 Jetons consommés — la chaîne est COMPLÈTE depuis le lot K4
///
/// Les jetons demandés au lot K2 ont été posés dans `zcrud_core` (lot K4) :
/// chaque champ se résout désormais **paramètre > jeton > référence**.
///
/// | Champ | Jeton niveau 2 | Statut |
/// |---|---|---|
/// | [ZChatComposerChromeStyle.padding] | `formPadding` | existant |
/// | [ZChatComposerChromeStyle.containerRadius] | `radiusM` | existant |
/// | [ZChatComposerChromeStyle.fieldContentPadding] | `inputContentPadding` | existant |
/// | [ZChatComposerChromeStyle.badgeRadius] | `badgeRadius` | existant (nullable) |
/// | [ZChatComposerChromeStyle.sendTargetSize] | `chatComposerSendTargetSize` | posé (K4) |
/// | échelles/durées d'envoi | `chatComposerSendScaleIdle/Active/Duration` | posés (K4) |
/// | [ZChatComposerChromeStyle.mobileBreakpoint] | `chatComposerMobileBreakpoint` | posé (K4) |
/// | durées du placeholder | `chatComposerHintRotationPeriod/SwitchDuration` | posés (K4) |
/// | accents de verbosité | `chatResponseLengthAccents` | posé (K4) |
///
/// ⚠️ `chatResponseLengthAccents` côté thème est indexé par le **nom** du
/// palier (`ZChatResponseLength.name` — `zcrud_core` ne peut pas importer
/// l'enum, AD-1) ; la consultation reste **clé par clé** à travers les trois
/// niveaux.
///
/// ## 🔴 AD-13 — le plancher n'est pas négociable
///
/// [ZChatComposerChromeStyle.sendTargetSize] est **écrêté** à
/// `kZChatMinTapTarget` : un paramètre (ou, demain, un jeton) qui demanderait
/// les 40 dp du legacy rend quand même 48. La valeur basse est inexprimable,
/// comme dans `_ZChatComposerTarget`.
///
/// ## 🔴 Reduce Motion (AD-13) — mesuré, pas affirmé
///
/// lex anime son placeholder **sans** garde Reduce-Motion (`chat_input.dart:
/// 1162-1198`) — c'est l'un des défauts relevés à l'étude, et il n'est pas
/// reproduit : [ZChatComposerAnimatedHint] est **inerte** sous
/// `MediaQuery.disableAnimations` (aucun `Timer` créé, premier libellé figé) et
/// [ZChatComposerSendTarget] y transitionne en `Duration.zero`. Les deux sont
/// mesurés par `test/z_chat_composer_chrome_test.dart`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_composer.dart';
import 'z_chat_composer_reference.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Réglage **partiel** du chrome du composer : tout champ `null` délègue au
/// niveau suivant (jeton s'il existe, puis référence lex).
///
/// Strictement additif et **immuable** — patron `ZChatNotebookSkin`.
@immutable
class ZChatComposerChrome {
  /// Construit un réglage. `const ZChatComposerChrome()` = « la référence lex,
  /// telle que mesurée » (aux jetons de l'hôte près).
  const ZChatComposerChrome({
    this.padding,
    this.containerRadius,
    this.fieldContentPadding,
    this.badgeRadius,
    this.sendTargetSize,
    this.sendScaleIdle,
    this.sendScaleActive,
    this.sendScaleDuration,
    this.mobileBreakpoint,
    this.hintRotationPeriod,
    this.hintSwitchDuration,
    this.responseLengthAccents,
  });

  /// Marge externe. `null` ⇒ jeton `formPadding`, puis référence.
  final EdgeInsetsDirectional? padding;

  /// Rayon du conteneur. `null` ⇒ jeton `radiusM`, puis référence (12).
  final Radius? containerRadius;

  /// Marge interne du champ. `null` ⇒ jeton `inputContentPadding`, puis
  /// référence.
  final EdgeInsetsDirectional? fieldContentPadding;

  /// Rayon des badges. `null` ⇒ jeton `badgeRadius`, puis référence (8).
  final Radius? badgeRadius;

  /// Côté de la cible d'envoi. `null` ⇒ jeton `chatComposerSendTargetSize`,
  /// puis référence (48). Toujours **écrêté** à `kZChatMinTapTarget`.
  final double? sendTargetSize;

  /// Échelle « saisie vide ». `null` ⇒ jeton `chatComposerSendScaleIdle`,
  /// puis référence (0.7).
  final double? sendScaleIdle;

  /// Échelle « saisie non vide ». `null` ⇒ jeton
  /// `chatComposerSendScaleActive`, puis référence (1).
  final double? sendScaleActive;

  /// Durée de la transition d'échelle. `null` ⇒ jeton
  /// `chatComposerSendScaleDuration`, puis référence (150 ms).
  final Duration? sendScaleDuration;

  /// Largeur du mode « icône seule ». `null` ⇒ jeton
  /// `chatComposerMobileBreakpoint`, puis référence (400).
  final double? mobileBreakpoint;

  /// Période de rotation du placeholder. `null` ⇒ jeton
  /// `chatComposerHintRotationPeriod`, puis référence (4 s).
  final Duration? hintRotationPeriod;

  /// Durée du fondu de changement de texte. `null` ⇒ jeton
  /// `chatComposerHintSwitchDuration`, puis référence (350 ms).
  final Duration? hintSwitchDuration;

  /// Accents des paliers de verbosité, consultés **clé par clé** : renseigner
  /// `concise` seul ne fait pas disparaître les deux autres accents de
  /// référence. `null`/clé absente ⇒ jeton `chatResponseLengthAccents` (posé
  /// au lot K4, indexé par `ZChatResponseLength.name`), puis référence —
  /// exception FR-26 encadrée, cf.
  /// `ZChatComposerReference.responseLengthAccents`.
  final Map<ZChatResponseLength, Color>? responseLengthAccents;
}

/// Les valeurs **résolues** du chrome — aucune n'est nulle.
@immutable
class ZChatComposerChromeStyle {
  /// Construit un style résolu. Réservé à [zChatComposerChromeOf] et aux
  /// tests ; un hôte règle par [ZChatComposerChrome].
  const ZChatComposerChromeStyle({
    required this.padding,
    required this.containerRadius,
    required this.fieldContentPadding,
    required this.badgeRadius,
    required this.sendTargetSize,
    required this.sendScaleIdle,
    required this.sendScaleActive,
    required this.sendScaleDuration,
    required this.mobileBreakpoint,
    required this.hintRotationPeriod,
    required this.hintSwitchDuration,
    this.responseLengthAccentOverrides,
    this.responseLengthAccentTokens,
  });

  /// Marge externe du conteneur.
  final EdgeInsetsDirectional padding;

  /// Rayon du conteneur.
  final Radius containerRadius;

  /// Marge interne du champ.
  final EdgeInsetsDirectional fieldContentPadding;

  /// Rayon des badges.
  final Radius badgeRadius;

  /// Côté de la cible d'envoi — **jamais** sous `kZChatMinTapTarget`.
  final double sendTargetSize;

  /// Échelle « saisie vide ».
  final double sendScaleIdle;

  /// Échelle « saisie non vide ».
  final double sendScaleActive;

  /// Durée de la transition d'échelle.
  final Duration sendScaleDuration;

  /// Largeur du mode « icône seule ».
  final double mobileBreakpoint;

  /// Période de rotation du placeholder.
  final Duration hintRotationPeriod;

  /// Durée du fondu de changement de texte du placeholder.
  final Duration hintSwitchDuration;

  /// Accents fournis en paramètre (niveau 1), ou `null`.
  final Map<ZChatResponseLength, Color>? responseLengthAccentOverrides;

  /// Accents du **jeton** `chatResponseLengthAccents` (niveau 2, lot K4),
  /// indexés par `ZChatResponseLength.name` — la seule clé que `zcrud_core`
  /// peut porter sans importer l'enum (AD-1). `null` si l'hôte n'a rien réglé.
  final Map<String, Color>? responseLengthAccentTokens;

  /// Accent d'un palier — paramètre, **jeton**, puis référence (clé par clé :
  /// renseigner `concise` seul, à n'importe quel niveau, ne fait pas
  /// disparaître les deux autres accents des niveaux suivants).
  ///
  /// Ne rend jamais `null` : l'axe `ZChatResponseLength` est scellé et la
  /// référence couvre ses trois paliers (asserté par la garde du lot).
  Color responseLengthAccent(ZChatResponseLength length) =>
      responseLengthAccentOverrides?[length] ??
      responseLengthAccentTokens?[length.name] ??
      ZChatComposerReference.responseLengthAccents[length]!;
}

/// Résout le chrome du composer contre le contexte — **paramètre > jeton >
/// référence**, champ par champ. **Ne lève jamais** (AD-10) : sans `ZcrudScope`
/// ni paramètre, tout retombe sur la référence lex.
ZChatComposerChromeStyle zChatComposerChromeOf(
  BuildContext context, {
  ZChatComposerChrome? chrome,
}) {
  final ZcrudTheme? theme = ZcrudScope.maybeOf(context)?.theme;
  final double floor = kZChatMinTapTarget;
  final double requestedSend =
      chrome?.sendTargetSize ??
      theme?.chatComposerSendTargetSize ??
      ZChatComposerReference.sendTargetSize;
  return ZChatComposerChromeStyle(
    padding:
        chrome?.padding ??
        theme?.formPadding ??
        ZChatComposerReference.outerPadding,
    containerRadius:
        chrome?.containerRadius ??
        theme?.radiusM ??
        ZChatComposerReference.containerRadius,
    fieldContentPadding:
        chrome?.fieldContentPadding ??
        theme?.inputContentPadding ??
        ZChatComposerReference.fieldContentPadding,
    badgeRadius:
        chrome?.badgeRadius ??
        theme?.badgeRadius ??
        ZChatComposerReference.badgeRadius,
    // 🔴 AD-13 : écrêté au plancher — les 40 dp du legacy sont inexprimables,
    // par paramètre aujourd'hui comme par jeton demain.
    sendTargetSize: requestedSend < floor ? floor : requestedSend,
    sendScaleIdle:
        chrome?.sendScaleIdle ??
        theme?.chatComposerSendScaleIdle ??
        ZChatComposerReference.sendScaleIdle,
    sendScaleActive:
        chrome?.sendScaleActive ??
        theme?.chatComposerSendScaleActive ??
        ZChatComposerReference.sendScaleActive,
    sendScaleDuration:
        chrome?.sendScaleDuration ??
        theme?.chatComposerSendScaleDuration ??
        ZChatComposerReference.sendScaleDuration,
    mobileBreakpoint:
        chrome?.mobileBreakpoint ??
        theme?.chatComposerMobileBreakpoint ??
        ZChatComposerReference.mobileBreakpoint,
    hintRotationPeriod:
        chrome?.hintRotationPeriod ??
        theme?.chatComposerHintRotationPeriod ??
        ZChatComposerReference.hintRotationPeriod,
    hintSwitchDuration:
        chrome?.hintSwitchDuration ??
        theme?.chatComposerHintSwitchDuration ??
        ZChatComposerReference.hintSwitchDuration,
    responseLengthAccentOverrides: chrome?.responseLengthAccents,
    responseLengthAccentTokens: theme?.chatResponseLengthAccents,
  );
}

/// Le créneau d'ENVOI par défaut — la géométrie et le geste de lex, en widget
/// **pur** : la cible 48 dp, l'échelle 0.7 → 1.0 en 150 ms, la sémantique de
/// bouton. Le **glyphe** vient de l'hôte ([child]) : ce paquet ne peut rendre
/// ni `Icons.send` (material banni) ni une couleur (FR-26). Le pixel-perfect
/// Material est l'affaire du satellite (lot suivant).
///
/// À monter dans le créneau `trailing` de `ZChatComposer` :
///
/// ```dart
/// trailing: (context, slot) =>
///     ZChatComposerSendTarget(slot: slot, child: monGlyphe),
/// ```
///
/// 🔴 Il n'introduit **aucun** chemin d'envoi : le tap appelle
/// [ZChatComposerSlot.submit] — la fermeture que le composer fournit, donc le
/// MÊME site que la touche « valider » du clavier (G-CH1/G-U1 intacts).
class ZChatComposerSendTarget extends StatelessWidget {
  /// Construit la cible d'envoi.
  const ZChatComposerSendTarget({
    required this.slot,
    required this.child,
    this.chrome,
    super.key,
  });

  /// Le contexte du créneau, fourni par `ZChatComposer`.
  final ZChatComposerSlot slot;

  /// Le glyphe de l'hôte.
  final Widget child;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex.
  final ZChatComposerChrome? chrome;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    // 🔴 Reduce Motion : la transition devient INSTANTANÉE — l'état final est
    // identique, seule l'animation disparaît (AD-13).
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ValueListenableBuilder<bool>(
      // 🔴 LA tranche granulaire : elle ne signale qu'aux transitions
      // vide ↔ non vide — jamais à chaque frappe (SM-1, AD-2).
      valueListenable: slot.controller.canSend,
      builder: (BuildContext context, bool canSend, Widget? glyph) => Semantics(
        button: true,
        enabled: canSend,
        label: zChatLabel(context, kZChatLabelSend),
        excludeSemantics: true,
        onTap: slot.submit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Le refus d'une saisie vide reste celui de `send()` — `submit` est
          // sans effet dans ce cas, jamais un second garde-fou divergent.
          onTap: slot.submit,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: style.sendTargetSize,
              minHeight: style.sendTargetSize,
            ),
            child: Align(
              // AD-13 : alignement DIRECTIONNEL.
              alignment: AlignmentDirectional.center,
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: ZChatComposerReference.sendPadding,
                child: AnimatedScale(
                  scale: canSend ? style.sendScaleActive : style.sendScaleIdle,
                  duration: reduceMotion
                      ? Duration.zero
                      : style.sendScaleDuration,
                  child: glyph,
                ),
              ),
            ),
          ),
        ),
      ),
      // Construit UNE fois : la transition d'échelle ne reconstruit pas le
      // glyphe de l'hôte.
      child: child,
    );
  }
}

/// Le PLACEHOLDER ANIMÉ de lex (`_AnimatedPlaceholder`,
/// `chat_input.dart:1113-1211`), porté en widget pur — à monter dans le créneau
/// `hint` de `ZChatComposer` (visible seulement quand la saisie est vide, la
/// visibilité restant l'affaire du composer).
///
/// Les [hints] sont des textes **déjà localisés par l'hôte** (chez lex ce sont
/// des suggestions par expert — une donnée métier que le socle ne connaît pas).
///
/// ## 🔴 Le défaut lex NON reproduit : Reduce Motion
///
/// lex fait tourner ses `Timer.periodic` sans aucune garde. Ici, sous
/// `MediaQuery.disableAnimations` : **aucun** minuteur n'est créé, le premier
/// libellé est figé — mesuré (deux volets, avec et sans, dans la garde du lot).
///
/// ## AD-14
///
/// Aucun `Random` : la rotation est **séquentielle** (`(i + 1) % n`), comme
/// chez lex.
class ZChatComposerAnimatedHint extends StatefulWidget {
  /// Construit le placeholder animé.
  const ZChatComposerAnimatedHint({
    required this.hints,
    this.leading,
    this.chrome,
    super.key,
  });

  /// Les libellés à faire tourner, localisés par l'hôte. Vide ⇒ rien (AD-4).
  final List<String> hints;

  /// Glyphe de tête optionnel (l'« étincelle » de lex). `null` ⇒ absent.
  final Widget? leading;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex.
  final ZChatComposerChrome? chrome;

  @override
  State<ZChatComposerAnimatedHint> createState() =>
      _ZChatComposerAnimatedHintState();
}

class _ZChatComposerAnimatedHintState extends State<ZChatComposerAnimatedHint> {
  /// Index courant — une TRANCHE, jamais un `setState` (G-CH5 interdit
  /// `setState` dans tout `lib/`).
  final ValueNotifier<int> _index = ValueNotifier<int>(0);

  Timer? _rotation;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce == _reduceMotion && _rotation != null) return;
    _reduceMotion = reduce;
    _rotation?.cancel();
    _rotation = null;
    // 🔴 Reduce Motion : AUCUN minuteur — l'inertie est structurelle, pas une
    // animation de durée nulle qui continuerait de battre.
    if (reduce || widget.hints.length < 2) return;
    _rotation = Timer.periodic(
      zChatComposerChromeOf(context, chrome: widget.chrome).hintRotationPeriod,
      (Timer _) => _index.value = (_index.value + 1) % widget.hints.length,
    );
  }

  @override
  void dispose() {
    _rotation?.cancel();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hints.isEmpty) return const SizedBox.shrink();
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: widget.chrome,
    );
    final Widget? leading = widget.leading;
    // 🔴 UN SEUL chemin de rendu — l'inertie sous Reduce Motion vient
    // UNIQUEMENT de l'absence de minuteur (`didChangeDependencies`), jamais
    // d'une seconde branche statique. La première rédaction portait les deux :
    // l'injection R3 « retirer la garde du minuteur » est restée VERTE, le
    // texte étant figé par l'autre mécanisme pendant qu'un minuteur vivant
    // battait pour rien. Une garde ne mord que si le défaut n'a qu'une porte.
    final Widget text = ValueListenableBuilder<int>(
      valueListenable: _index,
      builder: (BuildContext context, int i, Widget? _) => AnimatedSwitcher(
        duration: style.hintSwitchDuration,
        child: Text(
          widget.hints[i],
          // La clé fait du changement de texte un CHANGEMENT
          // d'enfant : sans elle, `AnimatedSwitcher` ne fondrait
          // jamais (même type, même widget).
          key: ValueKey<int>(i),
          // AD-13 : jamais `TextAlign.left`.
          textAlign: TextAlign.start,
        ),
      ),
    );
    if (leading == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        leading,
        SizedBox(width: ZChatComposerReference.badgeStartGap),
        Flexible(child: text),
      ],
    );
  }
}

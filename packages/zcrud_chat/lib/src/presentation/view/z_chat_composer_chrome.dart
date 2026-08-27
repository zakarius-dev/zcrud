/// La chaîne de résolution du chrome du composer, paramètre > jeton >
/// référence, et les créneaux par défaut en widgets purs (aucun `material`,
/// aucune couleur inventée).
///
/// ## Trois niveaux, champ par champ — jamais deux
///
/// ```
/// parametre  ZChatComposerChrome.<champ>     <- l'hote, ici et maintenant
///     v (si null)
/// jeton      ZcrudScope.theme.<...>          <- l'hote, pour toute sa surface
///     v (si null / scope absent)
/// reference  ZChatComposerReference.<...>     <- valeur de reference auditee
/// ```
///
/// Le niveau 2 lit `ZcrudScope.maybeOf(context)?.theme` et non
/// `ZcrudTheme.of(context)` : `of()` ne rend jamais `null` (repli neutre du
/// cœur), ce qui rendrait le niveau 3 inatteignable, et une référence que
/// rien ne peut atteindre serait une couche morte.
///
/// `chatResponseLengthAccents` côté thème est indexé par le nom du palier
/// (`ZChatResponseLength.name` — `zcrud_core` ne peut pas importer l'enum,
/// invariant AD-1) ; la consultation reste clé par clé à travers les trois
/// niveaux.
///
/// ## Invariant AD-13 — le plancher n'est pas négociable
///
/// [ZChatComposerChromeStyle.sendTargetSize] est écrêté à
/// `kZChatMinTapTarget` : un paramètre (ou un jeton) qui demanderait une
/// cible plus petite rend quand même 48 dp. La valeur basse est
/// inexprimable, comme dans `_ZChatComposerTarget`.
///
/// ## Invariant AD-13 — Reduce Motion
///
/// [ZChatComposerAnimatedHint] est inerte sous
/// `MediaQuery.disableAnimations` (aucun `Timer` créé, premier libellé figé)
/// et [ZChatComposerSendTarget] y transitionne en `Duration.zero`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_composer.dart';
import 'z_chat_composer_reference.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Réglage partiel du chrome du composer : tout champ `null` délègue au
/// niveau suivant (jeton s'il existe, puis référence).
///
/// Strictement additif et immuable — même patron que `ZChatNotebookSkin`.
@immutable
class ZChatComposerChrome {
  /// Construit un réglage. `const ZChatComposerChrome()` signifie « la
  /// référence, telle que mesurée » (aux jetons de l'hôte près).
  const ZChatComposerChrome({
    this.padding,
    this.containerRadius,
    this.fieldContentPadding,
    this.badgeRadius,
    this.borderWidth,
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

  /// Rayon du conteneur — le SEUL rayon du cadre : fond, filet et rognage le
  /// partagent, ils ne peuvent pas diverger. `null` ⇒ jeton
  /// `chatComposerRadius`, puis `radiusM`, puis référence (12).
  final Radius? containerRadius;

  /// Marge interne du champ. `null` ⇒ jeton `inputContentPadding`, puis
  /// référence.
  final EdgeInsetsDirectional? fieldContentPadding;

  /// Rayon des badges. `null` ⇒ jeton `badgeRadius`, puis référence (8).
  final Radius? badgeRadius;

  /// Épaisseur du filet du conteneur. `null` signifie jeton
  /// `chatComposerBorderWidth`, puis référence (1).
  ///
  /// L'épaisseur ne peint rien à elle seule : sans couleur résolue
  /// (`ZChatComposerSurface.borderColor`), il n'y a pas de filet.
  final double? borderWidth;

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

  /// Accents des paliers de verbosité, consultés clé par clé : renseigner
  /// `concise` seul ne fait pas disparaître les deux autres accents de
  /// référence. `null`/clé absente signifie jeton `chatResponseLengthAccents`
  /// (indexé par `ZChatResponseLength.name`), puis référence — cf.
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
    this.borderWidth = ZChatComposerReference.borderWidth,
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

  /// Épaisseur du filet du conteneur — jamais négative.
  final double borderWidth;

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

  /// Accents du jeton `chatResponseLengthAccents` (niveau 2), indexés par
  /// `ZChatResponseLength.name` — la seule clé que `zcrud_core` peut porter
  /// sans importer l'enum (invariant AD-1). `null` si l'hôte n'a rien réglé.
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

/// Résout le chrome du composer contre le contexte — paramètre > jeton >
/// référence, champ par champ. Ne lève jamais (invariant AD-10) : sans
/// `ZcrudScope` ni paramètre, tout retombe sur la référence.
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
    // Le rayon du CADRE avant le rayon générique : `chatComposerRadius` est
    // le rôle précis, `radiusM` le rôle large. Un hôte qui n'a réglé que
    // `radiusM` obtient exactement ce qu'il obtenait — l'insertion est
    // additive, elle ne déplace personne.
    containerRadius:
        chrome?.containerRadius ??
        theme?.chatComposerRadius ??
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
    // Une épaisseur négative est écrêtée à 0 (invariant AD-10 : un
    // paramètre absurde ne fait pas lever le rendu) — et l'écrêtage vaut
    // aussi pour le jeton, dont la dartdoc annonce « nulle ou négative vaut
    // pas de filet ».
    borderWidth:
        (chrome?.borderWidth ??
                theme?.chatComposerBorderWidth ??
                ZChatComposerReference.borderWidth)
            .clamp(0.0, double.infinity),
    // Invariant AD-13 : écrêté au plancher — une cible tactile trop petite
    // est inexprimable, par paramètre comme par jeton.
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

/// L'ÉTAT DE RENDU de l'affordance d'envoi — ce que le bouton doit dire,
/// jamais ce que l'application doit faire.
///
/// Quatre états, parce que le bouton d'envoi a quatre choses à dire et qu'un
/// glyphe unique n'en dirait qu'une :
///
/// | état | ce qui est vrai | ce que l'affordance annonce |
/// |---|---|---|
/// | [idle] | rien en cours | « envoyer » |
/// | [busy] | une préparation d'hôte est en cours (téléversement…) | « envoi en préparation » |
/// | [streaming] | une requête est en vol | « arrêter la génération » |
/// | [editing] | un message existant est en cours de modification | « valider la modification » |
///
/// C'est un état **dérivé**, jamais persisté : il se recalcule à partir de
/// tranches que le contrôleur porte déjà ([ZChatComposerSendState.resolve]).
/// Rien à sérialiser, rien à synchroniser.
enum ZChatComposerSendState {
  /// Repos — l'envoi est l'action offerte.
  idle,

  /// Une préparation fournie par l'hôte est en cours : l'envoi attend.
  ///
  /// Le socle ne devine jamais cet état — il n'a aucun moyen de savoir
  /// qu'un téléversement d'hôte tourne. Il est **injecté**.
  busy,

  /// Une requête est en vol : l'action offerte est l'ARRÊT.
  streaming,

  /// Un message existant est en cours de modification : l'action offerte est
  /// la validation de cette modification.
  editing;

  /// La clé de libellé de l'état — l'affordance n'annonce jamais « envoyer »
  /// quand elle arrête, ni « arrêter » quand elle valide.
  ///
  /// [idle] rend [kZChatLabelSend] : un appelant qui ne règle pas d'état
  /// obtient exactement l'annonce d'avant.
  String get labelKey => switch (this) {
    ZChatComposerSendState.idle => kZChatLabelSend,
    ZChatComposerSendState.busy => kZChatLabelSendBusy,
    ZChatComposerSendState.streaming => kZChatLabelStopGeneration,
    ZChatComposerSendState.editing => kZChatLabelSendEdit,
  };

  /// Résout l'état à partir des trois faits observables, **dans cet ordre de
  /// priorité** : [streaming] > [busy] > [editing] > [idle].
  ///
  /// L'ordre n'est pas un détail de mise en œuvre : il dit ce que
  /// l'utilisateur doit pouvoir faire quand deux faits sont vrais en même
  /// temps. Une requête en vol prime sur tout — sans quoi une génération
  /// lancée depuis le mode édition deviendrait ININTERROMPABLE. Une
  /// préparation en cours prime sur l'édition, parce que valider une
  /// modification dont la pièce jointe n'est pas encore prête l'enverrait
  /// sans elle.
  static ZChatComposerSendState resolve({
    required bool streaming,
    required bool busy,
    required bool editing,
  }) {
    if (streaming) return ZChatComposerSendState.streaming;
    if (busy) return ZChatComposerSendState.busy;
    if (editing) return ZChatComposerSendState.editing;
    return ZChatComposerSendState.idle;
  }
}

/// Les glyphes de l'affordance d'envoi, un par [ZChatComposerSendState].
///
/// Le socle ne peut rendre aucune icône : les quatre faces viennent de
/// l'hôte. Seule [idle] est exigée — les trois autres retombent sur elle,
/// pour qu'un hôte qui n'en fournit qu'une obtienne l'affordance d'hier, à la
/// face près, tout en gagnant l'annonce sémantique par état.
@immutable
class ZChatComposerSendGlyphs {
  /// Construit le jeu de faces. Seule [idle] est requise.
  const ZChatComposerSendGlyphs({
    required this.idle,
    this.busy,
    this.streaming,
    this.editing,
  });

  /// La face au repos — celle de l'avion en papier.
  final Widget idle;

  /// La face « préparation en cours » (un indicateur d'activité, typiquement).
  /// `null` ⇒ [idle].
  final Widget? busy;

  /// La face « arrêter » (le carré). `null` ⇒ [idle].
  final Widget? streaming;

  /// La face « valider la modification » (la coche). `null` ⇒ [idle].
  final Widget? editing;

  /// La face de [state], avec repli sur [idle] — jamais de créneau vide.
  Widget resolve(ZChatComposerSendState state) => switch (state) {
    ZChatComposerSendState.idle => idle,
    ZChatComposerSendState.busy => busy ?? idle,
    ZChatComposerSendState.streaming => streaming ?? idle,
    ZChatComposerSendState.editing => editing ?? idle,
  };
}

/// Le créneau d'envoi par défaut — la géométrie et le geste de référence, en
/// widget pur : la cible 48 dp, l'échelle 0.7 → 1.0 en 150 ms, la sémantique
/// de bouton. Le glyphe vient de l'hôte ([child]) : ce paquet ne peut rendre
/// ni une icône ni une couleur. Le rendu pixel-perfect d'un design system
/// particulier est l'affaire du satellite qui le porte.
///
/// À monter dans le créneau `trailing` de `ZChatComposer` :
///
/// ```dart
/// trailing: (context, slot) =>
///     ZChatComposerSendTarget(slot: slot, child: monGlyphe),
/// ```
///
/// Il n'introduit aucun chemin d'envoi : le tap appelle
/// [ZChatComposerSlot.submit] — la fermeture que le composer fournit, donc
/// le même site que la touche « valider » du clavier.
class ZChatComposerSendTarget extends StatelessWidget {
  /// Construit la cible d'envoi.
  const ZChatComposerSendTarget({
    required this.slot,
    required this.child,
    this.chrome,
    this.state = ZChatComposerSendState.idle,
    super.key,
  });

  /// Le contexte du créneau, fourni par `ZChatComposer`.
  final ZChatComposerSlot slot;

  /// Le glyphe de l'hôte.
  final Widget child;

  /// Réglage de chrome — `null` signifie jetons puis référence.
  final ZChatComposerChrome? chrome;

  /// Ce que l'affordance ANNONCE. [ZChatComposerSendState.idle] par défaut :
  /// l'annonce est alors « envoyer », exactement comme sans ce réglage.
  ///
  /// Il gouverne l'étiquette sémantique, pas le geste : le tap reste
  /// [ZChatComposerSlot.submit], l'unique chemin d'envoi. L'ARRÊT est une
  /// autre pièce (`ZChatComposerStopTarget`), parce que c'est un autre verbe —
  /// une cible qui changerait de verbe sous le doigt serait un second site
  /// d'appel déguisé.
  final ZChatComposerSendState state;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    // Reduce Motion : la transition devient instantanée — l'état final est
    // identique, seule l'animation disparaît (invariant AD-13).
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ValueListenableBuilder<bool>(
      // La tranche granulaire : elle ne signale qu'aux transitions
      // vide ↔ non vide — jamais à chaque frappe (invariant AD-2).
      valueListenable: slot.controller.canSend,
      builder: (BuildContext context, bool canSend, Widget? glyph) => Semantics(
        button: true,
        enabled: canSend,
        label: zChatLabel(context, state.labelKey),
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
              // Invariant AD-13 : alignement directionnel.
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

/// Le placeholder animé, porté en widget pur — à monter dans le créneau
/// `hint` de `ZChatComposer` (visible seulement quand la saisie est vide, la
/// visibilité restant l'affaire du composer).
///
/// Les [hints] sont des textes déjà localisés par l'hôte — typiquement des
/// suggestions de saisie, une donnée métier que le socle ne connaît pas.
///
/// ## Reduce Motion
///
/// Sous `MediaQuery.disableAnimations` : aucun minuteur n'est créé, le
/// premier libellé reste figé.
///
/// ## Rotation déterministe
///
/// Aucun `Random` : la rotation est séquentielle (`(i + 1) % n`).
class ZChatComposerAnimatedHint extends StatefulWidget {
  /// Construit le placeholder animé.
  const ZChatComposerAnimatedHint({
    required this.hints,
    this.leading,
    this.chrome,
    super.key,
  });

  /// Les libellés à faire tourner, localisés par l'hôte. Vide signifie rien
  /// rendu (invariant AD-4).
  final List<String> hints;

  /// Glyphe de tête optionnel. `null` signifie absent.
  final Widget? leading;

  /// Réglage de chrome — `null` signifie jetons puis référence.
  final ZChatComposerChrome? chrome;

  @override
  State<ZChatComposerAnimatedHint> createState() =>
      _ZChatComposerAnimatedHintState();
}

class _ZChatComposerAnimatedHintState extends State<ZChatComposerAnimatedHint> {
  /// Index courant — une tranche, jamais un `setState`.
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
    // Reduce Motion : aucun minuteur — l'inertie est structurelle, pas une
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
    // Un seul chemin de rendu — l'inertie sous Reduce Motion vient
    // uniquement de l'absence de minuteur (`didChangeDependencies`), jamais
    // d'une seconde branche statique redondante.
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
          // Invariant AD-13 : jamais `TextAlign.left`.
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

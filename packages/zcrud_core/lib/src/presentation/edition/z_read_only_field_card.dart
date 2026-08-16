/// `ZReadOnlyFieldCard` — le **rendu d'un champ consulté** : un libellé, sa
/// valeur, et de quoi la copier.
///
/// Ce widget porte les **cinq formes** de consultation ([ZReadFieldLayout]) :
/// la fiche pilotée par les jetons ([ZReadFieldLayout.card], par défaut), la
/// ligne Material ([ZReadFieldLayout.listTile]), la liste de définitions, la
/// ligne à deux colonnes et la ligne dense. La forme n'est pas un paramètre
/// qu'un appelant doit penser à recopier : elle descend par le **même canal**
/// que le mode de consultation lui-même (`ZReadModeScope`), à défaut par le
/// jeton `readLayout` du thème.
///
/// **Priorité** (du plus proche au plus lointain) : le paramètre [layout] →
/// `ZFieldSpec.readLayout` (que le moteur passe dans ce paramètre) → la surface
/// (`DynamicEdition.readLayout`, `ZStepperEdition.readLayout`) → le jeton
/// `ZcrudTheme.readLayout` → [ZReadFieldLayout.card].
///
/// Invariant AD-2 : widget **statique** (n'écoute AUCUNE tranche) — l'hôte
/// (`ZFieldWidget`) le monte SOUS `ZFieldListenableBuilder` et lui passe le
/// [label] (déjà résolu l10n), le Widget [value], le [copyText] (texte
/// copiable, `null` si non copiable) et [valueSemantics] (le texte à annoncer,
/// même lorsqu'il n'est pas copiable).
///
/// Invariant FR-26 : aucune couleur ni mesure en dur. Chaque forme dérive ses
/// valeurs du `ColorScheme`/`TextTheme` ; les jetons `read*` de `ZcrudTheme`
/// les **remplacent** — les styles de texte par fusion (un style sans couleur
/// garde la couleur dérivée), les mesures par substitution.
///
/// **Sans aucun réglage, la forme par défaut est posée à plat** : ni fond ni
/// filet, libellé en corps de texte au-dessus d'une valeur en gris, rang de 72
/// — la présentation d'un document qu'on lit et qu'on imprime. Une application
/// qui veut la **fiche encadrée** la retrouve en déclarant deux jetons :
///
/// ```dart
/// ZcrudTheme(readFillColor: scheme.surfaceContainerLow, readBorderWidth: 1)
/// ```
///
/// Les champs de **saisie** ne bougent dans aucun cas : leur filet reste
/// gouverné par `inputBorderWidth`, distinct de celui de la fiche.
///
/// Invariant AD-13 : insets **directionnels**, `Semantics` conteneur annonçant
/// la paire « libellé : valeur » dans **chaque** forme, et aucune cible
/// interactive sous 48 — les formes denses n'affichent pas de bouton de copie,
/// elles offrent l'appui long et une **action annoncée** aux lecteurs d'écran.
/// Invariant AD-1 : `package:flutter/services.dart` (`Clipboard`) +
/// `package:flutter/semantics.dart` (`SemanticsService`,
/// `CustomSemanticsAction`) sont des **services Flutter natifs** admis (aucun
/// gestionnaire d'état, aucune dépendance lourde).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsService;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../domain/edition/z_read_field_layout.dart';
// Préfixé : le helper l10n `label(...)` est masqué par le champ `label` de la
// fiche — on l'appelle donc via `l10n.label(...)`.
import '../l10n/z_localizations.dart' as l10n;
import '../theme/z_theme.dart';
import 'z_read_mode_scope.dart';

/// Rendu d'un champ consulté (libellé + valeur + copie), dans la forme
/// demandée par la surface.
class ZReadOnlyFieldCard extends StatelessWidget {
  /// Construit le rendu de consultation portant [label] et [value].
  ///
  /// [copyText] `null` ⇒ aucune affordance de copie (placeholder « — » /
  /// valeur-Widget). [valueSemantics] est le texte **annoncé** aux lecteurs
  /// d'écran ; à défaut, [copyText] fait office. [layout] force la forme et
  /// prime sur la surface comme sur le thème.
  const ZReadOnlyFieldCard({
    required this.label,
    required this.value,
    this.copyText,
    this.valueSemantics,
    this.layout,
    super.key,
  });

  /// Libellé du champ (déjà résolu l10n par l'hôte).
  final String label;

  /// Widget de rendu de la valeur (texte, placeholder, ou pastille couleur).
  final Widget value;

  /// Représentation textuelle **copiable** ; `null` ⇒ copie désactivée.
  final String? copyText;

  /// Texte **annoncé** avec le libellé par le conteneur `Semantics`.
  ///
  /// Une valeur peut être lisible sans être copiable (un placeholder, une
  /// valeur formatée) : sans ce paramètre, elle resterait muette pour un
  /// lecteur d'écran alors qu'elle est affichée. `null` ⇒ [copyText] ; `null`
  /// des deux ⇒ c'est la valeur-Widget qui parle pour elle-même.
  final String? valueSemantics;

  /// **Forme** de ce rendu. `null` (défaut) ⇒ celle de la surface
  /// (`ZReadModeScope.layout`), à défaut le jeton `ZcrudTheme.readLayout`, à
  /// défaut [ZReadFieldLayout.card].
  final ZReadFieldLayout? layout;

  bool get _copyable => copyText != null && copyText!.isNotEmpty;

  /// Texte annoncé par le conteneur `Semantics` (`null` ⇒ la valeur-Widget
  /// garde sa propre sémantique).
  String? get _announced => valueSemantics ?? copyText;

  @override
  Widget build(BuildContext context) {
    final tokens = ZcrudTheme.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final form = layout ??
        ZReadModeScope.layoutOf(context) ??
        tokens.readLayout ??
        ZReadFieldLayout.card;

    final labelStyle = _merged(
      _labelStyleOf(form, theme.textTheme, scheme),
      tokens.readLabelTextStyle,
    );
    final valueStyle = _merged(
      _valueStyleOf(form, theme.textTheme, scheme),
      tokens.readValueTextStyle,
    );
    final padding = tokens.readPadding ?? _paddingOf(form);
    final gap = tokens.readLabelGap ?? _gapOf(form);

    final labelWidget = ExcludeSemantics(
      child: Text(label, style: labelStyle),
    );
    // La valeur n'est retirée de la sémantique que si le conteneur l'annonce à
    // sa place : sinon elle serait affichée mais muette.
    final valueWidget = DefaultTextStyle.merge(
      style: valueStyle,
      textAlign: form == ZReadFieldLayout.inlineRow
          ? TextAlign.end
          : TextAlign.start,
      child: _announced == null ? value : ExcludeSemantics(child: value),
    );

    final Widget visual;
    switch (form) {
      case ZReadFieldLayout.card:
        visual = _card(context, tokens, scheme, labelWidget, valueWidget,
            padding, gap);
      case ZReadFieldLayout.listTile:
        visual = _listTile(context, tokens, labelWidget, valueWidget);
      case ZReadFieldLayout.definition:
        visual = _dense(
          context,
          _stacked(labelWidget, valueWidget, padding, gap),
        );
      case ZReadFieldLayout.inlineRow:
        visual = _dense(
          context,
          LayoutBuilder(
            builder: (context, constraints) {
              // Une ligne à deux colonnes n'a plus de sens sur une surface
              // étroite : elle se replie alors en présentation empilée.
              final replie = constraints.maxWidth.isFinite &&
                  constraints.maxWidth < (tokens.readRowMinWidth ?? 360);
              if (replie) {
                return _stacked(
                  labelWidget,
                  valueWidget,
                  padding,
                  _gapOf(ZReadFieldLayout.definition),
                );
              }
              return Padding(
                padding: padding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: tokens.readRowLabelWidth ?? 160,
                      child: labelWidget,
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: valueWidget,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      case ZReadFieldLayout.compact:
        visual = _dense(
          context,
          Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                labelWidget,
                SizedBox(width: gap),
                Expanded(child: valueWidget),
              ],
            ),
          ),
        );
    }

    final margin = tokens.readCardMargin ?? EdgeInsetsDirectional.zero;
    return Semantics(
      container: true,
      label: label,
      value: _announced,
      // Formes denses : le bouton de copie n'existe pas (il aurait imposé une
      // cible de 48 et annulé la densité). L'action reste offerte aux lecteurs
      // d'écran, et par appui long au doigt.
      customSemanticsActions: _copyable && !_showsCopyButton(form)
          ? <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: _copyLabel(context)):
                  () => _copy(context),
            }
          : null,
      child: margin == EdgeInsetsDirectional.zero
          ? visual
          : Padding(padding: margin, child: visual),
    );
  }

  // ── Formes ───────────────────────────────────────────────────────────────

  /// [ZReadFieldLayout.card] : carte pilotée par les jetons, rang d'une hauteur
  /// minimale (72 par défaut) pour tenir le rythme vertical d'une liste.
  Widget _card(
    BuildContext context,
    ZcrudTheme tokens,
    ColorScheme scheme,
    Widget labelWidget,
    Widget valueWidget,
    EdgeInsetsDirectional padding,
    double gap,
  ) {
    final content = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                labelWidget,
                if (gap > 0) SizedBox(height: gap),
                valueWidget,
              ],
            ),
          ),
          if (_copyable) _copyButton(context),
        ],
      ),
    );
    final minHeight = tokens.readCardMinHeight ?? 72;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      // Fond et filet **de la fiche** : jetons dédiés, posés à plat par défaut
      // (aucun fond, aucun filet). Une application qui veut la fiche encadrée
      // déclare `readFillColor` et `readBorderWidth`, sans toucher aux champs
      // de saisie (invariant FR-26).
      // Défaut **dérivé** du `ColorScheme` et rendu totalement translucide :
      // aucune couleur en dur (invariant FR-26), et une fiche posée à plat.
      color: tokens.readFillColor ?? scheme.surface.withAlpha(0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(tokens.inputRadius),
        // Largeur `0` ⇒ **aucun** filet (`BorderSide.none`), et non le filet
        // d'un pixel physique que dessinerait une largeur nulle.
        side: _side(tokens.readBorderWidth ?? 0,
            tokens.readBorderColor ?? scheme.outline),
      ),
      child: InkWell(
        // `onLongPress` : copie la valeur textuelle. No-op si non copiable
        // (placeholder / valeur-Widget).
        onLongPress: _copyable ? () => _copy(context) : null,
        borderRadius: BorderRadius.all(tokens.inputRadius),
        child: minHeight > 0
            ? ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: content,
              )
            : content,
      ),
    );
  }

  /// [ZReadFieldLayout.listTile] : la ligne Material native — libellé en
  /// `title`, valeur en `subtitle`. Sa structure appartient à Material ; seuls
  /// le retrait (si `readPadding` est déclaré) et les styles de texte suivent
  /// les jetons.
  Widget _listTile(
    BuildContext context,
    ZcrudTheme tokens,
    Widget labelWidget,
    Widget valueWidget,
  ) =>
      ListTile(
        contentPadding: tokens.readPadding,
        title: labelWidget,
        subtitle: valueWidget,
        trailing: _copyable ? _copyButton(context) : null,
        onLongPress: _copyable ? () => _copy(context) : null,
      );

  /// Présentation **empilée** sans chrome : libellé au-dessus de la valeur.
  /// Sert [ZReadFieldLayout.definition], et [ZReadFieldLayout.inlineRow]
  /// lorsqu'elle se replie faute de largeur.
  Widget _stacked(
    Widget labelWidget,
    Widget valueWidget,
    EdgeInsetsDirectional padding,
    double gap,
  ) =>
      Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            labelWidget,
            if (gap > 0) SizedBox(height: gap),
            valueWidget,
          ],
        ),
      );

  /// Enveloppe des formes **denses** : aucun chrome, aucun bouton, mais l'appui
  /// long pour copier. `GestureDetector` et non `InkWell` : rien ici ne se
  /// présente comme un contrôle, donc rien n'a à porter une cible de 48.
  Widget _dense(BuildContext context, Widget child) => GestureDetector(
        onLongPress: _copyable ? () => _copy(context) : null,
        behavior: HitTestBehavior.opaque,
        child: child,
      );

  /// `true` si la forme affiche le **bouton** de copie. Les formes denses ne le
  /// font pas : cf. [_dense].
  static bool _showsCopyButton(ZReadFieldLayout form) =>
      form == ZReadFieldLayout.card || form == ZReadFieldLayout.listTile;

  // ── Défauts par forme (dérivés du thème — invariant FR-26) ───────────────

  /// Style du libellé propre à [form] (`null` ⇒ celui que Material applique).
  static TextStyle? _labelStyleOf(
    ZReadFieldLayout form,
    TextTheme text,
    ColorScheme scheme,
  ) {
    switch (form) {
      case ZReadFieldLayout.card:
        return text.bodyLarge;
      case ZReadFieldLayout.listTile:
        return null;
      case ZReadFieldLayout.definition:
        return text.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
      case ZReadFieldLayout.inlineRow:
      case ZReadFieldLayout.compact:
        return text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    }
  }

  /// Style de la valeur propre à [form] (`null` ⇒ celui que Material applique).
  static TextStyle? _valueStyleOf(
    ZReadFieldLayout form,
    TextTheme text,
    ColorScheme scheme,
  ) {
    switch (form) {
      case ZReadFieldLayout.card:
        return text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
      case ZReadFieldLayout.listTile:
        return null;
      case ZReadFieldLayout.definition:
        return text.bodyLarge?.copyWith(color: scheme.onSurface);
      case ZReadFieldLayout.inlineRow:
      case ZReadFieldLayout.compact:
        return text.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        );
    }
  }

  /// Padding interne propre à [form] (`readPadding` le remplace).
  static EdgeInsetsDirectional _paddingOf(ZReadFieldLayout form) {
    switch (form) {
      case ZReadFieldLayout.card:
      case ZReadFieldLayout.inlineRow:
        return const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 8,
        );
      case ZReadFieldLayout.listTile:
        return const EdgeInsetsDirectional.symmetric(horizontal: 16);
      case ZReadFieldLayout.definition:
        return const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 6,
        );
      case ZReadFieldLayout.compact:
        return const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 4,
        );
    }
  }

  /// Écart libellé → valeur propre à [form] — vertical dans les formes
  /// empilées, horizontal dans les formes en ligne (`readLabelGap` le
  /// remplace).
  static double _gapOf(ZReadFieldLayout form) {
    switch (form) {
      case ZReadFieldLayout.card:
      case ZReadFieldLayout.listTile:
        return 0;
      case ZReadFieldLayout.definition:
        return 2;
      case ZReadFieldLayout.inlineRow:
        return 12;
      case ZReadFieldLayout.compact:
        return 8;
    }
  }

  /// Fusionne le style **déclaré** par-dessus celui de la forme : un jeton sans
  /// couleur garde la couleur dérivée du `ColorScheme` (invariant FR-26).
  static TextStyle? _merged(TextStyle? base, TextStyle? token) {
    if (token == null) return base;
    return (base ?? const TextStyle()).merge(token);
  }

  /// Filet de la fiche : `BorderSide.none` dès que la largeur demandée est
  /// nulle ou négative — une largeur `0` passée à `BorderSide` dessinerait
  /// encore un trait d'un pixel physique.
  static BorderSide _side(double width, Color color) =>
      width <= 0 ? BorderSide.none : BorderSide(color: color, width: width);

  /// Libellé localisé de l'action de copie (tooltip **et** action sémantique).
  String _copyLabel(BuildContext context) =>
      l10n.label(context, 'copy', fallback: 'Copier');

  /// Action de copie **explicite** et accessible (≥ 48 — invariant AD-13) :
  /// une affordance visible, distincte du seul appui long. Tooltip/`Semantics`
  /// localisés.
  Widget _copyButton(BuildContext context) => IconButton(
        icon: const Icon(Icons.copy_outlined),
        tooltip: _copyLabel(context),
        // IconButton porte nativement une cible ≥ 48 (Material tap target).
        onPressed: () => _copy(context),
      );

  /// Copie [copyText] dans le presse-papier + retour utilisateur **best-effort
  /// sans dépendance** (invariant AD-10) : annonce sémantique + SnackBar si un
  /// `ScaffoldMessenger` est disponible (sinon aucun throw).
  void _copy(BuildContext context) {
    final text = copyText;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    final message = l10n.label(
      context,
      'copied',
      fallback: 'Valeur copiée dans le presse-papier',
    );
    // Annonce lecteur d'écran (a11y invariant AD-13) via le service natif —
    // variante multi-fenêtres de `announce` (évite l'API dépréciée).
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}

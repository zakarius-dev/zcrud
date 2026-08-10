/// Widget de la **famille booléen** (E3-3a) : `boolean`.
///
/// `SwitchListTile` : lit `value` (coché si `== true`) et écrit via `onChanged`
/// (aucun `TextEditingController` — AD-2). Le `SwitchListTile` porte nativement
/// l'**état sémantique** (coché/décoché, rôle `switch`) et une cible ≥ 48 dp
/// (hauteur de `ListTile`), satisfaisant AC5/AC6 sans style codé en dur (FR-26).
///
/// Convention (story #3) : `boolean` = **toggle unique** ; la multi-sélection
/// par cases relève de `checkb` (famille select).
///
/// ## CR-DODLP-BOOL — texte d'état optionnel (2026-08-10)
///
/// Avec un `ZBooleanConfig` dont [ZBooleanConfig.showsStateLabel] est vrai, un
/// **texte d'état** (« Oui »/« Non », clés l10n `yes`/`no`, surchargeables) est
/// rendu **à la fin du `title`**, donc immédiatement avant le `Switch` — la
/// position de parité legacy DODLP (`Le magasin… ●— Non`).
///
/// **Forme retenue et pourquoi.** La CR proposait `SwitchListTile.secondary`, un
/// sous-titre, ou un `Row[Switch, Text]` fait main :
/// * `secondary` occupe le slot **leading** (le `Switch` est déjà en trailing) :
///   le texte atterrirait du mauvais côté ;
/// * `subtitle` place le texte sous le libellé, loin du switch ;
/// * un `Row[Switch, Text]` fait main **remplacerait** `SwitchListTile` : il
///   faudrait re-fabriquer à l'identique le `MergeSemantics`, l'`onTap` de
///   ligne, le `ListTileTheme` et la hauteur minimale — donc réintroduire à la
///   main la cible ≥ 48 dp et le nœud sémantique `switch` que Material fournit.
///
/// Injecter le texte dans le `title` garde **le même `SwitchListTile`** dans les
/// deux cas : la cible tactile, le `MergeSemantics` et l'`onTap` restent ceux de
/// Material, et le chemin de l'hôte passif est **littéralement le chemin
/// antérieur** (`title: Text(resolvedLabel)`).
///
/// **A11y (AD-13) — le texte d'état est DÉCORATIF.** `SwitchListTile` annonce
/// déjà l'état via le drapeau `toggled` du nœud fusionné ; laisser « Non »
/// entrer dans le `label` le ferait entendre **deux fois** (« … Non,
/// interrupteur, désactivé »). Le `Text` d'état est donc enveloppé dans
/// `ExcludeSemantics`, comme l'astérisque du champ requis. La couleur n'est
/// jamais le seul canal : l'information est portée par du **texte** (et l'état
/// reste porté par le `Switch` lui-même).
///
/// **Lecture seule.** `field.readOnly` désactive le switch mais **conserve** le
/// texte d'état : c'est le cas où la seule position d'un toggle grisé est la
/// plus difficile à lire, et cela s'aligne sur le mode lecture (DP-13), où
/// `zReadOnlyValueOf` rend déjà `Oui`/`Non` en toutes lettres pour un `boolean`.
///
/// ## CR-DODLP-BOOL-PILL — le rendu « pilule » (voie A, 2026-08-10)
///
/// `ZBooleanConfig(style: ZBooleanStyle.pill)` peint la **pilule** du legacy
/// DODLP (`FlutterSwitch`, `edition_screen.dart:1629`) : piste arrondie, texte
/// d'état **à l'intérieur**, libellé du champ à gauche.
///
/// 🔴 **Peinte nativement, aucune dépendance** (AD-1, CORE OUT = 0) : le paquet
/// `flutter_switch` demandé par la CR ne peut pas entrer dans `zcrud_core`.
/// Les mesures relevées **à la source** sont reproduites (65 × 30, pouce 20,
/// rayon 20, padding 4, texte 12 sp) ; les **couleurs**, elles, ne peuvent PAS
/// l'être : le legacy pose un vert (`kSuccessColorLight`) et un blanc
/// littéraux, ce que FR-26 interdit ici. Chaîne appliquée, par état :
///
/// > **paramètre** (`ZBooleanConfig.activeColorKey`/`inactiveColorKey`, résolue
/// > par le seam `ZcrudScope.colorKeyResolver`) **>** jeton
/// > (`ZcrudTheme.booleanPill*`) **>** rôle (`ColorScheme.primary`/`outline`).
///
/// C'est par la **clé sémantique** que le vert exact du legacy entre — le même
/// seam que `zResolveColorKey` a été créé pour servir, précisément parce que
/// Material 3 n'a pas de rôle « succès » et que le cœur refuse de l'inventer.
///
/// **Contraste (AD-13).** Le legacy écrit un `activeTextColor` BLANC littéral : dès
/// qu'un hôte donne une piste claire, le texte devient illisible. Le premier
/// plan (texte **et** pouce) est donc **dérivé** de la piste quand rien ne le
/// fixe — `ThemeData.estimateBrightnessForColor` → `surface`/`onSurface`,
/// exactement le précédent `stepperBadgeForegroundColor` posé pour ce défaut.
/// Une clé sémantique fournit en outre son propre `onColor` (paire M3 garantie).
///
/// **A11y (AD-13).** La forme est **celle de `SwitchListTile`** —
/// `MergeSemantics(ListTile(…, trailing: <porteur d'état>))` — au porteur près :
/// là où Material pose un `Switch`, la pilule pose un
/// `Semantics(toggled:, excludeSemantics: true)`. Le texte interne reste donc
/// **DÉCORATIF** (la mesure de v0.74 vaut ici à l'identique : non exclu, il
/// ferait entendre l'état **deux fois**), et le libellé du champ n'apparaît
/// qu'**une** fois dans l'arbre sémantique. La cible tactile est la pilule
/// elle-même, plancher **48 dp** posé par une `ConstrainedBox` (contrainte
/// LIANTE : la pilule peinte ne fait que 30 dp).
///
/// **Mouvement.** Le legacy anime la course du pouce (200 ms). La pilule est
/// rendue **statique** : rien à réduire (Reduce Motion), et aucun `Opacity`
/// animé ne laisse dans l'arbre un texte invisible que `find.text` trouverait
/// quand même (le legacy empile les deux textes à opacité 0/1 ; ici **seul**
/// le texte de l'état courant est construit).
///
/// ## CR-DODLP-BOOL-BOXED — l'encart de champ (option A, 2026-08-10)
///
/// `ZBooleanConfig(boxed: true)` enveloppe le champ (les **deux** formes) dans
/// le **conteneur décoré du thème**, celui de ses voisins `text`/`number`/
/// `select` : fond `fieldFillColor`, bordure `fieldBorderColor`, rayon
/// `inputRadius`, marge interne `inputContentPadding`. **Opt-in** : sans le
/// drapeau, le rendu est strictement celui de v0.75 (ligne nue).
///
/// 🔴 **Aucun cadre peint à la main, aucun jeton nouveau** : la décoration vient
/// de la **fabrique centrale** [ZcrudTheme.inputDecoration] — exactement celle
/// que `zFieldDecoration` appelle pour text/number/select
/// (`z_field_adornment_view.dart:178`). Une seconde façon de dessiner un cadre
/// de champ serait précisément la divergence que ce paquet combat.
///
/// **Pourquoi `zFieldDecoration` lui-même n'est PAS appelé ici** — mesuré : ses
/// deux réglages sont l'un et l'autre inutilisables pour un encart.
/// * `bare: false` pose **toujours** `labelWidget: ZFieldLabel(field: …)`
///   (`z_field_adornment_view.dart:180`) : le libellé du champ serait rendu une
///   seconde fois, en flottant, alors que le `ListTile` le porte déjà dans son
///   `title` — un doublon **visuel et sémantique**, exactement le défaut mesuré
///   en v0.74 (état annoncé deux fois) puis en v0.75 (titre annoncé deux fois) ;
/// * `bare: true` renvoie une décoration **sans boîte** (`InputBorder.none` sur
///   les cinq bordures, `filled: false`, `contentPadding: zero`,
///   `z_theme.dart:2050-2071`) : aucun encart.
///
/// Le point de réutilisation exact est donc la fabrique **sous**
/// `zFieldDecoration` : `ZcrudTheme.of(context).inputDecoration(context)` sans
/// libellé — mêmes jetons, mêmes bordures, même remplissage que le voisin.
///
/// **Ce que l'encart ne touche pas** : le `ListTile` (donc la cible ≥ 48 dp de
/// Material), le `MergeSemantics`, le nœud `switch` porteur de l'état, le
/// `onTap` de ligne. Seule la marge interne du `ListTile` passe à zéro en mode
/// encart — sans quoi les 16 dp du `ListTile` s'ajouteraient aux 16 dp de
/// `inputContentPadding` et le booléen serait **plus indenté** que ses voisins.
///
/// **`ZFieldSize.large`** : l'encart est **inhibé**, la `ZLargeFieldCard` du
/// dispatcher portant déjà le cadre — même règle que le `bare` des familles
/// décor-portantes (`ZDecoratedFieldTrigger`), pas de double cadre.
///
/// **Libellé en gras** : NON fait (cf. rapport). Aucun jeton ne décrit le poids
/// d'un *titre de ligne* ; `labelTextStyle`/`floatingLabelWeight` sont
/// contractuellement ceux du **label d'`InputDecoration`**, et un poids en dur
/// est interdit (FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_size.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_color_key_resolver.dart';
import '../../theme/z_theme.dart';

/// Valeurs de RÉFÉRENCE de la pilule — relevées à la source du legacy DODLP
/// (`edition_screen.dart:1629` + `flutter_switch` 0.3.2). Aucune n'est une
/// couleur : FR-26 reste intact.
const double _kPillWidth = 65; // `width: 65`
const double _kPillHeight = 30; // `height: 30`
const double _kPillThumbSize = 20; // `toggleSize: 20`
const double _kPillRadius = 20; // `borderRadius: 20`
const double _kPillPadding = 4; // `padding: 4` (défaut du paquet)
const double _kPillTextPadding = 4; // marge horizontale du texte interne
const double _kPillDisabledOpacity = 0.6; // `disabled` → `Opacity(0.6)`

/// Plancher de cible tactile (AD-13). La pilule peinte ne fait que 30 dp de
/// haut : sans cette contrainte, la cible serait sous le plancher.
const double _kPillMinTarget = 48;

/// Clé de la **piste** peinte (rendu pilule). Publique et stable : c'est le
/// point d'ancrage des gardes de mesure (dimensions, teinte) — sans elle, un
/// test devrait deviner un `Container` parmi d'autres.
const Key zBooleanPillKey = ValueKey<String>('zboolean:pill');

/// Clé du **pouce** de la pilule (mesure de taille et de teinte).
const Key zBooleanPillThumbKey = ValueKey<String>('zboolean:pill:thumb');

/// Clé de la **contrainte de cible tactile** (plancher 48 dp, AD-13). La garde
/// lit `constraints.minHeight` sur cette boîte — la contrainte LIANTE, jamais
/// une taille rendue.
const Key zBooleanPillTargetKey = ValueKey<String>('zboolean:pill:target');

/// Clé de l'**encart de champ** (CR-DODLP-BOOL-BOXED). Point d'ancrage stable
/// des gardes : c'est l'`InputDecorator` qui porte la décoration thémée. Absent
/// de l'arbre tant que `ZBooleanConfig.boxed` n'est pas posé.
const Key zBooleanBoxKey = ValueKey<String>('zboolean:box');

/// Champ d'édition **booléen** (interrupteur avec libellé et état sémantique).
class ZBooleanFieldWidget extends StatelessWidget {
  /// Construit l'interrupteur lié à [field] ; [value] est la valeur courante
  /// (coché si `== true`), [onChanged] écrit le nouvel état.
  const ZBooleanFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (coché si `== true`).
  final Object? value;

  /// Notifié avec le nouvel état booléen.
  final ValueChanged<bool> onChanged;

  /// Config booléenne depuis `field.config` (défaut sûr : config vide ⇒ aucun
  /// texte d'état, rendu antérieur strictement inchangé — AD-10).
  ZBooleanConfig get _config {
    final config = field.config;
    return config is ZBooleanConfig ? config : const ZBooleanConfig();
  }

  /// Texte d'état pour [checked] : libellé de l'hôte s'il est fourni et non
  /// vide, sinon repli sur les clés l10n `yes`/`no` (FR-26 — aucun littéral en
  /// dur ici ; les deux clés existent en `en` et en `fr`).
  String _stateText(BuildContext context, ZBooleanConfig config, bool checked) {
    final custom = checked ? config.trueLabel : config.falseLabel;
    if (custom != null && custom.isNotEmpty) return custom;
    return label(context, checked ? 'yes' : 'no');
  }

  /// Couleur EFFECTIVE de la piste pour [checked] — chaîne stricte
  /// **paramètre > jeton > rôle**. La paire éventuelle (clé sémantique) est
  /// rendue telle quelle : son `onColor` sert ensuite de premier plan.
  ZColorPair? _trackPair(BuildContext context, ZBooleanConfig config, bool checked) {
    final key = checked ? config.activeColorKey : config.inactiveColorKey;
    if (key == null || key.isEmpty) return null;
    return zResolveColorKey(context, key);
  }

  /// L'encart de champ est-il actif ? `boxed` demandé **et** champ non `large`
  /// (la `ZLargeFieldCard` du dispatcher porte déjà le cadre — même règle que le
  /// `bare` des familles décor-portantes : jamais deux cadres).
  bool _boxedOf(ZBooleanConfig config) =>
      config.boxed && field.fieldSize != ZFieldSize.large;

  /// Marge interne du `ListTile`. Hors encart : la valeur historique
  /// (16 dp, v0.74/v0.75). En encart : **zéro**, la marge étant portée par
  /// `inputContentPadding` (elle vaut 16 dp par défaut ⇒ indentation identique
  /// à celle des voisins ; les cumuler donnerait 32 dp).
  EdgeInsetsDirectional _tilePadding(bool boxed) => boxed
      ? EdgeInsetsDirectional.zero
      : const EdgeInsetsDirectional.symmetric(horizontal: 16);

  /// Enveloppe [child] dans le **conteneur décoré du thème** (CR-DODLP-BOOL-BOXED).
  ///
  /// 🔴 La décoration n'est pas fabriquée ici : elle vient de la **fabrique
  /// centrale** [ZcrudTheme.inputDecoration] — la même que `zFieldDecoration`
  /// appelle pour `text`/`number`/`select`. Aucun `BoxDecoration` maison, aucun
  /// jeton nouveau : `fieldFillColor`, `fieldBorderColor`, `inputRadius` et
  /// `inputContentPadding` sont lus par la fabrique, pas par ce fichier.
  ///
  /// **Aucun libellé n'est passé** : le `ListTile` porte déjà le sien dans son
  /// `title` (cf. l'entête de bibliothèque). L'`InputDecorator` n'ajoute donc ni
  /// label, ni hint, ni erreur — il n'a **rien** à annoncer, et l'arbre
  /// sémantique du champ est inchangé (mesuré : le libellé y apparaît une seule
  /// fois, l'état `toggled` une seule fois).
  ///
  /// `enabled` n'est **pas** rabattu sur `field.readOnly` : `disabledBorder`
  /// n'appartient pas à la chaîne de jetons (`inputDecoration` ne le pose pas),
  /// donc un champ en lecture seule perdrait la bordure `fieldBorderColor` de
  /// l'hôte au profit d'un défaut Flutter. L'état désactivé reste porté par le
  /// contrôle lui-même (switch grisé / pilule atténuée), pas par le cadre.
  Widget _box(BuildContext context, Widget child) => InputDecorator(
        key: zBooleanBoxKey,
        decoration: ZcrudTheme.of(context).inputDecoration(context),
        child: child,
      );

  /// Construit le rendu **pilule** (parité legacy DODLP, peint nativement).
  Widget _buildPill(
    BuildContext context,
    ZBooleanConfig config,
    String resolvedLabel,
    bool checked,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = ZcrudTheme.of(context);
    final disabled = field.readOnly;

    // ── Couleurs : paramètre (clé sémantique) > jeton > rôle. ───────────────
    final pair = _trackPair(context, config, checked);
    final Color track = pair?.color ??
        (checked
            ? tokens.booleanPillActiveColor
            : tokens.booleanPillInactiveColor) ??
        (checked ? scheme.primary : scheme.outline);
    // Premier plan (texte + pouce) : `onColor` de la paire (venu du PARAMÈTRE,
    // donc prioritaire sur le jeton), puis jeton, puis contraste DÉRIVÉ — le
    // blanc littéral du legacy deviendrait illisible sur une piste claire.
    final Color foreground = pair?.onColor ??
        (checked
            ? tokens.booleanPillActiveForegroundColor
            : tokens.booleanPillInactiveForegroundColor) ??
        (ThemeData.estimateBrightnessForColor(track) == Brightness.dark
            ? scheme.surface
            : scheme.onSurface);

    // ── Mesures : jeton > référence legacy. ────────────────────────────────
    final double width = tokens.booleanPillWidth ?? _kPillWidth;
    final double height = tokens.booleanPillHeight ?? _kPillHeight;
    final double thumb = tokens.booleanPillThumbSize ?? _kPillThumbSize;
    final Radius radius =
        tokens.booleanPillRadius ?? const Radius.circular(_kPillRadius);
    // `labelMedium` vaut 12 sp en Material 3 : la mesure `valueFontSize: 12` du
    // legacy, obtenue SANS littéral de taille. La couleur est toujours celle du
    // premier plan résolu — un jeton de style ne peut pas casser le contraste.
    final TextStyle textStyle =
        (tokens.booleanPillTextStyle ?? theme.textTheme.labelMedium ?? const TextStyle())
            .copyWith(color: foreground);

    // Espace laissé au texte à côté du pouce (formule du legacy).
    final double textSpace = width - thumb;

    Widget pill = Container(
      key: zBooleanPillKey,
      width: width,
      height: height,
      padding: const EdgeInsets.all(_kPillPadding),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.all(radius),
      ),
      child: Stack(
        children: <Widget>[
          // Texte d'état À L'INTÉRIEUR, du côté OPPOSÉ au pouce (legacy).
          Align(
            alignment:
                checked ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: SizedBox(
              width: textSpace,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: _kPillTextPadding,
                ),
                child: Text(
                  _stateText(context, config, checked),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textAlign: checked ? TextAlign.start : TextAlign.end,
                  style: textStyle,
                ),
              ),
            ),
          ),
          // Pouce, du côté de l'état.
          Align(
            alignment:
                checked ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            child: Container(
              key: zBooleanPillThumbKey,
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
    if (disabled) {
      // Parité `FlutterSwitch(disabled:)`. Un composant DÉSACTIVÉ est hors du
      // champ de WCAG 1.4.3 (exception « inactive ») : l'atténuation ne crée
      // donc pas de défaut de contraste, et l'état reste lisible en TEXTE.
      pill = Opacity(opacity: _kPillDisabledOpacity, child: pill);
    }

    // Cible tactile : la PILULE, plancher 48 dp par contrainte LIANTE (la
    // pilule peinte ne fait que 30 dp — une garde sur `getSize()` serait
    // vacante).
    final Widget target = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: disabled ? null : () => onChanged(!checked),
      child: ConstrainedBox(
        key: zBooleanPillTargetKey,
        constraints: const BoxConstraints(
          minWidth: _kPillMinTarget,
          minHeight: _kPillMinTarget,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: pill),
      ),
    );

    // 🔴 MÊME FORME que `SwitchListTile` : `MergeSemantics(ListTile(…, trailing:
    // <porteur d'état>))`. Le porteur n'est plus un `Switch` mais un
    // `Semantics(toggled:)` posé sur la cible, avec `excludeSemantics` — le
    // contenu peint (texte d'état, pouce) est DÉCORATIF, exactement comme en
    // v0.74 : sans cette exclusion l'état serait annoncé DEUX fois.
    //
    // Mesuré : envelopper le `ListTile` dans un `Semantics` supplémentaire
    // produit DEUX nœuds portant le libellé du champ (donc un titre annoncé en
    // double) ; poser l'état sur le trailing en produit UN — le compte exact du
    // rendu `switchTile`.
    return MergeSemantics(
      child: ListTile(
        title: Text(resolvedLabel),
        trailing: Semantics(
          toggled: checked,
          enabled: !disabled,
          excludeSemantics: true,
          child: target,
        ),
        onTap: disabled ? null : () => onChanged(!checked),
        contentPadding: _tilePadding(_boxedOf(config)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);
    final checked = value == true;
    final config = _config;

    // CR-DODLP-BOOL-BOXED : l'encart est un pur DÉCOR posé autour du rendu — il
    // n'altère ni la forme, ni la sémantique, ni le geste. Défaut `false` ⇒ les
    // deux chemins ci-dessous sont littéralement ceux de v0.75.
    final boxed = _boxedOf(config);

    // CR-DODLP-BOOL-PILL : la forme d'affichage s'active par la MÊME config que
    // le texte d'état (v0.74). Défaut `switchTile` ⇒ chemin ci-dessous, intact.
    if (config.style == ZBooleanStyle.pill) {
      final pill = _buildPill(context, config, resolvedLabel, checked);
      return boxed ? _box(context, pill) : pill;
    }

    final tile = SwitchListTile(
      value: checked,
      onChanged: field.readOnly ? null : onChanged,
      title: config.showsStateLabel
          // Le texte d'état termine la ligne de titre ⇒ accolé au `Switch`
          // (trailing). `Row`/`EdgeInsetsDirectional` suivent la
          // `Directionality` : en RTL le texte reste du côté du switch (AD-13).
          ? Row(
              children: <Widget>[
                Expanded(child: Text(resolvedLabel)),
                // DÉCORATIF : l'état est déjà annoncé par le `Switch` fusionné.
                // Sans cette exclusion, le lecteur d'écran l'entendrait 2 fois.
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                    child: Text(_stateText(context, config, checked)),
                  ),
                ),
              ],
            )
          : Text(resolvedLabel),
      // `ListTile` fournit une cible ≥ 48 dp et fusionne le libellé du titre
      // avec l'état `switch` du contrôle (Semantics natif).
      contentPadding: _tilePadding(boxed),
    );
    return boxed ? _box(context, tile) : tile;
  }
}

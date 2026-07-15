/// `ZTagChips` — affichage d'une rangée de tags de flashcard sous forme de puces
/// (Story ES-8.1, AC1/AC4/AC6). ADAPTATEUR MINCE de PRÉSENTATION : il COMPOSE des
/// primitives de domaine DÉJÀ LIVRÉES (`ZFlashcardTag`, `remapColorKey`/
/// `ZColorPalette` du kernel ; `zResolveColorKeyOrSlot`/`ZColorPair`/`ZcrudTheme`
/// du cœur) — il n'en réimplémente AUCUNE.
///
/// Invariants (NON-NÉGOCIABLES) :
/// - **AD-1** : AUCUNE nouvelle arête. Tous les symboles proviennent de
///   `zcrud_study_kernel` et `zcrud_core`, DÉJÀ en dépendance de `zcrud_study`.
/// - **AD-4** : `tag.id`/`tag.title` restent opaques ; `onTagTap`/`onTagRemoved`
///   `null` = capacité ABSENTE (jamais un no-op).
/// - **AD-13/FR-26 (AC6)** : le **titre textuel** du tag est TOUJOURS rendu à côté
///   de la pastille de couleur (**couleur jamais seul canal** — WCAG/NFR-S6) ;
///   cibles interactives ≥ 48 dp ; libellés sémantiques INJECTÉS ; chrome
///   directionnel (`EdgeInsetsDirectional`, `TextAlign.start`) ; couleurs/gaps
///   issus de `zResolveColorKeyOrSlot`/`ZcrudTheme.of` (repli `Theme.of`) — AUCUNE
///   couleur ni valeur d'espacement de couleur codée en dur.
/// - **AD-19 (AC4)** : `ZFlashcardTag` n'a AUCUN champ `usageCount` — le compteur
///   d'usages est **DÉRIVÉ au rendu** via [referencingCardsCountOf] (nb de cartes
///   référençantes recalculé), jamais un champ figé.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Diamètre de la pastille de couleur (dimension de LAYOUT admissible — jamais une
/// couleur codée en dur). Le titre textuel reste le canal d'identification (AC6).
const double _kPastilleSize = 12.0;

/// Signature d'un fournisseur de compteur d'usages **DÉRIVÉ** (AC4/AD-19) : le
/// nombre de cartes référençant [tag], recalculé À CHAQUE rendu (jamais un champ
/// stocké sur l'entité).
typedef ZTagUsageCount = int Function(ZFlashcardTag tag);

/// Signature d'un libellé sémantique INJECTÉ dérivé d'un tag (i18n — AC6).
typedef ZTagSemanticLabel = String Function(ZFlashcardTag tag);

/// Rangée de puces de tags (affichage seul — `StatelessWidget`).
///
/// La couleur de fond de chaque puce **FILE la palette INJECTÉE** à travers
/// `remapColorKey` puis le résolveur du cœur (`zResolveColorKeyOrSlot`) — jamais
/// une couleur codée en dur ni la palette ignorée (AC1). Le compteur d'usages est
/// DÉRIVÉ au rendu (AC4).
class ZTagChips extends StatelessWidget {
  /// Construit la rangée de puces. [palette] est INJECTÉE (défaut recommandé
  /// documenté [ZColorPalette.defaultStudy], jamais verrouillée). Tous les
  /// libellés sémantiques sont INJECTÉS (replis neutres documentés — AD-13/FR-26).
  const ZTagChips({
    required this.tags,
    this.palette = const ZColorPalette.defaultStudy(),
    this.referencingCardsCountOf = _zeroCount,
    this.onTagTap,
    this.onTagRemoved,
    this.showUsageCount = false,
    this.tagSemanticLabel = _defaultTagSemanticLabel,
    this.removeTagSemanticLabel = _defaultRemoveSemanticLabel,
    this.removeIcon = Icons.close,
    super.key,
  });

  /// Tags à afficher (ordre préservé). Immuables (`ZFlashcardTag`).
  final List<ZFlashcardTag> tags;

  /// Palette **INJECTÉE** bornant la `colorKey` affichable (AC1). Filée jusqu'à la
  /// couleur du chip via `remapColorKey` → `zResolveColorKeyOrSlot`.
  final ZColorPalette palette;

  /// Compteur d'usages **DÉRIVÉ** (AC4/AD-19) — nb de cartes référençant le tag,
  /// recalculé au rendu. JAMAIS un champ stocké.
  final ZTagUsageCount referencingCardsCountOf;

  /// Tap sur une puce (`null` = capacité ABSENTE — AD-4).
  final void Function(ZFlashcardTag tag)? onTagTap;

  /// Retrait d'une puce (`null` = puce NON supprimable — AD-4). Rend un bouton de
  /// suppression ≥ 48 dp au libellé sémantique INJECTÉ.
  final void Function(ZFlashcardTag tag)? onTagRemoved;

  /// Affiche le compteur d'usages DÉRIVÉ à côté du titre (AC4).
  final bool showUsageCount;

  /// Libellé sémantique INJECTÉ de la puce (défaut : le titre du tag).
  final ZTagSemanticLabel tagSemanticLabel;

  /// Libellé sémantique INJECTÉ du bouton de suppression (défaut documenté).
  final ZTagSemanticLabel removeTagSemanticLabel;

  /// Icône INJECTÉE du bouton de suppression (repli neutre documenté).
  final IconData removeIcon;

  static int _zeroCount(ZFlashcardTag tag) => 0;

  static String _defaultTagSemanticLabel(ZFlashcardTag tag) => tag.title;

  static String _defaultRemoveSemanticLabel(ZFlashcardTag tag) =>
      'Supprimer le tag ${tag.title}';

  /// Clé NEUTRE de la puce (id opaque si présent, sinon titre) — jamais l'entité.
  static String _keyId(ZFlashcardTag tag) => tag.id ?? tag.title;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // `Wrap` (jamais `ListView(children:[...])` nu — Key Don'ts) : rangée fluide de
    // puces, une frontière de widget par tag (clé neutre).
    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapS,
      children: <Widget>[
        for (final tag in tags) _buildChip(context, theme, tag),
      ],
    );
  }

  Widget _buildChip(BuildContext context, ZcrudTheme theme, ZFlashcardTag tag) {
    // AC1 — FIL palette→chip PROPRE à ZTagChips : la palette INJECTÉE (widget.
    // palette) est filée à travers `remapColorKey` (kernel) puis le résolveur du
    // cœur. Ignorer `palette` / coder une clé en dur ⇒ RC=1 (R3-I1).
    final remappedKey = remapColorKey(
      palette: palette,
      rawColorKey: tag.colorKey,
      seedTitle: tag.title,
    );
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      remappedKey,
      slotIndex: palette.indexOf(remappedKey),
    );

    final chip = DecoratedBox(
      // Clé de FOND — point d'ancrage de l'assertion AC1 (couleur du chip filée).
      key: ValueKey<String>('z-tag-chip-bg:${_keyId(tag)}'),
      decoration: BoxDecoration(
        color: pair.color,
        borderRadius: BorderRadius.all(theme.radiusM),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: theme.gapM,
          end: onTagRemoved != null ? theme.gapS : theme.gapM,
          top: theme.gapS,
          bottom: theme.gapS,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Pastille de couleur (canal COMPLÉMENTAIRE, jamais unique — AC6).
            SizedBox(
              width: _kPastilleSize,
              height: _kPastilleSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pair.onColor,
                ),
              ),
            ),
            SizedBox(width: theme.gapS),
            // AC6 — TITRE TEXTUEL TOUJOURS rendu (couleur jamais seul canal).
            Text(
              tag.title,
              textAlign: TextAlign.start,
              style: TextStyle(color: pair.onColor),
            ),
            if (showUsageCount) ...<Widget>[
              SizedBox(width: theme.gapS),
              // AC4 — compteur DÉRIVÉ au rendu (jamais un champ figé).
              Text(
                '${referencingCardsCountOf(tag)}',
                key: ValueKey<String>('z-tag-usage:${_keyId(tag)}'),
                textAlign: TextAlign.start,
                style: TextStyle(color: pair.onColor),
              ),
            ],
            if (onTagRemoved != null) _buildRemoveButton(theme, tag, pair),
          ],
        ),
      ),
    );

    // Puce entière tappable ⇒ cible ≥ 48 dp (AC6).
    if (onTagTap != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: Semantics(
          button: true,
          label: tagSemanticLabel(tag),
          child: InkWell(
            onTap: () => onTagTap!(tag),
            borderRadius: BorderRadius.all(theme.radiusM),
            child: chip,
          ),
        ),
      );
    }
    return Semantics(label: tagSemanticLabel(tag), child: chip);
  }

  /// Bouton de suppression : cible ≥ 48 dp, libellé sémantique INJECTÉ (= tooltip),
  /// icône INJECTÉE, couleur dérivée de la paire résolue (AC6).
  Widget _buildRemoveButton(
    ZcrudTheme theme,
    ZFlashcardTag tag,
    ZColorPair pair,
  ) {
    final label = removeTagSemanticLabel(tag);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: IconButton(
        onPressed: () => onTagRemoved!(tag),
        tooltip: label,
        padding: EdgeInsetsDirectional.zero,
        icon: Icon(removeIcon, color: pair.onColor, semanticLabel: label),
      ),
    );
  }
}

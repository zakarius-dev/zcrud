/// `ZDefaultFlashcardCard` — **carte de flashcard PAR DÉFAUT** du socle
/// (CR-IFFD-47).
///
/// ## Le besoin, et la forme qu'il ne pouvait PAS prendre
///
/// `ZStudyToolsSectionSpec.itemBuilder` est **requis** : chaque application
/// d'étude réécrit donc la même carte de flashcard. Le besoin est réel.
///
/// 🔴 La forme demandée — « rendre `itemBuilder` facultatif, avec un rendu par
/// défaut » — **ne peut pas fonctionner**, et c'est vérifiable sur la data-class
/// elle-même : `ZStudyToolsSectionSpec` porte `itemCount` + `itemBuilder(context,
/// index)` et **AUCUNE donnée**. Sans `itemBuilder`, le socle ne sait pas ce
/// qu'est l'item numéro *i* : il ne pourrait rendre **rien du tout**. Le défaut
/// n'est pas un manque de volonté, c'est une **absence d'information**.
///
/// Deux livrables remplacent donc cette forme, et suppriment réellement le
/// travail répété :
/// 1. **ce widget** — autonome, instanciable dans l'`itemBuilder` de l'hôte ;
/// 2. **`ZStudyToolsSectionSpec.flashcards(cards: …)`** — la voie TYPÉE qui
///    porte les données, et fabrique elle-même `itemCount` **et** un
///    `itemBuilder` bâti sur ce widget.
///
/// ✅ **`itemBuilder` reste `required` dans le constructeur principal** : aucun
/// hôte existant n'est touché, et aucun ne peut l'être (garde de source
/// CR-IFFD-47).
///
/// ## Ce que cette carte NE prend PAS — et pourquoi
///
/// La carte de référence de l'hôte prend **quatorze** entrées, dont quatre types
/// de **son** domaine (matière, dossier, permissions, routeur IA). Rien de tout
/// cela n'est nécessaire au **dessin** : ce que le dessin lit est déjà dans
/// [ZFlashcard] — `type`, `question`, `tagIds`, `id`. Le reste sert aux
/// **actions**, qui restent à l'hôte par créneaux ([onTap], [onLongPress],
/// [trailing]).
///
/// 🔴 **Test de frontière** : si cette carte exigeait un jour un type que seule
/// une application possède, la frontière serait mal placée — pas la carte.
///
/// ## Composition (ZÉRO carte réécrite)
///
/// Elle **compose** des primitives déjà livrées, elle n'en réimplémente aucune :
/// - [ZStudyToolsItemCard] — structure, `InkWell`, cible ≥ 48 dp, `Semantics`,
///   ombre/forme/marge issues du thème, slots `aboveTitle`/`badge`/
///   `belowSubtitle`/`trailing`/`accent` ;
/// - [ZTagChips] — zone de balises (pastille + **titre textuel**, palette filée,
///   cibles ≥ 48 dp) ;
/// - `remapColorKey` (kernel) + `zResolveColorKeyOrSlot` (cœur) — accent dérivé
///   d'une clé **stable**, jamais une table de couleurs locale, jamais un hex.
///
/// ## Invariants
///
/// - **FR-26/NFR-S7** : aucune couleur ni libellé en dur. « QCM », « Vrai/Faux »
///   sont des libellés **visibles** ⇒ ils arrivent par [typeLabels] (repli sur
///   la clé opaque `type.name`, patron `ZFlashcardListView.typeLabels`).
/// - **AD-13** : l'information portée par la couleur est **aussi** en texte (la
///   pastille d'en-tête est décorative et muette ; le **pied redit le type en
///   toutes lettres**) ; insets/alignements directionnels ; `Semantics`.
/// - **AD-4** : tout créneau non fourni est **absent de l'arbre** — jamais un
///   `SizedBox.shrink()` inerte.
/// - **AD-1** : aucune nouvelle arête (`zcrud_study → zcrud_flashcard` et
///   `→ zcrud_study_kernel` existent déjà).
/// - **AD-2/SM-1** : `StatelessWidget` pur, aucun état, aucun controller.
///
/// ℹ️ **Aucune enveloppe colorée sous du contenu d'HÔTE** : la seule surface
/// teintée de cette carte (barre d'accent, pastille, puce de pied) ne porte que
/// du texte **rendu par le socle**, à qui la couleur de premier plan est
/// appliquée directement. `ZForegroundOverride` n'a donc pas lieu d'être ici —
/// et la garde de source du cœur (qui interdit un `DefaultTextStyle.merge`/
/// `IconTheme.merge` **coloré** hors de cette primitive) n'est pas déclenchée :
/// aucun `merge` n'est écrit dans ce fichier.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

import 'z_study_tools_item_card.dart';
import 'z_tag_chips.dart';

/// Épaisseur de la barre d'accent de tête (dimension de LAYOUT — jamais une
/// couleur). Publique pour rester ajustable sans coder de valeur en dur.
const double kZDefaultFlashcardAccentHeight = 4;

/// Diamètre de la pastille de type d'en-tête (dimension de LAYOUT).
const double kZDefaultFlashcardTypeDotSize = 12;

/// Cible tactile minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Carte de flashcard **par défaut** du socle — autonome, sur le modèle
/// [ZFlashcard] (CR-IFFD-47).
///
/// ```dart
/// ZDefaultFlashcardCard(
///   card: card,
///   typeLabels: {'multipleChoice': l10n.qcm, 'trueFalse': l10n.trueFalse},
///   tags: tagsOf(card),                 // résolus par l'hôte (ids → entités)
///   emptyTagsLabel: l10n.addTags,       // zone de balises = appel à l'action
///   onTagsTap: () => openTagEditor(card),
///   trailing: myCardMenu,               // le socle ignore ce qu'il contient
///   onTap: () => open(card),
///   onLongPress: () => showActions(card),
/// )
/// ```
class ZDefaultFlashcardCard extends StatelessWidget {
  /// Construit la carte ; seule [card] est requise.
  const ZDefaultFlashcardCard({
    required this.card,
    this.typeLabels,
    this.tags = const <ZFlashcardTag>[],
    this.emptyTagsLabel,
    this.onTagsTap,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.questionMaxLines = 3,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  }) : assert(
          questionMaxLines > 0,
          'questionMaxLines doit être ≥ 1 (l\'énoncé est le contenu principal '
          'de la carte : le tronquer à zéro ligne la viderait).',
        );

  /// Carte rendue — **seule** entrée requise. Le dessin ne lit que `type`,
  /// `question`, `tagIds` et `id` (cf. dartdoc de bibliothèque).
  final ZFlashcard card;

  /// Résolution `type.name → libellé LOCALISÉ` (FR-26/AD-13).
  ///
  /// `null` ou clé absente ⇒ **repli sur la clé opaque** (`'openQuestion'`) —
  /// patron EXACT de `ZFlashcardListView.typeLabels`. Le socle ne traduit
  /// **jamais** en dur : « QCM » est un libellé visible, donc de la
  /// localisation, donc la propriété de l'hôte.
  final Map<String, String>? typeLabels;

  /// Balises **résolues par l'hôte** (`tagIds` → entités). `ZFlashcard` ne porte
  /// que des **ids** : le socle ne peut pas les résoudre lui-même sans un store,
  /// ce qu'AD-2 lui interdit.
  ///
  /// Vide ⇒ la zone devient un **appel à l'action** si [emptyTagsLabel] est
  /// fourni, sinon elle est **absente** de l'arbre (AD-4).
  final List<ZFlashcardTag> tags;

  /// Libellé LOCALISÉ **INJECTÉ** de la zone de balises **vide** (appel à
  /// l'action). `null` ⇒ zone **absente** quand [tags] est vide (AD-4) —
  /// jamais un texte en dur, jamais un espace réservé muet.
  final String? emptyTagsLabel;

  /// Activation de la zone de balises **vide** (ex. ouvrir l'éditeur de tags).
  ///
  /// `null` ⇒ l'appel à l'action reste **affiché** mais n'est pas un bouton
  /// (AD-45 : pas de bouton inerte). Sans effet si [emptyTagsLabel] est `null`.
  final VoidCallback? onTagsTap;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron [ZTagChips]).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ l'accent est
  /// dérivé du **type** de la carte (`card.type.name`) — donc **stable** :
  /// deux cartes du même type portent le même accent, sur toutes les
  /// plateformes et tous les lancements (remap FNV-1a déterministe du kernel).
  final String? colorKey;

  /// Nombre maximal de lignes de l'énoncé (2-3 en pratique). Défaut `3`.
  final int questionMaxLines;

  /// Créneau d'actions de fin de carte (menu contextuel de l'hôte, avec ses
  /// propres règles de droits — que le socle ignore). `null` ⇒ absent (AD-4).
  final Widget? trailing;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ carte non
  /// interactive (AD-45 — aucun `InkWell` inerte).
  final VoidCallback? onTap;

  /// Appui long (menu contextuel). `null` ⇒ capacité **ABSENTE** (AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : l'énoncé.
  final String? semanticLabel;

  /// Libellé de type **affiché** : injecté, repli sur la clé opaque.
  String get _typeLabel => typeLabels?[card.type.name] ?? card.type.name;

  /// Paire fond/premier plan de l'accent — **dérivée** d'une clé stable, via le
  /// remap du kernel puis le résolveur TOTAL du cœur (jamais `null`, jamais de
  /// throw — AD-10). Aucune table de couleurs locale (leçon `ZFolderCard` D2).
  ZColorPair _accent(BuildContext context) {
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      seedTitle: card.type.name,
    );
    return zResolveColorKeyOrSlot(
      context,
      key,
      slotIndex: palette.indexOf(key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZColorPair pair = _accent(context);
    final Widget? tagsZone = _buildTagsZone(context, theme);

    return ZStudyToolsItemCard(
      // ① Accent de tête, dérivé de la clé d'identité (décor : ni geste, ni
      // sémantique — c'est `ZStudyToolsItemCard` qui l'isole).
      accent: SizedBox(
        key: accentKey,
        height: kZDefaultFlashcardAccentHeight,
        child: ColoredBox(color: pair.color),
      ),
      // ② badge de type (pastille) + ③ zone de balises, AU-DESSUS de l'énoncé :
      // c'est l'ordre de lecture de la forme de référence.
      aboveTitle: tagsZone == null
          ? _buildTypeDot(pair)
          : Row(
              children: <Widget>[
                _buildTypeDot(pair),
                SizedBox(width: theme.gapS),
                Expanded(child: tagsZone),
              ],
            ),
      // ④ énoncé, tronqué proprement sur 2-3 lignes.
      title: card.question,
      titleMaxLines: questionMaxLines,
      // ⑤ pied : le type redit **en TEXTE** (AD-13 — la couleur n'est jamais le
      // seul canal ; la pastille ② est muette et purement décorative).
      belowSubtitle: _buildTypeChip(context, theme, pair),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? card.question,
    );
  }

  /// ② Pastille de type — **décorative et MUETTE** : l'information qu'elle
  /// porte est redite en toutes lettres par la puce de pied (AD-13). L'annoncer
  /// ici aussi la ferait entendre deux fois.
  Widget _buildTypeDot(ZColorPair pair) => ExcludeSemantics(
        child: SizedBox(
          key: typeDotKey,
          width: kZDefaultFlashcardTypeDotSize,
          height: kZDefaultFlashcardTypeDotSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pair.color,
            ),
          ),
        ),
      );

  /// ③ Zone de balises — **affichée même vide**, sous forme d'appel à l'action.
  ///
  /// `null` ⇒ zone **absente** de l'arbre (AD-4) : c'est le cas « aucune balise
  /// ET aucun libellé d'appel à l'action injecté ».
  Widget? _buildTagsZone(BuildContext context, ZcrudTheme theme) {
    if (tags.isNotEmpty) {
      // Aucune rangée de puces réécrite : `ZTagChips` porte déjà la palette
      // filée, le titre textuel systématique (AD-13) et les cibles ≥ 48 dp.
      return ZTagChips(key: tagsKey, tags: tags, palette: palette);
    }
    final String? label = emptyTagsLabel;
    if (label == null) return null;

    final Widget text = Text(
      label,
      key: emptyTagsKey,
      textAlign: TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall,
    );
    final VoidCallback? tap = onTagsTap;
    if (tap == null) {
      // AD-45 — pas de bouton inerte : sans action, c'est une simple invite.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        // 🔴 `heightFactor: 1` — MESURÉ, pas supposé : un `Align` sans facteur
        // **remplit** la hauteur disponible. Sous une colonne à hauteur non
        // bornée (rail, cellule libre), la carte passait ainsi de ~140 dp à
        // **854 dp** — un vide de ~400 dp entre les balises et la puce de pied.
        heightFactor: 1,
        child: text,
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.all(theme.radiusM),
            // La sémantique est portée UNE seule fois — par le nœud ci-dessus.
            excludeFromSemantics: true,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapS),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⑤ Puce de pied : le type **en texte**, sur le fond d'accent, avec le
  /// premier plan APPARIÉ (contraste garanti par Material 3 — `ZColorPair`).
  Widget _buildTypeChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        // 🔴 `heightFactor: 1` — cf. la zone de balises : sans lui, l'`Align`
        // remplit la hauteur disponible et gonfle la carte (mesuré).
        heightFactor: 1,
        child: DecoratedBox(
          key: typeChipKey,
          decoration: BoxDecoration(
            color: pair.color,
            borderRadius: BorderRadius.all(theme.radiusM),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.gapM,
              vertical: theme.gapS,
            ),
            child: Text(
              _typeLabel,
              key: typeLabelKey,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 🔴 Taille depuis le thème (jamais un `fontSize:` littéral :
              // a11y/`textScaler`) ; couleur = premier plan APPARIÉ au fond
              // réellement peint (jamais une couleur de fond en premier plan).
              style: (Theme.of(context).textTheme.labelSmall ??
                      const TextStyle())
                  .copyWith(color: pair.onColor),
            ),
          ),
        ),
      );

  /// Clé de la barre d'accent (testabilité).
  static const ValueKey<String> accentKey =
      ValueKey<String>('zDefaultFlashcardCard_accent');

  /// Clé de la pastille de type d'en-tête (testabilité).
  static const ValueKey<String> typeDotKey =
      ValueKey<String>('zDefaultFlashcardCard_typeDot');

  /// Clé de la puce de type de pied (testabilité).
  static const ValueKey<String> typeChipKey =
      ValueKey<String>('zDefaultFlashcardCard_typeChip');

  /// Clé du **texte** de type de pied (testabilité — AD-13).
  static const ValueKey<String> typeLabelKey =
      ValueKey<String>('zDefaultFlashcardCard_typeLabel');

  /// Clé de la zone de balises renseignée (testabilité).
  static const ValueKey<String> tagsKey =
      ValueKey<String>('zDefaultFlashcardCard_tags');

  /// Clé de l'appel à l'action « aucune balise » (testabilité).
  static const ValueKey<String> emptyTagsKey =
      ValueKey<String>('zDefaultFlashcardCard_emptyTags');
}

/// La **feuille de réglages par défaut** — `ZChatSettingsSheet` (lot γ0/δ du
/// chantier Notebook/Chat, suite de l'étude CR-IFFD-72).
///
/// ## 🔴 Le manque mesuré était le PORTEUR, puis la SURFACE — jamais les enums
///
/// L'étude (§ 3, § 4.3) a établi que les réglages du chat existent « **en
/// donnée mais sans aucune surface** » : `ZChatResponseLength`,
/// `ZChatLengthBias`, `ZChatComputeEffort` et les étapes de raisonnement sont
/// modélisés depuis CHAT-0/CHAT-1, le porteur et la portée depuis le lot β. Il
/// ne manquait que de quoi les **régler**.
///
/// ⇒ Ce fichier ne déclare **aucun** enum, aucun palier, aucun équivalent : il
/// rend ceux du kernel. C'est le risque n°1 nommé par CR-IFFD-72 —
/// « reconstruire la moitié de `zcrud_chat_kernel` » — et une garde de source
/// l'atteste (`z_chat_settings_guard_test.dart`, groupe ANTI-RÉINVENTION).
///
/// ## 🔴 Le catalogue de corpus est une donnée d'HÔTE
///
/// Le socle ne porte **aucune** valeur métier : ni code douanier, ni libellé de
/// corpus, ni famille nommée. C'est ce qui a fait écarter, au lot β, les
/// booléens `enableCodesDouanes`/`enableTec`/`enableValuation` de lex — ils
/// imposeraient la douane à IFFD et à DODLP. L'hôte fournit ses
/// [ZChatCorpusOption] (clé stable + libellé **déjà traduit par lui**) ; le
/// socle rend le mécanisme, confronte les clés à `ZChatCorpusScope` et rien de
/// plus. Une garde de source vérifie qu'aucun terme métier n'entre ici.
///
/// ## Composabilité — un builder par tuile, et l'AD-4 préservée
///
/// Chaque tuile a son builder **nullable**, et la règle est unique :
///
/// | Builder | Effet |
/// |---|---|
/// | absent (`null`) | la tuile est rendue par le **défaut du socle** |
/// | fourni, rend un widget | ce widget **remplace** la tuile |
/// | fourni, rend `null` | la tuile est **ABSENTE de l'arbre** (AD-4) |
///
/// Un seul bouton pour trois besoins — personnaliser, remplacer, retirer — au
/// lieu d'un drapeau `showX` par tuile, qui aurait fait grossir la signature à
/// chaque réglage ajouté. Même arbitrage que les créneaux de `ZChatComposer`.
///
/// ## 🔴 Priorité **paramètre > jeton > référence** (FR-26)
///
/// Les deux seules valeurs de rendu que cette feuille pose — sa marge et son
/// interligne — se résolvent dans cet ordre, et les **trois** niveaux sont
/// atteignables (mesuré : `SET-T1`/`SET-T2`/`SET-T3`) :
///
/// 1. le **paramètre** ([padding], [spacing]) ;
/// 2. le **jeton** injecté par l'hôte — `ZcrudScope.theme` ;
/// 3. la **référence** du socle — [kZChatSettingsReferencePadding],
///    [kZChatSettingsReferenceGap].
///
/// ⚠️ Le niveau 2 lit `ZcrudScope.maybeOf(context)?.theme` et **non**
/// `ZcrudTheme.of(context)`, contrairement au reste du paquet. Ce n'est pas une
/// inattention : `ZcrudTheme.of` **ne rend jamais `null`** (il retombe sur
/// `ZcrudTheme.fallback(Theme.of(context))`, c'est-à-dire sur une échelle
/// dérivée de *Material*). Le lire ici rendrait le niveau 3 **inatteignable** —
/// une « référence » que rien ne peut atteindre est une garde vacante déguisée
/// en gouvernance. Aucune couleur n'est concernée : ces deux constantes sont des
/// espacements, pas une exception FR-26.
///
/// ## AD-13
///
/// Chaque option est un `Semantics(button: true, selected: …)` dans une boîte de
/// [kZChatMinTapTarget] mesurée **en géométrie rendue** ; tout est directionnel
/// (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`) ; l'état
/// choisi est porté par le **drapeau sémantique `selected`**, jamais par la
/// seule couleur — c'est l'un des 18 défauts structurants que l'étude a relevés
/// dans le legacy (§ 2.3, « information portée par la seule couleur »).
///
/// ## 🔴 AD-13, son SYMÉTRIQUE — et pourquoi il manquait (CR-IFFD-74)
///
/// AD-13 énonce qu'une information ne doit **jamais** être portée par la seule
/// **couleur**. Son symétrique n'était écrit nulle part, et son absence a coûté
/// exactement un défaut :
///
/// > 🔴 **Un état doit être perceptible par au moins un canal VISIBLE** — le
/// > drapeau sémantique n'en est pas un.
///
/// Mesuré sur appareil le 2026-08-07 : on touchait une option, **rien ne
/// changeait à l'écran** (deux captures identiques au pixel). La correction
/// d'origine — porter l'état dans l'arbre sémantique — était juste, et elle est
/// **conservée intacte** ; le tort était de l'avoir substituée au canal visible
/// au lieu de l'ajouter à côté. On était passé de « un seul canal, visuel » à
/// « un seul canal, sémantique ».
///
/// ⇒ Les deux canaux coexistent désormais, et **aucun ne remplace l'autre** :
///
/// | Canal | Porteur | Public |
/// |---|---|---|
/// | sémantique | `Semantics(selected:)` | lecteur d'écran |
/// | **graisse** | [kZChatSettingsReferenceSelectedWeight] | vue |
/// | **soulignement** | [kZChatSettingsReferenceSelectedDecoration] | vue |
///
/// ### Pourquoi ni couleur, ni forme, mais graisse + soulignement
///
/// * **Aucune couleur** — mesuré : sur un `ZcrudTheme` sans réglage d'hôte,
///   **tous** les jetons de couleur sont `null` (`labelColor`, `surfaceColor`,
///   `fieldBorderColor`, `chatToolAccentColor`…). Un canal de couleur serait
///   donc *absent par défaut*, c'est-à-dire le défaut même que CR-IFFD-74
///   corrige, et le socle n'a pas le droit d'en inventer une (FR-26). Peindre
///   « en primaire » supposerait de plus un `ColorScheme`, que ce package
///   n'importe pas (AD-57 : `material` est banni de `lib/`).
/// * **Deux canaux, pas un** — mesuré : une graisse *seule* s'ANNULE sous un
///   `DefaultTextStyle` ambiant déjà gras (l'option choisie et les autres
///   redeviennent identiques). Le soulignement survit à ce cas ; et le cas
///   symétrique (ambiant déjà souligné) est fermé par la règle de non-annulation
///   ci-dessous.
/// * **Invariant de luminosité** — graisse et soulignement ne dépendent d'aucune
///   couleur : ils rendent la **même** différence en clair et en sombre
///   (mesuré), là où un canal coloré doit être re-décidé par thème.
///
/// ### 🔴 Le canal ne peut pas s'ANNULER (AD-10)
///
/// Si le style hérité porte **déjà** la graisse ET le soulignement d'emphase, la
/// paire s'effondrerait — une option choisie redeviendrait indiscernable. Dans
/// ce seul cas, le socle **retire** le soulignement des options NON choisies :
/// la différence est alors garantie, sans jamais dépendre de ce que l'hôte a
/// posé au-dessus. Hors de ce cas, le rendu des options non choisies est
/// **strictement inchangé**.
///
/// ### Remplaçabilité (FR-26)
///
/// Les deux canaux se règlent par **paramètre** ([selectedWeight],
/// [selectedDecoration]) et retombent sinon sur la **référence** du socle.
/// ⚠️ Le niveau **jeton** n'existe pas encore : `ZcrudTheme` ne porte aucune
/// graisse ni décoration d'emphase de sélection, et `zcrud_core` est hors du
/// périmètre de cette CR. Deux jetons **nullables** sont demandés —
/// `chatSelectedEmphasisWeight` (`FontWeight?`) et
/// `chatSelectedEmphasisDecoration` (`TextDecoration?`), tous deux `null` par
/// défaut. Ils s'inséreront **entre** le paramètre et la référence, lus sur
/// `ZcrudScope.maybeOf(context)?.theme` — jamais sur `ZcrudTheme.of`, pour la
/// raison écrite plus haut. `floatingLabelWeight` n'a **pas** été détourné pour
/// tenir ce rôle : c'est le jeton du *label flottant d'un formulaire*, et un
/// hôte qui le règle ne demande pas de changer l'emphase d'un choix de chat.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../settings/z_chat_settings_controller.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Marge **de référence** de la feuille — dernier ressort, quand l'hôte n'a ni
/// passé de paramètre ni injecté de `ZcrudScope.theme`.
const EdgeInsetsDirectional kZChatSettingsReferencePadding =
    EdgeInsetsDirectional.all(12);

/// Interligne **de référence** de la feuille — même régime que
/// [kZChatSettingsReferencePadding].
const double kZChatSettingsReferenceGap = 8;

/// Graisse **de référence** de l'option CHOISIE — le premier des deux canaux
/// visibles exigés par CR-IFFD-74.
///
/// 🔴 Une graisse, pas une couleur : le socle n'a le droit d'en inventer aucune
/// (FR-26), et tous les jetons de couleur d'un `ZcrudTheme` non réglé sont
/// `null` — un canal coloré serait donc *absent par défaut*, c'est-à-dire le
/// défaut même que cette CR corrige.
const FontWeight kZChatSettingsReferenceSelectedWeight = FontWeight.w700;

/// Soulignement **de référence** de l'option CHOISIE — le second canal visible.
///
/// 🔴 Il existe parce qu'une graisse SEULE s'annule sous un `DefaultTextStyle`
/// ambiant déjà gras (mesuré). Deux canaux indépendants, aucun coloré : la
/// différence survit au style de l'hôte **et** aux deux luminosités.
const TextDecoration kZChatSettingsReferenceSelectedDecoration =
    TextDecoration.underline;

/// Une entrée du **catalogue de corpus de l'hôte**.
///
/// 🔴 [key] est la **clé stable** confrontée à `ZChatCorpusScope` (et, en bout
/// de chaîne, à `ZChatSource.corpusKey`) ; [label] est le texte **déjà résolu
/// par l'hôte**, dans sa langue. Le socle ne traduit pas un corpus : il n'en
/// connaît aucun.
@immutable
class ZChatCorpusOption {
  /// Construit une entrée de catalogue.
  const ZChatCorpusOption({required this.key, required this.label});

  /// Clé **stable et opaque**, jamais un libellé. C'est la distinction que
  /// l'étude a établie (§ 4.2) et sans laquelle une restriction ne serait pas
  /// vérifiable : `ZChatSource.corpus` est traduisible, `corpusKey` ne l'est
  /// pas.
  final String key;

  /// Libellé affiché, **fourni et localisé par l'hôte**.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCorpusOption && key == other.key && label == other.label;

  @override
  int get hashCode => Object.hash(key, label);
}

/// Ce que le socle offre au builder d'une tuile de réglage.
///
/// 🔴 **Un objet, pas une liste d'arguments** — même arbitrage que
/// `ZChatComposerSlot` : un réglage de plus deviendra un **champ de plus ici**,
/// jamais un paramètre de plus dans la signature du builder, donc jamais un
/// hôte cassé.
@immutable
class ZChatSettingsSlot {
  /// Construit le contexte d'une tuile.
  const ZChatSettingsSlot({
    required this.controller,
    required this.settings,
    required this.corpusScope,
    required this.corpusCatalog,
  });

  /// Le contrôleur de réglages — l'hôte y écrit par les gestes existants
  /// (`setResponseLength`, `toggleCorpusKey`, …), jamais par un second canal.
  final ZChatSettingsController controller;

  /// Valeur **courante** des quatre réglages, déjà lue par le socle : le
  /// builder n'a pas à s'abonner lui-même (et ne doit pas — ce serait un second
  /// abonnement à la même tranche).
  final ZChatGenerationSettings settings;

  /// Portée documentaire courante, ou `null` ⇒ aucune restriction.
  final ZChatCorpusScope? corpusScope;

  /// Le catalogue tel que l'hôte l'a fourni (jamais une donnée du socle).
  final List<ZChatCorpusOption> corpusCatalog;
}

/// Construit — ou retire — une tuile de la feuille de réglages.
///
/// Rendre `null` ⇒ **aucun widget inséré** (AD-4).
typedef ZChatSettingsTileBuilder =
    Widget? Function(BuildContext context, ZChatSettingsSlot slot);

/// Rend les réglages de génération d'un [ZChatSettingsController] — **zéro
/// dépendance tierce**, aucune couleur, aucun libellé en dur.
///
/// Utilisable telle quelle (aucun builder n'est requis), et branchée au créneau
/// `tools` de `ZChatComposer` : c'est le chemin par lequel les réglages
/// atteignent réellement `ZChatController.send(settings:, corpusScope:)`.
class ZChatSettingsSheet extends StatelessWidget {
  /// Construit la feuille.
  const ZChatSettingsSheet({
    required this.controller,
    this.corpusCatalog = const <ZChatCorpusOption>[],
    this.responseLengthBuilder,
    this.lengthBiasBuilder,
    this.computeBudgetBuilder,
    this.revealThinkingBuilder,
    this.corpusBuilder,
    this.padding,
    this.spacing,
    this.selectedWeight,
    this.selectedDecoration,
    super.key,
  });

  /// Le contrôleur rendu. Il n'est **ni créé ni disposé** ici (AD-2).
  final ZChatSettingsController controller;

  /// Catalogue de corpus **de l'hôte**. Vide ⇒ la tuile de portée documentaire
  /// est **absente** : le socle n'a aucun corpus à proposer, et une tuile vide
  /// laisserait croire l'inverse.
  final List<ZChatCorpusOption> corpusCatalog;

  /// Remplace la tuile de verbosité (`ZChatResponseLength`). Cf. le tableau du
  /// dartdoc de bibliothèque pour la règle des trois cas.
  final ZChatSettingsTileBuilder? responseLengthBuilder;

  /// Remplace la tuile de biais de régénération (`ZChatLengthBias`).
  final ZChatSettingsTileBuilder? lengthBiasBuilder;

  /// Remplace la tuile de budget de calcul (`ZChatComputeEffort`).
  final ZChatSettingsTileBuilder? computeBudgetBuilder;

  /// Remplace la tuile « exposer le raisonnement ».
  final ZChatSettingsTileBuilder? revealThinkingBuilder;

  /// Remplace la tuile de portée documentaire (`ZChatCorpusScope`).
  final ZChatSettingsTileBuilder? corpusBuilder;

  /// Marge **directionnelle** (AD-13). `null` ⇒ jeton puis référence.
  final EdgeInsetsDirectional? padding;

  /// Interligne entre les tuiles. `null` ⇒ jeton puis référence.
  final double? spacing;

  /// Graisse de l'option **choisie** — canal visible n°1 (CR-IFFD-74).
  ///
  /// `null` ⇒ [kZChatSettingsReferenceSelectedWeight]. Le niveau **jeton**
  /// s'insérera ici quand `zcrud_core` portera
  /// `chatSelectedEmphasisWeight` (cf. le dartdoc de bibliothèque).
  final FontWeight? selectedWeight;

  /// Décoration de l'option **choisie** — canal visible n°2 (CR-IFFD-74).
  ///
  /// `null` ⇒ [kZChatSettingsReferenceSelectedDecoration]. Un hôte qui ne veut
  /// que la graisse passe `TextDecoration.none` ; un hôte qui veut tout autre
  /// chose remplace la tuile par son builder.
  final TextDecoration? selectedDecoration;

  /// Résout la marge selon **paramètre > jeton > référence**.
  EdgeInsetsDirectional resolvePadding(BuildContext context) =>
      padding ??
      ZcrudScope.maybeOf(context)?.theme?.formPadding ??
      kZChatSettingsReferencePadding;

  /// Résout l'interligne selon **paramètre > jeton > référence**.
  double resolveGap(BuildContext context) =>
      spacing ??
      ZcrudScope.maybeOf(context)?.theme?.gapS ??
      kZChatSettingsReferenceGap;

  /// Résout la graisse d'emphase selon **paramètre > référence** (le niveau
  /// jeton reste à poser dans `zcrud_core`).
  FontWeight resolveSelectedWeight(BuildContext context) =>
      selectedWeight ?? kZChatSettingsReferenceSelectedWeight;

  /// Résout la décoration d'emphase selon **paramètre > référence**.
  TextDecoration resolveSelectedDecoration(BuildContext context) =>
      selectedDecoration ?? kZChatSettingsReferenceSelectedDecoration;

  @override
  Widget build(BuildContext context) {
    final double gap = resolveGap(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, kZChatLabelSettings),
      // 🔴 L'emphase visible est posée UNE fois, au-dessus des deux
      // `ValueListenableBuilder` : les CINQ familles de tuiles la lisent au même
      // endroit, donc aucune ne peut diverger — et la poser ici ne provoque
      // aucun rebuild supplémentaire (elle ne change qu'à une reconfiguration
      // de la feuille, AD-2/SM-1).
      child: _ZChatSettingsEmphasis(
        weight: resolveSelectedWeight(context),
        decoration: resolveSelectedDecoration(context),
        child: Padding(
          padding: resolvePadding(context),
        // 🔴 Les DEUX tranches sont écoutées SÉPARÉMENT et au plus bas :
        // cocher un corpus ne reconstruit pas les tuiles de verbosité. Rien
        // ici n'écoute `ZChatController.messages` — c'est ce qui fait qu'ouvrir
        // ou fermer la feuille ne reconstruit aucune tuile de conversation
        // (SM-1, mesuré).
        child: ValueListenableBuilder<ZChatGenerationSettings>(
          valueListenable: controller.settings,
          builder:
              (
                BuildContext context,
                ZChatGenerationSettings settings,
                Widget? _,
              ) => ValueListenableBuilder<ZChatCorpusScope?>(
                valueListenable: controller.corpusScope,
                builder:
                    (
                      BuildContext context,
                      ZChatCorpusScope? scope,
                      Widget? _,
                    ) => _body(context, settings, scope, gap),
              ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ZChatGenerationSettings settings,
    ZChatCorpusScope? scope,
    double gap,
  ) {
    final ZChatSettingsSlot slot = ZChatSettingsSlot(
      controller: controller,
      settings: settings,
      corpusScope: scope,
      corpusCatalog: corpusCatalog,
    );
    final List<Widget> tiles = <Widget>[
      ?_tile(context, slot, responseLengthBuilder, _responseLength),
      ?_tile(context, slot, lengthBiasBuilder, _lengthBias),
      ?_tile(context, slot, computeBudgetBuilder, _computeBudget),
      ?_tile(context, slot, revealThinkingBuilder, _revealThinking),
      ?_tile(context, slot, corpusBuilder, _corpus),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < tiles.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          tiles[i],
        ],
      ],
    );
  }

  /// Applique la règle des trois cas : builder absent ⇒ défaut, builder fourni
  /// ⇒ son résultat, `null` rendu ⇒ tuile ABSENTE (AD-4).
  Widget? _tile(
    BuildContext context,
    ZChatSettingsSlot slot,
    ZChatSettingsTileBuilder? override,
    Widget? Function(BuildContext, ZChatSettingsSlot) fallback,
  ) => override == null
      ? fallback(context, slot)
      : override(context, slot);

  Widget? _responseLength(BuildContext context, ZChatSettingsSlot slot) =>
      _ZChatSettingsGroup(
        labelKey: kZChatLabelResponseLength,
        gap: resolveGap(context),
        options: <_ZChatSettingsOption>[
          _ZChatSettingsOption.key(
            labelKey: kZChatLabelSettingAuto,
            selected: slot.settings.responseLength == null,
            onTap: () => slot.controller.setResponseLength(null),
          ),
          for (final MapEntry<ZChatResponseLength, String> e
              in _kResponseLengthLabels.entries)
            _ZChatSettingsOption.key(
              labelKey: e.value,
              selected: slot.settings.responseLength == e.key,
              onTap: () => slot.controller.setResponseLength(e.key),
            ),
        ],
      );

  Widget? _lengthBias(BuildContext context, ZChatSettingsSlot slot) =>
      _ZChatSettingsGroup(
        labelKey: kZChatLabelLengthBias,
        gap: resolveGap(context),
        options: <_ZChatSettingsOption>[
          _ZChatSettingsOption.key(
            labelKey: kZChatLabelSettingAuto,
            selected: slot.settings.lengthBias == null,
            onTap: () => slot.controller.setLengthBias(null),
          ),
          for (final MapEntry<ZChatLengthBias, String> e
              in _kLengthBiasLabels.entries)
            _ZChatSettingsOption.key(
              labelKey: e.value,
              selected: slot.settings.lengthBias == e.key,
              onTap: () => slot.controller.setLengthBias(e.key),
            ),
        ],
      );

  Widget? _computeBudget(BuildContext context, ZChatSettingsSlot slot) =>
      _ZChatSettingsGroup(
        labelKey: kZChatLabelComputeBudget,
        gap: resolveGap(context),
        options: <_ZChatSettingsOption>[
          _ZChatSettingsOption.key(
            labelKey: kZChatLabelSettingAuto,
            selected: slot.settings.computeEffort == null,
            onTap: () => slot.controller.setComputeEffort(null),
          ),
          // 🔴 Les paliers viennent des BORNES du kernel (`1..5`, l'intervalle
          // commun aux deux backends), jamais d'une liste recopiée ici : élargir
          // l'intervalle côté kernel élargit la feuille, sans retouche.
          for (
            int level = ZChatComputeEffort.min;
            level <= ZChatComputeEffort.max;
            level++
          )
            _ZChatSettingsOption.key(
              labelKey: kZChatLabelComputeBudgetLevel,
              count: level,
              selected: slot.settings.computeEffort?.level == level,
              onTap: () =>
                  slot.controller.setComputeEffort(ZChatComputeEffort(level)),
            ),
        ],
      );

  Widget? _revealThinking(BuildContext context, ZChatSettingsSlot slot) =>
      _ZChatSettingsGroup(
        labelKey: kZChatLabelRevealThinking,
        gap: resolveGap(context),
        options: <_ZChatSettingsOption>[
          _ZChatSettingsOption.key(
            labelKey: kZChatLabelSettingAuto,
            selected: slot.settings.revealThinkingSteps == null,
            onTap: () => slot.controller.setRevealThinkingSteps(null),
          ),
          _ZChatSettingsOption.key(
            labelKey: kZChatLabelRevealThinking,
            selected: slot.settings.revealThinkingSteps ?? false,
            onTap: () => slot.controller.setRevealThinkingSteps(
              !(slot.settings.revealThinkingSteps ?? false),
            ),
          ),
        ],
      );

  /// La portée documentaire — **absente** tant que l'hôte n'a fourni aucun
  /// corpus (AD-4). Le socle n'en invente pas.
  Widget? _corpus(BuildContext context, ZChatSettingsSlot slot) {
    if (slot.corpusCatalog.isEmpty) return null;
    return _ZChatSettingsGroup(
      labelKey: kZChatLabelCorpusScope,
      gap: resolveGap(context),
      options: <_ZChatSettingsOption>[
        _ZChatSettingsOption.key(
          labelKey: kZChatLabelCorpusAll,
          selected: slot.corpusScope == null,
          onTap: () => slot.controller.setCorpusScope(null),
        ),
        for (final ZChatCorpusOption option in slot.corpusCatalog)
          _ZChatSettingsOption.host(
            // 🔴 Le libellé vient de l'HÔTE : pas de clé, pas de traduction du
            // socle. C'est ce qui tient « aucune valeur métier ici ».
            text: option.label,
            selected: slot.controller.selectsCorpusKey(option.key),
            onTap: () => slot.controller.toggleCorpusKey(option.key),
          ),
      ],
    );
  }
}

/// Correspondance palier ⇄ clé de libellé — **référence** aux enums du kernel,
/// jamais redéclaration : le `switch` exhaustif du compilateur signale un palier
/// ajouté en amont, ce qu'une liste de chaînes ne ferait pas.
const Map<ZChatResponseLength, String> _kResponseLengthLabels =
    <ZChatResponseLength, String>{
      ZChatResponseLength.concise: kZChatLabelLengthConcise,
      ZChatResponseLength.standard: kZChatLabelLengthStandard,
      ZChatResponseLength.detailed: kZChatLabelLengthDetailed,
    };

const Map<ZChatLengthBias, String> _kLengthBiasLabels = <ZChatLengthBias, String>{
  ZChatLengthBias.shorter: kZChatLabelBiasShorter,
  ZChatLengthBias.asIs: kZChatLabelBiasAsIs,
  ZChatLengthBias.longer: kZChatLabelBiasLonger,
};

/// Porte l'**emphase visible** de l'option choisie jusqu'aux CINQ familles de
/// tuiles, sans la faire transiter par six sites de construction.
///
/// 🔴 Un seul porteur ⇒ **une seule** définition de « ce qu'on voit quand c'est
/// choisi ». Le défaut d'origine (CR-IFFD-74) était partagé par les cinq
/// familles précisément parce qu'elles partagent une primitive : le correctif
/// doit se partager par la même arête, sinon il se corrigerait quatre fois et
/// divergerait une cinquième.
class _ZChatSettingsEmphasis extends InheritedWidget {
  const _ZChatSettingsEmphasis({
    required this.weight,
    required this.decoration,
    required super.child,
  });

  final FontWeight weight;
  final TextDecoration decoration;

  /// AD-10 : hors de la feuille, l'option retombe sur les **références** — elle
  /// ne rend jamais un état invisible, et ne lève jamais.
  static _ZChatSettingsEmphasis? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ZChatSettingsEmphasis>();

  @override
  bool updateShouldNotify(_ZChatSettingsEmphasis old) =>
      weight != old.weight || decoration != old.decoration;
}

/// Combine la décoration héritée et celle d'emphase — **additif** : un hôte qui
/// barre son texte le garde barré ET souligné, il ne le perd pas.
TextDecoration _mergeDecoration(TextDecoration? base, TextDecoration add) =>
    base == null || base == TextDecoration.none
    ? add
    : TextDecoration.combine(<TextDecoration>[base, add]);

/// La paire de styles d'une option : ce que rend une option **non choisie**, et
/// ce que rend une option **choisie**. Fonction PURE, donc mesurable seule.
///
/// 🔴 Elle porte l'invariant de CR-IFFD-74 : sous les références du socle, les
/// deux styles **diffèrent toujours**. Si le style hérité portait déjà la
/// graisse ET la décoration d'emphase, les deux canaux s'annuleraient — le socle
/// retire alors la décoration des options NON choisies, plutôt que de laisser
/// l'état redevenir invisible (AD-10). Hors de ce cas, l'option non choisie rend
/// **exactement** le style hérité : le correctif est strictement additif.
({TextStyle plain, TextStyle chosen}) _optionStyles(
  TextStyle base, {
  required FontWeight weight,
  required TextDecoration decoration,
}) {
  final TextStyle chosen = base.copyWith(
    fontWeight: weight,
    decoration: _mergeDecoration(base.decoration, decoration),
  );
  final bool collapsed =
      chosen.fontWeight == base.fontWeight &&
      chosen.decoration == base.decoration;
  final bool baseDecorated =
      base.decoration != null && base.decoration != TextDecoration.none;
  return (
    plain: collapsed && baseDecorated
        ? base.copyWith(decoration: TextDecoration.none)
        : base,
    chosen: chosen,
  );
}

/// Un groupe de réglage : un intitulé, puis ses options.
class _ZChatSettingsGroup extends StatelessWidget {
  const _ZChatSettingsGroup({
    required this.labelKey,
    required this.options,
    required this.gap,
  });

  final String labelKey;
  final List<_ZChatSettingsOption> options;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, labelKey),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // AD-13 : alignement DIRECTIONNEL.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // L'intitulé est déjà porté par le `Semantics` du groupe : le
          // dupliquer dans l'arbre sémantique le ferait annoncer DEUX fois
          // (leçon MAJEUR-doublon de la bande de pièces jointes, où un
          // `contains` était aveugle à la concaténation).
          ExcludeSemantics(
            child: Text(
              zChatLabel(context, labelKey),
              // AD-13 : jamais `TextAlign.left`.
              textAlign: TextAlign.start,
            ),
          ),
          SizedBox(height: gap),
          Wrap(spacing: gap, runSpacing: gap, children: options),
        ],
      ),
    );
  }
}

/// Une option : cible **≥ 48 dp en géométrie rendue**, état porté par **deux**
/// canaux — le drapeau sémantique `selected` (lecteur d'écran) ET l'emphase
/// typographique (vue). Jamais par la seule couleur, et jamais par le seul
/// drapeau sémantique (AD-13 et son symétrique, CR-IFFD-74).
class _ZChatSettingsOption extends StatelessWidget {
  /// Option dont le libellé est une **clé du socle**.
  const _ZChatSettingsOption.key({
    required String this.labelKey,
    required this.selected,
    required this.onTap,
    this.count,
  }) : text = null;

  /// Option dont le libellé est **fourni par l'hôte** (catalogue de corpus).
  ///
  /// 🔴 Deux constructeurs plutôt qu'un couple de champs nullables : « exactement
  /// l'une des deux sources » devient une propriété du TYPE, pas une convention
  /// qu'un appel futur pourrait enfreindre en passant les deux — ou aucune.
  const _ZChatSettingsOption.host({
    required String this.text,
    required this.selected,
    required this.onTap,
  }) : labelKey = null,
       count = null;

  /// Clé du libellé, résolue par le registre de l'hôte. Exclusive de [text].
  final String? labelKey;

  /// Libellé **déjà résolu par l'hôte** (catalogue de corpus). Exclusif de
  /// [labelKey].
  final String? text;

  /// Substitué à `{n}` dans le libellé, quand la clé en porte un.
  final int? count;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String resolved =
        text ??
        (count == null
            ? zChatLabel(context, labelKey!)
            : zChatCountLabel(context, labelKey!, count!));
    // 🔴 LE CANAL VISIBLE (CR-IFFD-74). Il s'AJOUTE au drapeau sémantique
    // ci-dessous ; il ne le remplace pas — c'est exactement l'erreur que cette
    // CR corrige, dans l'autre sens.
    final _ZChatSettingsEmphasis? emphasis = _ZChatSettingsEmphasis.maybeOf(
      context,
    );
    final ({TextStyle plain, TextStyle chosen}) styles = _optionStyles(
      DefaultTextStyle.of(context).style,
      weight: emphasis?.weight ?? kZChatSettingsReferenceSelectedWeight,
      decoration:
          emphasis?.decoration ?? kZChatSettingsReferenceSelectedDecoration,
    );
    return Semantics(
      button: true,
      // 🔴 L'ÉTAT, dans l'arbre sémantique. Le legacy porte le choix par la
      // seule couleur : un lecteur d'écran y annonce quatre boutons identiques.
      selected: selected,
      // 🔴 Le libellé est porté ICI, et les descendants sont exclus.
      //
      // Mesuré : sans cela, le groupe parent étant en `explicitChildNodes`, le
      // `Text` devenait un nœud SÉPARÉ — si bien que le nœud portant
      // `selected` n'avait aucun libellé et que le nœud portant le libellé
      // n'avait aucun état. Un lecteur d'écran annonçait donc quatre boutons
      // indiscernables **et** quatre textes muets : la garde SET-R1 l'a
      // attrapé (0 nœud satisfaisant « libellé ∧ choisi »). Regrouper les deux
      // sur un seul nœud est la seule forme qui annonce « Concise, choisie ».
      label: resolved,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.center,
            // 🔴 Ici les facteurs ne sont PAS inertes — contrairement à ceux de
            // `_ZChatComposerTarget`, mesurés inertes sous une `Row`. Le parent
            // est un `Wrap` : ses enfants reçoivent la contrainte de LARGEUR de
            // la ligne. Sans `widthFactor`, `Align` l'occuperait entièrement et
            // la garde « ≥ 48 dp » passerait pour la mauvaise raison — le
            // précédent exact de `z_chat_diffusion_bar.dart`. L'injection R3
            // jumelle le vérifie.
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              resolved,
              // 🔴 Le style est posé EXPLICITEMENT sur les deux états : c'est
              // ce qui rend la différence mesurable sur le `RenderParagraph`,
              // et non « présente quelque part dans l'arbre ».
              style: selected ? styles.chosen : styles.plain,
              // AD-13 : jamais `TextAlign.left`.
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}

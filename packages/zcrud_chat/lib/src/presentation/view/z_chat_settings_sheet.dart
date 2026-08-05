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

  @override
  Widget build(BuildContext context) {
    final double gap = resolveGap(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, kZChatLabelSettings),
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

/// Une option : cible **≥ 48 dp en géométrie rendue**, état porté par le
/// drapeau sémantique `selected` — jamais par la seule couleur (AD-13).
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
            child: Text(resolved, textAlign: TextAlign.start),
          ),
        ),
      ),
    );
  }
}

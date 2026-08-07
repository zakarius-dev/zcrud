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
/// [selectedDecoration]), puis par les **jetons** `chatSelectedEmphasisWeight`
/// (`FontWeight?`) et `chatSelectedEmphasisDecoration` (`TextDecoration?`) —
/// demandés par CR-IFFD-74, **posés au lot K4** —, et retombent sinon sur la
/// **référence** du socle. Les jetons sont lus sur
/// `ZcrudScope.maybeOf(context)?.theme` — jamais sur `ZcrudTheme.of`, pour la
/// raison écrite plus haut. `floatingLabelWeight` n'a **pas** été détourné pour
/// tenir ce rôle : c'est le jeton du *label flottant d'un formulaire*, et un
/// hôte qui le règle ne demande pas de changer l'emphase d'un choix de chat.
///
/// ## 🔴 CR-IFFD-75 — deux cibles adjacentes restent DISTINCTES quel que soit
/// leur libellé
///
/// Le plancher de 48 dp ([kZChatMinTapTarget]) est une borne **basse** : il
/// garantit qu'une cible est *atteignable*, pas qu'elle est *lisible*. Un
/// libellé plus large que 48 dp fait grandir la boîte au-delà du plancher, et
/// deux boîtes voisines finissent bord à bord — mesuré sur appareil en
/// français (« RéinitialiserFermer »), invisible en anglais (Reset/Close
/// < 48 dp, donc dans la langue de développement).
///
/// > 🔴 **Deux cibles adjacentes doivent rester visuellement distinctes
/// > indépendamment de la longueur de leur libellé** — le pendant GÉOMÉTRIQUE
/// > de la règle CR-74 ci-dessus (« un état perceptible par au moins un canal
/// > visible ») : là-bas un état sans canal visible, ici deux affordances sans
/// > frontière visible.
///
/// Le correctif vit dans la **PRIMITIVE** (`_ZChatSettingsAction`), pas dans le
/// seul en-tête — la CR le pressentait : la primitive « pourrait servir
/// ailleurs et porter le même risque ». Chaque action réserve un dégagement
/// horizontal autour de son libellé (la moitié de
/// [kZChatSettingsReferenceActionGap] de chaque côté, réglable par
/// [actionSpacing] ; le jeton de niveau 2, `chatSettingsActionGap`, est
/// **demandé** à `zcrud_core` — hors périmètre de ce lot), si bien que deux
/// actions posées bord à bord gardent leurs libellés écartés d'au moins cet
/// écart :
///
/// * en **RTL** — l'ordre des actions s'inverse ; le dégagement étant
///   symétrique, l'écart tient (mesuré) ;
/// * sous un **petit écran** — les actions sont `Flexible` : un libellé plus
///   large que la place restante passe à la ligne au lieu de faire déborder la
///   `Row` (mesuré, l'`Expanded` du titre comprimé à quelques dp).
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../settings/z_chat_settings_controller.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;
import 'z_chat_settings_entry.dart';

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

/// Écart de **référence** GARANTI entre les libellés de deux actions
/// adjacentes de l'en-tête (CR-IFFD-75) — chaque [_ZChatSettingsAction]
/// réserve la **moitié** de cet écart de chaque côté de son libellé, si bien
/// que deux actions posées bord à bord restent visuellement distinctes quel
/// que soit leur libellé (le plancher 48 dp, borne basse, ne le garantit pas).
///
/// Réglable par le paramètre [ZChatSettingsSheet.actionSpacing] ; le jeton de
/// niveau 2 (`chatSettingsActionGap`) est **demandé** à `zcrud_core` et
/// s'insérera entre les deux, comme `chatSelectedEmphasisWeight` l'a été pour
/// CR-74.
const double kZChatSettingsReferenceActionGap = 16;

/// Écart de **référence** entre la coche d'hôte ([ZChatScaleControl
/// .selectionMark]) et le libellé d'un segment choisi — même régime que
/// [kZChatSettingsReferenceGap].
const double kZChatSettingsReferenceMarkGap = 4;

/// Une entrée du **catalogue de corpus de l'hôte**.
///
/// 🔴 [key] est la **clé stable** confrontée à `ZChatCorpusScope` (et, en bout
/// de chaîne, à `ZChatSource.corpusKey`) ; [label] est le texte **déjà résolu
/// par l'hôte**, dans sa langue. Le socle ne traduit pas un corpus : il n'en
/// connaît aucun.
@immutable
class ZChatCorpusOption {
  /// Construit une entrée de catalogue.
  const ZChatCorpusOption({
    required this.key,
    required this.label,
    this.children = const <ZChatCorpusOption>[],
    this.enabled = true,
  });

  /// Clé **stable et opaque**, jamais un libellé. C'est la distinction que
  /// l'étude a établie (§ 4.2) et sans laquelle une restriction ne serait pas
  /// vérifiable : `ZChatSource.corpus` est traduisible, `corpusKey` ne l'est
  /// pas.
  final String key;

  /// Libellé affiché, **fourni et localisé par l'hôte**.
  final String label;

  /// **Second niveau** de filtre — lot K2 (T1, le filtre par entrée de lex :
  /// chip « Tous » + `FilterChip` par document du catalogue,
  /// `tools_sheet.dart:571-645`). Vide ⇒ l'entrée est plate, comme avant ce
  /// lot. Les enfants ne sont rendus que lorsque l'entrée parente est
  /// sélectionnée — le mécanisme lex (switch actif ⇒ rangée de filtres).
  final List<ZChatCorpusOption> children;

  /// `false` ⇒ entrée présente mais NON sélectionnable — l'« entrée non
  /// indexée » de lex (grisée alpha 0.38, `tools_sheet.dart:598-617`). Le
  /// socle la rend **sans couleur** : sémantique `enabled: false` + style
  /// italique — deux canaux, aucun chromatique (leçon CR-74).
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCorpusOption &&
          key == other.key &&
          label == other.label &&
          enabled == other.enabled &&
          listEquals(other.children, children);

  @override
  int get hashCode =>
      Object.hash(key, label, enabled, Object.hashAll(children));
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
    this.presetCatalog = const <ZChatSettingsPreset>[],
    this.capabilityCatalog = const <ZChatSettingsHostOption>[],
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

  /// Les préréglages de l'hôte — lot K2 (T2). Vide ⇒ tuile absente (AD-4).
  final List<ZChatSettingsPreset> presetCatalog;

  /// Les capacités SUPPLÉMENTAIRES de l'hôte — lot K4 (raccord kernel K1).
  /// La recherche web n'a pas besoin d'y figurer : c'est l'entrée par défaut
  /// du socle (`kZChatCapabilityWebSearch`, la seule qu'il nomme).
  final List<ZChatSettingsHostOption> capabilityCatalog;
}

/// Construit — ou retire — une tuile de la feuille de réglages.
///
/// Rendre `null` ⇒ **aucun widget inséré** (AD-4).
typedef ZChatSettingsTileBuilder =
    Widget? Function(BuildContext context, ZChatSettingsSlot slot);

/// Construit — ou retire — la tuile d'une **entrée déclarative**
/// ([ZChatSettingsEntry]) : cible des `entryBuilders` (par id), des
/// `kindBuilders` (par kind) et de `unknownEntryBuilder`.
///
/// Rendre `null` ⇒ **entrée absente de l'arbre** (AD-4).
typedef ZChatSettingsEntryTileBuilder =
    Widget? Function(
      BuildContext context,
      ZChatSettingsSlot slot,
      ZChatSettingsEntry entry,
    );

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
    this.presetCatalog = const <ZChatSettingsPreset>[],
    this.capabilityCatalog = const <ZChatSettingsHostOption>[],
    this.headerBuilder,
    this.onClose,
    this.presetsBuilder,
    this.responseLengthBuilder,
    this.lengthBiasBuilder,
    this.computeBudgetBuilder,
    this.revealThinkingBuilder,
    this.capabilitiesBuilder,
    this.corpusBuilder,
    this.entries = const <ZChatSettingsEntry>[],
    this.sections = const <ZChatSettingsSection>[],
    this.entryBuilders = const <String, ZChatSettingsEntryTileBuilder>{},
    this.kindBuilders = const <String, ZChatSettingsEntryTileBuilder>{},
    this.sectionBuilders = const <String, ZChatSettingsTileBuilder>{},
    this.unknownEntryBuilder,
    this.padding,
    this.spacing,
    this.actionSpacing,
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

  /// Les préréglages de l'HÔTE — lot K2 (T2, l'« expert » de lex rendu
  /// neutre). Vide ⇒ la tuile de préréglages est **absente** (AD-4).
  final List<ZChatSettingsPreset> presetCatalog;

  /// Remplace l'EN-TÊTE de la feuille (titre + réinitialiser + fermer — la
  /// forme lex, `tools_sheet.dart:44-61`). Règle des trois cas, comme les
  /// tuiles. Lot K2 (T1).
  final ZChatSettingsTileBuilder? headerBuilder;

  /// Ferme la feuille — le conteneur appartient à l'hôte (F11), donc la
  /// fermeture aussi. `null` ⇒ l'affordance « fermer » de l'en-tête par défaut
  /// est **absente** (AD-4 : jamais un bouton inerte).
  final VoidCallback? onClose;

  /// Remplace la tuile de préréglages. Lot K2 (T2).
  final ZChatSettingsTileBuilder? presetsBuilder;

  /// Remplace la tuile de verbosité (`ZChatResponseLength`). Cf. le tableau du
  /// dartdoc de bibliothèque pour la règle des trois cas.
  final ZChatSettingsTileBuilder? responseLengthBuilder;

  /// Remplace la tuile de biais de régénération (`ZChatLengthBias`).
  final ZChatSettingsTileBuilder? lengthBiasBuilder;

  /// Remplace la tuile de budget de calcul (`ZChatComputeEffort`).
  final ZChatSettingsTileBuilder? computeBudgetBuilder;

  /// Remplace la tuile « exposer le raisonnement ».
  final ZChatSettingsTileBuilder? revealThinkingBuilder;

  /// Capacités SUPPLÉMENTAIRES de l'hôte (clé opaque + libellé **déjà localisé
  /// par lui**) — lot K4. Elles s'ajoutent à l'entrée par défaut du socle, la
  /// recherche web (`kZChatCapabilityWebSearch` — la seule capacité que le
  /// socle nomme, parce que le kernel la type). Un hôte qui fournit sa propre
  /// entrée pour la clé réservée remplace celle du socle (jamais deux entrées
  /// pour une même clé).
  final List<ZChatSettingsHostOption> capabilityCatalog;

  /// Remplace la tuile de capacités (`ZChatGenerationSettings.capabilities`,
  /// kernel K1) — lot K4. Règle des trois cas ; rendre `null` la retire.
  final ZChatSettingsTileBuilder? capabilitiesBuilder;

  /// Remplace la tuile de portée documentaire (`ZChatCorpusScope`).
  final ZChatSettingsTileBuilder? corpusBuilder;

  /// Les **entrées déclaratives** de l'HÔTE (lot Tile, arbitrage 1) — elles
  /// s'injectent dans les MÊMES sections que les familles standard :
  /// `sectionId` nul ⇒ section de génération, après les familles ;
  /// `kZChatSettingsSectionCorpus` ⇒ après la portée documentaire ; tout autre
  /// id ⇒ section d'hôte (déclarée dans [sections], ou anonyme en fin de
  /// feuille — une entrée n'est **jamais** silencieusement perdue, AD-10).
  final List<ZChatSettingsEntry> entries;

  /// Les **sections** déclarées par l'hôte : ordre des sections d'hôte, et
  /// titres — y compris pour les deux sections du socle, sans titre par
  /// défaut (l'arbre d'un hôte passif ne bouge pas).
  final List<ZChatSettingsSection> sections;

  /// Builder **par entrée** (clé = [ZChatSettingsEntry.id]) — prioritaire sur
  /// [kindBuilders]. Règle des trois cas ; les cinq familles standard sont
  /// ciblables par leurs ids `kZChatSettingsEntry*` (les builders historiques
  /// `responseLengthBuilder`… restent, eux, prioritaires — API inchangée).
  final Map<String, ZChatSettingsEntryTileBuilder> entryBuilders;

  /// Builder **par kind** (clé = [ZChatSettingsControl.kind]) — c'est la porte
  /// d'un kind d'HÔTE : un contrôle à kind inconnu du socle est rendu par son
  /// builder de kind, sinon par [unknownEntryBuilder], sinon **absent** —
  /// jamais un throw (AD-10).
  final Map<String, ZChatSettingsEntryTileBuilder> kindBuilders;

  /// Builder **par section** (clé = id de section) — remplace le BLOC entier
  /// (en-tête + tuiles). Règle des trois cas.
  final Map<String, ZChatSettingsTileBuilder> sectionBuilders;

  /// Rendu de secours d'une entrée dont le kind n'a **aucun** renderer (ni
  /// défaut du socle, ni [kindBuilders], ni [entryBuilders]). `null` ⇒
  /// l'entrée est **absente** (AD-10 : jamais un throw, jamais un placeholder
  /// inerte inventé).
  final ZChatSettingsEntryTileBuilder? unknownEntryBuilder;

  /// Marge **directionnelle** (AD-13). `null` ⇒ jeton puis référence.
  final EdgeInsetsDirectional? padding;

  /// Interligne entre les tuiles. `null` ⇒ jeton puis référence.
  final double? spacing;

  /// Écart minimal GARANTI entre les libellés de deux actions adjacentes de
  /// l'en-tête (CR-IFFD-75). `null` ⇒ jeton demandé (`chatSettingsActionGap`,
  /// pas encore posé dans `zcrud_core` — listé au rapport de lot), puis
  /// [kZChatSettingsReferenceActionGap].
  final double? actionSpacing;

  /// Graisse de l'option **choisie** — canal visible n°1 (CR-IFFD-74).
  ///
  /// `null` ⇒ jeton `chatSelectedEmphasisWeight` (lot K4), puis
  /// [kZChatSettingsReferenceSelectedWeight].
  final FontWeight? selectedWeight;

  /// Décoration de l'option **choisie** — canal visible n°2 (CR-IFFD-74).
  ///
  /// `null` ⇒ jeton `chatSelectedEmphasisDecoration` (lot K4), puis
  /// [kZChatSettingsReferenceSelectedDecoration]. Un hôte qui ne veut
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

  /// Résout l'écart entre actions adjacentes (CR-IFFD-75) — **paramètre >
  /// référence** aujourd'hui ; le jeton `chatSettingsActionGap` (demandé à
  /// `zcrud_core`, hors périmètre de ce lot) s'insérera entre les deux.
  double resolveActionGap(BuildContext context) =>
      actionSpacing ?? kZChatSettingsReferenceActionGap;

  /// Résout la graisse d'emphase selon **paramètre > jeton > référence** — le
  /// jeton `chatSelectedEmphasisWeight` demandé par CR-IFFD-74 a été posé au
  /// lot K4, et il est lu sur `ZcrudScope.maybeOf` (jamais `ZcrudTheme.of`,
  /// cf. le dartdoc de bibliothèque : la référence doit rester atteignable).
  FontWeight resolveSelectedWeight(BuildContext context) =>
      selectedWeight ??
      ZcrudScope.maybeOf(context)?.theme?.chatSelectedEmphasisWeight ??
      kZChatSettingsReferenceSelectedWeight;

  /// Résout la décoration d'emphase selon **paramètre > jeton > référence**
  /// (jeton `chatSelectedEmphasisDecoration`, lot K4 — même régime).
  TextDecoration resolveSelectedDecoration(BuildContext context) =>
      selectedDecoration ??
      ZcrudScope.maybeOf(context)?.theme?.chatSelectedEmphasisDecoration ??
      kZChatSettingsReferenceSelectedDecoration;

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
      presetCatalog: presetCatalog,
      capabilityCatalog: capabilityCatalog,
    );
    final List<Widget> tiles = <Widget>[
      ?_tile(context, slot, headerBuilder, _header),
      ?_tile(context, slot, presetsBuilder, _presets),
      // 🔴 RE-EXPRESSION (CR-LEX-78, arbitrage 1) : les familles standard ne
      // sont plus des tuiles ad hoc — ce sont des [ZChatSettingsEntry] rendues
      // par la MÊME voie que les entrées d'hôte (`_renderEntry`). La feuille
      // par défaut rend un arbre STRICTEMENT identique à l'avant-re-expression
      // (garde RX-1, étalon versionné).
      ..._sectionBlock(context, slot, kZChatSettingsSectionGeneration, <Widget>[
        ?_tile(context, slot, responseLengthBuilder, _responseLength),
        ?_tile(context, slot, lengthBiasBuilder, _lengthBias),
        ?_tile(context, slot, computeBudgetBuilder, _computeBudget),
        ?_tile(context, slot, revealThinkingBuilder, _revealThinking),
      ]),
      ?_tile(context, slot, capabilitiesBuilder, _capabilities),
      ..._sectionBlock(context, slot, kZChatSettingsSectionCorpus, <Widget>[
        ?_tile(context, slot, corpusBuilder, _corpus),
      ]),
      // Sections d'HÔTE : celles déclarées d'abord (dans leur ordre), puis les
      // ids orphelins par ordre d'apparition — une entrée n'est jamais perdue.
      for (final String id in _hostSectionIds())
        ..._sectionBlock(context, slot, id, const <Widget>[]),
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

  // ── Le pipeline d'ENTRÉES — l'unique voie de rendu (CR-LEX-78) ────────────

  /// Section d'appartenance d'une entrée — `null` ⇒ génération.
  String _entrySection(ZChatSettingsEntry e) =>
      e.sectionId ?? kZChatSettingsSectionGeneration;

  /// Ids de sections d'HÔTE, dans l'ordre : les déclarées d'abord, puis les
  /// orphelines (id référencé par une entrée mais jamais déclaré — rendue
  /// quand même, AD-10) par ordre d'apparition.
  List<String> _hostSectionIds() {
    const Set<String> socle = <String>{
      kZChatSettingsSectionGeneration,
      kZChatSettingsSectionCorpus,
    };
    final List<String> ids = <String>[
      for (final ZChatSettingsSection s in sections)
        if (!socle.contains(s.id)) s.id,
    ];
    for (final ZChatSettingsEntry e in entries) {
      final String id = _entrySection(e);
      if (!socle.contains(id) && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  /// Le BLOC d'une section : en-tête éventuel + tuiles par défaut + entrées
  /// d'hôte de la section — ou le remplacement/retrait de `sectionBuilders`
  /// (règle des trois cas, appliquée au bloc ENTIER).
  List<Widget> _sectionBlock(
    BuildContext context,
    ZChatSettingsSlot slot,
    String id,
    List<Widget> defaults,
  ) {
    final ZChatSettingsTileBuilder? override = sectionBuilders[id];
    if (override != null) {
      final Widget? replaced = override(context, slot);
      return replaced == null ? const <Widget>[] : <Widget>[replaced];
    }
    final List<Widget> tiles = <Widget>[
      ...defaults,
      for (final ZChatSettingsEntry e in entries)
        if (_entrySection(e) == id) ?_renderEntry(context, slot, e),
    ];
    // Section VIDE ⇒ absente, en-tête compris (AD-4 : jamais un titre inerte).
    if (tiles.isEmpty) return const <Widget>[];
    return <Widget>[?_sectionHeader(context, id), ...tiles];
  }

  /// L'EN-TÊTE d'une section — rendu **seulement** si l'hôte a déclaré la
  /// section avec un titre ([ZChatSettingsSection.title] non nul). Les deux
  /// sections du socle n'en ont pas par défaut : l'arbre d'un hôte passif ne
  /// bouge pas (garde RX-1).
  Widget? _sectionHeader(BuildContext context, String id) {
    ZChatSettingsSection? declared;
    for (final ZChatSettingsSection s in sections) {
      if (s.id == id) {
        declared = s;
        break;
      }
    }
    final ZChatSettingsLabel? title = declared?.title;
    if (title == null) return null;
    final String resolved = _resolveLabel(context, title, null);
    return Semantics(
      header: true,
      label: resolved,
      excludeSemantics: true,
      child: Text(resolved, textAlign: TextAlign.start),
    );
  }

  /// Résout un [ZChatSettingsLabel] — la clé passe par le registre + repli
  /// ([zChatLabel], convention `kZChatLabelFallbacks`), le texte d'hôte est
  /// rendu tel quel.
  String _resolveLabel(
    BuildContext context,
    ZChatSettingsLabel label,
    int? count,
  ) {
    final String? key = label.labelKey;
    if (key == null) return label.text!;
    return count == null
        ? zChatLabel(context, key)
        : zChatCountLabel(context, key, count);
  }

  /// Rend une entrée : `entryBuilders[id]` > `kindBuilders[kind]` > défaut du
  /// socle > [unknownEntryBuilder] > **absente** (AD-4/AD-10 — un kind inconnu
  /// ne lève jamais).
  Widget? _renderEntry(
    BuildContext context,
    ZChatSettingsSlot slot,
    ZChatSettingsEntry entry,
  ) {
    final ZChatSettingsEntryTileBuilder? override =
        entryBuilders[entry.id] ?? kindBuilders[entry.kind];
    if (override != null) return override(context, slot, entry);
    return _defaultEntryTile(context, slot, entry);
  }

  /// Le rendu PAR DÉFAUT d'une entrée — le mode Tile IFFD (icône + titre +
  /// sous-titre + contrôle) sur les contrôles au rendu lex (segments à
  /// emphase CR-74, échelle labellisée). Un kind que le socle ne sait pas
  /// rendre retombe sur [unknownEntryBuilder], sinon l'entrée est absente.
  Widget? _defaultEntryTile(
    BuildContext context,
    ZChatSettingsSlot slot,
    ZChatSettingsEntry entry,
  ) {
    final double gap = resolveGap(context);
    final ZChatSettingsControl control = entry.control;
    Widget? tile;
    if (control is ZChatSelectControl) {
      tile = _choicesGroup(
        context,
        entry,
        control.choices,
        control.selectionMark,
        control.footer,
        gap,
      );
    } else if (control is ZChatScaleControl) {
      tile = _choicesGroup(
        context,
        entry,
        control.choices,
        control.selectionMark,
        control.footer,
        gap,
      );
    } else if (control is ZChatToggleControl) {
      tile = _ZChatSettingsToggleTile(
        title: _resolveLabel(context, entry.title, null),
        subtitle: entry.subtitle == null
            ? null
            : _resolveLabel(context, entry.subtitle!, null),
        value: control.value,
        onChanged: control.onChanged,
        gap: gap,
      );
    } else if (control is ZChatNavigationControl) {
      tile = _ZChatSettingsNavigationTile(
        title: _resolveLabel(context, entry.title, null),
        subtitle: entry.subtitle == null
            ? null
            : _resolveLabel(context, entry.subtitle!, null),
        value: control.value == null
            ? null
            : _resolveLabel(context, control.value!, null),
        trailing: control.trailing,
        onTap: control.onTap,
        gap: gap,
      );
    } else if (control is ZChatNumberControl) {
      tile = _ZChatSettingsNumberTile(
        title: _resolveLabel(context, entry.title, null),
        subtitle: entry.subtitle == null
            ? null
            : _resolveLabel(context, entry.subtitle!, null),
        control: control,
        gap: gap,
      );
    } else {
      // 🔴 Kind INCONNU : jamais un throw — le repli de l'hôte, sinon rien.
      return unknownEntryBuilder?.call(context, slot, entry);
    }
    final Widget? icon = entry.icon;
    if (icon == null) return tile;
    return _ZChatSettingsIconRow(icon: icon, gap: gap, child: tile);
  }

  /// Le rendu commun des kinds à SEGMENTS (`select`/`scale`) — la primitive
  /// exacte des familles standard : même groupe, mêmes options, même emphase
  /// CR-74 (c'est ce qui rend la re-expression indolore, garde RX-1).
  Widget _choicesGroup(
    BuildContext context,
    ZChatSettingsEntry entry,
    List<ZChatSettingsChoice> choices,
    Widget? selectionMark,
    Widget? footer,
    double gap,
  ) => _ZChatSettingsGroup(
    labelKey: entry.title.labelKey,
    text: entry.title.text,
    subtitle: entry.subtitle == null
        ? null
        : _resolveLabel(context, entry.subtitle!, null),
    gap: gap,
    options: <_ZChatSettingsOption>[
      for (final ZChatSettingsChoice c in choices)
        if (c.label.labelKey != null && c.enabled)
          _ZChatSettingsOption.key(
            labelKey: c.label.labelKey!,
            count: c.count,
            selected: c.selected,
            onTap: c.onTap,
            mark: selectionMark,
          )
        else
          _ZChatSettingsOption.host(
            text: _resolveLabel(context, c.label, c.count),
            enabled: c.enabled,
            selected: c.selected,
            onTap: c.onTap,
            mark: selectionMark,
          ),
    ],
    footer: footer,
  );

  // ── Les CINQ familles standard, RE-EXPRIMÉES en entrées (arbitrage 1) ─────

  /// L'EN-TÊTE par défaut — la forme lex (`tools_sheet.dart:44-61`) : le titre,
  /// « réinitialiser » (le `reset()` déjà corrigé du contrôleur), et
  /// « fermer ».
  ///
  /// 🔴 **Hôte passif inchangé** : sans [onClose] ni [headerBuilder], aucun
  /// en-tête n'est monté — l'arbre d'avant ce lot, à l'identique. L'en-tête
  /// par défaut n'apparaît que lorsque l'hôte fournit le geste de fermeture
  /// (c'est lui qui possède le conteneur, F11) ; un hôte qui veut l'en-tête
  /// sans « fermer » passe son [headerBuilder].
  Widget? _header(BuildContext context, ZChatSettingsSlot slot) {
    final VoidCallback? close = onClose;
    if (close == null) return null;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                zChatLabel(context, kZChatLabelSettings),
                // AD-13 : jamais `TextAlign.left`.
                textAlign: TextAlign.start,
              ),
            ),
          ),
          // 🔴 CR-IFFD-75 : chaque action réserve la moitié de l'écart résolu
          // de chaque côté de son libellé — deux actions bord à bord restent
          // distinctes quel que soit leur libellé. `Flexible` (loose) : sous
          // un petit écran, un libellé trop large passe à la ligne au lieu de
          // faire déborder la Row (l'`Expanded` du titre se comprime déjà).
          Flexible(
            child: _ZChatSettingsAction(
              labelKey: kZChatLabelSettingsReset,
              onTap: slot.controller.reset,
              inset: resolveActionGap(context) / 2,
            ),
          ),
          Flexible(
            child: _ZChatSettingsAction(
              labelKey: kZChatLabelSettingsClose,
              onTap: close,
              inset: resolveActionGap(context) / 2,
            ),
          ),
        ],
      ),
    );
  }

  /// La tuile de PRÉRÉGLAGES — absente sans catalogue d'hôte (AD-4). Lot K2
  /// (T2) : « Aucun » restitue l'état d'avant le premier préréglage
  /// (`clearPreset`), un préréglage l'applique avec mémoire (`applyPreset`).
  Widget? _presets(BuildContext context, ZChatSettingsSlot slot) {
    if (slot.presetCatalog.isEmpty) return null;
    // 🔴 Tranche dédiée, écoutée AU PLUS BAS : appliquer un préréglage change
    // aussi les tranches settings/scope (qui reconstruisent le corps), mais un
    // simple retrait/retour n'abonne rien d'autre que cette tuile (SM-1).
    return ValueListenableBuilder<String?>(
      valueListenable: slot.controller.activePresetId,
      builder: (BuildContext context, String? active, Widget? _) =>
          _ZChatSettingsGroup(
            labelKey: kZChatLabelPresets,
            gap: resolveGap(context),
            options: <_ZChatSettingsOption>[
              _ZChatSettingsOption.key(
                labelKey: kZChatLabelPresetNone,
                selected: active == null,
                onTap: slot.controller.clearPreset,
              ),
              for (final ZChatSettingsPreset preset in slot.presetCatalog)
                _ZChatSettingsOption.host(
                  text: preset.label,
                  selected: active == preset.id,
                  onTap: () => slot.controller.applyPreset(
                    preset.id,
                    preset.settings,
                    preset.corpusScope,
                  ),
                ),
            ],
          ),
    );
  }

  /// La famille « verbosité » — une [ZChatSettingsEntry] de kind `select`,
  /// rendue par la voie commune. Rendu STRICTEMENT identique à l'ancienne
  /// tuile (garde RX-1) ; les gestes restent ceux du contrôleur.
  Widget? _responseLength(BuildContext context, ZChatSettingsSlot slot) =>
      _renderEntry(
        context,
        slot,
        ZChatSettingsEntry(
          id: kZChatSettingsEntryResponseLength,
          title: const ZChatSettingsLabel.key(kZChatLabelResponseLength),
          control: ZChatSelectControl(
            choices: <ZChatSettingsChoice>[
              ZChatSettingsChoice(
                label: const ZChatSettingsLabel.key(kZChatLabelSettingAuto),
                selected: slot.settings.responseLength == null,
                onTap: () => slot.controller.setResponseLength(null),
              ),
              for (final MapEntry<ZChatResponseLength, String> e
                  in _kResponseLengthLabels.entries)
                ZChatSettingsChoice(
                  label: ZChatSettingsLabel.key(e.value),
                  selected: slot.settings.responseLength == e.key,
                  onTap: () => slot.controller.setResponseLength(e.key),
                ),
            ],
          ),
        ),
      );

  Widget? _lengthBias(BuildContext context, ZChatSettingsSlot slot) =>
      _renderEntry(
        context,
        slot,
        ZChatSettingsEntry(
          id: kZChatSettingsEntryLengthBias,
          title: const ZChatSettingsLabel.key(kZChatLabelLengthBias),
          control: ZChatSelectControl(
            choices: <ZChatSettingsChoice>[
              ZChatSettingsChoice(
                label: const ZChatSettingsLabel.key(kZChatLabelSettingAuto),
                selected: slot.settings.lengthBias == null,
                onTap: () => slot.controller.setLengthBias(null),
              ),
              for (final MapEntry<ZChatLengthBias, String> e
                  in _kLengthBiasLabels.entries)
                ZChatSettingsChoice(
                  label: ZChatSettingsLabel.key(e.value),
                  selected: slot.settings.lengthBias == e.key,
                  onTap: () => slot.controller.setLengthBias(e.key),
                ),
            ],
          ),
        ),
      );

  Widget? _computeBudget(BuildContext context, ZChatSettingsSlot slot) =>
      _renderEntry(
        context,
        slot,
        ZChatSettingsEntry(
          id: kZChatSettingsEntryComputeBudget,
          title: const ZChatSettingsLabel.key(kZChatLabelComputeBudget),
          // Une ÉCHELLE : les paliers sont ordonnés — et ils viennent des
          // BORNES du kernel (`1..5`), jamais d'une liste recopiée ici :
          // élargir l'intervalle côté kernel élargit la feuille, sans retouche.
          control: ZChatScaleControl(
            choices: <ZChatSettingsChoice>[
              ZChatSettingsChoice(
                label: const ZChatSettingsLabel.key(kZChatLabelSettingAuto),
                selected: slot.settings.computeEffort == null,
                onTap: () => slot.controller.setComputeEffort(null),
              ),
              for (
                int level = ZChatComputeEffort.min;
                level <= ZChatComputeEffort.max;
                level++
              )
                ZChatSettingsChoice(
                  label: const ZChatSettingsLabel.key(
                    kZChatLabelComputeBudgetLevel,
                  ),
                  count: level,
                  selected: slot.settings.computeEffort?.level == level,
                  onTap: () => slot.controller.setComputeEffort(
                    ZChatComputeEffort(level),
                  ),
                ),
            ],
            // 🔴 Lot K2 (T1) — l'ÉCHELLE LABELLISÉE de lex (`tools_sheet.dart:
            // 322-392`) : trois repères qualitatifs SOUS les paliers. Hors de
            // l'arbre sémantique — l'état est déjà annoncé par les options ;
            // les dupliquer ferait annoncer chaque palier deux fois (leçon
            // MAJEUR-doublon).
            // 🔴 Chaque repère est `Flexible` : mesuré au volet petit écran de
            // CR-75 (280 dp), la rangée fixe débordait de 58 px — le même
            // genre de défaut que l'en-tête (une largeur supposée, jamais
            // bornée). Un repère trop large passe à la ligne au lieu de faire
            // déborder la Row.
            footer: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      zChatLabel(context, kZChatLabelComputeBudgetFast),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      zChatLabel(context, kZChatLabelComputeBudgetBalanced),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      zChatLabel(context, kZChatLabelComputeBudgetDeep),
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget? _revealThinking(BuildContext context, ZChatSettingsSlot slot) =>
      _renderEntry(
        context,
        slot,
        ZChatSettingsEntry(
          id: kZChatSettingsEntryRevealThinking,
          title: const ZChatSettingsLabel.key(kZChatLabelRevealThinking),
          // ⚠️ PAS un kind `toggle` : l'axe du kernel est TERNAIRE
          // (`null`/`true`/`false` — « l'hôte décide » est un état rendu,
          // cf. kZChatLabelSettingAuto). Deux options, comme avant la
          // re-expression — et c'est ce que RX-1 fige.
          control: ZChatSelectControl(
            choices: <ZChatSettingsChoice>[
              ZChatSettingsChoice(
                label: const ZChatSettingsLabel.key(kZChatLabelSettingAuto),
                selected: slot.settings.revealThinkingSteps == null,
                onTap: () => slot.controller.setRevealThinkingSteps(null),
              ),
              ZChatSettingsChoice(
                label: const ZChatSettingsLabel.key(kZChatLabelRevealThinking),
                selected: slot.settings.revealThinkingSteps ?? false,
                onTap: () => slot.controller.setRevealThinkingSteps(
                  !(slot.settings.revealThinkingSteps ?? false),
                ),
              ),
            ],
          ),
        ),
      );

  /// La famille « CAPACITÉS » par défaut — lot K4, le raccord de la tuile
  /// générique [ZChatSettingsCapabilityTile] sur le kernel K1
  /// (`ZChatGenerationSettings.capabilities` + `webSearch`).
  ///
  /// 🔴 L'entrée par défaut est la recherche web — la SEULE capacité que le
  /// socle nomme (`kZChatCapabilityWebSearch`), parce que le kernel la type
  /// (mesurée vivante chez les DEUX hôtes). Toute autre entrée vient du
  /// [capabilityCatalog] de l'hôte, clé opaque + libellé déjà localisé par
  /// lui : zéro libellé métier en dur (FR-26). Un hôte qui fournit sa propre
  /// entrée pour la clé réservée remplace celle du socle.
  ///
  /// La sélection lit `settings.capability(key)` — la lecture CANONIQUE du
  /// kernel (champ typé prioritaire) — et le geste est
  /// `ZChatSettingsController.toggleCapability` : demandé ⇔ non exprimé (le
  /// couple de la chip lex ; exprimer `false` reste possible par
  /// `setCapability`).
  Widget? _capabilities(BuildContext context, ZChatSettingsSlot slot) {
    final bool hostOverridesWebSearch = slot.capabilityCatalog.any(
      (ZChatSettingsHostOption o) =>
          o.key.trim() == kZChatCapabilityWebSearch,
    );
    final List<ZChatSettingsHostOption> options = <ZChatSettingsHostOption>[
      if (!hostOverridesWebSearch)
        ZChatSettingsHostOption(
          key: kZChatCapabilityWebSearch,
          label: zChatLabel(context, kZChatLabelCapabilityWebSearch),
        ),
      ...slot.capabilityCatalog,
    ];
    return ZChatSettingsCapabilityTile(
      label: zChatLabel(context, kZChatLabelCapabilities),
      options: options,
      selectedKeys: <String>{
        for (final ZChatSettingsHostOption o in options)
          if (slot.settings.capability(o.key) ?? false) o.key,
      },
      onToggle: slot.controller.toggleCapability,
      spacing: resolveGap(context),
    );
  }

  /// La portée documentaire — **absente** tant que l'hôte n'a fourni aucun
  /// corpus (AD-4). Le socle n'en invente pas.
  ///
  /// Lot K2 (T1) : **filtres à deux niveaux** — une entrée sélectionnée dont
  /// le catalogue porte des [ZChatCorpusOption.children] déroule sa rangée de
  /// filtres (« Tous » + une option par enfant), le mécanisme lex
  /// (`tools_sheet.dart:571-645`). Désélectionner l'entrée retire aussi ses
  /// clés d'enfants : une portée ne garde jamais de clé orpheline.
  Widget? _corpus(BuildContext context, ZChatSettingsSlot slot) {
    if (slot.corpusCatalog.isEmpty) return null;
    final double gap = resolveGap(context);
    final List<Widget> childRows = <Widget>[
      for (final ZChatCorpusOption option in slot.corpusCatalog)
        if (option.children.isNotEmpty &&
            slot.controller.selectsCorpusKey(option.key))
          Padding(
            // AD-13 : indentation DIRECTIONNELLE du second niveau.
            padding: EdgeInsetsDirectional.only(start: gap * 2, top: gap),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                _ZChatSettingsOption.key(
                  labelKey: kZChatLabelCorpusAll,
                  selected: !option.children.any(
                    (ZChatCorpusOption c) =>
                        slot.controller.selectsCorpusKey(c.key),
                  ),
                  onTap: () => _removeKeys(
                    slot,
                    option.children.map((ZChatCorpusOption c) => c.key),
                  ),
                ),
                for (final ZChatCorpusOption child in option.children)
                  _ZChatSettingsOption.host(
                    text: child.label,
                    enabled: child.enabled,
                    selected: slot.controller.selectsCorpusKey(child.key),
                    onTap: () => slot.controller.toggleCorpusKey(child.key),
                  ),
              ],
            ),
          ),
    ];
    return _renderEntry(
      context,
      slot,
      ZChatSettingsEntry(
        id: kZChatSettingsEntryCorpus,
        sectionId: kZChatSettingsSectionCorpus,
        title: const ZChatSettingsLabel.key(kZChatLabelCorpusScope),
        control: ZChatSelectControl(
          choices: <ZChatSettingsChoice>[
            ZChatSettingsChoice(
              label: const ZChatSettingsLabel.key(kZChatLabelCorpusAll),
              selected: slot.corpusScope == null,
              onTap: () => slot.controller.setCorpusScope(null),
            ),
            for (final ZChatCorpusOption option in slot.corpusCatalog)
              ZChatSettingsChoice(
                // 🔴 Le libellé vient de l'HÔTE : pas de clé, pas de
                // traduction du socle. C'est ce qui tient « aucune valeur
                // métier ici ».
                label: ZChatSettingsLabel.text(option.label),
                enabled: option.enabled,
                selected: slot.controller.selectsCorpusKey(option.key),
                onTap: () => option.children.isNotEmpty &&
                        slot.controller.selectsCorpusKey(option.key)
                    // Désélection d'un parent : ses enfants sortent AVEC lui.
                    ? _removeKeys(slot, <String>[
                        option.key,
                        ...option.children.map((ZChatCorpusOption c) => c.key),
                      ])
                    : slot.controller.toggleCorpusKey(option.key),
              ),
          ],
          footer: childRows.isEmpty
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: childRows,
                ),
        ),
      ),
    );
  }

  /// Retire [keys] de la portée courante, par le geste public du contrôleur
  /// (`setCorpusScope` — l'un des deux écrivains, jamais un canal parallèle).
  void _removeKeys(ZChatSettingsSlot slot, Iterable<String> keys) {
    final Set<String> removed = keys.toSet();
    final List<String> next = <String>[
      for (final String k
          in slot.corpusScope?.corpusKeys ?? const <String>[])
        if (!removed.contains(k)) k,
    ];
    slot.controller.setCorpusScope(
      next.isEmpty ? null : ZChatCorpusScope.ofKeys(next),
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

/// Un groupe de réglage : un intitulé, puis ses options — et, depuis le lot
/// K2, un [footer] optionnel (échelle labellisée du budget, second niveau de
/// filtres du corpus). `null` ⇒ absent (AD-4).
class _ZChatSettingsGroup extends StatelessWidget {
  const _ZChatSettingsGroup({
    required this.options,
    required this.gap,
    this.labelKey,
    this.text,
    this.subtitle,
    this.footer,
  }) : assert((labelKey == null) != (text == null));

  /// Titre par CLÉ du socle — exclusif de [text]. La distinction reste une
  /// propriété du site d'appel (les familles standard passent la clé, les
  /// entrées d'hôte leur texte déjà localisé).
  final String? labelKey;

  /// Titre d'HÔTE, déjà résolu. Exclusif de [labelKey].
  final String? text;

  /// Sous-titre déjà résolu (mode Tile, arbitrage 1). `null` ⇒ absent (AD-4)
  /// — et l'arbre redevient EXACTEMENT celui d'avant la re-expression.
  final String? subtitle;

  final List<_ZChatSettingsOption> options;
  final double gap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final String title = text ?? zChatLabel(context, labelKey!);
    final String? sub = subtitle;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      // Le sous-titre entre dans le libellé du groupe : un lecteur d'écran
      // l'entend, sans nœud supplémentaire (leçon MAJEUR-doublon).
      label: sub == null ? title : '$title\n$sub',
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
              title,
              // AD-13 : jamais `TextAlign.left`.
              textAlign: TextAlign.start,
            ),
          ),
          if (sub != null)
            ExcludeSemantics(
              child: Text(sub, textAlign: TextAlign.start),
            ),
          SizedBox(height: gap),
          Wrap(spacing: gap, runSpacing: gap, children: options),
          ?footer,
        ],
      ),
    );
  }
}

/// Une ACTION de l'en-tête (réinitialiser, fermer) : cible ≥ 48 dp en
/// géométrie rendue, `Semantics(button:)` — jamais `selected`, ce n'est pas un
/// choix. Lot K2 (T1).
///
/// 🔴 **CR-IFFD-75 — le dégagement vit ICI, dans la primitive.** Le plancher
/// 48 dp est une borne *basse* : un libellé plus large fait grandir la boîte
/// et deux actions voisines finissent bord à bord (« RéinitialiserFermer »,
/// mesuré sur appareil en français — invisible en anglais). Chaque action
/// réserve donc [inset] de chaque côté de son libellé, en
/// `EdgeInsetsDirectional` : la garantie tient en LTR comme en RTL, et pour
/// toute surface future qui poserait cette primitive ailleurs que dans
/// l'en-tête.
class _ZChatSettingsAction extends StatelessWidget {
  const _ZChatSettingsAction({
    required this.labelKey,
    required this.onTap,
    this.inset = kZChatSettingsReferenceActionGap / 2,
  });

  final String labelKey;
  final VoidCallback onTap;

  /// Dégagement horizontal réservé de CHAQUE côté du libellé — la moitié de
  /// l'écart garanti entre deux actions adjacentes (CR-IFFD-75).
  final double inset;

  @override
  Widget build(BuildContext context) {
    final String resolved = zChatLabel(context, labelKey);
    return Semantics(
      button: true,
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
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              // 🔴 CR-IFFD-75 : le dégagement, directionnellement symétrique.
              padding: EdgeInsetsDirectional.symmetric(horizontal: inset),
              child: Text(resolved, textAlign: TextAlign.start),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tuile GÉNÉRIQUE « échelle discrète » — lot K2 (T1, fusion F4 de l'étude) :
/// un axe d'HÔTE (niveau de connaissance, sévérité, …) rendu avec la même
/// primitive que les cinq familles — donc la même emphase CR-74, la même
/// sémantique, les mêmes cibles 48 dp.
///
/// L'état de l'axe appartient à l'HÔTE ([selectedKey]/[onSelect]) : le socle
/// n'a nulle part où ranger un « niveau utilisateur » (`UserKnowledgeLevel` lex
/// et `NiveauIFFD` sont des valeurs métier). Chips plutôt que slider : le
/// verdict F4 de l'étude (cibles 48 dp, aucun Syncfusion).
class ZChatSettingsScaleTile extends StatelessWidget {
  /// Construit la tuile.
  const ZChatSettingsScaleTile({
    required this.label,
    required this.options,
    required this.onSelect,
    this.selectedKey,
    this.spacing,
    super.key,
  });

  /// Intitulé du groupe, **déjà localisé par l'hôte**.
  final String label;

  /// Les échelons, dans l'ordre de l'échelle.
  final List<ZChatSettingsHostOption> options;

  /// Échelon choisi, ou `null`.
  final String? selectedKey;

  /// Choix d'un échelon — l'hôte range la valeur chez lui.
  final ValueChanged<String> onSelect;

  /// Interligne. `null` ⇒ jeton `gapS`, puis référence.
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final double gap =
        spacing ??
        ZcrudScope.maybeOf(context)?.theme?.gapS ??
        kZChatSettingsReferenceGap;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Text(label, textAlign: TextAlign.start),
          ),
          SizedBox(height: gap),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final ZChatSettingsHostOption option in options)
                _ZChatSettingsOption.host(
                  text: option.label,
                  enabled: option.enabled,
                  selected: option.key == selectedKey,
                  onTap: () => onSelect(option.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tuile GÉNÉRIQUE « capacités booléennes » — lot K2 (T1, fusion F6) : des
/// interrupteurs d'HÔTE (recherche web, résumé, …) rendus par la primitive
/// commune. Le socle ne code AUCUNE capacité en dur — quand le kernel portera
/// ses capacités (`ZChatGenerationSettings`, lot K1 en vol), la feuille
/// gagnera une famille par défaut qui s'appuiera sur cette même tuile.
class ZChatSettingsCapabilityTile extends StatelessWidget {
  /// Construit la tuile.
  const ZChatSettingsCapabilityTile({
    required this.label,
    required this.options,
    required this.selectedKeys,
    required this.onToggle,
    this.spacing,
    super.key,
  });

  /// Intitulé du groupe, **déjà localisé par l'hôte**.
  final String label;

  /// Les capacités proposées.
  final List<ZChatSettingsHostOption> options;

  /// Clés des capacités ACTIVES.
  final Set<String> selectedKeys;

  /// Bascule d'une capacité — l'hôte range la valeur chez lui.
  final ValueChanged<String> onToggle;

  /// Interligne. `null` ⇒ jeton `gapS`, puis référence.
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final double gap =
        spacing ??
        ZcrudScope.maybeOf(context)?.theme?.gapS ??
        kZChatSettingsReferenceGap;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Text(label, textAlign: TextAlign.start),
          ),
          SizedBox(height: gap),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final ZChatSettingsHostOption option in options)
                _ZChatSettingsOption.host(
                  text: option.label,
                  enabled: option.enabled,
                  selected: selectedKeys.contains(option.key),
                  onTap: () => onToggle(option.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une option d'HÔTE des tuiles génériques : clé stable, libellé localisé par
/// l'hôte, disponibilité. Lot K2 (T1).
@immutable
class ZChatSettingsHostOption {
  /// Construit une option.
  const ZChatSettingsHostOption({
    required this.key,
    required this.label,
    this.enabled = true,
  });

  /// Clé **stable et opaque** — jamais un libellé.
  final String key;

  /// Libellé **déjà localisé par l'hôte**.
  final String label;

  /// `false` ⇒ présente mais non sélectionnable (sémantique `enabled: false` +
  /// italique — deux canaux, aucun chromatique).
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSettingsHostOption &&
          key == other.key &&
          label == other.label &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(key, label, enabled);
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
    this.mark,
  }) : text = null,
       enabled = true;

  /// Option dont le libellé est **fourni par l'hôte** (catalogue de corpus).
  ///
  /// 🔴 Deux constructeurs plutôt qu'un couple de champs nullables : « exactement
  /// l'une des deux sources » devient une propriété du TYPE, pas une convention
  /// qu'un appel futur pourrait enfreindre en passant les deux — ou aucune.
  const _ZChatSettingsOption.host({
    required String this.text,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.mark,
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

  /// `false` ⇒ NON sélectionnable — l'« entrée non indexée » de lex, rendue
  /// SANS couleur : sémantique `enabled: false` + italique (lot K2). Le geste
  /// est retiré, jamais silencieusement ignoré.
  final bool enabled;

  /// Glyphe d'HÔTE posé DEVANT le libellé de l'option **choisie** — la coche
  /// des segments lex (lot Tile). `null` ⇒ l'emphase CR-74 seule, et l'arbre
  /// redevient EXACTEMENT celui d'avant ce lot (garde RX-1). Décoratif :
  /// hors de l'arbre sémantique — l'état est déjà annoncé par `selected`.
  final Widget? mark;

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
    if (!enabled) {
      // 🔴 Entrée NON disponible (lot K2) — deux canaux, aucun chromatique :
      // la sémantique `enabled: false` (lecteur d'écran) ET l'italique (vue).
      // lex la grise en alpha 0.38 — une information portée par la seule
      // couleur, le défaut que CR-74 a déjà fermé ici.
      return Semantics(
        button: true,
        enabled: false,
        label: resolved,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              resolved,
              style: styles.plain.copyWith(fontStyle: FontStyle.italic),
              textAlign: TextAlign.start,
            ),
          ),
        ),
      );
    }
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
            child: _withMark(
              Text(
                resolved,
                // 🔴 Le style est posé EXPLICITEMENT sur les deux états :
                // c'est ce qui rend la différence mesurable sur le
                // `RenderParagraph`, et non « présente quelque part dans
                // l'arbre ».
                style: selected ? styles.chosen : styles.plain,
                // AD-13 : jamais `TextAlign.left`.
                textAlign: TextAlign.start,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pose le glyphe d'hôte devant le libellé de l'option CHOISIE — et rend le
  /// libellé SEUL partout ailleurs : sans [mark], l'arbre est celui d'avant ce
  /// lot, au widget près (garde RX-1).
  Widget _withMark(Widget label) {
    final Widget? m = mark;
    if (m == null || !selected) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Décoratif : l'état est déjà porté par `Semantics(selected:)`.
        ExcludeSemantics(child: m),
        const SizedBox(width: kZChatSettingsReferenceMarkGap),
        label,
      ],
    );
  }
}

/// La rangée « icône + tuile » du mode Tile (IFFD/f007) — l'icône est un
/// glyphe d'HÔTE, décoratif (hors arbre sémantique : le titre est déjà
/// annoncé par la tuile).
class _ZChatSettingsIconRow extends StatelessWidget {
  const _ZChatSettingsIconRow({
    required this.icon,
    required this.gap,
    required this.child,
  });

  final Widget icon;
  final double gap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(child: icon),
        SizedBox(width: gap),
        Expanded(child: child),
      ],
    );
  }
}

/// Le corps « titre + sous-titre » commun aux tuiles non segmentées.
class _ZChatSettingsTileBody extends StatelessWidget {
  const _ZChatSettingsTileBody({required this.title, this.subtitle, this.value});

  final String title;
  final String? subtitle;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      // AD-13 : alignement DIRECTIONNEL.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, textAlign: TextAlign.start),
        if (subtitle != null) Text(subtitle!, textAlign: TextAlign.start),
        if (value != null) Text(value!, textAlign: TextAlign.start),
      ],
    );
  }
}

/// Tuile par défaut du kind `toggle` — la `ToolTile` d'IFFD sans sa coche
/// orange en dur : l'état est porté par la sémantique (`toggled:`) ET par un
/// canal visible non chromatique (libellé Activé/Désactivé + emphase CR-74
/// quand actif). Toute la tuile est la cible (≥ 48 dp en géométrie rendue).
class _ZChatSettingsToggleTile extends StatelessWidget {
  const _ZChatSettingsToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.gap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final String state = zChatLabel(
      context,
      value ? kZChatLabelToggleOn : kZChatLabelToggleOff,
    );
    final _ZChatSettingsEmphasis? emphasis =
        _ZChatSettingsEmphasis.maybeOf(context);
    final ({TextStyle plain, TextStyle chosen}) styles = _optionStyles(
      DefaultTextStyle.of(context).style,
      weight: emphasis?.weight ?? kZChatSettingsReferenceSelectedWeight,
      decoration:
          emphasis?.decoration ?? kZChatSettingsReferenceSelectedDecoration,
    );
    void toggle() => onChanged(!value);
    return Semantics(
      // 🔴 L'état par le drapeau `toggled` (lecteur d'écran) ET par le texte
      // d'état stylé (vue) — deux canaux, aucun chromatique (leçon CR-74).
      button: true,
      toggled: value,
      label: subtitle == null ? title : '$title\n$subtitle',
      value: state,
      excludeSemantics: true,
      onTap: toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _ZChatSettingsTileBody(title: title, subtitle: subtitle),
              ),
              SizedBox(width: gap),
              Text(
                state,
                style: value ? styles.chosen : styles.plain,
                textAlign: TextAlign.start,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile par défaut du kind `navigation` — le « Domaine d'expertise » d'IFFD :
/// titre, valeur courante d'hôte, glyphe de fin d'hôte. La destination
/// appartient à l'hôte ; le socle rend l'affordance (`Semantics(button:)`,
/// cible ≥ 48 dp).
class _ZChatSettingsNavigationTile extends StatelessWidget {
  const _ZChatSettingsNavigationTile({
    required this.title,
    required this.onTap,
    required this.gap,
    this.subtitle,
    this.value,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback onTap;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final Widget? end = trailing;
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title\n$subtitle',
      value: value,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _ZChatSettingsTileBody(
                  title: title,
                  subtitle: subtitle,
                  value: value,
                ),
              ),
              if (end != null) ...<Widget>[
                SizedBox(width: gap),
                // Décoratif (le chevron) : l'affordance est déjà annoncée.
                ExcludeSemantics(child: end),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile par défaut du kind `numberBounded` — les bornes sont APPLIQUÉES :
/// l'affordance hors borne est désactivée (sémantique `enabled: false`) et le
/// geste n'émet jamais une valeur hors `[min, max]` (AD-10). Le
/// `MinMaxFormatter` mort d'IFFD n'est pas porté ; la saisie texte
/// pixel-perfect est l'affaire du satellite Material.
class _ZChatSettingsNumberTile extends StatelessWidget {
  const _ZChatSettingsNumberTile({
    required this.title,
    required this.control,
    required this.gap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final ZChatNumberControl control;
  final double gap;

  @override
  Widget build(BuildContext context) {
    // Valeur ÉCRÊTÉE au rendu : un hôte qui passe 12 sur [0, 9] voit 9 —
    // jamais un throw, jamais un état inatteignable (AD-10).
    final int value = control.value.clamp(control.min, control.max);
    final bool canDecrease = value - control.step >= control.min;
    final bool canIncrease = value + control.step <= control.max;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: subtitle == null ? title : '$title\n$subtitle',
      child: Row(
        children: <Widget>[
          Expanded(
            child: ExcludeSemantics(
              child: _ZChatSettingsTileBody(title: title, subtitle: subtitle),
            ),
          ),
          _ZChatSettingsStepTarget(
            labelKey: kZChatLabelDecrease,
            enabled: canDecrease,
            glyph: control.decrementGlyph,
            onTap: () => control.onChanged(value - control.step),
          ),
          SizedBox(width: gap),
          Semantics(
            // La valeur courante, annoncée comme telle.
            label: title,
            value: '$value',
            excludeSemantics: true,
            child: Text(value.toString(), textAlign: TextAlign.start),
          ),
          SizedBox(width: gap),
          _ZChatSettingsStepTarget(
            labelKey: kZChatLabelIncrease,
            enabled: canIncrease,
            glyph: control.incrementGlyph,
            onTap: () => control.onChanged(value + control.step),
          ),
        ],
      ),
    );
  }
}

/// Une affordance de PAS du nombre borné : cible ≥ 48 dp en géométrie rendue,
/// `Semantics(button:, enabled:)` — le geste est RETIRÉ hors borne, jamais
/// silencieusement ignoré.
class _ZChatSettingsStepTarget extends StatelessWidget {
  const _ZChatSettingsStepTarget({
    required this.labelKey,
    required this.enabled,
    required this.onTap,
    this.glyph,
  });

  final String labelKey;
  final bool enabled;
  final VoidCallback onTap;

  /// Glyphe d'HÔTE. `null` ⇒ le libellé résolu (le socle n'invente aucun
  /// glyphe — `material` banni).
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final String resolved = zChatLabel(context, labelKey);
    final Widget face = glyph == null
        ? Text(resolved, textAlign: TextAlign.start)
        : glyph!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: resolved,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL. Facteurs posés : sous un `Row`
            // parent la boîte épouse déjà son enfant, mais la défense vaut si
            // cette cible est un jour posée sous des contraintes bornées
            // (précédent `_ZChatComposerTarget`, mesuré).
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            child: face,
          ),
        ),
      ),
    );
  }
}

/// État réactif des **réglages de génération** — `ZChatSettingsController`
/// (lot γ0/δ du chantier Notebook/Chat, suite de l'étude CR-IFFD-72).
///
/// ## 🔴 Ce fichier n'invente AUCUN réglage
///
/// Les quatre axes réglables et la portée documentaire sont **déjà modélisés**
/// dans `zcrud_chat_kernel` (lot β) :
///
/// | Axe | Type porté | Déclaré où |
/// |---|---|---|
/// | verbosité | `ZChatResponseLength` | `z_chat_enums.dart` (CHAT-0) |
/// | biais de régénération | `ZChatLengthBias` | `z_chat_enums.dart` (CHAT-0) |
/// | budget de calcul `1..5` | `ZChatComputeEffort` | `z_chat_compute_effort.dart` (CHAT-1) |
/// | étapes de raisonnement | `bool?` sur `ZChatGenerationSettings` | lot β |
/// | portée documentaire | `ZChatCorpusScope` (clés stables) | lot β |
///
/// Le risque n°1 nommé par CR-IFFD-72 est « reconstruire la moitié de
/// `zcrud_chat_kernel` ». Ce contrôleur **transporte** ces valeurs ; il ne
/// déclare ni enum, ni palier, ni équivalent. Une garde de source l'atteste
/// (`z_chat_settings_guard_test.dart`, groupe ANTI-RÉINVENTION).
///
/// ## 🔴 Pourquoi ce n'est PAS un membre de `ZChatController`
///
/// La garde **G-CH1** asserte l'**égalité d'ensemble** des membres publics du
/// contrôleur de conversation : tout membre ajouté la fait rougir, et c'est
/// voulu — chaque membre public qui *exécute* est un site d'appel de plus, donc
/// une divergence possible entre deux surfaces d'UI (le défaut IFFD des deux
/// barres d'actions parallèles). Les réglages sont donc un **objet d'état
/// séparé**, exactement comme `ZChatCaptureController` l'est pour la dictée : on
/// les **passe** à `send(settings:, corpusScope:)`, on ne les greffe pas sur le
/// contrôleur.
///
/// ## 🔴 AD-2/SM-1 — deux tranches, pas un `ChangeNotifier`
///
/// Il n'y a **aucun** canal global ici : deux `ValueNotifier` indépendants,
/// dimensionnés sur ce qui change ensemble. Régler la verbosité ne reconstruit
/// pas la liste des corpus, et **rien** de ce fichier n'est branché sur la
/// tranche de messages : ouvrir, régler puis fermer la feuille ne reconstruit
/// aucune tuile de conversation (mesuré — `SET-M1`).
///
/// ## Pourquoi des constructions explicites plutôt que `copyWith`
///
/// `ZChatGenerationSettings.copyWith` **ne peut pas retirer** un réglage : y
/// passer `null` est indistinguable d'un paramètre omis (le kernel le dit dans
/// son propre dartdoc, et refuse les drapeaux `clear*` de lex parce qu'ils
/// heurtent la garde G16). Or « revenir à *l'hôte décide* » est un geste
/// d'utilisateur de premier plan sur une feuille de réglages. Chaque geste
/// **construit** donc la valeur en nommant les quatre champs — c'est la seule
/// forme qui rend le retrait exprimable.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Un PRÉRÉGLAGE de génération fourni par l'HÔTE — lot K2 (chantier
/// composer-lex, T2).
///
/// C'est l'« expert IA » de lex rendu **neutre** : un identifiant stable, un
/// libellé **déjà localisé par l'hôte**, et les valeurs qu'appliquer
/// ([settings] + [corpusScope]). Le socle ne connaît ni douane ni pédagogie :
/// il applique, mémorise l'état d'avant, et sait le rendre
/// ([ZChatSettingsController.applyPreset]/[ZChatSettingsController.clearPreset]).
///
/// Le contre-modèle mesuré est l'écrasement destructif d'IFFD (`setAiExpert`
/// écrase 13 réglages et sa branche `null` remet des défauts DIFFÉRENTS des
/// défauts initiaux — `discovry_page_controller.dart:733-781`).
@immutable
class ZChatSettingsPreset {
  /// Construit un préréglage.
  const ZChatSettingsPreset({
    required this.id,
    required this.label,
    this.settings = const ZChatGenerationSettings(),
    this.corpusScope,
  });

  /// Identifiant **stable et opaque** — jamais un libellé.
  final String id;

  /// Libellé affiché, **fourni et localisé par l'hôte**.
  final String label;

  /// Réglages appliqués par le préréglage.
  final ZChatGenerationSettings settings;

  /// Portée documentaire appliquée, ou `null` ⇒ aucune restriction.
  final ZChatCorpusScope? corpusScope;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSettingsPreset &&
          id == other.id &&
          label == other.label &&
          settings == other.settings &&
          corpusScope == other.corpusScope;

  @override
  int get hashCode => Object.hash(id, label, settings, corpusScope);
}

/// Porte les réglages de génération choisis par l'utilisateur, en **tranches
/// réactives granulaires**.
///
/// Ni créé ni disposé par un widget : son cycle de vie appartient à l'hôte
/// (AD-2), comme celui de `ZChatController`. Le rendu par défaut est
/// `ZChatSettingsSheet` ; la valeur courante rejoint la requête par
/// `ZChatController.send(settings:, corpusScope:)` — chemin que le composer
/// câble pour l'hôte lorsqu'on lui passe ce contrôleur.
class ZChatSettingsController {
  /// Construit un contrôleur de réglages.
  ///
  /// [settings] vide et [corpusScope] `null` — les défauts — signifient
  /// « l'hôte décide » et « aucune restriction » : c'est **exactement** le
  /// comportement d'avant ce lot.
  ZChatSettingsController({
    ZChatGenerationSettings settings = const ZChatGenerationSettings(),
    ZChatCorpusScope? corpusScope,
  }) : _settings = ValueNotifier<ZChatGenerationSettings>(settings),
       _corpusScope = ValueNotifier<ZChatCorpusScope?>(corpusScope),
       _activeCount = ValueNotifier<int>(
         _countOf(settings, corpusScope),
       );

  final ValueNotifier<ZChatGenerationSettings> _settings;
  final ValueNotifier<ZChatCorpusScope?> _corpusScope;
  final ValueNotifier<String?> _activePresetId = ValueNotifier<String?>(null);
  final ValueNotifier<int> _activeCount;

  /// État sauvegardé AVANT le premier préréglage — restitué par [clearPreset].
  ///
  /// C'est le `preExpertToolsContext` de lex
  /// (`chat_input_controller.dart:333-350`), généralisé : sauvegardé seulement
  /// si aucun préréglage n'était actif, CONSERVÉ quand on passe d'un
  /// préréglage à un autre — restaurer rend toujours l'état d'AVANT le
  /// premier.
  ({ZChatGenerationSettings settings, ZChatCorpusScope? scope})? _prePreset;

  // ── Tranches réactives ────────────────────────────────────────────────────

  /// Réglages courants. Ne signale qu'aux changements de **valeur** : un
  /// `ValueNotifier` ignore une valeur `==` égale, et `ZChatGenerationSettings`
  /// implémente `==` par valeur — re-choisir le palier déjà choisi ne
  /// reconstruit donc rien.
  ValueListenable<ZChatGenerationSettings> get settings => _settings;

  /// Portée documentaire courante, ou `null` ⇒ **aucune restriction**.
  ///
  /// Tranche **distincte** de [settings] : cocher un corpus ne reconstruit pas
  /// les tuiles de verbosité, et régler la verbosité ne reconstruit pas la
  /// liste des corpus (AD-2).
  ValueListenable<ZChatCorpusScope?> get corpusScope => _corpusScope;

  /// Identifiant du PRÉRÉGLAGE actif, ou `null` — lot K2 (T2).
  ///
  /// Il reste actif tant qu'on ne l'a pas retiré ([clearPreset]/[reset]) : un
  /// réglage manuel par-dessus ne le révoque pas — même règle que lex, où
  /// modifier un outil ne désélectionne pas l'expert.
  ValueListenable<String?> get activePresetId => _activePresetId;

  /// Nombre de demandes ACTIVES — lot K2 (F12, le `toolsCount` des deux apps
  /// rendu neutre) : axes non-« l'hôte décide » + clés de la portée (une portée
  /// sans clé — familles seules — compte pour 1).
  ///
  /// Tranche dédiée : le badge du bouton « outils » (créneau `tools` de
  /// l'hôte) l'écoute sans se reconstruire à chaque frappe ni s'abonner aux
  /// deux tranches sources (SM-1).
  ValueListenable<int> get activeCount => _activeCount;

  // ── Écriture — un seul écrivain par tranche ───────────────────────────────

  /// **L'unique écrivain** de la tranche [settings].
  ///
  /// Tous les gestes ci-dessous passent par ici : un geste qui écrirait
  /// directement dans le notifier serait un second site, donc la possibilité
  /// que deux gestes divergent — la classe de défaut que ce dépôt combat
  /// partout (garde de source `SET-F1`).
  void update(ZChatGenerationSettings value) {
    _settings.value = value;
    _activeCount.value = _countOf(value, _corpusScope.value);
  }

  /// **L'unique écrivain** de la tranche [corpusScope]. `null` ⇒ restriction
  /// retirée.
  void setCorpusScope(ZChatCorpusScope? value) {
    _corpusScope.value = value;
    _activeCount.value = _countOf(_settings.value, value);
  }

  /// Applique le préréglage [id] — lot K2 (T2, le `selectExpert` de lex rendu
  /// neutre, `chat_input_controller.dart:333-341`).
  ///
  /// Si aucun préréglage n'était actif, l'état courant est **sauvegardé**
  /// d'abord ; passer d'un préréglage à un autre conserve cette sauvegarde
  /// (c'est l'état d'AVANT le premier que [clearPreset] restitue). L'écriture
  /// passe par [update]/[setCorpusScope] — les uniques écrivains (SET-F4).
  void applyPreset(
    String id,
    ZChatGenerationSettings settings,
    ZChatCorpusScope? scope,
  ) {
    _prePreset ??= (settings: _settings.value, scope: _corpusScope.value);
    update(settings);
    setCorpusScope(scope);
    _activePresetId.value = id;
  }

  /// Retire le préréglage actif et RESTITUE l'état d'avant — lot K2 (T2, le
  /// `clearExpert` de lex, `chat_input_controller.dart:344-350`).
  ///
  /// Sans préréglage actif, l'appel est sans effet. La restitution est
  /// **exacte** (mesurée par la garde du lot, snapshot non vacant) — jamais des
  /// « défauts » réinventés, le contre-modèle IFFD.
  void clearPreset() {
    if (_activePresetId.value == null) return;
    final ({ZChatGenerationSettings settings, ZChatCorpusScope? scope})?
    saved = _prePreset;
    _prePreset = null;
    _activePresetId.value = null;
    if (saved == null) return;
    update(saved.settings);
    setCorpusScope(saved.scope);
  }

  /// Choisit la verbosité, ou la retire (`null` ⇒ « l'hôte décide »).
  void setResponseLength(ZChatResponseLength? value) =>
      update(_with(responseLength: value, keepResponseLength: false));

  /// Choisit le biais de longueur d'une régénération, ou le retire.
  void setLengthBias(ZChatLengthBias? value) =>
      update(_with(lengthBias: value, keepLengthBias: false));

  /// Choisit le budget de calcul (`1..5`, écrêté par le kernel), ou le retire.
  void setComputeEffort(ZChatComputeEffort? value) =>
      update(_with(computeEffort: value, keepComputeEffort: false));

  /// Demande — ou cesse de demander — l'exposition des étapes de raisonnement.
  void setRevealThinkingSteps(bool? value) =>
      update(_with(revealThinkingSteps: value, keepThinking: false));

  /// Exprime — ou retire (`null` ⇒ « l'hôte décide ») — la capacité [key]
  /// (kernel K1, lot K4). `true` la demande, `false` demande son **absence**
  /// (les deux comptent dans [activeCount] : ce sont des demandes).
  ///
  /// La clé réservée `kZChatCapabilityWebSearch` écrit le champ **typé**
  /// `webSearch` et n'entre jamais dans le canal ouvert — une seule écriture
  /// pour une seule lecture, l'invariant canonique du kernel. Toute autre clé
  /// va au canal ouvert, **rognée** ; une clé blanche est ignorée (AD-10).
  /// L'écriture passe par [update] — l'unique écrivain (SET-F1).
  void setCapability(String key, bool? value) {
    final String trimmed = key.trim();
    if (trimmed.isEmpty) return;
    if (trimmed == kZChatCapabilityWebSearch) {
      update(_with(webSearch: value, keepWebSearch: false));
      return;
    }
    final Map<String, bool> next = <String, bool>{
      for (final MapEntry<String, bool> e
          in _settings.value.capabilities.entries)
        if (e.key.trim() != trimmed) e.key: e.value,
      trimmed: ?value,
    };
    update(_with(capabilities: next, keepCapabilities: false));
  }

  /// Bascule la capacité [key] entre **demandée** (`true`) et **non exprimée**
  /// (« l'hôte décide ») — le geste de la tuile par défaut. Exprimer `false`
  /// (couper une capacité) reste possible par [setCapability] : la feuille par
  /// défaut n'offre que le couple demandé/retiré, comme la chip lex.
  void toggleCapability(String key) => setCapability(
        key,
        (_settings.value.capability(key) ?? false) ? null : true,
      );

  /// Bascule l'appartenance de [key] à la portée documentaire.
  ///
  /// Sémantique **portée de lex, rendue générique** : une sélection vide ne
  /// veut pas dire « aucun corpus », elle veut dire « tous » — la portée est
  /// alors remise à `null`, c'est-à-dire au comportement d'avant le lot β. Un
  /// hôte qui a besoin des **deux** niveaux (famille puis clés) construit sa
  /// portée et la pose par [setCorpusScope] : ce geste-ci ne couvre que le
  /// niveau 2, qui est la forme la plus courante côté hôte
  /// (`ZChatCorpusScope.ofKeys`).
  void toggleCorpusKey(String key) {
    final List<String> next = <String>[..._corpusScope.value?.corpusKeys ?? const <String>[]];
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    setCorpusScope(next.isEmpty ? null : ZChatCorpusScope.ofKeys(next));
  }

  /// `true` si [key] est dans la portée courante.
  bool selectsCorpusKey(String key) =>
      _corpusScope.value?.corpusKeys.contains(key) ?? false;

  /// Remet **tout** à « l'hôte décide » / « aucune restriction ».
  ///
  /// C'est le `resetToDefaults` de lex, sans son défaut : là-bas il remet des
  /// valeurs *inventées par l'application*, ici il remet l'**absence de
  /// demande** — le socle n'a aucun défaut à imposer (FR-26).
  void reset() {
    // Lot K2 : un préréglage encore affiché après un reset mentirait — il est
    // retiré, et sa sauvegarde avec lui (l'état restitué par `clearPreset`
    // n'aurait plus de sens une fois tout remis à « l'hôte décide »).
    _prePreset = null;
    _activePresetId.value = null;
    update(const ZChatGenerationSettings());
    setCorpusScope(null);
  }

  /// Libère les tranches. À appeler par l'hôte, qui possède l'instance.
  void dispose() {
    _settings.dispose();
    _corpusScope.dispose();
    _activePresetId.dispose();
    _activeCount.dispose();
  }

  /// Le comptage de [activeCount] — fonction PURE, donc mesurable seule.
  ///
  /// Lot K4 : les **capacités exprimées** comptent aussi —
  /// `expressedCapabilityKeys` est la forme CANONIQUE du kernel (le champ typé
  /// `webSearch` y figure sous `kZChatCapabilityWebSearch`, jamais compté
  /// deux fois), et `false` est une DEMANDE (couper une capacité est une
  /// demande active, pas une absence).
  static int _countOf(ZChatGenerationSettings s, ZChatCorpusScope? scope) {
    int count = 0;
    if (s.responseLength != null) count++;
    if (s.lengthBias != null) count++;
    if (s.computeEffort != null) count++;
    if (s.revealThinkingSteps != null) count++;
    count += s.expressedCapabilityKeys.length;
    if (scope != null) {
      final int keys = scope.corpusKeys.length;
      count += keys == 0 ? 1 : keys;
    }
    return count;
  }

  /// Construit la valeur suivante en **nommant chaque champ** — la seule
  /// forme qui permette de RETIRER un réglage (cf. le dartdoc de bibliothèque).
  ///
  /// 🔴 Lot K4 : les champs du kernel K1 ([ZChatGenerationSettings.webSearch],
  /// [ZChatGenerationSettings.capabilities]) sont TRANSPORTÉS tels quels —
  /// sans quoi régler la verbosité effacerait silencieusement les capacités
  /// (la construction explicite nomme TOUS les champs, pas seulement ceux
  /// d'avant K1).
  ZChatGenerationSettings _with({
    ZChatResponseLength? responseLength,
    bool keepResponseLength = true,
    ZChatLengthBias? lengthBias,
    bool keepLengthBias = true,
    ZChatComputeEffort? computeEffort,
    bool keepComputeEffort = true,
    bool? revealThinkingSteps,
    bool keepThinking = true,
    bool? webSearch,
    bool keepWebSearch = true,
    Map<String, bool>? capabilities,
    bool keepCapabilities = true,
  }) {
    final ZChatGenerationSettings current = _settings.value;
    return ZChatGenerationSettings(
      responseLength:
          keepResponseLength ? current.responseLength : responseLength,
      lengthBias: keepLengthBias ? current.lengthBias : lengthBias,
      computeEffort: keepComputeEffort ? current.computeEffort : computeEffort,
      revealThinkingSteps:
          keepThinking ? current.revealThinkingSteps : revealThinkingSteps,
      webSearch: keepWebSearch ? current.webSearch : webSearch,
      capabilities: (keepCapabilities ? current.capabilities : capabilities) ??
          const <String, bool>{},
    );
  }
}

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
       _corpusScope = ValueNotifier<ZChatCorpusScope?>(corpusScope);

  final ValueNotifier<ZChatGenerationSettings> _settings;
  final ValueNotifier<ZChatCorpusScope?> _corpusScope;

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

  // ── Écriture — un seul écrivain par tranche ───────────────────────────────

  /// **L'unique écrivain** de la tranche [settings].
  ///
  /// Tous les gestes ci-dessous passent par ici : un geste qui écrirait
  /// directement dans le notifier serait un second site, donc la possibilité
  /// que deux gestes divergent — la classe de défaut que ce dépôt combat
  /// partout (garde de source `SET-F1`).
  void update(ZChatGenerationSettings value) => _settings.value = value;

  /// **L'unique écrivain** de la tranche [corpusScope]. `null` ⇒ restriction
  /// retirée.
  void setCorpusScope(ZChatCorpusScope? value) => _corpusScope.value = value;

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
    update(const ZChatGenerationSettings());
    setCorpusScope(null);
  }

  /// Libère les deux tranches. À appeler par l'hôte, qui possède l'instance.
  void dispose() {
    _settings.dispose();
    _corpusScope.dispose();
  }

  /// Construit la valeur suivante en **nommant les quatre champs** — la seule
  /// forme qui permette de RETIRER un réglage (cf. le dartdoc de bibliothèque).
  ZChatGenerationSettings _with({
    ZChatResponseLength? responseLength,
    bool keepResponseLength = true,
    ZChatLengthBias? lengthBias,
    bool keepLengthBias = true,
    ZChatComputeEffort? computeEffort,
    bool keepComputeEffort = true,
    bool? revealThinkingSteps,
    bool keepThinking = true,
  }) {
    final ZChatGenerationSettings current = _settings.value;
    return ZChatGenerationSettings(
      responseLength:
          keepResponseLength ? current.responseLength : responseLength,
      lengthBias: keepLengthBias ? current.lengthBias : lengthBias,
      computeEffort: keepComputeEffort ? current.computeEffort : computeEffort,
      revealThinkingSteps:
          keepThinking ? current.revealThinkingSteps : revealThinkingSteps,
    );
  }
}

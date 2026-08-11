/// Intentions d'action sur un message de conversation — `ZChatAction`.
///
/// Domaine PUR (aucun Flutter, aucun `BuildContext`, aucun gestionnaire
/// d'état, aucun libellé, aucune icône, aucune couleur).
///
/// ## La règle que ce contrat rend structurelle
///
/// > **UN VERBE = UN SEUL SITE D'APPEL DANS LE CONTRÔLEUR.**
///
/// Une même barre d'actions dupliquée en deux implémentations parallèles
/// (barre de bulle, en-tête compact) dérive vite : supprimer confirmé d'un
/// côté et silencieux de l'autre, régénérer avec des comportements
/// divergents, annuler qui supprime la saisie en cours, une action « morte »
/// jamais câblée. Une checklist ne corrige pas cela durablement : la
/// **structure** doit rendre le second chemin d'exécution inexprimable.
///
/// ## Les trois formes pesées
///
/// | Forme | Verdict |
/// |---|---|
/// | (a) `abstract interface class` à un membre par verbe | REJETÉE — 5 membres publics = 5 points d'entrée, et aucune garde ne peut dire quel site est légitime. |
/// | (b) un `typedef` par verbe (`void Function(String)`) | REJETÉE (la pire) — un callback est libre en nombre de sites, invisible au typage et **peut être vide**. |
/// | (c) intentions **scellées** + répartiteur **unique** | RETENUE — le verbe devient une **donnée** ; l'effet vit derrière un répartiteur à **deux** membres publics, et les identifiants d'effet ne sont invocables que depuis un seul fichier. |
///
/// ## Patron `sealed` interne + variant ouvert (invariant AD-4)
///
/// Décalqué de [ZContentBlock] : `sealed` donne l'**exhaustivité au
/// socle** (un verbe non traité par le répartiteur **ne compile pas**), et
/// l'extension inter-package passe par le variant ouvert
/// [ZChatCustomAction] — **jamais** par l'héritage externe.
///
/// ## Règle de projection vers la couche de rendu — NORMATIVE
///
/// Ce type déclare **ce que le geste fait**, jamais **comment il s'affiche**.
/// Les types de rendu existent déjà et sont **réutilisés, pas dupliqués** :
/// `ZItemAction` (+ `ZItemActionsMenu`, `zcrud_study`), `ZBatchAction`
/// (`zcrud_core/presentation`), `ZAppBarAction` (`zcrud_ui_kit`).
///
/// ```dart
/// // Côté hôte — le libellé et l'icône sont ceux de l'HÔTE (i18n, thème).
/// ZItemAction(
///   kind: ZItemActionKind.delete,
///   label: label(context, 'chat.delete'),
///   icon: monIcone,
///   onSelected: () async {
///     final ZChatActionPlan? plan = (await dispatcher.prepare(
///       const ZChatDeleteAction(messageId: 'm1'),
///     )).fold((_) => null, (ZChatActionPlan p) => p);
///     if (plan == null) return;
///     final jeton = plan.requiresConfirmation
///         ? (await monDialogue() ? plan.confirmedByUser() : null)
///         : plan.proceedWithoutConfirmation();
///     if (jeton != null) await dispatcher.execute(jeton);
///   },
/// );
/// ```
///
/// La règle « `onSelected == null` ⇒ action **absente** » reste celle de
/// `ZItemAction` (invariant AD-4) : elle est **réutilisée**, jamais
/// réimplémentée ici.
///
/// **Pourquoi `ZChatAction` n'hérite PAS de `ZItemAction`** : (1)
/// `ZItemAction` vit dans un **satellite** ⇒ l'arête `zcrud_core → zcrud_study`
/// serait un cycle (invariant AD-1) ; (2) il porte `IconData`/`String label`
/// ⇒ présentation dans le domaine (invariants AD-2, AD-13) ; (3) l'invariant
/// AD-4 rejette l'héritage comme mécanisme d'extension inter-package ; (4)
/// **raison fatale** — il porte `VoidCallback? onSelected` : tout héritier
/// gagnerait un **second chemin d'exécution** à côté du répartiteur, rouvrant
/// exactement le défaut que ce contrat existe pour fermer.
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_corpus_scope.dart';
import '../ai/z_chat_generation_settings.dart';

/// Saisie en cours de l'utilisateur (« composer ») transportée par une action.
///
/// L'annulation **porte** la saisie pour que le contrat puisse imposer
/// qu'elle soit **rendue intacte** ([ZChatActionOutcome.preservedDraft]) —
/// c'est le garde-fou structurel contre un enchaînement « arrêter la
/// génération » puis « supprimer le message » qui ferait disparaître la
/// question tapée, sans confirmation ni avertissement.
class ZChatDraft {
  /// Construit un brouillon.
  const ZChatDraft({
    this.text = '',
    this.attachmentIds = const <String>[],
  });

  /// Texte en cours de saisie (jamais rendu comme réponse — c'est une entrée).
  final String text;

  /// Identités opaques des pièces jointes attachées à la saisie.
  final List<String> attachmentIds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatDraft &&
          text == other.text &&
          zListEquals(attachmentIds, other.attachmentIds);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(attachmentIds));

  @override
  String toString() =>
      'ZChatDraft(text: ${text.length} chars, attachments: '
      '${attachmentIds.length})';
}

/// Format demandé pour un rendu de copie ([ZChatCopyAction]).
///
/// Ce n'est **pas** un libellé d'affichage : c'est un discriminant technique.
enum ZChatCopyFormat {
  /// Texte brut, sans balisage.
  plainText,

  /// Markdown (le rendu exact appartient à l'hôte).
  markdown,
}

/// Intention d'action sur un message — **scellée**.
///
/// Chaque variant **doit** se prononcer sur les quatre membres abstraits :
/// l'oubli **ne compile pas**. C'est ce qui empêche un futur verbe d'arriver
/// sans avis explicite sur sa destructivité.
sealed class ZChatAction {
  /// Constructeur `const` de base.
  const ZChatAction();

  /// Nom technique du verbe (jamais un libellé traduisible).
  String get verb;

  /// `true` si l'action **détruit** ou remplace du contenu déjà visible.
  ///
  /// Un `true` impose la confirmation ([ZChatActionPlan.requiresConfirmation]).
  bool get isDestructive;

  /// `true` si l'action **entraîne** d'autres messages que sa cible directe
  /// (paire question/réponse, messages postérieurs).
  ///
  /// Une cascade non annoncée (retirer une question supprime aussi sa
  /// réponse, sans que l'appelant sache combien de messages sont touchés) est
  /// le défaut que ce champ ferme : la cascade est ici une **donnée du
  /// plan**, chiffrée avant toute destruction.
  bool get cascades;

  /// `true` si l'action **garantit** que la saisie soumise est rendue intacte.
  bool get preservesDraft;
}

/// Éditer un message puis relancer la génération.
///
/// Destructif : la reprise **entraîne** les messages postérieurs. Le brouillon
/// est transporté pour qu'un échec ne fasse **jamais** perdre la saisie.
class ZChatEditAction extends ZChatAction {
  /// Construit une édition.
  const ZChatEditAction({
    required this.messageId,
    required this.newText,
    this.draft = const ZChatDraft(),
  });

  /// Identité opaque du message édité.
  final String messageId;

  /// Nouveau texte de la requête.
  final String newText;

  /// Saisie à préserver.
  final ZChatDraft draft;

  @override
  String get verb => 'edit';

  @override
  bool get isDestructive => true;

  @override
  bool get cascades => true;

  @override
  bool get preservesDraft => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatEditAction &&
          messageId == other.messageId &&
          newText == other.newText &&
          draft == other.draft;

  @override
  int get hashCode => Object.hash(verb, messageId, newText, draft);
}

/// Régénérer la réponse d'un message.
///
/// La règle de confirmation est **uniforme** quel que soit le contexte
/// d'appel : c'est le **plan** qui décide, jamais le verbe pris isolément —
/// ce qui évite que des chemins de régénération distincts (reprise complète,
/// rafraîchissement, ajout) divergent silencieusement sur ce point.
///
/// ## Le défaut structurel que ce variant portait
///
/// Ce variant ne portait à l'origine que `{messageId}`, alors que
/// `ZChatLengthBias` est défini comme le « biais d'une **régénération** » :
/// le seul réglage dont le cas d'usage EST ce verbe lui était donc
/// **structurellement inatteignable** — régénérer « plus court » n'était pas
/// exprimable.
///
/// [settings] et [corpusScope] ferment ce défaut, **par champs optionnels** —
/// jamais par un nouveau variant (qui aurait exigé un `case` de plus au
/// répartiteur). Les deux valent `null` par défaut : une régénération écrite
/// avant l'ajout de ces champs se comporte **exactement** comme avant, et
/// emprunte le même chemin d'exécution.
class ZChatRegenerateAction extends ZChatAction {
  /// Construit une régénération.
  const ZChatRegenerateAction({
    required this.messageId,
    this.settings,
    this.corpusScope,
  });

  /// Identité opaque du message dont la réponse est régénérée.
  final String messageId;

  /// Réglages demandés pour **cette** régénération, ou `null` (« comme la
  /// requête d'origine »).
  ///
  /// C'est ici que `ZChatLengthBias` redevient atteignable sur son propre cas
  /// d'usage.
  final ZChatGenerationSettings? settings;

  /// Portée documentaire demandée pour **cette** régénération, ou `null`
  /// (aucune restriction).
  final ZChatCorpusScope? corpusScope;

  /// `true` si la régénération demande autre chose que « refais pareil ».
  ///
  /// C'est ce prédicat qui rend l'oubli **détectable** : le répartiteur
  /// refuse explicitement (`ZUnsupportedOperationFailure`) plutôt que de
  /// laisser tomber en silence des réglages que l'appelant a demandés — un
  /// réglage transmis à la couche d'appel puis silencieusement ignoré par
  /// l'implémentation est exactement le repli muet que ce prédicat rend
  /// détectable.
  bool get overridesRequest => settings != null || corpusScope != null;

  @override
  String get verb => 'regenerate';

  @override
  bool get isDestructive => false;

  @override
  bool get cascades => false;

  @override
  bool get preservesDraft => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatRegenerateAction &&
          messageId == other.messageId &&
          settings == other.settings &&
          corpusScope == other.corpusScope;

  @override
  int get hashCode => Object.hash(verb, messageId, settings, corpusScope);
}

/// Retirer un message — **soft-delete uniquement** (invariant AD-9).
///
/// Un retrait physique du document violerait AD-9 même si le code compile :
/// c'est `ZSyncMeta.isDeleted`/`updatedAt` qui porte le retrait, jamais une
/// suppression matérielle — sans quoi le merge offline-first ne peut plus
/// propager le retrait aux autres appareils.
class ZChatDeleteAction extends ZChatAction {
  /// Construit un retrait.
  const ZChatDeleteAction({
    required this.messageId,
    this.cascadeToPair = true,
  });

  /// Identité opaque du message retiré.
  final String messageId;

  /// `true` si la paire question/réponse est entraînée.
  final bool cascadeToPair;

  @override
  String get verb => 'delete';

  @override
  bool get isDestructive => true;

  @override
  bool get cascades => cascadeToPair;

  @override
  bool get preservesDraft => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatDeleteAction &&
          messageId == other.messageId &&
          cascadeToPair == other.cascadeToPair;

  @override
  int get hashCode => Object.hash(verb, messageId, cascadeToPair);
}

/// Annuler une génération **en cours** — verbe non destructif.
///
/// Deux garanties, toutes deux vérifiées par assertion :
/// * **la saisie survit** — [draft] est rendu intact dans l'issue, y compris
///   sur le chemin d'échec ; le comportement rejeté est celui d'une
///   annulation qui effacerait la question en cours de saisie ;
/// * **l'adressage se fait par [requestId]** — jamais par un jeton d'instance
///   partagé, ce qui empêcherait d'annuler le mauvais flux quand plusieurs
///   requêtes sont en vol. Le transport concret
///   (`CancelToken`/`StreamSubscription`) reste un détail d'implémentation
///   du port de génération ; ce type fixe seulement l'adressage.
class ZChatCancelAction extends ZChatAction {
  /// Construit une annulation.
  const ZChatCancelAction({
    required this.requestId,
    this.draft = const ZChatDraft(),
  });

  /// Identité opaque de la **requête** à annuler (jamais « la courante »).
  final String requestId;

  /// Saisie à restituer intacte.
  final ZChatDraft draft;

  @override
  String get verb => 'cancel';

  @override
  bool get isDestructive => false;

  @override
  bool get cascades => false;

  @override
  bool get preservesDraft => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCancelAction &&
          requestId == other.requestId &&
          draft == other.draft;

  @override
  int get hashCode => Object.hash(verb, requestId, draft);
}

/// Copier le rendu d'un message — lecture seule.
///
/// Ce verbe passe par le **même** répartiteur que les autres, ce qui ferme un
/// défaut classique d'UI de chat : un bouton « copier » câblé nulle part
/// (callback vide, site mort). Ici, un verbe non implémenté par l'hôte rend
/// `Left(ZUnsupportedOperationFailure)`, jamais un silence.
class ZChatCopyAction extends ZChatAction {
  /// Construit une copie.
  const ZChatCopyAction({
    required this.messageId,
    this.format = ZChatCopyFormat.plainText,
  });

  /// Identité opaque du message copié.
  final String messageId;

  /// Format de rendu demandé.
  final ZChatCopyFormat format;

  @override
  String get verb => 'copy';

  @override
  bool get isDestructive => false;

  @override
  bool get cascades => false;

  @override
  bool get preservesDraft => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCopyAction &&
          messageId == other.messageId &&
          format == other.format;

  @override
  int get hashCode => Object.hash(verb, messageId, format);
}

/// **Variant ouvert** (invariant AD-4) — verbe propre à un hôte, sans forker
/// le cœur.
///
/// Même patron que `ZCustomContentBlock` dans [ZContentBlock]. [isDestructive]
/// et [cascades] sont **requis** : aucun défaut permissif, l'hôte doit se
/// prononcer — sans quoi une cascade non annoncée redeviendrait exprimable.
class ZChatCustomAction extends ZChatAction {
  /// Construit un verbe d'hôte.
  const ZChatCustomAction({
    required this.verb,
    required this.isDestructive,
    required this.cascades,
    this.payload = const <String, dynamic>{},
    this.preservesDraft = false,
  });

  @override
  final String verb;

  @override
  final bool isDestructive;

  @override
  final bool cascades;

  @override
  final bool preservesDraft;

  /// Charge utile opaque de l'hôte (jamais interprétée par le socle).
  final Map<String, dynamic> payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCustomAction &&
          verb == other.verb &&
          isDestructive == other.isDestructive &&
          cascades == other.cascades &&
          preservesDraft == other.preservesDraft &&
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(
        verb,
        isDestructive,
        cascades,
        preservesDraft,
        zJsonHash(payload),
      );
}

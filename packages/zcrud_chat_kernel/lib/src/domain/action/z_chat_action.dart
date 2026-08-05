/// Intentions d'action sur un message de conversation — `ZChatAction`.
///
/// CHAT-0b, décision **D1**. Domaine PUR (aucun Flutter, aucun `BuildContext`,
/// aucun gestionnaire d'état, aucun libellé, aucune icône, aucune couleur).
///
/// ## 🔴 La règle que ce contrat rend structurelle
///
/// > **UN VERBE = UN SEUL SITE D'APPEL DANS LE CONTRÔLEUR.**
///
/// IFFD porte **deux** implémentations parallèles de la même barre d'actions
/// dans un fichier de 5153 lignes (`chatbot_conversation_screen.dart`) : barre
/// de bulle (≈ l.1650-2170) et en-tête compact (≈ l.3600-4120). Elles ne se
/// comportent **pas** pareil : supprimer est confirmé l.2134 et **silencieux**
/// l.3886 ; régénérer a **trois** comportements (l.1979, l.2000, l.2026) ;
/// annuler **supprime la question tapée** (l.3618-3672) ; copier est **mort**
/// (`onTap: () {}`, l.1513 / l.4208). Une checklist ne corrige pas cela : la
/// **structure** doit rendre le second chemin inexprimable.
///
/// ## Les trois formes pesées (D1)
///
/// | Forme | Verdict |
/// |---|---|
/// | (a) `abstract interface class` à un membre par verbe | 🔴 REJETÉE — 5 membres publics = 5 points d'entrée ; c'est **exactement** la forme d'IFFD, et aucune garde ne peut dire quel site est légitime. |
/// | (b) un `typedef` par verbe (`void Function(String)`) | 🔴 REJETÉE (la pire) — un callback est libre en nombre de sites, invisible au typage et **peut être vide** : littéralement le défaut « Copier » d'IFFD. |
/// | (c) intentions **scellées** + répartiteur **unique** | ✅ RETENUE — le verbe devient une **donnée** ; l'effet vit derrière un répartiteur à **deux** membres publics, et les identifiants d'effet ne sont invocables que depuis un seul fichier (garde **G-U1**). |
///
/// ## Patron `sealed` INTERNE + variant OUVERT (AD-4)
///
/// Décalqué de [ZContentBlock] (CHAT-0) : `sealed` donne l'**exhaustivité au
/// socle** (un verbe non traité par le répartiteur **ne compile pas**), et
/// l'extension inter-package passe par le variant ouvert
/// [ZChatCustomAction] — **jamais** par l'héritage externe.
///
/// ## 🔴 Règle de projection vers la couche de rendu (D8 / D8.1) — NORMATIVE
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
/// La règle AD-4 « `onSelected == null` ⇒ action **ABSENTE** » reste celle de
/// `ZItemAction` : elle est **réutilisée**, jamais réimplémentée ici.
///
/// 🔴 **Pourquoi `ZChatAction` n'hérite PAS de `ZItemAction`** (D8.1) : (1)
/// `ZItemAction` vit dans un **satellite** ⇒ l'arête `zcrud_core → zcrud_study`
/// serait un **cycle AD-1** (`graph_proof` CORE OUT ≠ 0) ; (2) il porte
/// `IconData`/`String label` ⇒ présentation dans le domaine (AD-2/AD-13/FR-26) ;
/// (3) AD-4 rejette l'héritage comme mécanisme d'extension inter-package ;
/// (4) **raison fatale** — il porte `VoidCallback? onSelected` : tout héritier
/// gagnerait un **second chemin d'exécution** à côté du répartiteur, et la garde
/// **G-U1** deviendrait incapable de mordre. C'est le défaut que cette story
/// corrige, réintroduit par la porte de service.
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_corpus_scope.dart';
import '../ai/z_chat_generation_settings.dart';

/// Saisie en cours de l'utilisateur (« composer ») transportée par une action.
///
/// 🔴 D3 : l'annulation **porte** la saisie pour que le contrat puisse imposer
/// qu'elle soit **rendue intacte** ([ZChatActionOutcome.preservedDraft]).
/// Défaut IFFD interdit : `chatbot_conversation_screen.dart:3618-3672` —
/// la poubelle de « Réflexion en cours » appelle `stopSubjectExplaningOnError()`
/// **puis** `delete(requestedMessage.id)` : la question tapée disparaît, sans
/// confirmation ni toast.
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

/// Intention d'action sur un message — **scellée** (D1).
///
/// Chaque variant **doit** se prononcer sur les quatre membres abstraits :
/// l'oubli **ne compile pas**. C'est ce qui empêche un futur verbe d'arriver
/// « sans avis » sur sa destructivité, comme l'a fait chaque surface d'IFFD.
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
  /// Défaut IFFD n°1 : le pied de requête supprime question **et** réponse en
  /// cascade — la surface A le confirme, la surface B non, et **aucune** ne dit
  /// combien. Ici la cascade est une **donnée du plan**, chiffrée avant toute
  /// destruction (D6).
  bool get cascades;

  /// `true` si l'action **garantit** que la saisie soumise est rendue intacte.
  bool get preservesDraft;
}

/// Éditer un message puis relancer la génération.
///
/// Destructif : la reprise **entraîne** les messages postérieurs. Le brouillon
/// est transporté pour qu'un échec ne fasse **jamais** perdre la saisie (D3).
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
/// ⚠️ lex ne confirme pas ce verbe, IFFD en a **trois** variantes divergentes
/// (`:1979` delete+resend, `:2000` `refresh:true`, `:2026` `create` additif).
/// Ici la règle est **uniforme** : c'est le **plan** qui décide de la
/// confirmation, jamais le verbe pris isolément (D6).
///
/// ## 🔴 Lot β — le défaut STRUCTUREL que ce variant portait
///
/// L'étude CR-IFFD-72 (§ 4.3) l'a mesuré : ce variant ne portait que
/// `{messageId}`, alors que `ZChatLengthBias` est défini — dans
/// `z_chat_enums.dart:116` — comme le « biais d'une **régénération** ». Le seul
/// réglage dont le cas d'usage EST ce verbe lui était donc **structurellement
/// inatteignable** : régénérer « plus court » n'était pas exprimable.
///
/// [settings] et [corpusScope] ferment ce défaut, **par champs optionnels** —
/// jamais par un nouveau variant (qui aurait exigé un `case` de plus au
/// répartiteur, garde G-SEAL). Les deux valent `null` par défaut : une
/// régénération écrite avant ce lot se comporte **exactement** comme avant, et
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
  /// requête d'origine ») — lot β.
  ///
  /// C'est ici que `ZChatLengthBias` redevient atteignable sur son propre cas
  /// d'usage.
  final ZChatGenerationSettings? settings;

  /// Portée documentaire demandée pour **cette** régénération, ou `null`
  /// (aucune restriction) — lot β.
  final ZChatCorpusScope? corpusScope;

  /// `true` si la régénération demande autre chose que « refais pareil ».
  ///
  /// 🔴 C'est ce prédicat qui rend l'oubli **détectable** : le répartiteur
  /// refuse explicitement (`ZUnsupportedOperationFailure`) plutôt que de
  /// laisser tomber en silence des réglages que l'appelant a demandés — le
  /// défaut IFFD mesuré au § 1.1 de l'étude (six drapeaux de corpus transmis
  /// par le contrôleur puis **jetés** par le repository, sans aucun signal).
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

/// Retirer un message — **soft-delete uniquement** (D7, AD-9).
///
/// ⚠️ **zcrud prime sur ses deux sources** : lex fait un *hard delete*
/// (`chat_repository_impl.dart:408-424, 247-254`, aucun drapeau posé) et IFFD
/// aussi (`FirebaseCrudRepositoryImpl.delete()`, alors qu'un `softDelete()`
/// existe l.365 et n'est **jamais** appelé). Les deux divergent d'AD-9.
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

/// Annuler une génération **en cours** — verbe NON destructif (D3, D4).
///
/// 🔴 Deux garanties, toutes deux vérifiées par assertion :
/// * **la saisie survit** — [draft] est rendu intact dans l'issue, y compris
///   sur le chemin d'échec (gardes **G-A1**/**G-A2**) ; le défaut interdit est
///   IFFD `chatbot_conversation_screen.dart:3618-3672` (annuler = supprimer la
///   question) ;
/// * **l'adressage se fait par [requestId]** — jamais par un jeton d'instance
///   partagé (défaut IFFD : annuler un flux annulait le mauvais). Le
///   `CancelToken`/`StreamSubscription` **réel** appartient à CHAT-1 : ici on
///   fixe l'adressage, pas le transport.
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
/// Défaut IFFD : le verbe existe dans l'UI mais **n'est câblé nulle part**
/// (`onTap: () {}` l.1513, callback jamais invoqué l.4208 — 3 sites morts).
/// Ici il passe par le **même** répartiteur que les autres : un verbe non
/// implémenté par l'hôte rend `Left(ZUnsupportedOperationFailure)`, jamais un
/// silence.
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

/// **Variant OUVERT** (AD-4) — verbe propre à un hôte, sans forker le cœur.
///
/// Patron `ZCustomContentBlock` de CHAT-0. [isDestructive] et [cascades] sont
/// **requis** : aucun défaut permissif, l'hôte doit se prononcer — sans quoi
/// une cascade non annoncée redeviendrait exprimable.
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

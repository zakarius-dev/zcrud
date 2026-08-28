/// Vocabulaire **déclaratif** des artefacts d'un fil de travail —
/// `ZChatArtifactVerb`, `ZChatArtifactDeclaration`, `ZChatArtifactRegistry`.
///
/// Un **artefact** est un matériau produit **à côté** d'une réponse (une carte
/// mentale, un paquet de flashcards, une reformulation). Il n'est pas un
/// message : c'est un **champ** du message, qui ne produit aucun tour de
/// conversation.
///
/// ## Le socle ne nomme rien, ne colore rien, ne dessine rien
///
/// Ce fichier est du domaine **pur** : aucun libellé, aucune couleur, aucun
/// glyphe. L'hôte déclare des **jetons** ([ZChatArtifactDeclaration.labelToken],
/// [ZChatArtifactDeclaration.iconKey], [ZChatArtifactDeclaration.accentToken])
/// qu'il résout lui-même au rendu. Le socle, lui, **dérive** : quels verbes
/// sont offerts dans quel état, et lesquels exigent une confirmation.
///
/// ## Ce que la déclaration fait disparaître
///
/// Sans registre, chaque hôte réécrit trois lambdas identiques (présence,
/// compte, occupation) et une algèbre de visibilité des verbes — et se trompe
/// sur la même règle : un verbe de lecture (« afficher ») reste offert sur un
/// dossier en lecture seule, sinon ce dossier perd tout son contenu produit.
/// Cette règle est portée ici, une fois ([ZChatArtifactVerbAvailability]).
library;

import 'package:zcrud_core/domain.dart';

import '../ai/z_chat_generation_style.dart';
import 'z_chat_artifact_status.dart';

/// Verbe « créer » — offert quand l'artefact est **absent**.
const String kZChatArtifactVerbCreate = 'create';

/// Verbe « ouvrir / afficher » — offert quand l'artefact est **présent**, y
/// compris en lecture seule.
const String kZChatArtifactVerbOpen = 'open';

/// Verbe « régénérer » — offert quand l'artefact est présent **et** éditable.
const String kZChatArtifactVerbRegenerate = 'regenerate';

/// Verbe « modifier » — offert quand l'artefact est présent **et** éditable.
const String kZChatArtifactVerbEdit = 'edit';

/// Verbe « supprimer » — offert quand présent et éditable ; **destructeur**.
const String kZChatArtifactVerbDelete = 'delete';

/// Verbe « imprimer / exporter » — offert quand présent, lecture seule comprise.
const String kZChatArtifactVerbPrint = 'print';

/// Verbe « partager » — offert quand présent, lecture seule comprise.
const String kZChatArtifactVerbShare = 'share';

/// Ce que le **toucher** d'un artefact déclenche quand un **seul** verbe est
/// offert.
///
/// Sur un artefact à plusieurs verbes visibles, le menu est la seule forme
/// possible et ce réglage est sans effet. Sur un verbe unique, trois
/// comportements sont déclarables :
///
/// * [menu] (défaut) — le menu, même à un seul élément : le toucher n'a
///   jamais d'effet direct, le verbe part au second geste ;
/// * [direct] — le verbe part au toucher, sans menu — pour une commande dont
///   l'effet est bon marché et réversible ;
/// * [confirm] — le verbe part au toucher, **après** une question : la forme
///   à déclarer quand l'effet est coûteux (une génération) sans être
///   destructeur.
///
/// Un verbe **destructeur** garde sa confirmation quel que soit le mode, et
/// n'en reçoit jamais deux.
enum ZChatArtifactActivation {
  /// Le toucher ouvre le menu, même à un seul élément (défaut).
  menu,

  /// Le toucher exécute le verbe unique, sans menu ni question — hors
  /// confirmation d'un verbe destructeur, qui demeure.
  direct,

  /// Le toucher pose une **question** puis exécute le verbe unique. Le
  /// message et les libellés de la question sont déclarables au rendu.
  confirm;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — une valeur inconnue retombe sur la plus **prudente**
  /// ([menu]) : un mode mal déclaré ne doit jamais exécuter au toucher un
  /// verbe qui ne l'a pas demandé. Ne lève jamais.
  static ZChatArtifactActivation fromJson(Object? raw) {
    switch (raw) {
      case 'direct':
        return ZChatArtifactActivation.direct;
      case 'confirm':
        return ZChatArtifactActivation.confirm;
      default:
        return ZChatArtifactActivation.menu;
    }
  }
}

/// Dans quel **état** de l'artefact un verbe est offert.
///
/// Trois valeurs suffisent à couvrir tous les verbes rencontrés, et la
/// troisième porte la règle qui compte : un verbe de **lecture** n'est pas
/// retiré par la lecture seule. Un artefact **en cours** n'offre jamais aucun
/// verbe, quelle que soit la valeur.
enum ZChatArtifactVerbAvailability {
  /// Offert quand l'artefact est **absent** (et le fil éditable) : « créer ».
  whenAbsent,

  /// Offert quand l'artefact est **présent**, **même en lecture seule** :
  /// « ouvrir », « imprimer », « partager ».
  whenPresent,

  /// Offert quand l'artefact est présent **et** le fil éditable :
  /// « régénérer », « modifier », « supprimer ».
  whenPresentEditable;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** — une valeur inconnue retombe sur la plus
  /// **restrictive** ([whenPresentEditable]) : un verbe mal déclaré ne doit
  /// jamais apparaître là où il ne devrait pas. Ne lève jamais.
  static ZChatArtifactVerbAvailability fromJson(Object? raw) {
    switch (raw) {
      case 'whenAbsent':
        return ZChatArtifactVerbAvailability.whenAbsent;
      case 'whenPresent':
        return ZChatArtifactVerbAvailability.whenPresent;
      default:
        return ZChatArtifactVerbAvailability.whenPresentEditable;
    }
  }

  /// `true` si un verbe de cette disponibilité est offert pour [status] dans
  /// un fil en lecture seule ([readOnly]) ou non.
  bool offersFor(ZChatArtifactStatus status, {required bool readOnly}) {
    switch (status.phase) {
      case ZChatArtifactPhase.inProgress:
        return false;
      case ZChatArtifactPhase.absent:
        return this == ZChatArtifactVerbAvailability.whenAbsent && !readOnly;
      case ZChatArtifactPhase.present:
        switch (this) {
          case ZChatArtifactVerbAvailability.whenAbsent:
            return false;
          case ZChatArtifactVerbAvailability.whenPresent:
            return true;
          case ZChatArtifactVerbAvailability.whenPresentEditable:
            return !readOnly;
        }
    }
  }
}

/// Un verbe offert sur un artefact, déclaré par l'hôte.
///
/// La [key] est un vocabulaire **ouvert** (invariant AD-4) : les constantes
/// `kZChatArtifactVerb*` sont des conventions, pas une énumération fermée.
/// Un verbe [destructive] **exige** une confirmation avant son exécution —
/// c'est [ZChatArtifactDeclaration.requiresConfirmation] qui le dit, et
/// aucune présentation ne peut le contourner.
class ZChatArtifactVerb {
  /// Construit un verbe.
  ZChatArtifactVerb({
    required this.key,
    required this.availability,
    this.destructive = false,
    this.iconKey,
    this.labelToken,
    this.accentToken,
    this.confirmToken,
    Map<String, dynamic> extra = const <String, dynamic>{},
  })  : _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Verbe « créer » avec ses conventions.
  factory ZChatArtifactVerb.create({String? iconKey, String? labelToken}) =>
      ZChatArtifactVerb(
        key: kZChatArtifactVerbCreate,
        availability: ZChatArtifactVerbAvailability.whenAbsent,
        iconKey: iconKey,
        labelToken: labelToken,
      );

  /// Verbe « ouvrir » avec ses conventions.
  factory ZChatArtifactVerb.open({String? iconKey, String? labelToken}) =>
      ZChatArtifactVerb(
        key: kZChatArtifactVerbOpen,
        availability: ZChatArtifactVerbAvailability.whenPresent,
        iconKey: iconKey,
        labelToken: labelToken,
      );

  /// Verbe « régénérer » avec ses conventions.
  factory ZChatArtifactVerb.regenerate({String? iconKey, String? labelToken}) =>
      ZChatArtifactVerb(
        key: kZChatArtifactVerbRegenerate,
        availability: ZChatArtifactVerbAvailability.whenPresentEditable,
        iconKey: iconKey,
        labelToken: labelToken,
      );

  /// Verbe « modifier » avec ses conventions.
  factory ZChatArtifactVerb.edit({String? iconKey, String? labelToken}) =>
      ZChatArtifactVerb(
        key: kZChatArtifactVerbEdit,
        availability: ZChatArtifactVerbAvailability.whenPresentEditable,
        iconKey: iconKey,
        labelToken: labelToken,
      );

  /// Verbe « supprimer » — **destructeur**, avec son jeton de confirmation.
  factory ZChatArtifactVerb.delete({
    String? iconKey,
    String? labelToken,
    String? confirmToken,
  }) =>
      ZChatArtifactVerb(
        key: kZChatArtifactVerbDelete,
        availability: ZChatArtifactVerbAvailability.whenPresentEditable,
        destructive: true,
        iconKey: iconKey,
        labelToken: labelToken,
        confirmToken: confirmToken,
      );

  /// Identité **opaque** du verbe, cible du répartiteur d'exécution de l'hôte.
  final String key;

  /// État dans lequel le verbe est offert.
  final ZChatArtifactVerbAvailability availability;

  /// `true` si le verbe détruit du contenu visible : la confirmation est
  /// alors obligatoire.
  final bool destructive;

  /// Clé d'icône **opaque**, résolue par l'hôte au rendu. `null` ⇒ aucune.
  final String? iconKey;

  /// Jeton de libellé, résolu par l'hôte. `null` ⇒ l'hôte décide.
  final String? labelToken;

  /// Jeton d'accent (couleur), résolu par l'hôte. `null` ⇒ accent de
  /// l'artefact.
  final String? accentToken;

  /// Jeton du message de confirmation d'un verbe destructeur. `null` ⇒ l'hôte
  /// fournit son message par défaut ; **jamais** une absence de question.
  final String? confirmToken;

  /// Données d'hôte libres (invariant AD-4), immuables.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) et les
  /// clés propres du verbe (`key`, `icon_key`…) en sont **retirées**, quelle
  /// que soit la voie d'écriture : elles ne sont ni conservées ni réémises par
  /// [toJson].
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  // Slot brut, lu uniquement par l'accesseur `extra`.
  final Map<String, dynamic> _extra;

  // Clés propres émises par `toJson` ∪ clés de sync hors-entité (AD-9).
  static const Set<String> _reservedKeys = <String>{
    'key',
    'availability',
    'destructive',
    'icon_key',
    'label_token',
    'accent_token',
    'confirm_token',
    ...ZSyncMeta.reservedKeys,
  };

  /// `true` si ce verbe est offert pour [status], fil en lecture seule ou non.
  bool isOfferedFor(ZChatArtifactStatus status, {required bool readOnly}) =>
      availability.offersFor(status, readOnly: readOnly);

  /// Décode **défensivement** — ne lève jamais ; sans clé ⇒ `null`.
  static ZChatArtifactVerb? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String? key = zJsonStringOrNull(map['key']);
    if (key == null || key.trim().isEmpty) return null;
    return ZChatArtifactVerb(
      key: key.trim(),
      availability: ZChatArtifactVerbAvailability.fromJson(map['availability']),
      destructive: zJsonBool(map['destructive'], false),
      iconKey: zJsonStringOrNull(map['icon_key']),
      labelToken: zJsonStringOrNull(map['label_token']),
      accentToken: zJsonStringOrNull(map['accent_token']),
      confirmToken: zJsonStringOrNull(map['confirm_token']),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont omis.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'availability': availability.jsonValue,
        if (destructive) 'destructive': true,
        if (iconKey != null) 'icon_key': iconKey,
        if (labelToken != null) 'label_token': labelToken,
        if (accentToken != null) 'accent_token': accentToken,
        if (confirmToken != null) 'confirm_token': confirmToken,
        if (extra.isNotEmpty) 'extra': extra,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactVerb &&
          key == other.key &&
          availability == other.availability &&
          destructive == other.destructive &&
          iconKey == other.iconKey &&
          labelToken == other.labelToken &&
          accentToken == other.accentToken &&
          confirmToken == other.confirmToken &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(key, availability, destructive, iconKey,
      labelToken, accentToken, confirmToken, zJsonHash(extra));

  @override
  String toString() => 'ZChatArtifactVerb($key, $availability'
      '${destructive ? ', destructive' : ''})';
}

/// La déclaration d'un artefact par l'hôte.
///
/// Tout ce que le rendu et le contrôleur ont besoin de savoir d'un artefact
/// est ici, **une fois** : son identité, ses jetons de présentation, ses
/// verbes (liste **ordonnée** — l'ordre est celui du menu), et s'il porte un
/// compte. Ce qui en est **dérivé** n'est jamais redemandé :
/// [verbsFor], [requiresConfirmation], [isDestructive].
class ZChatArtifactDeclaration {
  /// Construit une déclaration. Les verbes en doublon de clé sont réduits au
  /// **premier** déclaré.
  ZChatArtifactDeclaration({
    required this.key,
    this.iconKey,
    this.labelToken,
    this.accentToken,
    Iterable<ZChatArtifactVerb> verbs = const <ZChatArtifactVerb>[],
    this.activation = ZChatArtifactActivation.menu,
    this.activationPromptToken,
    this.hasCount = false,
    this.subjectRequired = false,
    this.style,
    this.order = 0,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  })  : verbs = List<ZChatArtifactVerb>.unmodifiable(_dedupe(verbs)),
        _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Identité **stable et opaque** de l'artefact : la clé sous laquelle
  /// l'état est lu ([ZChatArtifactStatePort]) et le contenu stocké.
  final String key;

  /// Clé d'icône opaque, résolue par l'hôte. `null` ⇒ aucune.
  final String? iconKey;

  /// Jeton de libellé, résolu par l'hôte. `null` ⇒ l'hôte décide.
  final String? labelToken;

  /// Jeton d'accent, résolu par l'hôte. `null` ⇒ accent par défaut.
  final String? accentToken;

  /// Verbes offerts, dans l'ordre de présentation. Une liste vide est une
  /// déclaration **légitime** : l'artefact est alors un pur indicateur d'état.
  final List<ZChatArtifactVerb> verbs;

  /// Ce que le toucher déclenche quand un **seul** verbe est offert
  /// (cf. [ZChatArtifactActivation]). Sans effet sur un artefact dont
  /// plusieurs verbes sont visibles. Défaut : le menu.
  final ZChatArtifactActivation activation;

  /// Jeton du message de la question posée en mode
  /// [ZChatArtifactActivation.confirm], résolu par l'hôte au rendu. `null` ⇒
  /// le rendu pose sa question générique localisée.
  final String? activationPromptToken;

  /// `true` si l'artefact porte un **compte** (nœuds, cartes…) affiché en
  /// pastille quand il est strictement positif.
  final bool hasCount;

  /// L'accent de cet artefact est-il porté **même quand il est absent** ?
  ///
  /// `false` (défaut) : la teinte dit l'**état** — un artefact vide est
  /// rendu éteint.
  ///
  /// `true` : la teinte dit la **nature** de l'artefact et l'accompagne en
  /// permanence ; l'existence reste portée par le compte et par l'annonce
  /// d'accessibilité, qui continuent de distinguer « déjà généré » de
  /// « aucun contenu ».
  ///
  /// `true` si la génération de cet artefact exige un **sujet** non vide, au
  /// même titre qu'une matière non vide (`ZChatArtifactGenerationRequest.
  /// subjectRequired`). Déclaré ici pour que le cas courant n'exige aucun
  /// ajusteur de requête.
  final bool subjectRequired;

  /// Style de génération à demander pour cet artefact, ou `null` (l'hôte ou
  /// le port décide). Donnée **ouverte** (invariant AD-4). Persisté à plat,
  /// sous les clés du style lui-même (`style`, `style_params`).
  final ZChatGenerationStyle? style;

  /// Rang de présentation (croissant) ; à égalité, l'ordre de déclaration.
  final int order;

  /// Slot d'extension typé versionné (invariant AD-4).
  final ZExtension? extension;

  /// Données d'hôte libres (invariant AD-4), immuables.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) et les
  /// clés propres de la déclaration (`key`, `verbs`, `style`…) en sont
  /// **retirées**, quelle que soit la voie d'écriture : elles ne sont ni
  /// conservées ni réémises par [toJson].
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  // Slot brut, lu uniquement par l'accesseur `extra`.
  final Map<String, dynamic> _extra;

  // Clés propres émises par `toJson` (style à plat compris) ∪ clés de sync
  // hors-entité (AD-9).
  static const Set<String> _reservedKeys = <String>{
    'key',
    'icon_key',
    'label_token',
    'accent_token',
    'verbs',
    'activation',
    'activation_prompt_token',
    'has_count',
    // Clé publiée puis retirée : filtrée pour qu'un document écrit par une
    // version qui la posait ne la fasse pas resurgir dans `extra`.
    'always_accented',
    'subject_required',
    kZChatGenerationStyleKindKey,
    kZChatGenerationStyleParamsKey,
    'order',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// `true` si **au moins un** verbe est destructeur.
  bool get isDestructive => verbs.any((ZChatArtifactVerb v) => v.destructive);

  /// Le verbe de clé [verbKey], ou `null`.
  ZChatArtifactVerb? verb(String verbKey) {
    for (final ZChatArtifactVerb v in verbs) {
      if (v.key == verbKey) return v;
    }
    return null;
  }

  /// Les verbes offerts pour [status] — dans l'ordre déclaré —, en lecture
  /// seule ou non. Un artefact **en cours** n'en offre aucun.
  List<ZChatArtifactVerb> verbsFor(
    ZChatArtifactStatus status, {
    bool readOnly = false,
  }) =>
      List<ZChatArtifactVerb>.unmodifiable(<ZChatArtifactVerb>[
        for (final ZChatArtifactVerb v in verbs)
          if (v.isOfferedFor(status, readOnly: readOnly)) v,
      ]);

  /// `true` si le verbe [verbKey] exige une confirmation avant exécution.
  ///
  /// Un verbe **inconnu** de cette déclaration rend `true` : refuser de
  /// demander est le seul choix qui pourrait détruire sans question.
  bool requiresConfirmation(String verbKey) =>
      verb(verbKey)?.destructive ?? true;

  /// Décode **défensivement** — ne lève jamais ; sans clé ⇒ `null`.
  static ZChatArtifactDeclaration? fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
    ZTypeRegistry? typeRegistry,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String? key = zJsonStringOrNull(map['key']);
    if (key == null || key.trim().isEmpty) return null;
    return ZChatArtifactDeclaration(
      key: key.trim(),
      iconKey: zJsonStringOrNull(map['icon_key']),
      labelToken: zJsonStringOrNull(map['label_token']),
      accentToken: zJsonStringOrNull(map['accent_token']),
      verbs: zJsonDecodeList<ZChatArtifactVerb>(
            map['verbs'],
            ZChatArtifactVerb.fromJson,
          ) ??
          const <ZChatArtifactVerb>[],
      activation: ZChatArtifactActivation.fromJson(map['activation']),
      activationPromptToken: zJsonStringOrNull(map['activation_prompt_token']),
      hasCount: zJsonBool(map['has_count'], false),
      subjectRequired: zJsonBool(map['subject_required'], false),
      // Le style est à PLAT sur la déclaration, sous ses propres clés
      // (`style`, `style_params`) : `fromJson` lit la carte entière.
      style: ZChatGenerationStyle.fromJson(map, typeRegistry: typeRegistry),
      order: zJsonInt(map['order'], 0),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont omis.
  Map<String, dynamic> toJson({ZTypeRegistry? typeRegistry}) =>
      <String, dynamic>{
        'key': key,
        if (iconKey != null) 'icon_key': iconKey,
        if (labelToken != null) 'label_token': labelToken,
        if (accentToken != null) 'accent_token': accentToken,
        if (verbs.isNotEmpty)
          'verbs': <Map<String, dynamic>>[
            for (final ZChatArtifactVerb v in verbs) v.toJson(),
          ],
        if (activation != ZChatArtifactActivation.menu)
          'activation': activation.jsonValue,
        if (activationPromptToken != null)
          'activation_prompt_token': activationPromptToken,
        if (hasCount) 'has_count': true,
        if (subjectRequired) 'subject_required': true,
        if (style != null) ...style!.toJson(typeRegistry: typeRegistry),
        if (order != 0) 'order': order,
        if (extension != null) 'extension': extension!.toJson(),
        if (extra.isNotEmpty) 'extra': extra,
      };

  @override
  String toString() =>
      'ZChatArtifactDeclaration($key, verbs: ${verbs.length}'
      '${hasCount ? ', counted' : ''})';

  static List<ZChatArtifactVerb> _dedupe(Iterable<ZChatArtifactVerb> raw) {
    final List<ZChatArtifactVerb> out = <ZChatArtifactVerb>[];
    final Set<String> seen = <String>{};
    for (final ZChatArtifactVerb v in raw) {
      if (seen.add(v.key)) out.add(v);
    }
    return out;
  }
}

/// Le **registre** des artefacts déclarés par l'hôte.
///
/// Immuable, ordonné par [ZChatArtifactDeclaration.order] puis par ordre de
/// déclaration. Une clé déclarée deux fois est réduite à sa **dernière**
/// déclaration — c'est ce qui permet à un hôte de **remplacer** une entrée
/// d'un registre de référence sans le reconstruire.
///
/// Toute question sur un artefact **inconnu** reçoit la réponse la plus
/// sûre : aucun verbe, confirmation exigée.
class ZChatArtifactRegistry {
  /// Construit un registre.
  ZChatArtifactRegistry([
    Iterable<ZChatArtifactDeclaration> declarations =
        const <ZChatArtifactDeclaration>[],
  ]) : declarations = List<ZChatArtifactDeclaration>.unmodifiable(
          _ordered(declarations),
        );

  /// Registre vide.
  static final ZChatArtifactRegistry empty = ZChatArtifactRegistry();

  /// Déclarations, dans l'ordre de présentation.
  final List<ZChatArtifactDeclaration> declarations;

  /// Clés déclarées, dans l'ordre de présentation.
  List<String> get keys => List<String>.unmodifiable(
        <String>[for (final ZChatArtifactDeclaration d in declarations) d.key],
      );

  /// `true` si aucune déclaration.
  bool get isEmpty => declarations.isEmpty;

  /// `true` si [artifactKey] est déclaré.
  bool contains(String artifactKey) => declarationOf(artifactKey) != null;

  /// La déclaration de [artifactKey], ou `null`.
  ZChatArtifactDeclaration? declarationOf(String artifactKey) {
    for (final ZChatArtifactDeclaration d in declarations) {
      if (d.key == artifactKey) return d;
    }
    return null;
  }

  /// Les verbes offerts sur [artifactKey] pour [status]. Inconnu ⇒ aucun.
  List<ZChatArtifactVerb> verbsFor(
    String artifactKey,
    ZChatArtifactStatus status, {
    bool readOnly = false,
  }) =>
      declarationOf(artifactKey)?.verbsFor(status, readOnly: readOnly) ??
      const <ZChatArtifactVerb>[];

  /// `true` si exécuter [verbKey] sur [artifactKey] exige une confirmation.
  /// Inconnu ⇒ `true`.
  bool requiresConfirmation(String artifactKey, String verbKey) =>
      declarationOf(artifactKey)?.requiresConfirmation(verbKey) ?? true;

  /// `true` si [artifactKey] porte un compte. Inconnu ⇒ `false`.
  bool hasCount(String artifactKey) =>
      declarationOf(artifactKey)?.hasCount ?? false;

  /// Nouveau registre où [declaration] **remplace** (ou ajoute) l'entrée de
  /// même clé.
  ZChatArtifactRegistry withDeclaration(ZChatArtifactDeclaration declaration) =>
      ZChatArtifactRegistry(<ZChatArtifactDeclaration>[
        for (final ZChatArtifactDeclaration d in declarations)
          if (d.key != declaration.key) d,
        declaration,
      ]);

  /// Nouveau registre sans l'entrée [artifactKey].
  ZChatArtifactRegistry without(String artifactKey) =>
      ZChatArtifactRegistry(<ZChatArtifactDeclaration>[
        for (final ZChatArtifactDeclaration d in declarations)
          if (d.key != artifactKey) d,
      ]);

  /// Décode **défensivement** une liste de déclarations — les entrées
  /// illisibles sont écartées, jamais une exception.
  static ZChatArtifactRegistry fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) =>
      ZChatArtifactRegistry(
        zJsonDecodeList<ZChatArtifactDeclaration>(
              raw,
              (Object? e) => ZChatArtifactDeclaration.fromJson(
                e,
                extensionParser: extensionParser,
              ),
            ) ??
            const <ZChatArtifactDeclaration>[],
      );

  /// Sérialise la liste des déclarations.
  List<Map<String, dynamic>> toJson() => <Map<String, dynamic>>[
        for (final ZChatArtifactDeclaration d in declarations) d.toJson(),
      ];

  @override
  String toString() => 'ZChatArtifactRegistry(${keys.join(', ')})';

  static List<ZChatArtifactDeclaration> _ordered(
    Iterable<ZChatArtifactDeclaration> raw,
  ) {
    // Dernière déclaration d'une clé gagnante, ordre d'arrivée conservé pour
    // la position (stable), puis tri stable sur `order`.
    final Map<String, ZChatArtifactDeclaration> byKey =
        <String, ZChatArtifactDeclaration>{};
    for (final ZChatArtifactDeclaration d in raw) {
      byKey[d.key] = d;
    }
    final List<ZChatArtifactDeclaration> out = byKey.values.toList();
    final List<int> index = List<int>.generate(out.length, (int i) => i);
    index.sort((int a, int b) {
      final int c = out[a].order.compareTo(out[b].order);
      return c != 0 ? c : a.compareTo(b);
    });
    return <ZChatArtifactDeclaration>[for (final int i in index) out[i]];
  }
}

/// Suggestions de relance — `ZChatSuggestion` / `ZChatSuggestionAction`.
///
/// origine: lex_core (module « Assistant ») — `lexia_suggestion.dart:6-44`
/// (`LexiaSuggestion` + `SuggestionAction`, `@JsonSerializable` **non porté** :
/// aucun codegen dans `zcrud_core` — D1).
///
/// ## Une amélioration sur lex, assumée : brut **ET** typé
///
/// lex porte `type`/`action_type` en **`String` brute** dans les entités
/// (`lexia_suggestion.dart:8,30`) et n'expose la version typée que par des
/// factories séparées (`SuggestionType.fromString`) — l'appelant doit convertir
/// lui-même, et une valeur inconnue est soit perdue, soit non typée.
/// Ici les **deux** coexistent : le champ brut garantit le **round-trip sans
/// perte** d'une valeur que le cœur ne connaît pas, et un **getter dérivé**
/// donne la valeur typée quand elle est reconnue (`null` sinon).
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_enums.dart';

/// Une action proposée par une suggestion (raccourci + libellés + charge utile).
class ZChatSuggestionAction {
  /// Construit une action (immuable, `const`).
  const ZChatSuggestionAction({
    this.shortcut = '',
    this.title = '',
    this.description = '',
    this.actionType = '',
    this.payload,
  });

  /// Raccourci clavier/textuel déclencheur.
  final String shortcut;

  /// Titre de l'action (libellé **fourni par l'hôte**, jamais traduit ici).
  final String title;

  /// Description de l'action.
  final String description;

  /// Nature **brute** de l'action (clé persistée `action_type`).
  final String actionType;

  /// Charge utile libre de l'action (paramètres de navigation, contenu à
  /// copier…), préservée telle quelle.
  final Map<String, dynamic>? payload;

  /// Nature **typée** de l'action, ou `null` si [actionType] est inconnu du
  /// cœur (la valeur brute reste, elle, intacte).
  ZChatSuggestionActionType? get typedActionType =>
      ZChatSuggestionActionType.fromJson(actionType);

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZChatSuggestionAction? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final Map<String, dynamic>? payload =
        zJsonMap(map['payload']);
    return ZChatSuggestionAction(
      shortcut: zJsonString(map['shortcut']),
      title: zJsonString(map['title']),
      description: zJsonString(map['description']),
      actionType: zJsonString(map['action_type']),
      payload:
          payload == null ? null : Map<String, dynamic>.unmodifiable(payload),
    );
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'shortcut': shortcut,
        'title': title,
        'description': description,
        'action_type': actionType,
        if (payload != null) 'payload': payload,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSuggestionAction &&
          shortcut == other.shortcut &&
          title == other.title &&
          description == other.description &&
          actionType == other.actionType &&
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(
        shortcut,
        title,
        description,
        actionType,
        zJsonHash(payload),
      );

  @override
  String toString() => 'ZChatSuggestionAction(shortcut: $shortcut)';
}

/// Une suggestion de relance proposée à l'utilisateur.
class ZChatSuggestion {
  /// Construit une suggestion (immuable, `const`).
  const ZChatSuggestion({
    this.id = '',
    this.type = '',
    this.content = '',
    this.actions = const <ZChatSuggestionAction>[],
  });

  /// Identifiant opaque de la suggestion.
  final String id;

  /// Nature **brute** de la suggestion.
  final String type;

  /// Texte de la suggestion (**fourni par l'hôte**, jamais traduit ici).
  final String content;

  /// Actions associées (jamais `null` : liste vide si absente).
  final List<ZChatSuggestionAction> actions;

  /// Nature **typée**, ou `null` si [type] est inconnu du cœur.
  ZChatSuggestionType? get typedType => ZChatSuggestionType.fromJson(type);

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null` ; une action
  /// illisible est **ignorée**, elle n'annule pas la liste (**G10**).
  static ZChatSuggestion? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatSuggestion(
      id: zJsonString(map['id']),
      type: zJsonString(map['type']),
      content: zJsonString(map['content']),
      actions: zJsonDecodeList<ZChatSuggestionAction>(
            map['actions'],
            ZChatSuggestionAction.fromJson,
          ) ??
          const <ZChatSuggestionAction>[],
    );
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'content': content,
        'actions': <Map<String, dynamic>>[
          for (final ZChatSuggestionAction a in actions) a.toJson(),
        ],
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSuggestion &&
          id == other.id &&
          type == other.type &&
          content == other.content &&
          zListEquals(actions, other.actions);

  @override
  int get hashCode =>
      Object.hash(id, type, content, zListHash(actions));

  @override
  String toString() => 'ZChatSuggestion(id: $id, type: $type)';
}

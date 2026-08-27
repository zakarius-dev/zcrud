/// **Le vocabulaire des commandes** — une commande déclarée, son catalogue, et
/// l'invocation que le socle remet à l'hôte.
///
/// Domaine PUR (aucun Flutter, aucun libellé, aucune icône, aucune couleur).
///
/// ## Les trois règles normatives portées par ce fichier
///
/// 1. **Le socle n'exécute AUCUNE commande.** Il reconnaît l'amorce, identifie
///    la commande **déclarée par l'hôte** qui répond au jeton saisi, et rend
///    une [ZChatSlashInvocation]. Ce que la commande fait, quand elle le fait
///    et avec quels effets n'appartient qu'à l'hôte : sans quoi le socle
///    deviendrait un interpréteur, avec son vocabulaire et ses surprises.
/// 2. **Un jeton inconnu n'est jamais deviné.** Pas de correspondance
///    approchée, pas de « vouliez-vous dire », pas de commande par défaut :
///    [ZChatSlashCatalog.commandFor] rend `null`, et le texte reste du texte.
/// 3. **Le socle ne nomme rien** (FR-26). Le nom de la commande, ses alias,
///    son libellé, sa description et l'invite d'argument sont **des données
///    d'hôte** — servies en dur par le code appelant ou par le backend, jamais
///    codées ici.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_mention.dart';

/// Une **commande déclarée** : une identité, les jetons qui l'appellent, et de
/// quoi la rendre.
class ZChatSlashCommand {
  /// Construit une commande.
  ZChatSlashCommand({
    required this.key,
    this.label,
    this.description,
    this.iconKey,
    this.sectionKey,
    Iterable<String> aliases = const <String>[],
    this.argumentHint,
    this.requiresArgument = false,
    this.disabledReasonToken,
    this.order = 0,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : aliases = List<String>.unmodifiable(_tokens(aliases)),
       _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Identité **stable et opaque**, et **premier jeton d'appel** : une saisie
  /// qui reproduit cette clé désigne cette commande.
  final String key;

  /// Libellé **déjà localisé par l'hôte**. `null` ⇒ absent ; le socle
  /// n'affiche jamais [key] à sa place.
  final String? label;

  /// Description d'hôte, déjà localisée. `null` ⇒ absente.
  final String? description;

  /// Clé d'icône **opaque**, résolue par l'hôte au rendu. `null` ⇒ aucune.
  final String? iconKey;

  /// Section d'appartenance dans le panneau. `null` ⇒ non assignée.
  final String? sectionKey;

  /// Jetons d'appel supplémentaires (abréviations, autre langue…), rognés,
  /// dédupliqués, vides écartés. La comparaison est **insensible à la casse**.
  final List<String> aliases;

  /// Invite d'argument **déjà localisée** par l'hôte. `null` ⇒ absente.
  final String? argumentHint;

  /// `true` si la commande n'a de sens qu'accompagnée d'un argument.
  ///
  /// C'est un **constat déclaré**, lu par [ZChatSlashInvocation.isComplete] :
  /// le socle n'en tire aucune conséquence — il ne bloque ni n'envoie rien.
  final bool requiresArgument;

  /// Jeton **opaque** de raison d'indisponibilité. `null` ⇒ commande
  /// appelable. Une commande indisponible est **rendue avec sa raison**,
  /// jamais masquée.
  final String? disabledReasonToken;

  /// `true` si la commande est appelable.
  bool get isEnabled => disabledReasonToken == null;

  /// Rang souhaité **par l'hôte** au sein du catalogue (croissant) ; à
  /// égalité, l'ordre de déclaration décide.
  final int order;

  /// Slot d'extension typé versionné (invariant AD-4).
  final ZExtension? extension;

  /// Données d'hôte libres (invariant AD-4), immuables.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) et les
  /// clés propres de la commande en sont **retirées**, quelle que soit la voie
  /// d'écriture : elles ne sont ni conservées ni réémises par [toJson].
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  final Map<String, dynamic> _extra;

  static const Set<String> _reservedKeys = <String>{
    'key',
    'label',
    'description',
    'icon_key',
    'section_key',
    'aliases',
    'argument_hint',
    'requires_argument',
    'disabled_reason_token',
    'order',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// `true` si [token] (rogné, insensible à la casse) désigne cette commande —
  /// par sa [key] ou par un de ses [aliases].
  ///
  /// Correspondance **exacte** : aucune approximation, aucun préfixe. Un jeton
  /// vide ne désigne rien.
  bool answersTo(String token) {
    final String t = token.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (key.toLowerCase() == t) return true;
    for (final String a in aliases) {
      if (a.toLowerCase() == t) return true;
    }
    return false;
  }

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais. Une commande
  /// sans clé lisible est écartée (`null`) : elle n'aurait aucun jeton
  /// d'appel, donc aucune existence utile.
  static ZChatSlashCommand? fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String key = zJsonString(map['key']).trim();
    if (key.isEmpty) return null;
    return ZChatSlashCommand(
      key: key,
      label: zJsonStringOrNull(map['label']),
      description: zJsonStringOrNull(map['description']),
      iconKey: zJsonStringOrNull(map['icon_key']),
      sectionKey: zJsonStringOrNull(map['section_key']),
      aliases: zJsonStringList(map['aliases']) ?? const <String>[],
      argumentHint: zJsonStringOrNull(map['argument_hint']),
      requiresArgument: zJsonBool(map['requires_argument'], false),
      disabledReasonToken: zJsonStringOrNull(map['disabled_reason_token']),
      order: zJsonInt(map['order'], 0),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    if (label != null) 'label': label,
    if (description != null) 'description': description,
    if (iconKey != null) 'icon_key': iconKey,
    if (sectionKey != null) 'section_key': sectionKey,
    if (aliases.isNotEmpty) 'aliases': aliases,
    if (argumentHint != null) 'argument_hint': argumentHint,
    if (requiresArgument) 'requires_argument': true,
    if (disabledReasonToken != null)
      'disabled_reason_token': disabledReasonToken,
    if (order != 0) 'order': order,
    if (extension != null) 'extension': extension!.toJson(),
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  String toString() => 'ZChatSlashCommand($key, alias: ${aliases.length})';
}

/// Le **catalogue** des commandes déclarées, avec l'amorce qui les appelle.
///
/// Sérialisable de bout en bout : un hôte peut le déclarer en dur **ou** le
/// recevoir de son backend, sans que le socle change de comportement.
class ZChatSlashCatalog {
  /// Construit un catalogue. Les commandes sont **dédupliquées par clé**
  /// (première déclaration gagnante) et l'ordre de déclaration est conservé.
  ZChatSlashCatalog({
    this.trigger,
    Iterable<ZChatSlashCommand> commands = const <ZChatSlashCommand>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : commands = List<ZChatSlashCommand>.unmodifiable(_dedupe(commands)),
       _extra = zSanitizeExtra(extra, _reservedKeys);

  /// L'amorce qui ouvre le panneau. `null` ⇒ aucune amorce déclarée : le
  /// catalogue reste consultable, mais [invocationIn] ne reconnaît plus rien.
  final ZChatMentionTrigger? trigger;

  /// Les commandes, dans l'ordre de **déclaration**.
  final List<ZChatSlashCommand> commands;

  /// Slot d'extension typé versionné (invariant AD-4).
  final ZExtension? extension;

  /// Données d'hôte libres (invariant AD-4), immuables — clés de sync et clés
  /// propres retirées, quelle que soit la voie d'écriture.
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  final Map<String, dynamic> _extra;

  static const Set<String> _reservedKeys = <String>{
    'trigger',
    'commands',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// `true` si aucune commande n'est déclarée.
  bool get isEmpty => commands.isEmpty;

  /// Les commandes rangées selon le rang **déclaré par l'hôte**
  /// ([ZChatSlashCommand.order]), à égalité l'ordre de déclaration.
  ///
  /// Le socle applique ici le classement de l'hôte ; il n'en invente aucun
  /// (ni alphabétique, ni par fréquence, ni par pertinence).
  List<ZChatSlashCommand> get ordered {
    final List<ZChatSlashCommand> out = List<ZChatSlashCommand>.of(commands);
    final Map<ZChatSlashCommand, int> rank = <ZChatSlashCommand, int>{
      for (int i = 0; i < out.length; i++) out[i]: i,
    };
    out.sort((ZChatSlashCommand a, ZChatSlashCommand b) {
      final int c = a.order.compareTo(b.order);
      return c != 0 ? c : rank[a]!.compareTo(rank[b]!);
    });
    return List<ZChatSlashCommand>.unmodifiable(out);
  }

  /// La commande que [token] désigne, ou `null` si aucune ne répond.
  ///
  /// Aucune approximation : un jeton inconnu reste inconnu.
  ZChatSlashCommand? commandFor(String token) {
    for (final ZChatSlashCommand c in commands) {
      if (c.answersTo(token)) return c;
    }
    return null;
  }

  /// Reconnaît une invocation dans [text] au curseur [caretOffset], ou rend
  /// `null` — sans jamais lever.
  ///
  /// La lecture s'arrête à l'identification : le résultat est **remis** à
  /// l'hôte, qui décide seul de ce qu'il en fait. Rend `null` si aucun
  /// [trigger] n'est déclaré, si l'amorce n'est pas reconnue, ou si le jeton
  /// saisi ne désigne aucune commande.
  ///
  /// Pour qu'une invocation porte des arguments, l'amorce doit avoir été
  /// déclarée avec [ZChatMentionTrigger.allowsWhitespace] à `true` ; sinon la
  /// requête s'arrête au premier blanc et [ZChatSlashInvocation.arguments]
  /// reste vide.
  ZChatSlashInvocation? invocationIn(String text, int caretOffset) {
    final ZChatMentionMatch? m = trigger?.matchIn(text, caretOffset);
    if (m == null) return null;
    final int cut = m.query.indexOf(' ');
    final String token = cut < 0 ? m.query : m.query.substring(0, cut);
    final String args = cut < 0 ? '' : m.query.substring(cut + 1).trim();
    final ZChatSlashCommand? command = commandFor(token);
    if (command == null) return null;
    return ZChatSlashInvocation(
      command: command,
      arguments: args,
      start: m.start,
      end: m.end,
    );
  }

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais. Une entrée
  /// illisible de `commands` est **sautée** sans emporter les autres ; une
  /// racine illisible rend un catalogue **vide**, jamais `null` : un panneau
  /// sans commande reste un panneau, une absence de catalogue serait une panne.
  static ZChatSlashCatalog fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return ZChatSlashCatalog();
    return ZChatSlashCatalog(
      trigger: ZChatMentionTrigger.fromJson(
        map['trigger'],
        extensionParser: extensionParser,
      ),
      commands:
          zJsonDecodeList<ZChatSlashCommand>(
            map['commands'],
            (Object? e) =>
                ZChatSlashCommand.fromJson(e, extensionParser: extensionParser),
          ) ??
          const <ZChatSlashCommand>[],
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (trigger != null) 'trigger': trigger!.toJson(),
    if (commands.isNotEmpty)
      'commands': <Map<String, dynamic>>[
        for (final ZChatSlashCommand c in commands) c.toJson(),
      ],
    if (extension != null) 'extension': extension!.toJson(),
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  String toString() => 'ZChatSlashCatalog(${commands.length} commandes)';
}

/// Ce que la reconnaissance a établi : **quelle commande déclarée** le texte
/// appelle, et **avec quoi**.
///
/// C'est un constat remis à l'hôte. Le socle n'a rien exécuté et n'exécutera
/// rien : il n'a même pas d'opinion sur le moment où l'hôte devrait agir.
class ZChatSlashInvocation {
  /// Construit une invocation.
  const ZChatSlashInvocation({
    required this.command,
    required this.arguments,
    required this.start,
    required this.end,
  });

  /// La commande **déclarée par l'hôte** que le jeton saisi désigne.
  final ZChatSlashCommand command;

  /// Le texte saisi après le jeton, rogné. Vide si aucun argument.
  final String arguments;

  /// Décalage de l'amorce dans le texte (inclus).
  final int start;

  /// Décalage du curseur (exclu).
  final int end;

  /// `true` si l'argument exigé par la déclaration est présent.
  ///
  /// Un `false` **n'empêche rien** : c'est une information rendue à l'hôte,
  /// pas un refus du socle.
  bool get isComplete => !command.requiresArgument || arguments.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSlashInvocation &&
          identical(command, other.command) &&
          arguments == other.arguments &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(command), arguments, start, end);

  @override
  String toString() =>
      'ZChatSlashInvocation(${command.key}, "$arguments", $start..$end)';
}

List<String> _tokens(Iterable<String> raw) {
  final List<String> out = <String>[];
  for (final String t in raw) {
    final String v = t.trim();
    if (v.isEmpty || out.contains(v)) continue;
    out.add(v);
  }
  return out;
}

List<ZChatSlashCommand> _dedupe(Iterable<ZChatSlashCommand> raw) {
  final List<ZChatSlashCommand> out = <ZChatSlashCommand>[];
  final Set<String> seen = <String>{};
  for (final ZChatSlashCommand c in raw) {
    if (!seen.add(c.key)) continue;
    out.add(c);
  }
  return out;
}

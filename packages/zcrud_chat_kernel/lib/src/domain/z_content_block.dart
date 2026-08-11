/// Blocs de contenu structuré d'un message d'assistant — `ZContentBlock`.
///
/// (enveloppe `{type, data}` + 12 variantes `sealed`).
///
/// ## 9 variantes fermées + 1 variant ouvert + le registre
///
/// Une application de chat enrichie tend à accumuler plus de variantes de
/// blocs que ce qu'un socle générique peut porter. Neuf sont **génériques**
/// et sont typées ici. D'autres ne peuvent **pas** entrer dans le cœur, et le
/// dire est la preuve que le registre n'est pas décoratif :
///
/// | Variante | Statut | Pourquoi | Clé de registre recommandée |
/// |---|---|---|---|
/// | Référence légale/juridique | **app-side** | vocabulaire (« articles »…) trop spécialisé pour un socle éducatif générique | `'legalReference'` |
/// | Flashcards | **satellite/app-side** | porterait `List<ZFlashcard>` ⇒ arête `zcrud_core → zcrud_flashcard` = invariant AD-1 rouge | `'flashcards'` |
/// | Carte mentale | **satellite/app-side** | porterait `ZMindmap` ⇒ arête `zcrud_core → zcrud_mindmap` = invariant AD-1 rouge | `'mindmap'` |
///
/// L'hôte les rebranche **sans forker le cœur** :
///
/// ```dart
/// final types = ZTypeRegistry()
///   ..register(
///     'legalReference',
///     fromJson: (json) => MonBlocJuridique.fromJson(json),
///     toJson: (value) => (value as MonBlocJuridique).toJson(),
///   );
/// final bloc = ZContentBlock.fromJson(raw, typeRegistry: types);
/// ```
///
/// **Sans** registre, le même document retombe sur [ZCustomContentBlock] —
/// **payload verbatim, round-trip garanti** : la donnée n'est jamais perdue,
/// seul le *type* n'est pas reconstruit.
///
/// ## Un type inconnu ne devient pas du texte
///
/// Un mapping de secours naïf du genre `_ => TextBlock(text: json.toString())`
/// transforme un bloc inconnu en une bulle de texte contenant le **dump
/// Dart** de la map. C'est **destructeur** (round-trip perdu) **et visible
/// par l'utilisateur**. Ici, le payload est **préservé tel quel**.
///
/// ## Casse du discriminant — principe de Postel
///
/// Un document existant peut persister ses discriminants en PascalCase
/// (`'Text'`, `'KeyDefinition'`) ; zcrud persiste les siens en **camelCase**
/// (convention `Naming & Consistency`). **Écriture** = camelCase canonique ;
/// **lecture** = tolérante, les alias PascalCase historiquement rencontrés
/// sont acceptés — c'est ce qui rend un document existant relisible
/// **typé**, sans migration préalable.
///
/// ## [ZContentBlock.accessibleText] — le résumé annonçable, réglé une fois
///
/// Un composant de rendu tiers qui exige un `String` pour son résumé
/// accessible pousse souvent l'adaptateur à écrire son propre résumé, qui ne
/// connaît que `ZTextBlock`. Un **tableau**, un bloc de **sources** ou un
/// diagramme ne sont alors **pas annoncés du tout** à un lecteur d'écran. Le
/// même trou se rouvrirait dans chaque adaptateur futur.
///
/// Le résumé est donc posé **ici**, sur la famille elle-même : un `switch`
/// **exhaustif** sur l'union scellée, ce qui fait de l'oubli d'une variante une
/// erreur de **compilation** et non un silence.
///
/// ### Arbitrage de LOCALISATION (le kernel est pur-Dart, sans `BuildContext`)
///
/// [accessibleText] n'émet **que la donnée portée par le bloc**, plus de la
/// **ponctuation** ([kZContentBlockAccessibleSeparator]). Il n'écrit **aucune
/// phrase**, aucun nom de rubrique, dans aucune langue : un socle
/// multi-consommateurs qui figerait « Tableau : » ou « Sources : » produirait
/// une régression de localisation **silencieuse** (même arbitrage que
/// `z_chat_labels.dart` de `zcrud_chat`, qui refuse jusqu'au repli français).
///
/// Ce qui est localisable est injecté par la couche **qui possède un
/// `BuildContext`**, via le seam [ZAccessibleTextResolver] : un hôte y branche
/// `label(context, clé)` et **préfixe/remplace** ce qu'il veut, bloc par bloc.
/// Le kernel ne porte donc **aucune table de traduction** — la l10n reste au
/// seul endroit qui en a une.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_source.dart';
import 'z_chat_suggestion.dart';

/// Clé du discriminant de l'enveloppe (`{'type': …, 'data': {…}}`).
const String kZContentBlockTypeKey = 'type';

/// Clé de la charge utile de l'enveloppe.
const String kZContentBlockDataKey = 'data';

/// Alias de **lecture** PascalCase → discriminant canonique camelCase.
const Map<String, String> kZContentBlockReadAliases = <String, String>{
  'Text': 'text',
  'Table': 'table',
  'KeyDefinition': 'keyDefinition',
  'ComparisonTable': 'comparisonTable',
  'Timeline': 'timeline',
  'Alert': 'alert',
  'MermaidDiagram': 'mermaidDiagram',
  'Sources': 'sources',
  'Suggestions': 'suggestions',
};

/// Séparateur des fragments d'un résumé accessible : un saut de ligne.
///
/// C'est de la **ponctuation**, pas un libellé : aucune langue n'y est engagée.
const String kZContentBlockAccessibleSeparator = '\n';

/// Séparateur des cellules d'une même ligne dans un résumé accessible.
///
/// Virgule + espace : ponctuation, jamais un mot. Sans elle, `['01','5%']`
/// s'annoncerait « 015 % » — c'est-à-dire faux.
const String kZContentBlockAccessibleCellSeparator = ', ';

/// Discriminant de repli quand un bloc n'a **ni donnée textuelle ni `kind`**.
///
/// C'est un **jeton machine**, du même vocabulaire que `'text'` ou `'table'` —
/// pas une phrase traduisible. Il n'est jamais vide : une chaîne vide rendue à
/// un lecteur d'écran est le pire des cas (le bloc devient **invisible**, sans
/// que rien ne le signale).
const String kZContentBlockUnknownKind = 'unknown';

/// Seam d'hôte du **résumé accessible** (AD-4).
///
/// Rend le texte à annoncer pour [block], ou `null` pour « je ne prends pas ce
/// bloc, garde le résumé du kernel » — exactement la sémantique de `null` de
/// `ZChatRenderer`/`zResolveGradient`.
///
/// C'est par lui qu'un hôte :
/// * annonce **son** bloc ouvert ([ZCustomContentBlock] : `'legalReference'`,
///   `'flashcards'`, `'mindmap'`), que le kernel ne peut pas connaître ;
/// * **localise** ce qui doit l'être — il est appelé depuis la couche qui
///   possède un `BuildContext`.
///
/// AD-10 : un resolver qui **lève** est absorbé (repli sur le résumé du
/// kernel), et un resolver qui rend une chaîne **vide ou blanche** est ignoré —
/// sans quoi le seam permettrait de rendre un bloc muet par accident.
typedef ZAccessibleTextResolver = String? Function(ZContentBlock block);

/// Résumé accessible d'une **suite** de blocs (un message entier).
///
/// Les blocs vides ne produisent rien de plus qu'eux-mêmes : la fonction est
/// **totale**, ne lève jamais, et rend `''` **uniquement** pour une suite vide —
/// un message sans aucun bloc n'a rien à annoncer, et inventer un texte pour lui
/// serait mentir.
String zChatAccessibleTextOf(
  Iterable<ZContentBlock> blocks, {
  ZAccessibleTextResolver? resolver,
}) {
  final List<String> parts = <String>[
    for (final ZContentBlock b in blocks)
      b.accessibleText(resolver: resolver),
  ];
  return parts.join(kZContentBlockAccessibleSeparator);
}

/// Union **scellée en interne** des blocs de contenu (AD-4 : l'ouverture
/// inter-package passe **exclusivement** par [ZTypeRegistry], jamais par
/// l'héritage d'une classe sérialisée).
sealed class ZContentBlock {
  /// Constructeur `const` (variants immuables).
  const ZContentBlock();

  /// Discriminant persisté du bloc (camelCase, ou valeur brute arbitraire pour
  /// un [ZCustomContentBlock]).
  String get kind;

  /// Sérialise l'enveloppe complète `{'type': kind, 'data': {…}}`.
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  });

  /// Décode **défensivement** un bloc (AD-10) — **totale, ne lève jamais**.
  ///
  /// - [raw] non-`Map` ⇒ `null` ;
  /// - `type` absent, non-`String` ou vide ⇒ `null` ;
  /// - `type` reconnu (canonique **ou** alias PascalCase) ⇒ variant typé, champs
  ///   manquants remplacés par des défauts sûrs ;
  /// - `type` **enregistré** dans [typeRegistry] ⇒ [ZCustomContentBlock] dont le
  ///   payload est reconstruit par le codec de l'app (codec qui lève ⇒ absorbé,
  ///   repli sur le payload verbatim) ;
  /// - `type` inconnu et non enregistré ⇒ [ZCustomContentBlock], **payload
  ///   verbatim**.
  static ZContentBlock? fromJson(
    Object? raw, {
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) {
    final Map<String, dynamic>? envelope = zJsonMap(raw);
    if (envelope == null) return null;
    final Object? rawType = envelope[kZContentBlockTypeKey];
    if (rawType is! String || rawType.isEmpty) return null;
    final Map<String, dynamic> data =
        zJsonMap(envelope[kZContentBlockDataKey]) ??
            const <String, dynamic>{};
    final String kind = kZContentBlockReadAliases[rawType] ?? rawType;

    switch (kind) {
      case 'text':
        return ZTextBlock(text: zJsonString(data['text']));
      case 'table':
        return ZTableBlock(
          title: zJsonStringOrNull(data['title']),
          headers: zJsonStringList(data['headers']) ?? const <String>[],
          rows: _rowsOf(data['rows']),
        );
      case 'keyDefinition':
        return ZKeyDefinitionBlock(
          term: zJsonString(data['term']),
          definition: zJsonString(data['definition']),
          source: zJsonStringOrNull(data['source']),
        );
      case 'comparisonTable':
        return ZComparisonTableBlock(
          title: zJsonStringOrNull(data['title']),
          columns: zJsonDecodeList<ZComparisonColumn>(
                data['columns'],
                ZComparisonColumn.fromJson,
              ) ??
              const <ZComparisonColumn>[],
        );
      case 'timeline':
        return ZTimelineBlock(
          title: zJsonStringOrNull(data['title']),
          events: zJsonDecodeList<ZTimelineEvent>(
                data['events'],
                ZTimelineEvent.fromJson,
              ) ??
              const <ZTimelineEvent>[],
        );
      case 'alert':
        return ZAlertBlock(
          level: zJsonString(data['level']),
          title: zJsonStringOrNull(data['title']),
          message: zJsonString(data['message']),
        );
      case 'mermaidDiagram':
        return ZMermaidDiagramBlock(
          title: zJsonStringOrNull(data['title']),
          code: zJsonString(data['code']),
        );
      case 'sources':
        return ZSourcesBlock(
          sources: zJsonDecodeList<ZChatSource>(
                data['sources'],
                (Object? e) =>
                    ZChatSource.fromJson(e, registry: sourceRegistry),
              ) ??
              const <ZChatSource>[],
        );
      case 'suggestions':
        return ZSuggestionsBlock(
          suggestions: zJsonDecodeList<ZChatSuggestion>(
                data['suggestions'],
                ZChatSuggestion.fromJson,
              ) ??
              const <ZChatSuggestion>[],
        );
      default:
        // `tryCodecFor`, jamais `codecFor` (qui lève — AD-10).
        final ZValueCodec? codec = typeRegistry?.tryCodecFor(rawType);
        if (codec != null) {
          final Map<String, dynamic>? decoded =
              zJsonMap(zJsonGuard(() => codec.fromJson(data)));
          return ZCustomContentBlock(rawType, decoded ?? data);
        }
        return ZCustomContentBlock(rawType, data);
    }
  }

  /// Lecture défensive d'une matrice de chaînes (`rows`) — une ligne non-`List`
  /// est ignorée, une cellule non-`String` est ignorée.
  static List<List<String>> _rowsOf(Object? raw) {
    if (raw is! List) return const <List<String>>[];
    return <List<String>>[
      for (final Object? row in raw)
        if (row is List) zJsonStringList(row) ?? const <String>[],
    ];
  }

  /// Texte **annonçable** du bloc — total, jamais vide, jamais traduit ici.
  ///
  /// Contrat, en quatre points :
  /// 1. **Totalité** : ne lève jamais (AD-10), quelle que soit la donnée — y
  ///    compris un `payload` custom hostile.
  /// 2. **Jamais vide** : le repli final est le [kind] du bloc (un
  ///    discriminant machine), puis [kZContentBlockUnknownKind]. Une chaîne
  ///    vide rendrait le bloc **muet et invisible** au lecteur d'écran.
  /// 3. **Exhaustivité prouvée par le compilateur** : le `switch` ci-dessous
  ///    porte sur l'union scellée — ajouter une variante au kernel **casse la
  ///    compilation** ici plutôt que de la laisser silencieuse. C'est le trou
  ///    exact que C6 a mesuré côté adaptateur (résumé local ne connaissant que
  ///    `ZTextBlock` ⇒ tableaux et sources **non annoncés**).
  /// 4. **Aucune prose du socle** : seules la donnée et la ponctuation. Ce qui
  ///    doit être localisé passe par [resolver] — cf. l'en-tête de bibliothèque.
  ///
  /// [resolver] est consulté **en premier, pour TOUTE variante** (pas seulement
  /// les blocs ouverts) : un hôte qui veut annoncer son tableau autrement le
  /// peut, sans que le kernel ait à prévoir le cas.
  String accessibleText({ZAccessibleTextResolver? resolver}) {
    if (resolver != null) {
      // AD-10 : un seam d'hôte qui lève ne doit pas rendre le message muet.
      String? custom;
      try {
        custom = resolver(this);
      } catch (_) {
        custom = null;
      }
      if (custom != null && custom.trim().isNotEmpty) return custom;
    }
    final List<String> parts = _accessibleParts();
    final List<String> kept = <String>[
      for (final String p in parts)
        if (p.trim().isNotEmpty) p,
    ];
    if (kept.isNotEmpty) return kept.join(kZContentBlockAccessibleSeparator);
    return kind.trim().isEmpty ? kZContentBlockUnknownKind : kind;
  }

  /// Fragments annonçables du bloc, dans l'ordre de lecture. Les vides sont
  /// filtrés par [accessibleText] — jamais ici, pour que chaque variante reste
  /// lisible telle qu'elle est écrite.
  List<String> _accessibleParts() {
    switch (this) {
      case final ZTextBlock b:
        return <String>[b.text];
      case final ZTableBlock b:
        return <String>[
          if (b.title != null) b.title!,
          if (b.headers.isNotEmpty)
            b.headers.join(kZContentBlockAccessibleCellSeparator),
          for (final List<String> row in b.rows)
            row.join(kZContentBlockAccessibleCellSeparator),
        ];
      case final ZKeyDefinitionBlock b:
        return <String>[b.term, b.definition, if (b.source != null) b.source!];
      case final ZComparisonTableBlock b:
        return <String>[
          if (b.title != null) b.title!,
          for (final ZComparisonColumn c in b.columns)
            <String>[
              c.header,
              ...c.values,
            ].where((String s) => s.trim().isNotEmpty)
                .join(kZContentBlockAccessibleCellSeparator),
        ];
      case final ZTimelineBlock b:
        return <String>[
          if (b.title != null) b.title!,
          for (final ZTimelineEvent e in b.events) ...<String>[
            <String>[e.date, e.title]
                .where((String s) => s.trim().isNotEmpty)
                .join(kZContentBlockAccessibleCellSeparator),
            if (e.description != null) e.description!,
          ],
        ];
      case final ZAlertBlock b:
        // Le NIVEAU est une donnée de l'hôte (`String` ouverte), annoncée telle
        // quelle — jamais traduite par le socle, exactement comme le fait déjà
        // le rendu neutre (`Semantics(label: block.level)`).
        return <String>[b.level, if (b.title != null) b.title!, b.message];
      case final ZMermaidDiagramBlock b:
        return <String>[if (b.title != null) b.title!, b.code];
      case final ZSourcesBlock b:
        return <String>[
          // Même règle que le rendu neutre : le texte d'affichage porté par la
          // donnée, à défaut son type. Aucun libellé fabriqué.
          for (final ZChatSource s in b.sources)
            s.displayText.trim().isEmpty ? s.sourceType : s.displayText,
        ];
      case final ZSuggestionsBlock b:
        return <String>[for (final ZChatSuggestion s in b.suggestions) s.content];
      case final ZCustomContentBlock b:
        // Le payload n'est PAS dumpé : le kernel l'a délibérément préservé
        // verbatim, et l'annoncer reproduirait à l'oreille le défaut d'un
        // mapping de secours naïf (`TextBlock(text: json.toString())`).
        // Sans [resolver], le bloc est annoncé par son `kind` — signalé,
        // jamais muet.
        return <String>[b.kind];
    }
  }

  /// Enveloppe canonique `{'type': kind, 'data': body}`.
  Map<String, dynamic> _envelope(Map<String, dynamic> body) =>
      <String, dynamic>{
        kZContentBlockTypeKey: kind,
        kZContentBlockDataKey: body,
      };
}

/// Bloc de texte brut.
class ZTextBlock extends ZContentBlock {
  /// Construit un bloc de texte.
  const ZTextBlock({this.text = ''});

  /// Contenu textuel.
  final String text;

  @override
  String get kind => 'text';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{'text': text});

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ZTextBlock && text == other.text;

  @override
  int get hashCode => Object.hash(kind, text);
}

/// Tableau simple (en-têtes + lignes).
class ZTableBlock extends ZContentBlock {
  /// Construit un tableau.
  const ZTableBlock({
    this.title,
    this.headers = const <String>[],
    this.rows = const <List<String>>[],
  });

  /// Titre optionnel.
  final String? title;

  /// En-têtes de colonnes.
  final List<String> headers;

  /// Lignes du tableau.
  final List<List<String>> rows;

  @override
  String get kind => 'table';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        if (title != null) 'title': title,
        'headers': headers,
        'rows': rows,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTableBlock &&
          title == other.title &&
          zListEquals(headers, other.headers) &&
          zJsonEquals(rows, other.rows);

  @override
  int get hashCode =>
      Object.hash(kind, title, zListHash(headers), zJsonHash(rows));
}

/// Définition d'un terme clé (terme / définition / source).
class ZKeyDefinitionBlock extends ZContentBlock {
  /// Construit une définition.
  const ZKeyDefinitionBlock({
    this.term = '',
    this.definition = '',
    this.source,
  });

  /// Terme défini.
  final String term;

  /// Définition du terme.
  final String definition;

  /// Provenance libre de la définition.
  final String? source;

  @override
  String get kind => 'keyDefinition';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        'term': term,
        'definition': definition,
        if (source != null) 'source': source,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZKeyDefinitionBlock &&
          term == other.term &&
          definition == other.definition &&
          source == other.source;

  @override
  int get hashCode => Object.hash(kind, term, definition, source);
}

/// Une colonne d'un [ZComparisonTableBlock].
class ZComparisonColumn {
  /// Construit une colonne.
  const ZComparisonColumn({
    this.header = '',
    this.values = const <String>[],
  });

  /// En-tête de la colonne.
  final String header;

  /// Valeurs de la colonne.
  final List<String> values;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZComparisonColumn? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZComparisonColumn(
      header: zJsonString(map['header']),
      values: zJsonStringList(map['values']) ?? const <String>[],
    );
  }

  /// Sérialise la colonne.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'header': header,
        'values': values,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZComparisonColumn &&
          header == other.header &&
          zListEquals(values, other.values);

  @override
  int get hashCode => Object.hash(header, zListHash(values));

  @override
  String toString() => 'ZComparisonColumn(header: $header)';
}

/// Tableau comparatif (colonnes parallèles).
class ZComparisonTableBlock extends ZContentBlock {
  /// Construit un tableau comparatif.
  const ZComparisonTableBlock({
    this.title,
    this.columns = const <ZComparisonColumn>[],
  });

  /// Titre optionnel.
  final String? title;

  /// Colonnes comparées.
  final List<ZComparisonColumn> columns;

  @override
  String get kind => 'comparisonTable';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        if (title != null) 'title': title,
        'columns': <Map<String, dynamic>>[
          for (final ZComparisonColumn c in columns) c.toJson(),
        ],
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZComparisonTableBlock &&
          title == other.title &&
          zListEquals(columns, other.columns);

  @override
  int get hashCode => Object.hash(kind, title, zListHash(columns));
}

/// Un évènement d'un [ZTimelineBlock].
class ZTimelineEvent {
  /// Construit un évènement.
  const ZTimelineEvent({
    this.date = '',
    this.title = '',
    this.description,
  });

  /// Date **libre** de l'évènement (`String` : une frise pédagogique porte
  /// « 1789 », « IIᵉ siècle », « vers 1500 » — pas une date ISO).
  final String date;

  /// Titre de l'évènement.
  final String title;

  /// Description optionnelle.
  final String? description;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZTimelineEvent? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZTimelineEvent(
      date: zJsonString(map['date']),
      title: zJsonString(map['title']),
      description: zJsonStringOrNull(map['description']),
    );
  }

  /// Sérialise l'évènement.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'title': title,
        if (description != null) 'description': description,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTimelineEvent &&
          date == other.date &&
          title == other.title &&
          description == other.description;

  @override
  int get hashCode => Object.hash(date, title, description);

  @override
  String toString() => 'ZTimelineEvent(date: $date, title: $title)';
}

/// Frise chronologique.
class ZTimelineBlock extends ZContentBlock {
  /// Construit une frise.
  const ZTimelineBlock({
    this.title,
    this.events = const <ZTimelineEvent>[],
  });

  /// Titre optionnel.
  final String? title;

  /// Évènements de la frise.
  final List<ZTimelineEvent> events;

  @override
  String get kind => 'timeline';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        if (title != null) 'title': title,
        'events': <Map<String, dynamic>>[
          for (final ZTimelineEvent e in events) e.toJson(),
        ],
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTimelineBlock &&
          title == other.title &&
          zListEquals(events, other.events);

  @override
  int get hashCode => Object.hash(kind, title, zListHash(events));
}

/// Encadré d'alerte.
class ZAlertBlock extends ZContentBlock {
  /// Construit une alerte.
  const ZAlertBlock({
    this.level = '',
    this.title,
    this.message = '',
  });

  /// Niveau d'alerte — **`String` ouverte, volontairement**.
  ///
  /// Fermer cet ensemble en un enum transformerait un niveau propre à un
  /// hôte (`'tip'`, `'deprecated'`) en donnée perdue à la première valeur non
  /// prévue.
  final String level;

  /// Titre optionnel de l'encadré.
  final String? title;

  /// Message de l'encadré.
  final String message;

  @override
  String get kind => 'alert';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        'level': level,
        if (title != null) 'title': title,
        'message': message,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAlertBlock &&
          level == other.level &&
          title == other.title &&
          message == other.message;

  @override
  int get hashCode => Object.hash(kind, level, title, message);
}

/// Diagramme Mermaid (titre optionnel + code source).
///
/// **Zéro dépendance** : deux chaînes. Le rendu est app-side.
class ZMermaidDiagramBlock extends ZContentBlock {
  /// Construit un diagramme.
  const ZMermaidDiagramBlock({this.title, this.code = ''});

  /// Titre optionnel.
  final String? title;

  /// Code source Mermaid, **non interprété** par le domaine.
  final String code;

  @override
  String get kind => 'mermaidDiagram';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        if (title != null) 'title': title,
        'code': code,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMermaidDiagramBlock &&
          title == other.title &&
          code == other.code;

  @override
  int get hashCode => Object.hash(kind, title, code);
}

/// Bloc de provenance (liste de [ZChatSource]).
class ZSourcesBlock extends ZContentBlock {
  /// Construit un bloc de sources.
  const ZSourcesBlock({this.sources = const <ZChatSource>[]});

  /// Sources citées.
  final List<ZChatSource> sources;

  @override
  String get kind => 'sources';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        'sources': <Map<String, dynamic>>[
          for (final ZChatSource s in sources)
            s.toJson(registry: sourceRegistry),
        ],
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSourcesBlock && zListEquals(sources, other.sources);

  @override
  int get hashCode => Object.hash(kind, zListHash(sources));
}

/// Bloc de relances (liste de [ZChatSuggestion]).
class ZSuggestionsBlock extends ZContentBlock {
  /// Construit un bloc de suggestions.
  const ZSuggestionsBlock({this.suggestions = const <ZChatSuggestion>[]});

  /// Suggestions proposées.
  final List<ZChatSuggestion> suggestions;

  @override
  String get kind => 'suggestions';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      _envelope(<String, dynamic>{
        'suggestions': <Map<String, dynamic>>[
          for (final ZChatSuggestion s in suggestions) s.toJson(),
        ],
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSuggestionsBlock &&
          zListEquals(suggestions, other.suggestions);

  @override
  int get hashCode => Object.hash(kind, zListHash(suggestions));
}

/// Variant **OUVERT** : tout `type` que le cœur ne connaît pas, **payload
/// préservé verbatim**.
///
/// C'est ce qui rend atteignable toute variante propre à un hôte (une
/// référence légale, un jeu de flashcards, une carte mentale…) **sans forker
/// le cœur** : avec un codec [ZTypeRegistry], le payload est reconstruit par
/// l'app ; sans codec, il traverse intact.
class ZCustomContentBlock extends ZContentBlock {
  /// Construit un bloc ouvert pour [kind] portant [payload].
  ZCustomContentBlock(this.kind, Map<String, dynamic> payload)
      : payload = Map<String, dynamic>.unmodifiable(payload);

  @override
  final String kind;

  /// Charge utile **verbatim** (le contenu de `data`).
  final Map<String, dynamic> payload;

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) {
    final ZValueCodec? codec = typeRegistry?.tryCodecFor(kind);
    final Map<String, dynamic> body = codec == null
        ? payload
        : (zJsonGuard(() => codec.toJson(payload)) ?? payload);
    return _envelope(body);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCustomContentBlock &&
          kind == other.kind &&
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(kind, zJsonHash(payload));

  @override
  String toString() => 'ZCustomContentBlock(kind: $kind)';
}

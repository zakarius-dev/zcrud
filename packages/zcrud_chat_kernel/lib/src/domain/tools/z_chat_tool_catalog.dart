/// **Le catalogue d'outils, et son état dérivé** — `ZChatToolCatalog`.
///
/// Domaine PUR : une donnée, et des **dérivations pures et testables**. Aucune
/// surface de rendu n'a de décision à reprendre — elle projette ce que la
/// résolution lui rend.
///
/// ## Ce que le catalogue répond, et pourquoi ces questions-là
///
/// | Question | Réponse |
/// |---|---|
/// | Qu'est-ce que cette surface doit rendre ? | [ZChatToolCatalog.resolve] |
/// | Pourquoi cette entrée n'est-elle pas là ? | [ZChatToolResolution.hidden] |
/// | Pourquoi celle-ci est-elle grisée ? | [ZChatToolResolvedEntry.disabledReasonToken] |
/// | Combien d'outils sont activés ? | [ZChatToolResolution.activeCount] |
/// | **Lesquels** sont activés ? | [ZChatToolResolution.activeKeys] |
/// | Comment tout remettre à zéro ? | [ZChatToolCatalog.reset] |
///
/// Les deux dernières lignes vont ensemble : un badge de comptage promet une
/// réponse à « qu'est-ce qui est activé ? » qu'un simple entier ne tient pas.
/// L'en-tête « actifs » est donc une **dérivation**, au même titre que le
/// compte — pas une liste que l'hôte tiendrait à côté et qui divergerait.
///
/// ## L'invariant du comptage — NORMATIF
///
/// [ZChatToolResolution.activeCount] et [ZChatToolResolution.activeKeys] sont
/// calculés sur la **feuille**, quelle que soit la surface interrogée : le
/// badge affiche le même nombre partout. Une entrée compte si, et seulement
/// si, elle est **révélée**, **non désactivée**, déclarée comptable
/// ([ZChatToolEntry.countsTowardActive]) et **active**. Un réglage fin dont la
/// bascule parente est éteinte est inerte : il ne compte pas.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_tool_entry.dart';
import 'z_chat_tool_state.dart';

/// Clé de la section qui recueille les entrées sans section déclarée (ou dont
/// la section est inconnue). Elle est rendue **en dernier** et sans libellé.
const String kZChatToolSectionUnassigned = 'unassigned';

/// Nombre de sections à partir duquel une recherche vaut la peine d'être
/// offerte ([ZChatToolCatalog.searchRecommended]).
const int kZChatToolSearchSectionThreshold = 3;

/// Une section titrée du catalogue.
class ZChatToolSection {
  /// Construit une section.
  const ZChatToolSection({required this.key, this.label, this.order = 0});

  /// Identité **stable et opaque** — cible de [ZChatToolEntry.sectionKey].
  final String key;

  /// Libellé **déjà localisé par l'hôte**. `null` ⇒ section sans en-tête
  /// (le socle n'invente aucun titre — FR-26).
  final String? label;

  /// Rang de la section (croissant) ; à égalité, l'ordre de déclaration décide.
  final int order;

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais ; une section
  /// sans clé est écartée.
  static ZChatToolSection? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String? key = zJsonStringOrNull(map['key']);
    if (key == null) return null;
    return ZChatToolSection(
      key: key,
      label: zJsonStringOrNull(map['label']),
      order: zJsonInt(map['order'], 0),
    );
  }

  /// Sérialise en clés `snake_case`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        if (label != null) 'label': label,
        if (order != 0) 'order': order,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatToolSection &&
          key == other.key &&
          label == other.label &&
          order == other.order;

  @override
  int get hashCode => Object.hash(key, label, order);

  @override
  String toString() => 'ZChatToolSection($key)';
}

/// Une entrée telle que la surface doit la rendre : l'entrée, et sa
/// disponibilité **motivée**.
class ZChatToolResolvedEntry {
  /// Construit une entrée résolue.
  const ZChatToolResolvedEntry({
    required this.entry,
    this.disabledReasonToken,
  });

  /// L'entrée déclarée.
  final ZChatToolEntry entry;

  /// Jeton de la raison de désactivation, ou `null` si l'entrée est
  /// disponible. Non-`null` signifie : **rendue, visible, non actionnable, et
  /// expliquée**.
  final String? disabledReasonToken;

  /// `true` si l'entrée est actionnable.
  bool get isEnabled => disabledReasonToken == null;

  @override
  String toString() =>
      'ZChatToolResolvedEntry(${entry.key}, disabled: $disabledReasonToken)';
}

/// Une section telle que la surface doit la rendre, avec ses entrées déjà
/// ordonnées. Une section **sans entrée visible n'est pas rendue** : elle
/// n'apparaît pas dans [ZChatToolResolution.sections].
class ZChatToolResolvedSection {
  /// Construit une section résolue.
  const ZChatToolResolvedSection({required this.section, required this.entries});

  /// La section déclarée (ou la section non assignée).
  final ZChatToolSection section;

  /// Ses entrées visibles, ordonnées.
  final List<ZChatToolResolvedEntry> entries;

  @override
  String toString() =>
      'ZChatToolResolvedSection(${section.key}, ${entries.length})';
}

/// L'état dérivé du catalogue pour une surface et une recherche données.
class ZChatToolResolution {
  /// Construit une résolution (produite par [ZChatToolCatalog.resolve]).
  const ZChatToolResolution({
    required this.sections,
    required this.entries,
    required this.hidden,
    required this.activeKeys,
  });

  /// Les sections à rendre, ordonnées, sans les vides.
  final List<ZChatToolResolvedSection> sections;

  /// Toutes les entrées visibles, à plat, dans l'ordre de rendu.
  final List<ZChatToolResolvedEntry> entries;

  /// Les entrées **non rendues**, et pourquoi. Une entrée déclarée est
  /// toujours soit dans [entries], soit ici — jamais nulle part.
  final Map<String, ZChatToolHiddenReason> hidden;

  /// Les clés des outils activés, dans l'ordre de rendu de la feuille. C'est la
  /// matière de l'en-tête « actifs ».
  final List<String> activeKeys;

  /// Le comptage agrégé qui alimente le badge du déclencheur.
  int get activeCount => activeKeys.length;

  @override
  String toString() =>
      'ZChatToolResolution(${entries.length} visibles, $activeCount actifs)';
}

/// Le catalogue déclaré : des sections, des entrées, et **rien d'autre**.
///
/// Immuable : chaque opération d'écriture rend un **nouveau** catalogue. C'est
/// ce qui rend l'exclusion mutuelle et la remise à zéro vérifiables — un état
/// dérivé ne peut pas se désynchroniser d'un état muté ailleurs.
class ZChatToolCatalog {
  /// Construit un catalogue. Les entrées et les sections sont **dédupliquées
  /// par clé** — la première déclaration gagne, les suivantes sont écartées.
  ZChatToolCatalog({
    Iterable<ZChatToolSection> sections = const <ZChatToolSection>[],
    Iterable<ZChatToolEntry> entries = const <ZChatToolEntry>[],
  })  : sections = List<ZChatToolSection>.unmodifiable(
          _dedupe<ZChatToolSection>(sections, (ZChatToolSection s) => s.key),
        ),
        entries = List<ZChatToolEntry>.unmodifiable(
          _dedupe<ZChatToolEntry>(entries, (ZChatToolEntry e) => e.key),
        );

  /// Les sections déclarées.
  final List<ZChatToolSection> sections;

  /// Les entrées déclarées.
  final List<ZChatToolEntry> entries;

  /// L'entrée de clé [key], ou `null`.
  ZChatToolEntry? entry(String key) {
    for (final ZChatToolEntry e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  /// Activité de [key] : `null` si la clé est **inconnue** (distinct de
  /// « connue et inactive »).
  bool? activityOf(String key) => entry(key)?.isActive;

  /// `true` si le catalogue est assez large pour qu'une recherche soit utile.
  bool get searchRecommended =>
      sections.length >= kZChatToolSearchSectionThreshold;

  /// L'état dérivé pour [surface], éventuellement filtré par [query].
  ///
  /// Ordre de rendu : sections par `order` puis déclaration, entrées par
  /// `order` puis déclaration. Les entrées sans section connue vont dans
  /// [kZChatToolSectionUnassigned], rendue en dernier.
  ZChatToolResolution resolve({
    ZChatToolSurface surface = ZChatToolSurface.sheet,
    String query = '',
  }) {
    final Map<String, ZChatToolHiddenReason> hidden =
        <String, ZChatToolHiddenReason>{};

    // 1. Révélation conditionnelle — indépendante de la surface et de la
    //    recherche, parce qu'elle décide de l'INERTIE d'un réglage, pas de son
    //    emplacement.
    final Map<String, ZChatToolHiddenReason?> reveal =
        <String, ZChatToolHiddenReason?>{};
    for (final ZChatToolEntry e in entries) {
      reveal[e.key] = _revealReason(e);
    }

    // 2. Désactivation motivée — première règle satisfaite.
    final Map<String, String?> disabled = <String, String?>{};
    for (final ZChatToolEntry e in entries) {
      disabled[e.key] = _disabledReason(e);
    }

    // 3. Comptage : toujours sur la FEUILLE, jamais sur la surface interrogée.
    final List<String> activeKeys = <String>[];
    for (final ZChatToolEntry e in _ordered()) {
      if (reveal[e.key] != null) continue;
      if (disabled[e.key] != null) continue;
      if (!e.countsTowardActive) continue;
      if (!e.isActive) continue;
      activeKeys.add(e.key);
    }

    // 4. Visibilité pour la surface demandée.
    final List<ZChatToolResolvedEntry> visible = <ZChatToolResolvedEntry>[];
    for (final ZChatToolEntry e in _ordered()) {
      final ZChatToolHiddenReason? revealReason = reveal[e.key];
      if (revealReason != null) {
        hidden[e.key] = revealReason;
        continue;
      }
      if (!_onSurface(e, surface)) {
        hidden[e.key] = ZChatToolHiddenReason.notOnSurface;
        continue;
      }
      if (!e.matches(query)) {
        hidden[e.key] = ZChatToolHiddenReason.filteredOut;
        continue;
      }
      visible.add(
        ZChatToolResolvedEntry(entry: e, disabledReasonToken: disabled[e.key]),
      );
    }

    return ZChatToolResolution(
      sections: _group(visible),
      entries: List<ZChatToolResolvedEntry>.unmodifiable(visible),
      hidden: Map<String, ZChatToolHiddenReason>.unmodifiable(hidden),
      activeKeys: List<String>.unmodifiable(activeKeys),
    );
  }

  /// Le comptage agrégé du catalogue (identique sur les deux surfaces).
  int get activeCount => resolve().activeCount;

  /// Les entrées activées, dans l'ordre de rendu de la feuille.
  List<ZChatToolEntry> get active => List<ZChatToolEntry>.unmodifiable(<
      ZChatToolEntry>[
    for (final String k in resolve().activeKeys) entry(k)!,
  ]);

  /// Pose un nouvel état sur [key] (invariant AD-5).
  ///
  /// Trois refus, tous explicites :
  /// * clé inconnue ⇒ `ZNotFoundFailure` ;
  /// * nature différente ⇒ `ZDomainFailure` — la nature d'un outil est
  ///   **déclarée**, elle ne se substitue pas à l'exécution ;
  /// * entrée désactivée ⇒ `ZDomainFailure` portant le jeton de la raison —
  ///   une entrée grisée n'est pas réglable par un autre chemin que celui qui
  ///   est grisé.
  ///
  /// Quand [next] est **actif**, les entrées listées dans
  /// [ZChatToolEntry.deactivates] sont ramenées à leur forme inactive : c'est
  /// le **site unique** de l'exclusion mutuelle.
  Either<ZFailure, ZChatToolCatalog> setState(String key, ZChatToolState next) {
    final ZChatToolEntry? target = entry(key);
    if (target == null) {
      return Left<ZFailure, ZChatToolCatalog>(
        ZNotFoundFailure('unknown tool entry', id: key, entity: 'ZChatToolEntry'),
      );
    }
    if (next.kind != target.state.kind) {
      return Left<ZFailure, ZChatToolCatalog>(
        ZDomainFailure(
          'tool "$key" is declared as "${target.state.kind}", '
          'cannot take a "${next.kind}" state',
        ),
      );
    }
    final String? reason = _disabledReason(target);
    if (reason != null) {
      return Left<ZFailure, ZChatToolCatalog>(
        ZDomainFailure('tool "$key" is disabled: $reason'),
      );
    }
    final Set<String> excluded =
        next.isActive ? target.deactivates.toSet() : const <String>{};
    return Right<ZFailure, ZChatToolCatalog>(
      ZChatToolCatalog(
        sections: sections,
        entries: <ZChatToolEntry>[
          for (final ZChatToolEntry e in entries)
            if (e.key == key)
              e.withState(next)
            else if (excluded.contains(e.key))
              e.cleared()
            else
              e,
        ],
      ),
    );
  }

  /// Fait **avancer** [key] d'un cran, sans que l'appelant ait à connaître sa
  /// nature : une bascule bascule, un cycle avance (**et revient à `0`**).
  ///
  /// Les natures qui n'ont pas de « cran suivant » (choix, échelle, catalogue,
  /// action, nature d'hôte) rendent `ZUnsupportedOperationFailure` : elles se
  /// règlent par [setState].
  Either<ZFailure, ZChatToolCatalog> advance(String key) {
    final ZChatToolEntry? target = entry(key);
    if (target == null) {
      return Left<ZFailure, ZChatToolCatalog>(
        ZNotFoundFailure('unknown tool entry', id: key, entity: 'ZChatToolEntry'),
      );
    }
    final ZChatToolState current = target.state;
    if (current is ZChatToggleState) return setState(key, current.toggled());
    if (current is ZChatCycleState) return setState(key, current.next());
    return Left<ZFailure, ZChatToolCatalog>(
      ZUnsupportedOperationFailure(
        'tool "$key" of kind "${current.kind}" has no next step',
        operation: 'advance',
      ),
    );
  }

  /// Remet **toutes** les entrées à leur état par défaut.
  ///
  /// Après cet appel, `resolve().activeKeys` est vide — c'est la promesse que
  /// l'en-tête « actifs » fait à côté de son bouton.
  ZChatToolCatalog reset() => ZChatToolCatalog(
        sections: sections,
        entries: <ZChatToolEntry>[
          for (final ZChatToolEntry e in entries) e.reset(),
        ],
      );

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais ; les
  /// sections et entrées illisibles sont **sautées**, le catalogue survit.
  static ZChatToolCatalog fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return ZChatToolCatalog();
    return ZChatToolCatalog(
      sections: zJsonDecodeList<ZChatToolSection>(
            map['sections'],
            ZChatToolSection.fromJson,
          ) ??
          const <ZChatToolSection>[],
      entries: zJsonDecodeList<ZChatToolEntry>(
            map['entries'],
            (Object? e) =>
                ZChatToolEntry.fromJson(e, extensionParser: extensionParser),
          ) ??
          const <ZChatToolEntry>[],
    );
  }

  /// Sérialise en clés `snake_case` ; les collections vides sont **omises**.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (sections.isNotEmpty)
          'sections': <Map<String, dynamic>>[
            for (final ZChatToolSection s in sections) s.toJson(),
          ],
        if (entries.isNotEmpty)
          'entries': <Map<String, dynamic>>[
            for (final ZChatToolEntry e in entries) e.toJson(),
          ],
      };

  @override
  String toString() =>
      'ZChatToolCatalog(${sections.length} sections, ${entries.length} entries)';

  // ── Dérivations internes ───────────────────────────────────────────────────

  // Une entrée est révélée si toute sa chaîne de parents est révélée ET
  // active. Une chaîne qui boucle, ou qui désigne un parent absent, est
  // traitée comme non établie : on ne révèle jamais « par défaut ».
  ZChatToolHiddenReason? _revealReason(ZChatToolEntry e) {
    final Set<String> seen = <String>{e.key};
    ZChatToolEntry current = e;
    while (current.revealedBy != null) {
      final String parentKey = current.revealedBy!;
      if (!seen.add(parentKey)) return ZChatToolHiddenReason.unknownParent;
      final ZChatToolEntry? parent = entry(parentKey);
      if (parent == null) return ZChatToolHiddenReason.unknownParent;
      if (!parent.isActive) return ZChatToolHiddenReason.parentInactive;
      current = parent;
    }
    return null;
  }

  String? _disabledReason(ZChatToolEntry e) {
    for (final ZChatToolRule rule in e.disabledWhen) {
      if (rule.condition.isSatisfiedBy(activityOf)) return rule.reasonToken;
    }
    return null;
  }

  bool _onSurface(ZChatToolEntry e, ZChatToolSurface surface) {
    if (surface == ZChatToolSurface.sheet) return true;
    switch (e.prominence) {
      case ZChatToolProminence.band:
        return true;
      case ZChatToolProminence.sheet:
        return false;
      case ZChatToolProminence.auto:
        return e.isActive;
    }
  }

  List<ZChatToolEntry> _ordered() {
    final Map<String, int> sectionRank = <String, int>{};
    for (int i = 0; i < sections.length; i++) {
      sectionRank[sections[i].key] = sections[i].order * 1000 + i;
    }
    final List<int> indexes = <int>[for (int i = 0; i < entries.length; i++) i];
    indexes.sort((int a, int b) {
      final ZChatToolEntry ea = entries[a];
      final ZChatToolEntry eb = entries[b];
      // Les entrées sans section connue passent en dernier (rang maximal).
      final int ra = sectionRank[ea.sectionKey] ?? 1 << 30;
      final int rb = sectionRank[eb.sectionKey] ?? 1 << 30;
      if (ra != rb) return ra.compareTo(rb);
      if (ea.order != eb.order) return ea.order.compareTo(eb.order);
      return a.compareTo(b);
    });
    return <ZChatToolEntry>[for (final int i in indexes) entries[i]];
  }

  List<ZChatToolResolvedSection> _group(List<ZChatToolResolvedEntry> visible) {
    final Map<String, List<ZChatToolResolvedEntry>> byKey =
        <String, List<ZChatToolResolvedEntry>>{};
    for (final ZChatToolResolvedEntry r in visible) {
      final String? declared = r.entry.sectionKey;
      final bool known =
          declared != null && sections.any((ZChatToolSection s) => s.key == declared);
      final String key = known ? declared : kZChatToolSectionUnassigned;
      (byKey[key] ??= <ZChatToolResolvedEntry>[]).add(r);
    }
    final List<ZChatToolResolvedSection> out = <ZChatToolResolvedSection>[];
    final List<ZChatToolSection> ordered = <ZChatToolSection>[...sections];
    final List<int> rank = <int>[for (int i = 0; i < ordered.length; i++) i];
    rank.sort((int a, int b) {
      if (ordered[a].order != ordered[b].order) {
        return ordered[a].order.compareTo(ordered[b].order);
      }
      return a.compareTo(b);
    });
    for (final int i in rank) {
      final List<ZChatToolResolvedEntry>? group = byKey[ordered[i].key];
      if (group == null || group.isEmpty) continue;
      out.add(
        ZChatToolResolvedSection(
          section: ordered[i],
          entries: List<ZChatToolResolvedEntry>.unmodifiable(group),
        ),
      );
    }
    final List<ZChatToolResolvedEntry>? rest = byKey[kZChatToolSectionUnassigned];
    if (rest != null && rest.isNotEmpty) {
      out.add(
        ZChatToolResolvedSection(
          section: const ZChatToolSection(key: kZChatToolSectionUnassigned),
          entries: List<ZChatToolResolvedEntry>.unmodifiable(rest),
        ),
      );
    }
    return List<ZChatToolResolvedSection>.unmodifiable(out);
  }
}

List<T> _dedupe<T>(Iterable<T> raw, String Function(T) keyOf) {
  final List<T> out = <T>[];
  final Set<String> seen = <String>{};
  for (final T item in raw) {
    if (seen.add(keyOf(item))) out.add(item);
  }
  return out;
}

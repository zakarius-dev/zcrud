/// L'état réactif de la **feuille d'outils** — `ZChatToolController`.
///
/// Le catalogue d'outils (`ZChatToolCatalog`) est une valeur immuable du
/// domaine : il sait dire ce qui est visible, grisé, actif et dans quel ordre,
/// mais il ne notifie personne. Ce contrôleur lui donne des tranches
/// `ValueListenable` **granulaires** :
///
/// | Tranche | Change quand |
/// |---|---|
/// | [sheetStructure] | l'ordre, les sections ou la liste des clés visibles de la feuille changent |
/// | [bandStructure] | la bande du composer gagne ou perd un outil |
/// | [entryOf] | **cette entrée-là** change d'état ou de motif de grisage |
/// | [activeKeys] / [activeCount] | le comptage agrégé change |
///
/// Une tuile n'écoute que [entryOf] : régler un outil ne reconstruit pas les
/// autres tuiles (invariant AD-2).
///
/// ## Aucune décision reprise au domaine
///
/// La visibilité, le grisage, l'ordre, le comptage et le filtre de recherche
/// sont **calculés par `ZChatToolCatalog.resolve`** ; ce contrôleur ne fait que
/// publier le résultat. Une seconde implémentation divergerait de la première.
///
/// ## Un refus n'est pas une erreur
///
/// Régler un outil grisé rend un `Left` : c'est le cas **nominal** quand
/// l'utilisateur touche une tuile désactivée. [setEntryState] et [advance] le
/// rendent à l'appelant qui veut montrer la raison ; [clearEntry] et [reset]
/// l'absorbent. Aucun de ces gestes ne lève.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Une section de la feuille, réduite à ce qui décide de la **structure** :
/// sa clé, son libellé d'hôte et les clés de ses entrées visibles.
@immutable
class ZChatToolSectionSlice {
  /// Construit la tranche.
  const ZChatToolSectionSlice({
    required this.sectionKey,
    required this.label,
    required this.entryKeys,
  });

  /// Clé de la section.
  final String sectionKey;

  /// Libellé d'hôte. `null` ⇒ **aucun en-tête rendu**.
  final String? label;

  /// Clés des entrées visibles, dans l'ordre de rendu.
  final List<String> entryKeys;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatToolSectionSlice &&
          sectionKey == other.sectionKey &&
          label == other.label &&
          listEquals(entryKeys, other.entryKeys);

  @override
  int get hashCode => Object.hash(sectionKey, label, Object.hashAll(entryKeys));

  @override
  String toString() =>
      'ZChatToolSectionSlice($sectionKey, ${entryKeys.length})';
}

/// La **structure** d'une surface : ses sections ordonnées et leurs clés.
///
/// C'est ce dont un `ListView.builder` a besoin, et rien de plus : l'état de
/// chaque entrée arrive par sa propre tranche ([ZChatToolController.entryOf]),
/// de sorte que régler un outil ne change pas la structure.
@immutable
class ZChatToolSheetStructure {
  /// Construit la structure.
  const ZChatToolSheetStructure(this.sections);

  /// Une structure vide (aucune section rendue).
  static const ZChatToolSheetStructure empty = ZChatToolSheetStructure(
    <ZChatToolSectionSlice>[],
  );

  /// Les sections, déjà ordonnées et purgées des sections vides.
  final List<ZChatToolSectionSlice> sections;

  /// `true` si aucune section n'est rendue.
  bool get isEmpty => sections.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatToolSheetStructure && listEquals(sections, other.sections);

  @override
  int get hashCode => Object.hashAll(sections);

  @override
  String toString() => 'ZChatToolSheetStructure(${sections.length})';
}

/// Porte le catalogue d'outils et publie ses dérivations en tranches
/// granulaires.
class ZChatToolController extends ChangeNotifier {
  /// Construit le contrôleur sur un [catalog] initial.
  ZChatToolController({ZChatToolCatalog? catalog})
      : _catalog = catalog ?? ZChatToolCatalog() {
    _publish();
  }

  ZChatToolCatalog _catalog;

  final ValueNotifier<String> _query = ValueNotifier<String>('');
  final ValueNotifier<ZChatToolSheetStructure> _sheetStructure =
      ValueNotifier<ZChatToolSheetStructure>(ZChatToolSheetStructure.empty);
  final ValueNotifier<ZChatToolSheetStructure> _bandStructure =
      ValueNotifier<ZChatToolSheetStructure>(ZChatToolSheetStructure.empty);
  final ValueNotifier<List<String>> _activeKeys = ValueNotifier<List<String>>(
    const <String>[],
  );
  final ValueNotifier<int> _activeCount = ValueNotifier<int>(0);
  final Map<String, ValueNotifier<ZChatToolResolvedEntry?>> _entries =
      <String, ValueNotifier<ZChatToolResolvedEntry?>>{};

  /// Le catalogue courant — valeur immuable, remplacée à chaque écriture.
  ZChatToolCatalog get catalog => _catalog;

  /// La requête de recherche courante (`''` ⇒ aucun filtre).
  ValueListenable<String> get query => _query;

  /// La structure de la **feuille**, filtrée par [query].
  ValueListenable<ZChatToolSheetStructure> get sheetStructure =>
      _sheetStructure;

  /// La structure de la **bande** du composer — jamais filtrée par la
  /// recherche : la recherche est un geste de la feuille.
  ValueListenable<ZChatToolSheetStructure> get bandStructure => _bandStructure;

  /// Les clés actives, dans l'ordre de rendu de la feuille.
  ValueListenable<List<String>> get activeKeys => _activeKeys;

  /// Le comptage agrégé — **le même nombre** sur la bande et sur la feuille.
  ValueListenable<int> get activeCount => _activeCount;

  /// `true` si le catalogue est assez large pour qu'une recherche soit utile.
  bool get searchRecommended => _catalog.searchRecommended;

  /// La tranche de l'entrée [key].
  ///
  /// Vaut `null` quand l'entrée est **inconnue** ou **non révélée** (sa
  /// bascule parente est éteinte) ; une entrée simplement **grisée** est bien
  /// présente et porte son `disabledReasonToken`.
  ValueListenable<ZChatToolResolvedEntry?> entryOf(String key) =>
      _entries.putIfAbsent(
        key,
        () => ValueNotifier<ZChatToolResolvedEntry?>(_canonical()[key]),
      );

  /// Remplace le catalogue (rechargement, restauration d'une persistance).
  void replaceCatalog(ZChatToolCatalog next) {
    _catalog = next;
    _publish();
    notifyListeners();
  }

  /// Pose la requête de recherche. Elle filtre le **rendu** de la feuille,
  /// jamais le comptage.
  void setQuery(String next) {
    if (_query.value == next) return;
    _query.value = next;
    _publish();
    notifyListeners();
  }

  /// Pose un nouvel état sur [key]. Le `Left` du domaine est **rendu tel
  /// quel** : refus d'une entrée grisée, clé inconnue, nature différente.
  ZResult<Unit> setEntryState(String key, ZChatToolState next) =>
      _write(_catalog.setState(key, next));

  /// Fait avancer [key] d'un cran — c'est `ZChatToolCatalog.advance` qui
  /// décide du cran suivant et du retour à zéro, jamais l'appelant.
  ZResult<Unit> advance(String key) => _write(_catalog.advance(key));

  /// Ramène [key] à sa forme inactive. Un refus est **absorbé**.
  void clearEntry(String key) {
    final ZChatToolEntry? target = _catalog.entry(key);
    if (target == null) return;
    setEntryState(key, target.state.cleared);
  }

  /// Remet **toutes** les entrées à leur état par défaut. Après cet appel,
  /// [activeKeys] est vide.
  void reset() {
    _catalog = _catalog.reset();
    _publish();
    notifyListeners();
  }

  ZResult<Unit> _write(ZResult<ZChatToolCatalog> outcome) => outcome.fold(
        (ZFailure f) => Left<ZFailure, Unit>(f),
        (ZChatToolCatalog next) {
          _catalog = next;
          _publish();
          notifyListeners();
          return const Right<ZFailure, Unit>(unit);
        },
      );

  Map<String, ZChatToolResolvedEntry> _canonical() {
    // La résolution CANONIQUE : surface feuille, sans requête. L'état et le
    // motif de grisage d'une entrée ne dépendent ni de la surface ni de la
    // recherche — seule sa PLACE en dépend.
    final ZChatToolResolution r = _catalog.resolve();
    return <String, ZChatToolResolvedEntry>{
      for (final ZChatToolResolvedEntry e in r.entries) e.entry.key: e,
    };
  }

  void _publish() {
    final ZChatToolResolution canonical = _catalog.resolve();
    final Map<String, ZChatToolResolvedEntry> byKey =
        <String, ZChatToolResolvedEntry>{
      for (final ZChatToolResolvedEntry e in canonical.entries) e.entry.key: e,
    };
    for (final MapEntry<String, ValueNotifier<ZChatToolResolvedEntry?>> slot
        in _entries.entries) {
      final ZChatToolResolvedEntry? next = byKey[slot.key];
      if (_sameResolved(slot.value.value, next)) continue;
      slot.value.value = next;
    }
    if (!listEquals(_activeKeys.value, canonical.activeKeys)) {
      _activeKeys.value = canonical.activeKeys;
    }
    _activeCount.value = canonical.activeCount;
    _sheetStructure.value = _structure(
      _catalog.resolve(query: _query.value),
    );
    _bandStructure.value = _structure(
      _catalog.resolve(surface: ZChatToolSurface.band),
    );
  }

  // Deux résolutions désignent le même état si l'entrée est la MÊME instance
  // et le motif de grisage identique. Le domaine ne recrée que les entrées
  // qu'il change : l'identité est donc la mesure exacte du « rien n'a bougé ».
  bool _sameResolved(ZChatToolResolvedEntry? a, ZChatToolResolvedEntry? b) {
    if (a == null || b == null) return a == null && b == null;
    return identical(a.entry, b.entry) &&
        a.disabledReasonToken == b.disabledReasonToken;
  }

  ZChatToolSheetStructure _structure(ZChatToolResolution r) =>
      ZChatToolSheetStructure(<ZChatToolSectionSlice>[
        for (final ZChatToolResolvedSection s in r.sections)
          ZChatToolSectionSlice(
            sectionKey: s.section.key,
            label: s.section.label,
            entryKeys: <String>[
              for (final ZChatToolResolvedEntry e in s.entries) e.entry.key,
            ],
          ),
      ]);

  @override
  void dispose() {
    _query.dispose();
    _sheetStructure.dispose();
    _bandStructure.dispose();
    _activeKeys.dispose();
    _activeCount.dispose();
    for (final ValueNotifier<ZChatToolResolvedEntry?> n in _entries.values) {
      n.dispose();
    }
    _entries.clear();
    super.dispose();
  }
}

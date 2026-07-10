import 'dart:async';

import 'package:zcrud_core/zcrud_core.dart';

/// Modèle de démonstration LISTE (EX-2, AC3). Entité de démo **scalaire/
/// affichable** (aucun type lourd) portant le vocabulaire de champs de
/// `reference_form.dart` : `name`/text, `category`/select, `quantity`/integer,
/// `unitPrice`/number, `createdAt`/dateTime, `active`/boolean.
///
/// `implements ZEntity` (identité `String?` opaque) — patron des fakes E4
/// (`_Item implements ZEntity`). Immuable (`const`), aucune (dé)sérialisation
/// déclarée sur la base (AD-4).
class DemoRecord implements ZEntity {
  /// Construit un enregistrement de démo.
  const DemoRecord({
    required this.recordId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.createdAt,
    required this.active,
  });

  /// Identité opaque (jamais `null` ici : les enregistrements sont matérialisés).
  final String recordId;

  /// Libellé (champ `searchable`).
  final String name;

  /// Catégorie (valeur de `select`, cf. [demoCategories]).
  final String category;

  /// Quantité (entier).
  final int quantity;

  /// Prix unitaire (nombre).
  final double unitPrice;

  /// Date de création (ISO-8601 au format neutre en cellule).
  final DateTime createdAt;

  /// Actif (booléen).
  final bool active;

  @override
  String? get id => recordId;

  @override
  bool get isEphemeral => id == null;

  /// (Dé)sérialisation map ADDITIVE (EX-3, AC7) — utilisée par la démo OFFLINE
  /// (`HiveZLocalStore` derrière le port `ZLocalStore`). N'altère PAS la démo
  /// LISTE EX-2 (qui n'en dépend pas). Persistance snake/camel neutre ; le store
  /// Hive réécrit le corps `id` lui-même (invariant clé↔corps E5-1).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': recordId,
        'name': name,
        'category': category,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'createdAt': createdAt.toIso8601String(),
        'active': active,
      };

  /// Lecture DÉFENSIVE (AD-10) : un champ absent/corrompu retombe sur un défaut,
  /// jamais de `throw` (le store écarte l'entrée si `fromMap` lançait).
  static DemoRecord fromMap(Map<String, dynamic> map) => DemoRecord(
        recordId: (map['id'] ?? map['recordId'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        category: (map['category'] ?? 'materiel').toString(),
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
                DateTime(2026),
        active: (map['active'] as bool?) ?? true,
      );
}

/// Choix de la catégorie (`select`) — réutilisés par le schéma ET les filtres
/// d'onglet/catégorie (AC4/AC6).
const List<ZFieldChoice> demoCategories = <ZFieldChoice>[
  ZFieldChoice(value: 'materiel', label: 'Matériel'),
  ZFieldChoice(value: 'service', label: 'Service'),
  ZFieldChoice(value: 'logiciel', label: 'Logiciel'),
  ZFieldChoice(value: 'formation', label: 'Formation'),
];

/// Schéma de démo LISTE (AC3) : uniquement des types **affichables** (whitelist
/// `_tabularTypes` du cœur). Les colonnes en sont **dérivées** via `deriveColumns`
/// (aucune colonne codée à la main). `name` est `searchable` → alimente la
/// recherche plein-texte du `ZListController`.
const List<ZFieldSpec> demoSchema = <ZFieldSpec>[
  ZFieldSpec(
    name: 'name',
    type: EditionFieldType.text,
    label: 'Désignation',
    searchable: true,
  ),
  ZFieldSpec(
    name: 'category',
    type: EditionFieldType.select,
    label: 'Catégorie',
    choices: demoCategories,
  ),
  ZFieldSpec(name: 'quantity', type: EditionFieldType.integer, label: 'Quantité'),
  ZFieldSpec(
    name: 'unitPrice',
    type: EditionFieldType.number,
    label: 'Prix unitaire',
  ),
  ZFieldSpec(
    name: 'createdAt',
    type: EditionFieldType.dateTime,
    label: 'Créé le',
  ),
  ZFieldSpec(name: 'active', type: EditionFieldType.boolean, label: 'Actif'),
];

/// Projection `DemoRecord → ZListRow` (neutre, `id` STABLE — jamais un index).
/// Le format des cellules est dérivé par `ZListColumn.format` (cœur) ; ici on
/// ne fournit que les valeurs brutes indexées par `field.name`.
ZListRow toDemoRow(DemoRecord r) => ZListRow(
      id: r.recordId,
      cells: <String, Object?>{
        'name': r.name,
        'category': r.category,
        'quantity': r.quantity,
        'unitPrice': r.unitPrice,
        'createdAt': r.createdAt,
        'active': r.active,
      },
    );

/// Magasin **partagé** in-memory (source de vérité de la démo) : la liste des
/// enregistrements + l'ensemble **hors-entité** `is_deleted` (bascule soft-delete
/// via un `Set<String>`, AD-9 : jamais de suppression dure) + un flux de
/// mutations broadcast. Plusieurs vues [DemoRepository] (liste active / corbeille /
/// onglets) partagent CE magasin → un soft-delete dans une vue se reflète partout.
class DemoStore {
  /// Construit le magasin seedé de [seedCount] enregistrements (≥ 40, AC3).
  DemoStore({int seedCount = 48}) : _records = _seed(seedCount);

  final List<DemoRecord> _records;

  /// Ids soft-deleted (métadonnée `is_deleted` HORS-ENTITÉ, AD-9).
  final Set<String> _deleted = <String>{};

  final StreamController<List<DemoRecord>> _changes =
      StreamController<List<DemoRecord>>.broadcast();

  /// Enregistrements **visibles** selon [includeDeleted] : la liste active
  /// exclut les soft-deleted ; la corbeille ne montre QUE les soft-deleted.
  List<DemoRecord> visible({required bool includeDeleted}) => <DemoRecord>[
        for (final r in _records)
          if (_deleted.contains(r.recordId) == includeDeleted) r,
      ];

  /// `true` si [id] est actuellement soft-deleted.
  bool isDeleted(String id) => _deleted.contains(id);

  /// Bascule `is_deleted` à `true` et notifie les abonnés (AD-9).
  void softDelete(String id) {
    _deleted.add(id);
    _emit();
  }

  /// Rétablit un enregistrement soft-deleted et notifie les abonnés.
  void restore(String id) {
    _deleted.remove(id);
    _emit();
  }

  void _emit() {
    if (_changes.isClosed) return;
    _changes.add(visible(includeDeleted: false));
  }

  /// Flux de mutations (relance de la requête courante via `watchMutations`).
  Stream<List<DemoRecord>> get changes => _changes.stream;

  /// Libère le flux (appelé par le `State` propriétaire).
  void dispose() => unawaited(_changes.close());

  static List<DemoRecord> _seed(int n) {
    const cats = <String>['materiel', 'service', 'logiciel', 'formation'];
    const names = <String>[
      'Ordinateur',
      'Imprimante',
      'Licence',
      'Formation SIG',
      'Serveur',
      'Routeur',
      'Écran',
      'Clavier',
      'Support annuel',
      'Audit sécurité',
    ];
    final base = DateTime(2026, 1, 1);
    return <DemoRecord>[
      for (var i = 0; i < n; i++)
        DemoRecord(
          recordId: 'rec-$i',
          name: '${names[i % names.length]} #${i + 1}',
          category: cats[i % cats.length],
          quantity: 1 + (i * 3) % 25,
          unitPrice: 10 + (i * 7) % 500 + 0.99,
          createdAt: base.add(Duration(days: i * 2)),
          active: i % 4 != 0,
        ),
    ];
  }
}

/// Vue **repository** in-memory sur un [DemoStore] partagé (port neutre
/// `ZRepository<DemoRecord>`). `includeDeleted` distingue la LISTE active
/// (`false`) de la CORBEILLE (`true`). Honore filtres/tri/recherche/curseur via
/// `zApplyListRequest` (patron `_FakeRepo` d'E4) → la pagination curseur backend
/// du `ZListController` fonctionne sans repli.
class DemoRepository implements ZRepository<DemoRecord> {
  /// Construit une vue sur [store]. [includeDeleted] : `true` = corbeille.
  DemoRepository(this.store, {this.includeDeleted = false});

  /// Magasin partagé sous-jacent.
  final DemoStore store;

  /// `true` = vue corbeille (n'expose que les soft-deleted).
  final bool includeDeleted;

  List<DemoRecord> get _data => store.visible(includeDeleted: includeDeleted);

  @override
  Future<ZResult<List<DemoRecord>>> getAll({ZDataRequest? request}) async =>
      Right<ZFailure, List<DemoRecord>>(
        _applyRequest(request ?? const ZDataRequest()),
      );

  // Les flux relaient CHAQUE mutation du magasin (le controller ne s'en sert que
  // comme déclencheur, `watchMutations: true`, puis relit via `getAll`). On
  // recalcule néanmoins la vue courante à chaque émission pour qu'un consommateur
  // lisant DIRECTEMENT le flux reçoive la vue correcte (`includeDeleted` honoré
  // par `_data` ; filtres/tri/curseur honorés par `zApplyListRequest`).
  @override
  Stream<List<DemoRecord>> watchAll() =>
      store.changes.map((_) => _data);

  @override
  Stream<List<DemoRecord>> watch(ZDataRequest request) =>
      store.changes.map((_) => _applyRequest(request));

  /// Applique [request] (filtres/tri/recherche/curseur) à la vue courante
  /// (`_data`, déjà filtrée par `includeDeleted`) via `zApplyListRequest`.
  List<DemoRecord> _applyRequest(ZDataRequest request) {
    final rows = <ZListRow>[for (final r in _data) toDemoRow(r)];
    final page = zApplyListRequest(rows, request, schema: demoSchema);
    final byId = <String, DemoRecord>{for (final r in _data) r.recordId: r};
    return <DemoRecord>[for (final row in page.rows) byId[row.id]!];
  }

  @override
  Future<ZResult<DemoRecord>> getById(String id) async {
    for (final r in _data) {
      if (r.recordId == id) return Right<ZFailure, DemoRecord>(r);
    }
    return Left<ZFailure, DemoRecord>(NotFoundFailure('DemoRecord', id: id));
  }

  @override
  Future<ZResult<DemoRecord>> save(DemoRecord item, {String? collectionId}) async =>
      Right<ZFailure, DemoRecord>(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    store.softDelete(id);
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    store.restore(id);
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right<ZFailure, int>(_data.length);

  @override
  void dispose() {
    // Le magasin partagé est possédé/liberé par le `State` de l'écran, pas par
    // une vue repository (plusieurs vues partagent le même magasin).
  }
}

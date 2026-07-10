import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

import 'list_demo_data.dart';

/// Écran de démo FIRESTORE / OFFLINE (EX-3, AC7, AC11). Démontre un **CRUD
/// offline** (créer / lister / modifier / soft-delete+restore / clear) sur
/// [DemoRecord], adossé au port **`ZLocalStore<DemoRecord>`** dont l'implémentation
/// runtime est **`HiveZLocalStore`** (source de vérité offline-first, AD-9).
///
/// Décision structurante (§4) : l'écran est construit **contre le port**
/// `ZLocalStore` (injectable) — runtime = `HiveZLocalStore` (via
/// `HiveZLocalStore.openBox`, après `Hive.initFlutter()` dans `main.dart`) ;
/// test = injection d'un store hermétique (Hive temp-dir OU fake in-memory).
/// Les signatures consommées restent **NEUTRES** (`ZResult<…>`,
/// `Stream<List<T>>` nus) — aucun type Hive/Firestore ne fuit.
///
/// BRANCHER LE DISTANT FIRESTORE RÉEL (documentation, NON initialisé ici) — la
/// voie distante offline-first se branche SANS toucher cet écran :
///
/// ```dart
/// // 1. Init plateforme (aucune config/clé Firebase committée — AD-12/gate:secrets)
/// await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
/// // 2. Store distant (fire-and-forget), signatures neutres
/// final remote = FirestoreZRemoteStore<DemoRecord>(
///   firestore: FirebaseFirestore.instance,
///   kind: 'demoRecord',
///   fromMap: DemoRecord.fromMap,
///   toMap: (r) => r.toMap(),
/// );
/// // 3. Repo offline-first : le LOCAL reste la source de vérité (merge LWW =
/// //    E5-3/E5-4, v1.x). Le store Hive de cet écran est passé en `local:`.
/// final repo = FirebaseZRepositoryImpl<DemoRecord>(local: localStore, remote: remote);
/// ```
///
/// La démo n'exerce QUE le local (portable + testable hermétiquement) ;
/// `FirestoreZRemoteStore` / `FirebaseZRepositoryImpl` ne sont PAS instanciés.
class OfflineDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo offline.
  ///
  /// [storeFactory] permet aux tests d'injecter un `ZLocalStore` hermétique
  /// (Hive temp-dir ou fake in-memory). En production (`null`), le store Hive
  /// réel est ouvert via `HiveZLocalStore.openBox` (nécessite
  /// `Hive.initFlutter()` préalable — cf. `main.dart`).
  const OfflineDemoScreen({this.storeFactory, super.key});

  /// Fabrique de store injectable (test) ; `null` → `HiveZLocalStore` réel.
  final Future<ZLocalStore<DemoRecord>> Function()? storeFactory;

  @override
  State<OfflineDemoScreen> createState() => _OfflineDemoScreenState();
}

class _OfflineDemoScreenState extends State<OfflineDemoScreen> {
  ZLocalStore<DemoRecord>? _store;

  /// Flux `watchAll()` créé UNE fois à l'ouverture du store — JAMAIS re-appelé
  /// dans un `build` (sinon chaque rebuild ré-abonnerait + re-seederait → boucle
  /// de reconstruction).
  Stream<List<DemoRecord>>? _stream;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _openStore();
  }

  Future<void> _openStore() async {
    final factory = widget.storeFactory ?? _openHiveStore;
    final store = await factory();
    if (!mounted) {
      // L'écran a été démonté avant l'ouverture : ne rien retenir.
      return;
    }
    setState(() {
      _store = store;
      _stream = store.watchAll();
    });
  }

  /// Ouverture PRODUCTION du store Hive (offline réel). `Hive.initFlutter()` doit
  /// avoir été appelé au démarrage (`main.dart`).
  static Future<ZLocalStore<DemoRecord>> _openHiveStore() =>
      HiveZLocalStore.openBox<DemoRecord>(
        kind: 'demoRecord',
        fromMap: DemoRecord.fromMap,
        toMap: (r) => r.toMap(),
      );

  Future<void> _create() async {
    final store = _store;
    if (store == null) return;
    _seq += 1;
    final now = DateTime.now();
    final record = DemoRecord(
      recordId: 'offline-${now.microsecondsSinceEpoch}',
      name: 'Enregistrement #$_seq',
      category: 'materiel',
      quantity: _seq,
      unitPrice: 9.99,
      createdAt: now,
      active: true,
    );
    await store.put(record);
  }

  Future<void> _rename(DemoRecord r) async {
    final store = _store;
    if (store == null) return;
    final renamed = DemoRecord(
      recordId: r.recordId,
      name: '${r.name} (modifié)',
      category: r.category,
      quantity: r.quantity,
      unitPrice: r.unitPrice,
      createdAt: r.createdAt,
      active: r.active,
    );
    await store.put(renamed);
  }

  /// Soft-delete (AD-9, drapeau `is_deleted` hors-entité) PUIS expose la voie de
  /// **restauration** à l'utilisateur : un SnackBar « Annuler » rappelle
  /// `store.restore(id)` (le port `ZLocalStore` n'exposant PAS les soft-deleted
  /// via `watchAll`/`getAll`, l'undo immédiat est la voie de restauration UI —
  /// l'enregistrement réapparaît dans le flux nu). Le CRUD offline complet
  /// (create / softDelete / **restore**) est ainsi exerçable À LA MAIN.
  Future<void> _softDelete(DemoRecord r) async {
    final store = _store;
    if (store == null) return;
    // Capté AVANT l'await (pas de BuildContext au travers d'un gap async).
    final messenger = ScaffoldMessenger.of(context);
    await store.softDelete(r.recordId);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('« ${r.name} » supprimé.', textAlign: TextAlign.start),
          action: SnackBarAction(
            key: const ValueKey<String>('offlineUndo'),
            label: 'Annuler',
            onPressed: () => unawaited(store.restore(r.recordId)),
          ),
        ),
      );
  }

  Future<void> _clear() async => _store?.clear();

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Démo Offline (E5)'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Vider le magasin',
            icon: const Icon(Icons.delete_forever),
            onPressed: store == null ? null : _clear,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey<String>('offlineCreate'),
        tooltip: 'Créer un enregistrement',
        onPressed: store == null ? null : _create,
        child: const Icon(Icons.add),
      ),
      body: store == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Text(
                    'CRUD offline via HiveZLocalStore (port ZLocalStore, '
                    'source de vérité AD-9). Firestore distant : documenté, '
                    'non initialisé (aucun secret).',
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: _OfflineList(
                    stream: _stream!,
                    onRename: _rename,
                    onDelete: _softDelete,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Liste réactive des enregistrements offline — observe le **flux nu**
/// `watchAll()` du port (aucun type Hive exposé). Chaque ligne offre modifier +
/// soft-delete.
class _OfflineList extends StatelessWidget {
  const _OfflineList({
    required this.stream,
    required this.onRename,
    required this.onDelete,
  });

  final Stream<List<DemoRecord>> stream;
  final ValueChanged<DemoRecord> onRename;
  final ValueChanged<DemoRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DemoRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <DemoRecord>[];
        if (records.isEmpty) {
          return const Center(
            key: ValueKey<String>('offlineEmpty'),
            child: Text('Aucun enregistrement (appuyez sur +).'),
          );
        }
        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final r = records[index];
            return ListTile(
              title: Text(r.name, textAlign: TextAlign.start),
              subtitle: Text('id: ${r.recordId}', textAlign: TextAlign.start),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(Icons.edit),
                    onPressed: () => onRename(r),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(r),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

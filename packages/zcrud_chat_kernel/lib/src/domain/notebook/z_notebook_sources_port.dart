/// Sources d'un notebook : liste, rattachement, retrait, état d'ingestion.
///
/// Le socle ne choisit pas le stockage ni le pipeline d'ingestion. Il
/// expose le contrat et un panneau qui l'affiche. Chaque méthode rend un
/// [ZResult] : un port qui échoue ne fait pas tomber le panneau.
library;

import 'package:zcrud_core/domain.dart';

/// Où en est l'ingestion d'une source.
///
/// Une absence (chaîne vide) reste [ready] : une source listée sans état
/// n'est pas un échec. Une chaîne présente mais non reconnue vaut [unknown].
enum ZNotebookIngestionState {
  /// En attente.
  pending,

  /// Ingestion en cours.
  running,

  /// Prête à être citée.
  ready,

  /// Ingestion échouée. La source reste dans la liste : le retrait est un
  /// geste séparé.
  failed,

  /// Valeur présente mais non reconnue. Une absence (chaîne vide) reste
  /// [ready] : une source listée sans état n'est pas un échec.
  unknown;

  /// Lecture défensive. Une chaîne vide ou `ready` vaut [ready]. Toute
  /// autre valeur non reconnue vaut [unknown].
  static ZNotebookIngestionState fromJson(Object? raw) {
    switch (zJsonString(raw)) {
      case 'pending':
        return ZNotebookIngestionState.pending;
      case 'running':
        return ZNotebookIngestionState.running;
      case 'failed':
        return ZNotebookIngestionState.failed;
      case '':
      case 'ready':
        return ZNotebookIngestionState.ready;
      default:
        return ZNotebookIngestionState.unknown;
    }
  }

  /// Valeur camelCase persistée.
  String get jsonValue => name;
}

/// Une source rattachée à un notebook.
class ZNotebookSource {
  /// Construit une source.
  const ZNotebookSource({
    required this.id,
    required this.title,
    this.state = ZNotebookIngestionState.ready,
    this.errorKey,
    this.pageCount,
  });

  /// Identité opaque.
  final String id;

  /// Titre affiché. Vide, le panneau montre l'identité.
  final String title;

  /// État d'ingestion.
  final ZNotebookIngestionState state;

  /// Clé de la cause d'échec, déjà choisie par l'hôte. `null` : aucune.
  ///
  /// Le panneau la résout comme un libellé s'il la connaît, sinon il
  /// l'affiche telle quelle. Elle n'est pas une phrase du socle.
  final String? errorKey;

  /// Nombre de pages extraites, ou `null` si l'hôte ne le connaît pas.
  final int? pageCount;

  /// Lecture défensive. Une donnée qui n'est pas une map devient une source
  /// vide, jamais une exception (invariant AD-10).
  factory ZNotebookSource.fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) {
      return const ZNotebookSource(id: '', title: '');
    }
    return ZNotebookSource(
      id: zJsonString(map['id']),
      title: zJsonString(map['title']),
      state: ZNotebookIngestionState.fromJson(map['state']),
      errorKey: zJsonStringOrNull(map['error_key']),
      pageCount: zJsonIntOrNull(map['page_count']),
    );
  }

  /// Forme neutre. Les champs absents ne sont pas émis.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'state': state.jsonValue,
    if (errorKey != null) 'error_key': errorKey,
    if (pageCount != null) 'page_count': pageCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNotebookSource &&
          id == other.id &&
          title == other.title &&
          state == other.state &&
          errorKey == other.errorKey &&
          pageCount == other.pageCount;

  @override
  int get hashCode => Object.hash(id, title, state, errorKey, pageCount);
}

/// Port des sources d'un notebook.
///
/// [attach] reçoit un titre déjà choisi par l'hôte : le sélecteur de
/// document appartient à l'application, pas à ce port.
abstract interface class ZNotebookSourcesPort {
  /// Sources courantes, dans l'ordre d'affichage.
  Future<ZResult<List<ZNotebookSource>>> list();

  /// Rattache une source.
  ///
  /// [title] est le libellé choisi par l'hôte. [fileId] identifie un
  /// fichier déjà téléversé ; `null` lorsque le rattachement ne porte
  /// qu'un titre. Le sélecteur de document reste dans l'application.
  Future<ZResult<ZNotebookSource>> attach({
    required String title,
    String? fileId,
  });

  /// Retire la source [id]. Retirer une source absente est un succès.
  Future<ZResult<Unit>> remove(String id);
}

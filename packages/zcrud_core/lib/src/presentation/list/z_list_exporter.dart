/// Port d'**export d'une liste** : le contrat neutre qui transforme ce que
/// l'écran affiche en octets de fichier.
///
/// ## Pourquoi un port
///
/// Produire un `.xlsx` ou un `.pdf` demande une bibliothèque lourde. La faire
/// entrer dans le cœur — ou dans l'écran assemblé — la ferait payer à **tous**
/// les hôtes, y compris à ceux qui n'exportent rien. Le cœur ne déclare donc
/// que le contrat ; les implémentations vivent dans les paquets d'export
/// (`zcrud_export`, `zcrud_export_pdf`), et un hôte qui n'en déclare aucune ne
/// tire aucune de ces dépendances.
///
/// Le contrat est volontairement **minimal et sans état** : un identifiant, de
/// quoi nommer le fichier, et une production d'octets à partir de la requête de
/// rendu déjà construite par la liste (colonnes dérivées + lignes). L'exporteur
/// ne connaît ni entité, ni dépôt, ni widget : il reçoit exactement ce que
/// l'écran montre.
///
/// ```dart
/// class MonExporteurCsv implements ZListExporter {
///   const MonExporteurCsv();
///
///   @override
///   String get id => 'csv';
///   @override
///   String get labelKey => 'CSV';
///   @override
///   String get fileExtension => 'csv';
///   @override
///   String get mimeType => 'text/csv';
///
///   @override
///   Future<ZResult<Uint8List>> export(
///     ZListRenderRequest request, {
///     String? title,
///     String Function(String headerKey)? resolveHeader,
///   }) async => Right(monEncodage(request));
/// }
/// ```
///
/// ## Ce que l'exporteur reçoit, et ce qu'il ne reçoit pas
///
/// La [ZListRenderRequest] porte les colonnes **dérivées du schéma** : les
/// champs d'identité et les types non tabulaires en sont déjà absents, et la
/// colonne de **numéro d'ordre** n'y figure pas non plus (elle vit à part, dans
/// `ZListRenderRequest.ordinal`, parce qu'elle décrit une position d'écran et
/// non une donnée). Les cases à cocher de sélection et la colonne d'actions
/// sont des ornements de rendu, jamais des colonnes : un exporteur qui itère
/// `request.columns` n'a donc rien à exclure lui-même.
///
/// La valeur d'une cellule se lit par `col.formatRow(row.cells[col.name],
/// row.cells)` — le formateur du cœur, celui-là même qui peint l'écran, devise
/// portée par la ligne comprise. Un exporteur qui appellerait `col.format` seul
/// perdrait silencieusement ces formats.
///
/// ## Défensif (invariant AD-10)
///
/// Un export est un geste accessoire : il ne doit **jamais** emporter l'écran.
/// Le contrat rend donc un `ZResult` plutôt que de lever — et pour les
/// implémentations qui laisseraient malgré tout échapper une exception (une
/// bibliothèque tierce, un octet illisible), [ZListExporterSafely.exportSafely]
/// convertit tout jet en échec ordinaire.
library;

import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../domain/failures/z_failure.dart';
import 'z_list_render_request.dart';

/// Contrat d'un **format d'export** de liste.
///
/// Implémenté par les paquets d'export ; déclaré au besoin par l'application.
/// Sans état et `const`-constructible par convention : la même instance sert
/// tous les exports d'un écran.
abstract interface class ZListExporter {
  /// Identifiant technique **stable** du format (`'csv'`, `'xlsx'`, `'pdf'`).
  ///
  /// Sert de clé : deux exporteurs de même [id] déclarés sur un même écran
  /// désignent le même format, et le second n'apporte rien.
  String get id;

  /// Clé de libellé du format, résolue par l'appelant (`label(context, …)`).
  ///
  /// Un sigle de format ne se traduit pas : passer `'CSV'` ou `'PDF'`
  /// directement est légitime — une clé inconnue des tables de libellés est
  /// rendue telle quelle.
  String get labelKey;

  /// Extension de fichier **sans point** (`'csv'`, `'xlsx'`, `'pdf'`).
  String get fileExtension;

  /// Type MIME du fichier produit (`'text/csv'`, `'application/pdf'`…).
  String get mimeType;

  /// Produit les octets du fichier pour la [request] — colonnes dérivées et
  /// lignes **telles qu'elles sont affichées**.
  ///
  /// [title] est le titre de l'écran, quand le format sait en faire quelque
  /// chose (un en-tête de document PDF, le nom d'une feuille de calcul) ; les
  /// formats qui n'en ont pas l'usage l'ignorent.
  ///
  /// [resolveHeader] résout la **clé l10n** d'un en-tête de colonne sans
  /// `BuildContext` (l'export est *headless*) ; omis, l'en-tête est écrit tel
  /// quel.
  ///
  /// Ne doit pas lever : un échec s'exprime par `Left(ZFailure)`.
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  });
}

/// Appel **blindé** d'un exporteur (invariant AD-10).
extension ZListExporterSafely on ZListExporter {
  /// Appelle [ZListExporter.export] en convertissant tout jet — exception ou
  /// erreur — en `Left(ZDomainFailure)`.
  ///
  /// C'est la voie que l'assemblage emprunte : un exporteur tiers défaillant
  /// produit alors une notification d'échec, jamais un écran cassé. Le message
  /// de l'échec porte le jet d'origine, pour rester diagnosticable.
  Future<ZResult<Uint8List>> exportSafely(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async {
    try {
      return await export(
        request,
        title: title,
        resolveHeader: resolveHeader,
      );
    } catch (error) {
      return Left<ZFailure, Uint8List>(ZDomainFailure('$error'));
    }
  }
}

/// Un fichier produit par un export : ses **octets**, un nom suggéré et son
/// type MIME.
///
/// Type de transport pur et immuable, remis à l'application pour qu'elle en
/// fasse ce que sa plateforme permet — enregistrer, partager, imprimer,
/// téléverser. Le cœur ne sait rien écrire sur un disque : c'est délibéré, la
/// destination d'un fichier n'est pas une décision d'écran.
class ZExportedBytes {
  /// Construit le fichier exporté.
  const ZExportedBytes({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// Octets du fichier.
  final Uint8List bytes;

  /// Nom de fichier suggéré, extension comprise (`'consignataires.csv'`).
  final String fileName;

  /// Type MIME du fichier (`'text/csv'`).
  final String mimeType;

  @override
  String toString() =>
      'ZExportedBytes(fileName: $fileName, mimeType: $mimeType, '
      'bytes: ${bytes.length})';
}

/// Compose un **nom de fichier** sûr à partir d'un [title] libre et d'une
/// [extension] sans point.
///
/// Le titre d'un écran est une phrase destinée à l'œil : accents, espaces,
/// ponctuation, parfois une barre oblique. Un nom de fichier ne l'est pas. Cette
/// fonction retient les lettres, les chiffres, le tiret et le tiret bas,
/// remplace tout le reste par un tiret bas et réduit les répétitions — de sorte
/// que deux titres différents ne se retrouvent pas sous le même nom pour cause
/// de ponctuation.
///
/// Un titre vide (ou entièrement fait de caractères écartés) donne `'export'` :
/// mieux vaut un nom générique qu'un fichier nommé `.csv`.
String zExportFileName(String title, String extension) {
  final buffer = StringBuffer();
  var pendingSeparator = false;
  for (final rune in title.runes) {
    final char = String.fromCharCode(rune);
    final isKept = RegExp(r'[A-Za-z0-9\-_]').hasMatch(char);
    if (isKept) {
      if (pendingSeparator && buffer.isNotEmpty) buffer.write('_');
      pendingSeparator = false;
      buffer.write(char);
    } else {
      pendingSeparator = true;
    }
  }
  final stem = buffer.isEmpty ? 'export' : buffer.toString();
  return '$stem.$extension';
}

/// Coutures d'export — mise en page PDF et destination système.
///
/// ## Pourquoi un moteur PDF et un service de partage ne sont pas des dépendances
///
/// Un export agrégé d'une conversation entière, mis en PDF puis remis au
/// partage ou à l'impression du système, suppose deux maillons : une mise en
/// page PDF (qui tire typiquement un moteur de rendu de document) et un
/// service de partage/impression (qui tire un plugin d'impression système).
///
/// Dépendre de ces paquets en dur ferait entrer ces dépendances lourdes dans
/// `zcrud_chat`, en violation de l'invariant AD-1 : un hôte qui n'exporte
/// jamais rien tirerait quand même un moteur PDF complet. La forme employée
/// est donc celle que ce paquet a déjà retenue pour le rendu : une couture,
/// avec un défaut fonctionnel à zéro dépendance. Aucun service de partage
/// n'est réimplémenté ici — l'implémentation d'hôte de [ZChatExportSink]
/// délègue à celui déjà disponible dans l'écosystème zcrud (`zcrud_export_ui`).
///
/// Les quatre formats textuels (Markdown, texte brut, HTML, références) sont
/// produits sans couture ni dépendance. Seuls le PDF et la destination
/// système exigent un branchement — et leur absence se signale par un `Left`
/// explicite, jamais par une exception.
library;

import 'dart:typed_data';

import 'package:zcrud_core/domain.dart';

import 'z_chat_export_result.dart';

/// Couture de **mise en page PDF** : le socle fournit le texte, l'hôte fournit
/// les octets.
///
/// L'hôte l'implémente avec `zcrud_export` (Syncfusion), le moteur PDF de son
/// choix, ou pas du tout. La signature est **neutre** : ni `PdfDocument`, ni
/// `pw.Document`, ni aucun type tiers ne la traverse — c'est ce qui rend le
/// confinement vérifiable par grep.
abstract class ZChatPdfComposer {
  /// Constructeur `const`, pour des implémentations immuables.
  const ZChatPdfComposer();

  /// Met [document] en page et renvoie les octets du PDF.
  ///
  /// [document] est le rendu **textuel** (Markdown) de la conversation agrégée,
  /// avec son titre : le socle a déjà fait tout le travail neutre.
  Future<ZResult<Uint8List>> compose(ZChatTextExport document);
}

/// Couture de destination : partage et impression système.
///
/// L'implémentation attendue délègue à un service de partage PDF déjà
/// disponible dans l'écosystème zcrud (`zcrud_export_ui`), elle ne
/// réimplémente rien :
///
/// ```dart
/// class MyChatExportSink implements ZChatExportSink {
///   const MyChatExportSink(this._pdf);
///   final ZPdfShareService _pdf; // zcrud_export_ui
///
///   @override
///   Future<ZResult<bool>> share(ZChatExportResult result) async =>
///       switch (result) {
///         ZChatBinaryExport(:final bytes, :final suggestedFileName) =>
///           Right<ZFailure, bool>(
///             await _pdf.share(bytes, fileName: suggestedFileName),
///           ),
///         ZChatTextExport() => /* la feuille de partage texte de l'app */,
///       };
/// }
/// ```
abstract class ZChatExportSink {
  /// Constructeur `const`, pour des implémentations immuables.
  const ZChatExportSink();

  /// Remet [result] à la feuille de **partage** du système.
  ///
  /// `Right(true)` si l'utilisateur a effectivement partagé, `Right(false)`
  /// s'il a renoncé — la sémantique exacte de `ZPdfShareService.share`.
  Future<ZResult<bool>> share(ZChatExportResult result);

  /// Remet [result] au flux d'**impression** du système.
  ///
  /// Sémantique de `ZPdfShareService.printDocument`. Une implémentation qui ne
  /// sait pas imprimer renvoie `Left`, jamais une exception.
  Future<ZResult<bool>> printDocument(ZChatExportResult result);
}

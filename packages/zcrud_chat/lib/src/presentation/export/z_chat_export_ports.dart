/// Coutures d'export — mise en page PDF et destination système (CHAT-5, AD-57).
///
/// ## 🔴 Pourquoi `zcrud_export` / `zcrud_export_ui` ne sont PAS des dépendances
///
/// La cible fonctionnelle d'IFFD est un export **agrégé** de la conversation
/// (Notes + Flashcards de TOUS les messages) mis en PDF puis remis au partage
/// ou à l'impression du système
/// (`chatbot_conversation_screen.dart:4441`, `exportExplanationToPdf` /
/// `exportFlashcardToPdf`). Les deux maillons existent déjà dans ce dépôt :
///
/// | Maillon | Où il vit DÉJÀ | Ce qu'il tire |
/// |---|---|---|
/// | mise en page PDF | `zcrud_export` | **Syncfusion** (`syncfusion_flutter_pdf`) |
/// | partage / impression | `zcrud_export_ui` — **`ZPdfShareService`** | `printing` (+ sa transitive `pdf`) |
///
/// 🔴 **Aucun second service de partage n'est écrit ici.** `ZPdfShareService`
/// (`zcrud_export_ui/lib/src/data/z_pdf_share_service.dart`) fait déjà
/// exactement cela — `Printing.sharePdf` et `Printing.layoutPdf`, API 100 %
/// `Uint8List`. En écrire un deuxième serait la duplication que ce lot doit
/// précisément éviter ; il est **CÂBLÉ** par [ZChatExportSink], dont
/// l'implémentation d'hôte tient en deux lignes de délégation.
///
/// Dépendre de ces packages **en dur** ferait entrer Syncfusion **et**
/// `printing` dans `zcrud_chat` — AD-1/AD-57 rouges, et le grep négatif
/// `G-R8` (`z_chat_render_guard_test.dart`) rougirait en nommant ce fichier.
/// Un hôte qui n'exporte jamais rien tirerait un moteur PDF complet. La forme
/// employée est donc celle que ce package a **déjà** retenue deux fois — pour
/// Quill (`ZChatRenderer`) et, avant lui, pour Syncfusion (`ZListRenderer`) :
/// une couture, avec un défaut fonctionnel à zéro dépendance.
///
/// **Défaut sans couture** : les quatre formats **textuels** (Markdown, texte
/// brut, HTML, références) sont produits ici, intégralement, sans aucune
/// dépendance. Seuls le PDF et la destination système exigent un branchement —
/// et leur absence se signale par un `Left` explicite, jamais par une exception.
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

/// Couture de **destination** : partage et impression système.
///
/// 🔴 L'implémentation attendue **délègue à `ZPdfShareService`**
/// (`zcrud_export_ui`), elle ne réimplémente rien :
///
/// ```dart
/// class MyChatExportSink implements ZChatExportSink {
///   const MyChatExportSink(this._pdf);
///   final ZPdfShareService _pdf; // zcrud_export_ui — DÉJÀ dans le dépôt
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

/// Barrel d'API publique de `zcrud_chat`.
///
/// CHAT-2 — le **contrôleur de conversation** Flutter-native :
/// - `ZChatController` : tranches `ValueListenable` **granulaires** (composer,
///   messages, texte en cours **par requête**, progression **par requête**,
///   échec typé, annonce a11y), **un** jeton `ZChatRequestToken` **par
///   requête**, reprise d'un flux interrompu **sous la même identité** (aucun
///   rejeu du tour), et **un seul point d'entrée** pour tous les verbes
///   (`runAction`) — l'invariant « un verbe = un seul site d'appel ».
/// - `ZChatPhase` / `ZChatStreamProgress` : progression **grossière** d'une
///   requête, volontairement séparée du texte à haute fréquence (SM-1).
/// - `ZChatConfirm` / `ZChatRequestIdFactory` / `ZChatRequestBuilder` : les
///   seams d'hôte (dialogue de confirmation, fabrique d'identité, construction
///   de la requête). Aucun libellé, aucune couleur, aucun prompt ici
///   (AD-11/AD-12/FR-26).
///
/// CHAT-3 — le **rendu neutre de conversation** :
/// - `ZChatRenderer` : le **port de rendu**, sur le patron strict de
///   `ZListRenderer`/`ZReorderRenderer` (AD-8/AD-57). `null` = « garde le rendu
///   neutre » — la sémantique de `zResolveGradient`.
/// - `ZChatRendererScope` / `zResolveChatBlock` : l'injection et la **chaîne
///   totale** `seam hôte → null`, qui ne lève jamais (AD-10).
/// - `ZChatConversationView` / `ZChatMessageTile` / `ZChatBlockView` : le rendu
///   **par défaut, à ZÉRO dépendance tierce** — `ListView.builder`, région live
///   a11y, dépli **inline** réel, libellés résolus par `ZcrudLabels`, tokens de
///   `ZcrudTheme`. Le rendu riche (Markdown/LaTeX de `zcrud_markdown`, vue
///   Syncfusion du lot C6) s'y branche **par la couture**, sans que ce package
///   ne dépende ni de Quill ni de Syncfusion.
///
/// Dépend de `zcrud_chat_kernel` (domaine du chat) et `zcrud_core`
/// (`ZResult`/`ZFailure`, `ZcrudTheme`, `label`) — arêtes SORTANTES seules,
/// graphe ACYCLIQUE, CORE OUT = 0. ⛔ AUCUN gestionnaire d'état (AD-2/AD-15),
/// ⛔ AUCUNE dépendance tierce (AD-57).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
/// CHAT-5 — **pièces jointes** et **export agrégé** :
/// - `ZChatAttachmentController` : le contrôleur de lex
///   (`chat_attachment_controller.dart`) PORTÉ — mêmes bornes, même ordre de
///   validation — en `ChangeNotifier` + tranches `ValueListenable`, avec
///   `ZResult` partout (AD-5) et `ZChatAttachment` du **kernel** câblé en
///   sortie de téléversement (aucun modèle concurrent).
/// - `ZChatAttachmentPicker` / `ZChatAttachmentUploader` : les coutures qui
///   tiennent `image_picker`/`file_picker` et le transport HORS du socle
///   (AD-57). Sans elles, le chat reste fonctionnel — on ne peut simplement pas
///   joindre de fichier.
/// - `ZChatExportService` : le service de lex
///   (`chat_export_service_impl.dart`, déjà conforme `Either`/AD-5) PORTÉ, avec
///   l'**agrégat de toute la conversation** qu'IFFD vise
///   (`chatbot_conversation_screen.dart:4441`). Les quatre formats TEXTUELS
///   sont produits ici, sans aucune dépendance.
/// - `ZChatPdfComposer` / `ZChatExportSink` : les coutures du PDF et de la
///   destination système. 🔴 **`ZPdfShareService` (`zcrud_export_ui`) n'est pas
///   dupliqué** — il est CÂBLÉ par l'implémentation d'hôte de `ZChatExportSink` ;
///   en dépendre en dur ferait entrer `printing` **et** Syncfusion dans ce
///   package (AD-1/AD-57).
/// - `ZChatAttachmentStrip` : le rendu neutre des pièces en attente — cible
///   ≥ 48 dp, variantes directionnelles, `Semantics` (AD-13).
library;

/// CR-IFFD-39 — la surface de **LISTE de conversations** :
/// - `ZChatConversationTile` : la tuile neutre (titre à `maxLines` paramétrable,
///   horodatage relatif **localisable** dont le champ source **et** le formateur
///   sont injectables, pastille teintable, badges par **prédicat**, slot
///   `trailing`, `Semantics` de ligne complet, cible ≥ 48 dp bornée par le
///   CONTENEUR).
/// - `ZChatConversationList` : `ListView.builder`, **trois** états distincts
///   (erreur testée **avant** chargement), squelette annoncé, état vide à deux
///   variantes, tri **exposé**, pagination par curseur, sélection multiple,
///   groupes à clé **opaque** repliés par un contrôleur **externe**.
/// - `ZChatConversationSelection` / `ZChatGroupExpansion` : les deux contrôleurs
///   d'hôte — jamais créés dans un `build` (le défaut mesuré chez IFFD).
/// - `zChatConversationActions` : les descripteurs d'action, **absents quand
///   leur callback est nul** — ce qui rend les huit ports de conversation du
///   kernel câblables sans qu'aucun verbe ne soit codé en dur.
/// - `ZChatHighlightedText` / `zChatHighlightRanges` : **l'unique** surlignage.
export 'src/presentation/attachment/z_chat_attachment_controller.dart';
export 'src/presentation/attachment/z_chat_attachment_failure.dart';
export 'src/presentation/attachment/z_chat_attachment_ports.dart';
export 'src/presentation/attachment/z_pending_attachment.dart';
// CHAT-10 — saisie ASSISTÉE : la dictée et l'OCR entrent par des PORTS du
// kernel, et la relecture est STRUCTURELLE — `ZChatCaptureController.acceptInto`
// rend `ZResult<Unit>`, aucune `String` ne s'en échappe vers l'envoi.
export 'src/presentation/capture/z_chat_capture_controller.dart';
export 'src/presentation/conversation/z_chat_conversation_selection.dart';
export 'src/presentation/conversation/z_chat_group_expansion.dart';
// CHAT-9 — diffusion : la voix par la chaîne de repli du kernel, l'export et le
// partage DÉLÉGUÉS à `ZChatExportService` (CHAT-5), jamais redéfinis ici.
export 'src/presentation/diffusion/z_chat_diffusion_service.dart';
export 'src/presentation/export/z_chat_export_format.dart';
export 'src/presentation/export/z_chat_export_ports.dart';
export 'src/presentation/export/z_chat_export_result.dart';
export 'src/presentation/export/z_chat_export_service.dart';
export 'src/presentation/render/z_chat_accessible_text_scope.dart';
export 'src/presentation/render/z_chat_render_request.dart';
export 'src/presentation/render/z_chat_renderer.dart';
export 'src/presentation/render/z_chat_renderer_scope.dart';
export 'src/presentation/render/z_chat_seam_failure.dart';
export 'src/presentation/render/z_chat_shell_render_request.dart';
export 'src/presentation/render/z_chat_shell_renderer.dart';
export 'src/presentation/render/z_chat_shell_renderer_scope.dart';
// Lot γ0/δ (CR-IFFD-72) — les **réglages de génération**, du contrat à l'écran :
// `ZChatSettingsController` porte l'état (hors de `ZChatController` : G-CH1
// asserte l'égalité d'ensemble de ses membres), `ZChatController.send(settings:,
// corpusScope:)` le transporte APRÈS le builder de l'hôte — donc sans qu'aucun
// hôte puisse le jeter en silence — et `ZChatSettingsSheet` le rend, tuile par
// tuile remplaçable. Aucun enum réinventé : tout vient du kernel (lot β).
export 'src/presentation/settings/z_chat_settings_controller.dart';
export 'src/presentation/view/z_chat_attachment_strip.dart';
export 'src/presentation/view/z_chat_block_view.dart';
export 'src/presentation/view/z_chat_capture_bar.dart';
export 'src/presentation/view/z_chat_capture_review_field.dart';
// Lot α (CR-IFFD-72) — la **zone de saisie PARTAGÉE** : `ZChatComposer` rend
// `ZChatController.composer` (le contrôleur existait, le WIDGET manquait), et
// les DEUX surfaces le montent par la fabrique unique `_zChatComposeSurface`.
// Aucun membre ajouté au contrôleur (G-CH1), aucun nouveau chemin d'exécution
// (l'envoi passe par `send()`), créneaux nullables (AD-4).
export 'src/presentation/view/z_chat_composer.dart';
// Lot K2 (chantier composer-lex) — la référence visuelle lex du composer, sa
// chaîne paramètre > jeton > référence et les créneaux par défaut PURS.
export 'src/presentation/view/z_chat_composer_chrome.dart';
export 'src/presentation/view/z_chat_composer_model_selector.dart';
export 'src/presentation/view/z_chat_composer_reference.dart';
export 'src/presentation/view/z_chat_conversation_actions.dart';
export 'src/presentation/view/z_chat_conversation_list.dart';
export 'src/presentation/view/z_chat_conversation_tile.dart';
export 'src/presentation/view/z_chat_conversation_view.dart';
export 'src/presentation/view/z_chat_diffusion_bar.dart';
export 'src/presentation/view/z_chat_highlight.dart';
export 'src/presentation/view/z_chat_labels.dart';
export 'src/presentation/view/z_chat_message_tile.dart';
// CR-IFFD-71 — la distinction NOTEBOOK / CONVERSATION : créneaux additifs
// (`identityBuilder` / `actionsBuilder`, builders nullables — défauts
// strictement inchangés) sur `ZChatMessageTile`/`ZChatConversationView`, et
// `ZChatNotebookView`, composition MINCE sur la MÊME racine (même fabrique de
// tuile — G-S5/G-N1) : identité structurellement masquée, actions par message
// exposées. Les capacités notebook (mindmap, flashcards, variantes, export,
// enregistrer en note) s'exécutent par `runAction(ZChatCustomAction(...))` —
// aucun nouveau chemin d'exécution.
// Lot γ (CR-IFFD-72) — le rendu de RÉFÉRENCE du notebook : un fichier de
// valeurs audité (exception FR-26 encadrée, exemption NOMINATIVE dans les deux
// gardes de source) et sa chaîne de résolution `paramètre > jeton > référence`.
// 🔴 Aucune vue ne les monte : le skin est OPT-IN, consommé par le backend de
// coquille auquel l'hôte le passe. L'arbre d'un hôte passif ne bouge pas.
export 'src/presentation/view/z_chat_notebook_reference.dart';
export 'src/presentation/view/z_chat_notebook_skin.dart';
export 'src/presentation/view/z_chat_notebook_view.dart';
// Lot « mode Tile + sélecteur de modèle » (arbitrage owner 2026-08-07) — le
// modèle d'entrées DÉCLARATIF de la feuille (kind OUVERT, AD-4 ; kind inconnu
// absent sans throw, AD-10), sur lequel les cinq familles standard sont
// RE-EXPRIMÉES en interne (une seule voie de rendu, arbre par défaut identique
// — garde RX-1), et le sélecteur de modèle d'IA du composer (contrat opaque
// `ZChatModelOption`, menu par défaut au rendu des vidéos, coche sur l'actif).
export 'src/presentation/view/z_chat_settings_entry.dart';
export 'src/presentation/view/z_chat_settings_sheet.dart';
export 'src/presentation/z_chat_controller.dart';
export 'src/presentation/z_chat_stream_progress.dart';

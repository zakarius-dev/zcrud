/// Barrel d'API publique de `zcrud_chat`.
///
/// Ce paquet porte l'état réactif Flutter-natif d'une conversation IA, sur le
/// domaine pur exposé par `zcrud_chat_kernel` :
///
/// - **Contrôleur de conversation** — `ZChatController` expose des tranches
///   `ValueListenable` granulaires (composer, messages, texte en cours par
///   requête, progression par requête, échec typé, annonce d'accessibilité),
///   un `ZChatRequestToken` par requête, la reprise d'un flux interrompu sous
///   la même identité (aucun rejeu du tour), et un unique point d'entrée pour
///   tous les verbes (`runAction`). `ZChatPhase` / `ZChatStreamProgress`
///   portent une progression grossière, volontairement séparée du texte à
///   haute fréquence (invariant AD-2). `ZChatConfirm`,
///   `ZChatRequestIdFactory` et `ZChatRequestBuilder` sont les seams fournis
///   par l'application hôte (dialogue de confirmation, fabrique d'identité,
///   construction de la requête) : ce paquet ne compose ni libellé, ni
///   couleur, ni prompt (invariants AD-11/AD-12).
/// - **Rendu neutre de conversation** — `ZChatRenderer` est le port de rendu,
///   sur le patron de `ZListRenderer`/`ZReorderRenderer` (invariant AD-8) ;
///   `null` signifie « garder le rendu neutre ». `ZChatRendererScope` et
///   `zResolveChatBlock` portent l'injection et la chaîne de résolution
///   complète (seam de l'hôte puis repli neutre), qui ne lève jamais
///   (invariant AD-10). `ZChatConversationView`, `ZChatMessageTile` et
///   `ZChatBlockView` fournissent le rendu par défaut, sans dépendance
///   tierce : `ListView.builder`, région live d'accessibilité, dépli inline,
///   libellés résolus par `ZcrudLabels`, jetons de `ZcrudTheme`. Un rendu
///   riche (Markdown/LaTeX, grille de données) se branche par la même
///   couture sans que ce paquet ne dépende de Quill ni de Syncfusion.
/// - **Pièces jointes et export** — `ZChatAttachmentController` gère le
///   cycle de vie d'une pièce jointe en `ChangeNotifier` à tranches
///   `ValueListenable`, avec `ZResult` sur chaque opération (invariant AD-5)
///   et `ZChatAttachment` du kernel en sortie de téléversement.
///   `ZChatAttachmentPicker` et `ZChatAttachmentUploader` sont les coutures
///   qui isolent la sélection de fichier et le transport hors du socle :
///   sans elles, le chat reste fonctionnel, seul le fait de joindre un
///   fichier est indisponible. `ZChatExportService` produit l'export agrégé
///   d'une conversation entière dans quatre formats textuels, sans aucune
///   dépendance tierce. `ZChatPdfComposer` et `ZChatExportSink` sont les
///   coutures du PDF et de la destination système : le service de partage de
///   fichier n'est jamais dupliqué ici, il est câblé par l'implémentation
///   d'hôte de `ZChatExportSink` — en dépendre en dur ferait entrer
///   l'impression et une dépendance de rendu de document dans ce paquet
///   (invariant AD-1). `ZChatAttachmentStrip` rend les pièces en attente avec
///   des cibles tactiles conformes (invariant AD-13).
///
/// Dépend de `zcrud_chat_kernel` (domaine du chat) et de `zcrud_core`
/// (`ZResult`/`ZFailure`, `ZcrudTheme`, `label`) — arêtes sortantes
/// uniquement, graphe acyclique (invariant AD-1). Aucun gestionnaire d'état
/// n'est importé (invariants AD-2/AD-15) et aucune dépendance tierce n'entre
/// dans ce paquet.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

/// Surface de liste de conversations :
/// - `ZChatConversationTile` : la tuile neutre (titre à `maxLines`
///   paramétrable, horodatage relatif localisable dont le champ source et le
///   formateur sont injectables, pastille teintable, badges par prédicat,
///   emplacement `trailing`, description d'accessibilité complète, cible
///   tactile bornée par le conteneur).
/// - `ZChatConversationList` : `ListView.builder` avec trois états distincts
///   (l'erreur est testée avant le chargement), squelette annoncé, état vide
///   à deux variantes, tri exposé, pagination par curseur, sélection
///   multiple, groupes à clé opaque repliés par un contrôleur externe.
/// - `ZChatConversationSelection` / `ZChatGroupExpansion` : les deux
///   contrôleurs fournis par l'hôte — à créer en dehors de `build`.
/// - `zChatConversationActions` : les descripteurs d'action, absents quand
///   leur callback est nul, ce qui rend les ports de conversation du kernel
///   câblables sans qu'aucun verbe ne soit codé en dur.
/// - `ZChatHighlightedText` / `zChatHighlightRanges` : le surlignage de texte
///   partagé par les surfaces de recherche.
export 'src/presentation/attachment/z_chat_attachment_controller.dart';
export 'src/presentation/attachment/z_chat_attachment_failure.dart';
export 'src/presentation/attachment/z_chat_attachment_ports.dart';
export 'src/presentation/attachment/z_pending_attachment.dart';
// Saisie assistée : la dictée et l'OCR entrent par des ports du kernel, et la
// relecture est structurelle — `ZChatCaptureController.acceptInto` rend un
// `ZResult<Unit>`, aucune `String` ne s'échappe directement vers l'envoi.
export 'src/presentation/capture/z_chat_capture_controller.dart';
export 'src/presentation/conversation/z_chat_conversation_selection.dart';
export 'src/presentation/conversation/z_chat_group_expansion.dart';
// Diffusion : la voix passe par la chaîne de repli du kernel ; l'export et le
// partage sont délégués à `ZChatExportService`, jamais redéfinis ici.
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
// Réglages de génération, du contrat à l'écran : `ZChatSettingsController`
// porte l'état hors de `ZChatController` ; `ZChatController.send(settings:,
// corpusScope:)` le transporte après le builder de l'hôte, de sorte qu'aucun
// hôte ne puisse le perdre en silence ; `ZChatSettingsSheet` le rend, tuile
// par tuile remplaçable. Aucun enum n'est réinventé : tout vient du kernel.
export 'src/presentation/settings/z_chat_settings_controller.dart';
// Les ARTEFACTS déclarés par message (CR-IFFD-84, volet A) :
// `ZChatArtifactSpec` porte une clé OPAQUE, un glyphe, un libellé déjà
// localisé et trois lectures d'ÉTAT sur le message brut (présence, compte,
// occupation) ; `ZChatArtifactAction` porte les verbes, leur condition de
// visibilité, leur teinte propre et leur rappel — l'ordre et la couleur
// restent ceux de l'hôte. `ZChatArtifactBar` rend l'état (glyphe teinté SI
// le contenu existe, pastille NON interactive, menu des verbes dont la
// condition tient, confirmation d'un verbe destructeur, état ANNONCÉ), et
// consomme enfin `capabilityAccents` — la table que le socle offrait sans
// que personne ne la lise.
export 'src/presentation/view/z_chat_artifact_bar.dart';
export 'src/presentation/view/z_chat_artifact_spec.dart';
export 'src/presentation/view/z_chat_attachment_strip.dart';
export 'src/presentation/view/z_chat_block_view.dart';
export 'src/presentation/view/z_chat_capture_bar.dart';
export 'src/presentation/view/z_chat_capture_review_field.dart';
// Zone de saisie partagée : `ZChatComposer` rend `ZChatController.composer`,
// et les deux surfaces de composition le montent par la même fabrique
// interne. Aucun membre n'est ajouté au contrôleur, aucun nouveau chemin
// d'exécution (l'envoi passe toujours par `send()`), créneaux nullables
// (invariant AD-4).
export 'src/presentation/view/z_chat_composer.dart';
// La référence visuelle du composer, sa chaîne de résolution
// paramètre > jeton > référence et ses créneaux par défaut purs ; les pièces
// assemblées en widgets purs (conteneur, sélecteurs à contrat opaque,
// bascules réfléchir/internet sur le même `ZChatSettingsController` que la
// feuille de réglages — un état, deux surfaces —, déclencheur « outils » à
// badge, arrêt câblé sur le verbe existant `runAction(ZChatCancelAction)`,
// bandeau d'édition) ; et `ZDefaultChatComposer`, l'assemblage par défaut
// opt-in de ces pièces.
export 'src/presentation/view/z_chat_composer_band.dart';
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
// Distinction notebook / conversation : créneaux additifs (`identityBuilder`
// / `actionsBuilder`, builders nullables, défauts inchangés) sur
// `ZChatMessageTile`/`ZChatConversationView`, et `ZChatNotebookView`,
// composition mince sur la même racine — identité structurellement masquée,
// actions par message exposées. Les capacités notebook (mindmap, flashcards,
// variantes, export, enregistrer en note) s'exécutent par
// `runAction(ZChatCustomAction(...))`, sans nouveau chemin d'exécution.
// Le rendu de référence du notebook (un fichier de valeurs audité, exception
// encadrée à l'invariant AD-13 sur les couleurs codées en dur) et sa chaîne
// de résolution paramètre > jeton > référence. Ce skin est opt-in : aucune
// vue ne le monte d'elle-même, il est consommé par le backend de coquille
// auquel l'hôte le passe — l'arbre d'un hôte passif ne change pas.
export 'src/presentation/view/z_chat_notebook_reference.dart';
export 'src/presentation/view/z_chat_notebook_skin.dart';
export 'src/presentation/view/z_chat_notebook_view.dart';
// Le modèle d'entrées déclaratif de la feuille de réglages (nature ouverte,
// invariant AD-4 ; une nature inconnue est simplement absente, sans lever,
// invariant AD-10), sur lequel les familles standard sont ré-exprimées en
// interne (une seule voie de rendu, arbre par défaut identique), et le
// sélecteur de modèle d'IA du composer (contrat opaque `ZChatModelOption`,
// menu par défaut au rendu des vidéos, coche sur l'actif).
export 'src/presentation/view/z_chat_settings_entry.dart';
export 'src/presentation/view/z_chat_settings_sheet.dart';
export 'src/presentation/view/z_default_chat_composer.dart';
export 'src/presentation/z_chat_assembly_contract.dart';
export 'src/presentation/z_chat_controller.dart';
export 'src/presentation/z_chat_stream_progress.dart';

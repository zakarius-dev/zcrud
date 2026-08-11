/// **UNIQUE** voie de réordonnancement des flashcards d'un dossier.
///
/// ## Pourquoi « une seule voie » n'est pas un slogan
///
/// L'ordre manuel a **deux déclencheurs** dans l'UI : le **drag** (souris/doigt)
/// et les **boutons Monter/Descendre** (a11y — un utilisateur de lecteur d'écran
/// ne peut pas glisser-déposer). S'ils empruntaient deux chemins d'écriture, ils
/// divergeraient : le drag persisterait `'flashcards'`, les boutons
/// `'flashcards/'`, et — `applyOrder` étant **TOTAL** — **rien ne rougirait**.
/// L'ordre serait simplement « oublié » pour l'un des deux, en silence.
///
/// ⇒ [zReorderFlashcards] est la **seule** fonction qui produit un
/// `ZFolderContentsOrder` réordonné. Drag **et** boutons l'appellent — prouvé
/// par une garde de source (une seule fonction écrit `sectionOrders`) **et**
/// par une garde de comportement (« drag et boutons ⇒ ordre persisté
/// IDENTIQUE »). Les deux canaux, jamais un seul.
///
/// ## Ce que ce fichier NE fait PAS
///
/// - Il ne compose **aucune** clé à la main : [zSectionKey] est la seule voie
///   (une garde du kernel interdit toute composition manuelle) ;
/// - Il ne **réimplémente pas** le déplacement : [zReorderIds] (pur, **total**,
///   indices **clampés**) le fait déjà ;
/// - Il ne **trie pas** : `applyOrder`/`applyTo` (kernel) applique l'ordre.
///
/// **PUR** : aucune I/O, aucune horloge. L'entrée n'est **jamais mutée**
/// (`copyWith` rend une nouvelle instance).
library;

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZFolderContentsOrder, zSectionKey;

import 'z_reorder_ids.dart';

/// `contentType` **canonique** des flashcards — **RISQUE DE DONNÉES**.
///
/// **VERBATIM `'flashcards'`, à ne JAMAIS modifier.** C'est la clé **déjà en
/// base** chez les applications consommatrices : la forme nue produite par
/// `zSectionKey(contentType: 'flashcards')` — **jamais** `'flashcards/'`, jamais
/// `'section:flashcards'`, jamais `'flashcard'` au singulier.
///
/// Tout préfixe, suffixe ou renommage **orphelinerait l'ordre persisté en
/// silence** : `applyOrder` est **TOTAL**, une clé qui ne correspond à rien est
/// ignorée **sans erreur et sans test rouge**. L'utilisateur verrait simplement
/// son classement « oublié ». Verrouillé par une preuve de rétro-compatibilité
/// **bout en bout**.
const String kFlashcardsContentType = 'flashcards';

/// Clé de section canonique des flashcards de [subfolderId].
///
/// **Unique** point de lecture COMME d'écriture — jamais composée à la main.
/// `subfolderId` `null` **ou vide** ⇒ clé **nue** [kFlashcardsContentType]
/// (`'flashcards'`), la forme historique **déjà persistée**.
String zFlashcardsSectionKey({String? subfolderId}) =>
    zSectionKey(contentType: kFlashcardsContentType, subfolderId: subfolderId);

/// Déplace la carte de [oldIndex] vers [newIndex] et rend l'ordre
/// **persistable** — **UNIQUE** voie de réordonnancement.
///
/// - [order] : ordre personnel actuel du dossier (**jamais muté**) ;
/// - [visibleIds] : ids des cartes **telles qu'affichées** (ordre courant à
///   l'écran, déjà filtré/trié). C'est sur **cette** liste que les indices
///   portent — jamais sur l'ordre persisté, qui peut contenir des orphelins ou
///   ignorer des cartes neuves ;
/// - [subfolderId] : sous-dossier de la section (`null` ⇒ section racine) ;
/// - [oldIndex]/[newIndex] : convention **`removeAt` puis `insert`** (celle de
///   [zReorderIds] ; l'ajustement `newIndex -= 1` propre à `ReorderableListView`
///   est déjà appliqué en amont par le SDK via `onReorderItem`).
///
/// ## Pourquoi l'ordre persisté est RECALCULÉ depuis [visibleIds]
///
/// L'ordre persisté peut être **périmé** (cartes supprimées depuis, cartes neuves
/// jamais ordonnées). Appliquer le déplacement à l'ordre **persisté** placerait la
/// carte à un index qui ne correspond à **rien** de ce que l'utilisateur voit.
/// On réordonne donc ce qui est **à l'écran**, puis on persiste ce résultat : le
/// geste et son effet coïncident toujours, et l'ordre se **répare** de lui-même
/// (les orphelins disparaissent, les nouvelles cartes prennent leur place).
///
/// **Total** (AD-10) : indices hors bornes **clampés** par [zReorderIds], liste
/// vide ⇒ ordre inchangé, jamais de throw.
ZFolderContentsOrder zReorderFlashcards(
  ZFolderContentsOrder order, {
  required List<String> visibleIds,
  required int oldIndex,
  required int newIndex,
  String? subfolderId,
}) {
  // Déplacement DÉLÉGUÉ (pur, total, indices clampés) — jamais réimplémenté.
  final reordered = zReorderIds(visibleIds, oldIndex, newIndex);

  // Clé composée par l'UNIQUE constructeur canonique.
  final key = zFlashcardsSectionKey(subfolderId: subfolderId);

  // Écriture via `copyWith` : l'ordre d'entrée n'est jamais muté, et la map
  // rendue est non modifiable EN PROFONDEUR (garde du kernel).
  return order.copyWith(
    sectionOrders: <String, List<String>>{
      ...order.sectionOrders,
      key: reordered,
    },
  );
}

/// Index de la carte [id] dans [visibleIds] déplacée d'un cran vers le **haut**
/// (bouton a11y « Monter ») — ou `null` si le déplacement est **impossible**
/// (carte absente, ou **déjà en tête**).
///
/// `null` ⇒ le bouton doit être **ABSENT** (`onSelected: null`), jamais grisé
/// ni no-op (invariant AD-4). C'est ce qui empêche un bouton « Monter » qui
/// ferait silencieusement avancer la première carte au lieu de ne rien faire.
({int oldIndex, int newIndex})? zMoveUpIndices(
  List<String> visibleIds,
  String id,
) {
  final index = visibleIds.indexOf(id);
  if (index <= 0) return null; // absent (-1) ou déjà en tête (0)
  return (oldIndex: index, newIndex: index - 1);
}

/// Index de la carte [id] dans [visibleIds] déplacée d'un cran vers le **bas**
/// (bouton a11y « Descendre ») — ou `null` si **impossible** (carte absente, ou
/// **déjà en dernier**).
///
/// `null` ⇒ bouton **ABSENT** : le dernier ne descend pas.
({int oldIndex, int newIndex})? zMoveDownIndices(
  List<String> visibleIds,
  String id,
) {
  final index = visibleIds.indexOf(id);
  if (index < 0 || index >= visibleIds.length - 1) return null;
  return (oldIndex: index, newIndex: index + 1);
}

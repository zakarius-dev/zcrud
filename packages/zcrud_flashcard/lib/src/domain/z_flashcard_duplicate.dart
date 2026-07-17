/// « Dupliquer pour modifier » (SU-8, FR-SU21 — AC13, AD-45, décision D6).
///
/// Répond au besoin d'une carte **partagée en lecture seule** (`isReadOnly`) :
/// l'utilisateur ne peut pas l'éditer, mais il peut en prendre **sa propre
/// copie** et la modifier. La copie est **éphémère** (`id: null`) : elle ne
/// franchit la frontière de persistance que par le **commit explicite** de
/// l'appelant (AD-43).
///
/// ## Ce qui est copié — et ce qui ne l'est JAMAIS (AD-45)
///
/// | | Champ | Pourquoi |
/// |---|---|---|
/// | ✅ | `question`, `answer`, `isTrue`, `choices`, `explanation`, `hint`, `type` | **le contenu** — c'est l'objet même de la duplication |
/// | ✅ | `tagIds` | classement **du contenu**, pas un état perso (`ZFlashcardTag` est une entité partagée) |
/// | ✅ | `folderId`, `subFolderId` | la copie naît **là où on l'a dupliquée** |
/// | ✅ | `source` | **provenance factuelle du contenu copié** — AD-45 ne bannit que SRS + ordre. L'origine du contenu reste vraie après copie |
/// | ✅ | `extension`, `extra` | slots AD-4 : les perdre serait une **perte muette** de données que le cœur ne comprend pas. `extra` est copié **EN PROFONDEUR** (décision D6, cf. ci-dessous) |
/// | 🚫 | `id` → **`null`** | **éphémère** (AD-43/AD-45) : sans id, la copie ne peut pas écraser l'original ni être jointe à quoi que ce soit |
/// | 🚫 | `isReadOnly` → **`false`** | AD-45 : « remis à faux » — une copie encore en lecture seule rendrait la fonction **morte sur son chemin documenté** |
/// | 🚫 | `createdAt`/`updatedAt` → **`null`** | ce sont les dates de l'**ORIGINAL** : les copier ferait **MENTIR** la copie sur sa provenance temporelle. Le commit les assignera |
/// | 🚫 | **état SRS** (`ZRepetitionInfo`) | AD-45. **Par construction** : le SRS n'est pas dans `ZFlashcard` (entité séparée, clé `flashcardId`) — et une copie sans id **ne peut pas** être jointe |
/// | 🚫 | **ordre** (`ZFolderContentsOrder`) | AD-45. Idem : l'ordre indexe des **ids** ; `id == null` ⇒ inatteignable |
///
/// Les deux dernières lignes ne sont pas une promesse : elles sont **prouvées**
/// par `test/z_flashcard_duplicate_test.dart` (un `ZRepetitionInfo` de l'original
/// n'est **pas** joignable à la copie ; `orderFor(zSectionKey(...))` ne la
/// contient pas).
///
/// Fonction **PURE** : l'original n'est **JAMAIS muté** (AD-45).
library;

import 'z_flashcard.dart';

/// Duplique [card] en une copie **éphémère et éditable** (AC13, AD-45).
///
/// L'**original n'est jamais muté** : une **nouvelle** instance est rendue.
///
/// ## Pourquoi un constructeur explicite et non `copyWith`
///
/// `copyWith` ne peut pas **remettre un champ à `null`** (un argument omis =
/// « inchangé », un argument `null` = « inchangé » aussi) : `card.copyWith(id:
/// null)` rendrait une copie **portant l'id de l'original** — qui, au commit,
/// **ÉCRASERAIT la carte partagée** au lieu d'en créer une nouvelle. C'est
/// précisément le défaut que AD-45 prévient, et il serait **silencieux**. Le
/// constructeur nominal est donc la **seule** voie correcte ici.
///
/// ⚠️ Corollaire : tout champ **ajouté** à `ZFlashcard` devra être ajouté ici
/// **explicitement**. Le test « champ par champ » de
/// `z_flashcard_duplicate_test.dart` est ce qui rend cet oubli **bruyant** (un
/// champ oublié = une perte muette de contenu à la duplication).
///
/// ## `extra` — copie PROFONDE (décision D6)
///
/// `Map.of`/`List.of` ne copient que le **premier niveau** : une sous-structure
/// imbriquée (`List`/`Map`) resterait **`identical`** entre l'original et la
/// copie ⇒ éditer la copie **muterait la carte partagée** en lecture seule —
/// exactement ce qu'AD-45 interdit, en silence. Or `extra` est le slot AD-4
/// **non typé** : du JSON arbitraire, donc précisément l'endroit où vivent les
/// `List`/`Map` imbriquées. On le clone donc **récursivement** ([_deepCopyJson]),
/// symétriquement à la copie défensive de `choices`.
ZFlashcard zDuplicateFlashcardForEditing(ZFlashcard card) {
  return ZFlashcard(
    // 🚫 ÉPHÉMÈRE — jamais l'id de l'original (sinon le commit l'écraserait).
    id: null,
    // ✅ La copie naît là où on l'a dupliquée.
    folderId: card.folderId,
    subFolderId: card.subFolderId,
    // ✅ LE CONTENU — l'objet même de la duplication.
    type: card.type,
    question: card.question,
    answer: card.answer,
    isTrue: card.isTrue,
    // Copie DÉFENSIVE de la liste : `ZChoice` est immuable, mais partager
    // l'instance de LISTE ferait qu'une mutation côté copie (ou côté original)
    // toucherait les deux. `null` reste `null` (une carte non-QCM n'a pas de
    // choix — lui en inventer une liste vide changerait son type effectif).
    choices: card.choices == null ? null : List<ZChoice>.of(card.choices!),
    explanation: card.explanation,
    hint: card.hint,
    // ✅ Classement du CONTENU (entité partagée, pas un état perso).
    tagIds: List<String>.of(card.tagIds),
    // 🚫 AD-45 : « remis à faux » — sinon la copie serait inéditable et la
    //    fonction entière serait morte sur son chemin documenté.
    isReadOnly: false,
    // 🚫 Dates de l'ORIGINAL : les copier MENTIRAIT sur la provenance.
    //    Le commit de l'appelant les assignera.
    createdAt: null,
    updatedAt: null,
    // ✅ Provenance factuelle du contenu copié (AD-45 ne bannit que SRS+ordre).
    source: card.source,
    // ✅ Slots AD-4 : les perdre serait une perte muette.
    extension: card.extension,
    // 🔴 D6/AD-45 — copie PROFONDE : `Map.of` ne clone que le 1er niveau ⇒ une
    // `List`/`Map` imbriquée resterait `identical` et éditer la copie muterait
    // la carte partagée. Symétrique du clonage défensif de `choices`.
    extra: _deepCopyExtra(card.extra),
  );
}

/// Clone **récursif** du slot [extra] (AD-4/AD-45, décision D6).
Map<String, dynamic> _deepCopyExtra(Map<String, dynamic> extra) =>
    <String, dynamic>{
      for (final entry in extra.entries) entry.key: _deepCopyJson(entry.value),
    };

/// Copie **PROFONDE** d'une valeur JSON (`Map`/`List`/scalaire).
///
/// Les `Map`/`List` sont reconstruites récursivement ; les scalaires
/// (`String`/`num`/`bool`/`null`) sont **immuables** ⇒ leur partage est sûr.
Object? _deepCopyJson(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        '${entry.key}': _deepCopyJson(entry.value),
    };
  }
  if (value is List) {
    return <dynamic>[for (final item in value) _deepCopyJson(item)];
  }
  return value;
}

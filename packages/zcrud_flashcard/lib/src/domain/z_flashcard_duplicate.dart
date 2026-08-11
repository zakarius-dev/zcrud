/// « Dupliquer pour modifier » — copie éphémère et éditable d'une carte.
///
/// Répond au besoin d'une carte partagée en lecture seule (`isReadOnly`) :
/// l'utilisateur ne peut pas l'éditer, mais il peut en prendre sa propre
/// copie et la modifier. La copie est éphémère (`id: null`) : elle ne
/// franchit la frontière de persistance que par le commit explicite de
/// l'appelant.
///
/// ## Ce qui est copié — et ce qui ne l'est jamais
///
/// | | Champ | Pourquoi |
/// |---|---|---|
/// | copié | `question`, `answer`, `isTrue`, `choices`, `explanation`, `hint`, `type` | le contenu — c'est l'objet même de la duplication |
/// | copié | `tagIds` | classement du contenu, pas un état personnel (l'entité de tag est partagée) |
/// | copié | `folderId`, `subFolderId` | la copie naît là où on l'a dupliquée |
/// | copié | `source` | provenance factuelle du contenu copié — l'origine du contenu reste vraie après copie |
/// | copié | `extension`, `extra` | les perdre serait une perte muette de données que le domaine ne comprend pas ; `extra` est copié en profondeur (voir plus bas) |
/// | jamais | `id` → `null` | éphémère : sans id, la copie ne peut pas écraser l'original ni être jointe à quoi que ce soit |
/// | jamais | `isReadOnly` → `false` | une copie encore en lecture seule rendrait la fonction inutilisable |
/// | jamais | `createdAt`/`updatedAt` → `null` | ce sont les dates de l'original : les copier ferait mentir la copie sur sa provenance temporelle — le commit les assignera |
/// | jamais | état SRS | par construction, l'état de répétition espacée n'est pas dans `ZFlashcard` (entité séparée, clé `flashcardId`) — et une copie sans id ne peut pas être jointe |
/// | jamais | ordre manuel de dossier | l'ordre indexe des ids ; `id == null` ⇒ inatteignable |
///
/// Fonction pure : l'original n'est jamais muté.
library;

import 'z_flashcard.dart';

/// Duplique [card] en une copie éphémère et éditable.
///
/// L'original n'est jamais muté : une nouvelle instance est rendue.
///
/// ## Pourquoi un constructeur explicite et non `copyWith`
///
/// `copyWith` ne peut pas remettre un champ à `null` (un argument omis
/// signifie « inchangé », un argument `null` signifie aussi « inchangé ») :
/// `card.copyWith(id: null)` rendrait une copie portant l'id de l'original —
/// qui, au commit, écraserait la carte partagée au lieu d'en créer une
/// nouvelle, silencieusement. Le constructeur nominal est donc la seule voie
/// correcte ici.
///
/// Tout champ ajouté à `ZFlashcard` devra être ajouté ici explicitement — un
/// champ oublié serait une perte muette de contenu à la duplication.
///
/// ## `extra` — copie profonde
///
/// `Map.of`/`List.of` ne copient que le premier niveau : une sous-structure
/// imbriquée (`List`/`Map`) resterait identique en mémoire entre l'original
/// et la copie, et éditer la copie muterait alors la carte partagée en
/// lecture seule. Or `extra` est le slot non typé de l'invariant AD-4 : du
/// JSON arbitraire, donc précisément l'endroit où vivent des structures
/// imbriquées. Il est donc cloné récursivement, symétriquement à la copie
/// défensive de `choices`.
ZFlashcard zDuplicateFlashcardForEditing(ZFlashcard card) {
  return ZFlashcard(
    // Éphémère — jamais l'id de l'original (sinon le commit l'écraserait).
    id: null,
    // La copie naît là où on l'a dupliquée.
    folderId: card.folderId,
    subFolderId: card.subFolderId,
    // Le contenu — l'objet même de la duplication.
    type: card.type,
    question: card.question,
    answer: card.answer,
    isTrue: card.isTrue,
    // Copie défensive de la liste : `ZChoice` est immuable, mais partager
    // l'instance de liste ferait qu'une mutation côté copie (ou côté
    // original) toucherait les deux. `null` reste `null` (une carte non-QCM
    // n'a pas de choix — lui en inventer une liste vide changerait son type
    // effectif).
    choices: card.choices == null ? null : List<ZChoice>.of(card.choices!),
    explanation: card.explanation,
    hint: card.hint,
    // Classement du contenu (entité partagée, pas un état personnel).
    tagIds: List<String>.of(card.tagIds),
    // Remis à `false` — sinon la copie serait inéditable.
    isReadOnly: false,
    // Dates de l'original : les copier mentirait sur la provenance. Le
    // commit de l'appelant les assignera.
    createdAt: null,
    updatedAt: null,
    // Provenance factuelle du contenu copié.
    source: card.source,
    // Slots d'extension : les perdre serait une perte muette.
    extension: card.extension,
    // Copie profonde : `Map.of` ne clone que le premier niveau, une
    // structure imbriquée resterait identique et éditer la copie muterait
    // la carte partagée. Symétrique du clonage défensif de `choices`.
    extra: _deepCopyExtra(card.extra),
  );
}

/// Clone récursif du slot [extra] (invariant AD-4).
Map<String, dynamic> _deepCopyExtra(Map<String, dynamic> extra) =>
    <String, dynamic>{
      for (final entry in extra.entries) entry.key: _deepCopyJson(entry.value),
    };

/// Copie profonde d'une valeur JSON (`Map`/`List`/scalaire).
///
/// Les `Map`/`List` sont reconstruites récursivement ; les scalaires
/// (`String`/`num`/`bool`/`null`) sont immuables, donc leur partage est sûr.
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

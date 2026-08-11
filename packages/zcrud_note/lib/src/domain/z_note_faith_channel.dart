/// `ZNoteContentFaithChannel` — le **canal de FOI** du corps d'une note.
///
/// ## Le défaut que ce type ferme (MESURÉ, pas lu)
///
/// Un hôte migré par *strangler fig* persiste son corps de note dans **son**
/// format d'origine (une `String` markdown, une `String` Delta JSON…). Pour être
/// lu par un consommateur zcrud pur, ce corps est **doublé** : (a) TYPÉ dans
/// [ZSmartNote.content] (ops Delta neutres), et (b) **verbatim** dans une clé
/// d'[ZSmartNote.extra] que l'hôte se réserve — laquelle **fait FOI** à la
/// relecture. Ce doublage n'est pas une bizarrerie d'un hôte : c'est le motif que
/// le socle **prescrit** dès que la donnée précède la migration.
///
/// `ZSmartNoteEditor` ne remontait que `note.copyWith(content: ops)` : **le champ
/// typé, et lui seul**. `extra` étant préservé verbatim par `copyWith`, le canal
/// de foi restait **figé sur l'état d'AVANT l'édition**. Mesuré (scénario complet
/// hôte + éditeur + frappe réelle) :
///
/// ```text
/// content typé        = '# Titre markdown legacy MODIF\n'   ← la frappe est là
/// extra['<foi>']      = '# Titre markdown legacy'           ← figé
/// relecture (foi) = '# Titre markdown legacy' ← MODIF PERDU
/// ```
///
/// Aucune erreur, aucun champ vide, rien à l'écran : **perte silencieuse**.
///
/// ## Ce que ce type change
///
/// Déclarer un canal de foi à l'éditeur (`ZSmartNoteEditor.faithChannel`) fait
/// écrire les **DEUX** canaux **dans la même remontée** — le champ typé *et* la
/// clé de foi, à partir des **mêmes** ops. Ils ne peuvent plus diverger.
///
/// ```dart
/// ZSmartNoteEditor(
///   note: note,
///   onChanged: save,
///   faithChannel: ZNoteContentFaithChannel(
///     extraKey: 'monapp_content',
///     // `ZMarkdownCodec` (zcrud_markdown) encode les ops en markdown ; un hôte
///     // qui persiste du Delta JSON passera `ZDeltaCodec().encode`.
///     encode: (ops) => const ZMarkdownCodec().encode(ops),
///   ),
/// )
/// ```
///
/// ## Ce type ne rend PAS le round-trip fidèle — il rend les deux canaux
/// COHÉRENTS
///
/// L'[encode] est **fourni par l'hôte** parce que **seul l'hôte connaît son
/// format persisté** et le niveau de fidélité qu'il accepte. Mesure du socle sur
/// un corpus de 46 constructions markdown (`String → ops → String` via
/// `ZMarkdownCodec`) : **2 %** de survie à l'octet, **67 %** en tolérant le `\n`
/// terminal. Ce qui **casse** : LaTeX **bloc** (`\` doublé, `\,` détruit), fusion
/// du **saut de ligne simple** (tout texte plat multi-ligne), citation
/// multi-lignes, retour souple, espaces de fin de ligne, lignes vides multiples,
/// entités HTML. Ce qui **survit** : titres H1–H6, gras/italique/barré, code
/// inline et blocs, listes (y compris imbriquées, ordonnées, cases à cocher),
/// liens, images avec ALT, LaTeX **inline**, unicode/accents/emoji, **RTL**.
///
/// ⇒ Une garantie de round-trip **à l'octet** est hors d'atteinte (et
/// architecturalement impossible pour un persisté Delta JSON : ré-encodage). Le
/// canal de foi reste donc **le seul moyen** de tenir la fidélité que l'hôte
/// exige — mais il doit être **écrit à chaque édition**, ce que ce type garantit.
///
/// ## AD-10 — un hôte SANS canal de foi n'est pas concerné
///
/// `faithChannel` est **facultatif** et **`null` par défaut** : un producteur
/// zcrud pur (aucun corpus legacy, aucune clé doublée dans `extra`) conserve
/// **exactement** le comportement d'avant. Aucune rupture d'API, aucun paramètre
/// rendu obligatoire.
library;

import 'z_smart_note.dart';

/// Encodeur `ops Delta neutres → valeur persistée par l'hôte`.
///
/// Signature **100 % neutre** (AD-1/AD-7) : aucun type Quill, aucun type de lib
/// de conversion. Rendre `null` **retire** la clé de foi (cas « corps vide »).
typedef ZNoteContentEncoder = Object? Function(List<Map<String, dynamic>> ops);

/// Déclare la clé d'[ZSmartNote.extra] qui **fait FOI** pour le corps de la note,
/// et comment y projeter les ops éditées.
///
/// Voir la dartdoc de bibliothèque pour le défaut mesuré que ce type ferme.
final class ZNoteContentFaithChannel {
  /// Déclare le canal de foi porté par [extraKey], alimenté par [encode].
  const ZNoteContentFaithChannel({
    required this.extraKey,
    required this.encode,
  });

  /// Clé d'[ZSmartNote.extra] tenue en doublon du champ typé, et qui **fait FOI**
  /// à la relecture chez l'hôte.
  ///
  /// Elle **DOIT** être une clé **non réservée** (ni un champ de schéma, ni
  /// `extension`, ni `content`, ni une clé de sync `ZSyncMeta`) : `ZSmartNote`
  /// **dépouille** les clés réservées de `extra` sur **toutes** ses voies
  /// d'écriture. Une clé réservée rendrait le canal **INERTE** — le cas est
  /// signalé par un `assert` en debug ([applyTo]), jamais par un throw en release
  /// (AD-10).
  final String extraKey;

  /// Projette les ops éditées vers la valeur que l'hôte persiste.
  ///
  /// Appelé **à chaque remontée d'édition** (donc potentiellement à chaque
  /// frappe) : il doit rester **bon marché**. Un encodeur markdown complet
  /// (`ZMarkdownCodec.encode`) l'est ; un aller-retour réseau ou disque ne le
  /// serait pas.
  final ZNoteContentEncoder encode;

  /// Rend [note] avec sa clé de foi **RE-SYNCHRONISÉE** sur `note.content`.
  ///
  /// - [encode] rend une valeur ⇒ la clé est **écrite/écrasée** ;
  /// - [encode] rend `null` ⇒ la clé est **RETIRÉE** (le corps n'a plus de
  ///   double ; laisser l'ancienne valeur serait exactement le défaut qu'on
  ///   ferme).
  ///
  /// Ne throw **jamais** sur la donnée (AD-10). Le seul `assert` porte sur une
  /// erreur de **programmation** (clé réservée), et il est retiré en release.
  ZSmartNote applyTo(ZSmartNote note) {
    final Object? encoded = encode(note.content);
    final next = Map<String, dynamic>.of(note.extra);
    if (encoded == null) {
      next.remove(extraKey);
    } else {
      next[extraKey] = encoded;
    }
    final ZSmartNote result = note.copyWith(extra: next);
    assert(
      encoded == null || result.extra.containsKey(extraKey),
      'ZNoteContentFaithChannel: la clé "$extraKey" est RÉSERVÉE par ZSmartNote '
      '(champ de schéma, "extension", "content" ou clé de sync ZSyncMeta) : elle '
      'est dépouillée de `extra` ⇒ le canal de foi serait INERTE et l\'édition '
      'silencieusement perdue. Choisir une clé propre à l\'hôte (préfixée).',
    );
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNoteContentFaithChannel &&
          extraKey == other.extraKey &&
          encode == other.encode;

  @override
  int get hashCode => Object.hash(extraKey, encode);
}

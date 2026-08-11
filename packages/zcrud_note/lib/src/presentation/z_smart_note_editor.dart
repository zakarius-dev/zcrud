/// `ZSmartNoteEditor` — **éditeur** du corps riche d'une [ZSmartNote].
///
/// C'est un **MINCE ADAPTATEUR** : il compose le [ZMarkdownField] de
/// `zcrud_markdown` **TEL QUEL** (voie `controller`), sans aucun nouveau codec ni
/// aucune réimplémentation d'éditeur rich-text (AD-28). Le pont domaine ↔
/// éditeur est une **IDENTITÉ** : [ZSmartNote.content] est déjà la « valeur
/// neutre » que consomme `ZMarkdownField`/`ZCodec` (`List<Map<String, dynamic>>`
/// d'ops Delta) ⇒ le codec applicable est [ZDeltaCodec] (identité).
///
/// ## RÉCONCILIÉE PAR CONSTRUCTION
///
/// Le contenu injecté dans [ZMarkdownField] est **TOUJOURS** [ZSmartNote.content]
/// — c.-à-d. des ops `List<Map>` déjà canoniques (le domaine a déjà exécuté
/// `normalizeNoteContentOps`). La branche destructrice de `zcrud_markdown`
/// (`asDeltaOps(String) → null → []`, qui EFFACE un corps markdown legacy) n'est
/// **JAMAIS atteinte** : on ne passe **jamais** une `String` brute au champ —
/// un corps markdown legacy fait un round-trip sans perte.
///
/// ## Le canal de foi
///
/// Un hôte migré double son corps de note : le champ TYPÉ [ZSmartNote.content]
/// **et** une clé d'[ZSmartNote.extra] qui **fait FOI** à la relecture. L'éditeur
/// ne remontait que `copyWith(content: ops)` — `extra` étant préservé verbatim,
/// **la clé de foi restait figée sur l'état d'AVANT l'édition** et la note se
/// rouvrait sans la modification. **Mesuré** (mapper hôte + éditeur + frappe
/// réelle) : `content` portait `'… MODIF'`, la relecture rendait `'…'` — perte
/// **silencieuse**, sans erreur ni champ vide.
///
/// ⇒ [ZSmartNoteEditor.faithChannel] (**facultatif**, `null` par défaut) fait
/// écrire les **DEUX** canaux dans la **même** remontée, depuis les **mêmes** ops.
/// Un producteur zcrud pur (sans canal doublé) est **strictement inchangé**
/// (AD-10) — c'est le cas qui rendait le défaut invisible en test, et il porte
/// désormais sa garde dédiée.
///
/// INVARIANTS (AD-2/AD-7, OBJECTIF PRODUIT N°1) :
/// - **Controller ISOLÉ + place stable** : le [ZFormController] est créé UNE FOIS
///   en [State.initState] (seed `{content: note.content}`), disposé en
///   [State.dispose] ; **jamais** recréé au rebuild. Le [ZMarkdownField] porte une
///   `ValueKey` stable ⇒ son `QuillController` n'est jamais recréé (focus/curseur
///   préservés).
/// - **Saisie à SENS UNIQUE** : on écoute la tranche `content` et on **remonte**
///   `note.copyWith(content: ops)` via [onChanged] — **jamais** de ré-injection
///   dans le champ pendant l'édition (la sync guardée de `ZMarkdownField` s'en
///   charge hors focus, et nous ne réécrivons JAMAIS la tranche).
/// - **AD-1/AD-7** : entrée/sortie NEUTRES ; **aucun** type Quill dans la surface
/// publique — [onChanged] reçoit une [ZSmartNote] (`content` en
///   `List<Map<String, dynamic>>`).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import '../domain/z_note_faith_channel.dart';
import '../domain/z_smart_note.dart';

/// Éditeur du corps riche d'une [ZSmartNote] à controller ISOLÉ.
///
/// Rend un unique [ZMarkdownField] (voie `controller`) seedé avec
/// [ZSmartNote.content] et remonte les modifications via [onChanged].
class ZSmartNoteEditor extends StatefulWidget {
  /// Construit l'éditeur pour [note].
  ///
  /// [onChanged] reçoit `note.copyWith(content: <ops neutres>)` à chaque mutation
  /// du corps (sens unique). Titre/dossier/extension/extra sont **préservés** —
  /// **sauf** la clé déclarée par [faithChannel], **RE-SYNCHRONISÉE** sur les
  /// mêmes ops.
  const ZSmartNoteEditor({
    required this.note,
    required this.onChanged,
    this.faithChannel,
    super.key,
  });

  /// Note dont on édite le corps riche.
  final ZSmartNote note;

  /// Remontée à SENS UNIQUE de la note mise à jour (corps neutre).
  final ValueChanged<ZSmartNote> onChanged;

  /// Canal optionnel d'[ZSmartNote.extra] qui **fait FOI** pour le corps
  /// chez l'hôte, à tenir en cohérence avec le champ typé.
  ///
  /// **`null` par défaut** ⇒ comportement **strictement identique** à avant
  /// (producteur zcrud pur : rien à doubler — AD-10). Renseigné, chaque remontée
  /// écrit `content` **et** la clé de foi depuis les **mêmes** ops : les deux ne
  /// peuvent plus diverger, et une édition ne peut plus être perdue au
  /// rechargement.
  ///
  /// Son `encode` est appelé **à chaque frappe** — cf.
  /// [ZNoteContentFaithChannel.encode].
  final ZNoteContentFaithChannel? faithChannel;

  @override
  State<ZSmartNoteEditor> createState() => _ZSmartNoteEditorState();
}

class _ZSmartNoteEditorState extends State<ZSmartNoteEditor> {
  /// Spécification `const` du champ corps rich-text (canal `content`).
  ///
  /// `EditionFieldType.markdown` ⇒ la voie `controller` de [ZMarkdownField] rend
  /// l'éditeur pleine-toolbar (le `mode` inline/block est ignoré sur cette voie).
  static const ZFieldSpec _contentSpec = ZFieldSpec(
    name: kContentKey,
    type: EditionFieldType.markdown,
    label: 'Contenu',
  );

  /// Controller de formulaire ISOLÉ — créé UNE FOIS, jamais recréé (AD-2).
  late final ZFormController _form;

  @override
  void initState() {
    super.initState();
    // on seed avec `note.content` : des ops `List<Map>` DÉJÀ canoniques
    // (jamais une `String`). La tranche porte donc la valeur neutre que
    // `ZMarkdownField` consomme sans conversion (codec IDENTITÉ).
    _form = ZFormController(
      initialValues: <String, Object?>{_contentSpec.name: widget.note.content},
    );
    // Écoute CIBLÉE de la tranche `content` (aucune écoute globale).
    _form.fieldListenable(_contentSpec.name).addListener(_onContentChanged);
  }

  /// Remontée à SENS UNIQUE : la tranche a changé ⇒ on relit la valeur NEUTRE
  /// (ops écrites par `ZMarkdownField`) et on remonte la note mise à jour.
  ///
  /// On NE réécrit JAMAIS la tranche (aucune ré-injection) : `copyWith` préserve
  /// titre/dossier/extension/extra, et `normalizeNoteContentOps` (dans `copyWith`)
  /// garde les ops neutres verbatim.
  ///
  /// — quand un [ZSmartNoteEditor.faithChannel] est déclaré, la
  /// clé de foi est **RE-SYNCHRONISÉE dans la MÊME remontée**, depuis les
  /// **MÊMES** ops que le champ typé. C'est ce qui rend la divergence
  /// **structurellement impossible** : il n'existe pas d'instant où l'un est écrit
  /// et l'autre pas.
  void _onContentChanged() {
    final Object? ops = _form.valueOf(_contentSpec.name);
    final ZSmartNote updated = widget.note.copyWith(content: ops);
    final ZNoteContentFaithChannel? channel = widget.faithChannel;
    widget.onChanged(channel == null ? updated : channel.applyTo(updated));
  }

  @override
  void dispose() {
    _form.fieldListenable(_contentSpec.name).removeListener(_onContentChanged);
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Place STABLE (AD-2) : `ValueKey(content)` — sans elle un rebuild parent
    // pourrait recréer le `QuillController` (perte de focus). Codec IDENTITÉ.
    return ZMarkdownField(
      key: const ValueKey<String>(kContentKey),
      controller: _form,
      field: _contentSpec,
      codec: const ZDeltaCodec(),
    );
  }
}

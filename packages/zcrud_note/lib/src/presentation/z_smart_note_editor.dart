/// `ZSmartNoteEditor` — **éditeur** du corps riche d'une [ZSmartNote] (ES-6.1,
/// FR-S25).
///
/// C'est un **MINCE ADAPTATEUR** (D2) : il compose le [ZMarkdownField] de
/// `zcrud_markdown` **TEL QUEL** (voie `controller`), sans aucun nouveau codec ni
/// aucune réimplémentation d'éditeur rich-text (SM-S4/AD-28). Le pont domaine ↔
/// éditeur est une **IDENTITÉ** : [ZSmartNote.content] est déjà la « valeur
/// neutre » que consomme `ZMarkdownField`/`ZCodec` (`List<Map<String, dynamic>>`
/// d'ops Delta) ⇒ le codec applicable est [ZDeltaCodec] (identité).
///
/// ## 🔴 DW-ES22-1 RÉCONCILIÉE PAR CONSTRUCTION (D4)
///
/// Le contenu injecté dans [ZMarkdownField] est **TOUJOURS** [ZSmartNote.content]
/// — c.-à-d. des ops `List<Map>` déjà canoniques (le domaine a déjà exécuté
/// `normalizeNoteContentOps`). La branche destructrice de `zcrud_markdown`
/// (`asDeltaOps(String) → null → []`, qui EFFACE un corps markdown legacy) n'est
/// **JAMAIS atteinte** : on ne passe **jamais** une `String` brute au champ.
/// Preuve exécutable = round-trip d'un corps `'# Titre markdown legacy'` sans
/// perte (test `z_smart_note_editor_test.dart` › AC5).
///
/// INVARIANTS (AD-2/AD-7, OBJECTIF PRODUIT N°1 / SM-1) :
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
///   publique (AC8) — [onChanged] reçoit une [ZSmartNote] (`content` en
///   `List<Map<String, dynamic>>`).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import '../domain/z_smart_note.dart';

/// Éditeur du corps riche d'une [ZSmartNote] à controller ISOLÉ.
///
/// Rend un unique [ZMarkdownField] (voie `controller`) seedé avec
/// [ZSmartNote.content] et remonte les modifications via [onChanged].
class ZSmartNoteEditor extends StatefulWidget {
  /// Construit l'éditeur pour [note].
  ///
  /// [onChanged] reçoit `note.copyWith(content: <ops neutres>)` à chaque mutation
  /// du corps (sens unique). Titre/dossier/extension/extra sont **préservés**.
  const ZSmartNoteEditor({
    required this.note,
    required this.onChanged,
    super.key,
  });

  /// Note dont on édite le corps riche.
  final ZSmartNote note;

  /// Remontée à SENS UNIQUE de la note mise à jour (corps neutre).
  final ValueChanged<ZSmartNote> onChanged;

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
    // 🔴 D4 — on seed avec `note.content` : des ops `List<Map>` DÉJÀ canoniques
    // (jamais une `String`). La tranche porte donc la valeur neutre que
    // `ZMarkdownField` consomme sans conversion (codec IDENTITÉ).
    _form = ZFormController(
      initialValues: <String, Object?>{_contentSpec.name: widget.note.content},
    );
    // Écoute CIBLÉE de la tranche `content` (SM-1 : aucune écoute globale).
    _form.fieldListenable(_contentSpec.name).addListener(_onContentChanged);
  }

  /// Remontée à SENS UNIQUE : la tranche a changé ⇒ on relit la valeur NEUTRE
  /// (ops écrites par `ZMarkdownField`) et on remonte la note mise à jour.
  ///
  /// On NE réécrit JAMAIS la tranche (aucune ré-injection) : `copyWith` préserve
  /// titre/dossier/extension/extra, et `normalizeNoteContentOps` (dans `copyWith`)
  /// garde les ops neutres verbatim.
  void _onContentChanged() {
    final Object? ops = _form.valueOf(_contentSpec.name);
    widget.onChanged(widget.note.copyWith(content: ops));
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

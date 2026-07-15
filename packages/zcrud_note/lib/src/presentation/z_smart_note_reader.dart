/// `ZSmartNoteReader` — **lecteur** du corps riche d'une [ZSmartNote] (ES-6.1,
/// FR-S25).
///
/// C'est un **MINCE ADAPTATEUR** (D1) : il compose le [ZMarkdownReader] de
/// `zcrud_markdown` **TEL QUEL**, sans aucun nouveau codec ni aucune
/// réimplémentation de lecteur rich-text (SM-S4/AD-28). Le pont domaine ↔ lecteur
/// est une **IDENTITÉ** : [ZSmartNote.content] est déjà la « valeur neutre » que
/// consomme `ZMarkdownReader`/`ZCodec` (`List<Map<String, dynamic>>` d'ops Delta)
/// ⇒ le codec applicable est [ZDeltaCodec] (identité), **aucune conversion**.
///
/// INVARIANTS (hérités des widgets `zcrud_markdown` réutilisés — l'adaptateur ne
/// les régresse pas) :
/// - **AD-7/AD-1** : entrée/sortie NEUTRES ; **aucun** type Quill
///   (`QuillController`/`Document`/`Delta`) dans la signature publique (AC8).
/// - **AD-10** : contenu absent/vide/corrompu ⇒ placeholder propre, jamais de
///   throw (le décodage défensif est celui de `ZMarkdownReader`).
/// - **AD-2** : `QuillController` readOnly créé une fois, aucune voie d'écriture.
/// - **AD-13/FR-26** : directionnel, `Semantics` lisible, thème injecté.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import '../domain/z_smart_note.dart';

/// Lecteur NON éditable du corps riche d'une [ZSmartNote].
///
/// Rend [ZSmartNote.content] (ops Delta neutres) via [ZMarkdownReader] en lecture
/// seule. Le [ZSmartNote.title] alimente la sémantique.
class ZSmartNoteReader extends StatelessWidget {
  /// Construit le lecteur pour [note].
  ///
  /// [placeholder] est le texte affiché quand le corps est vide (repli sur le
  /// défaut de [ZMarkdownReader] si `null`).
  const ZSmartNoteReader({
    required this.note,
    this.placeholder,
    super.key,
  });

  /// Note dont on lit le corps riche.
  final ZSmartNote note;

  /// Texte affiché quand le corps est vide (AD-10). `null` ⇒ défaut du lecteur.
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    // Pont IDENTITÉ (D1/D4) : `note.content` EST la valeur neutre — aucune
    // transformation, codec `ZDeltaCodec` (identité). `label` = titre de la note
    // pour la sémantique.
    return ZMarkdownReader(
      value: note.content,
      codec: const ZDeltaCodec(),
      label: note.title,
      placeholder: placeholder ?? _kDefaultPlaceholder,
    );
  }
}

/// Placeholder par défaut du corps vide (parité avec `ZMarkdownReader`).
const String _kDefaultPlaceholder = 'Aucun contenu';

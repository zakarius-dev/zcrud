/// `ZSmartNoteReader` — **lecteur** du corps riche d'une [ZSmartNote].
///
/// C'est un **MINCE ADAPTATEUR** : il compose le [ZMarkdownReader] de
/// `zcrud_markdown` **TEL QUEL**, sans aucun nouveau codec ni aucune
/// réimplémentation de lecteur rich-text (AD-28). Le pont domaine ↔ lecteur
/// est une **IDENTITÉ** : [ZSmartNote.content] est déjà la « valeur neutre » que
/// consomme `ZMarkdownReader`/`ZCodec` (`List<Map<String, dynamic>>` d'ops Delta)
/// ⇒ le codec applicable est [ZDeltaCodec] (identité), **aucune conversion**.
///
/// INVARIANTS (hérités des widgets `zcrud_markdown` réutilisés — l'adaptateur ne
/// les régresse pas) :
/// - **AD-7/AD-1** : entrée/sortie NEUTRES ; **aucun** type Quill
///   (`QuillController`/`Document`/`Delta`) dans la signature publique.
/// - **AD-10** : contenu absent/vide/corrompu ⇒ placeholder propre, jamais de
///   throw (le décodage défensif est celui de `ZMarkdownReader`).
/// - **AD-2** : `QuillController` readOnly créé une fois, aucune voie d'écriture.
/// - **AD-13** : directionnel, `Semantics` lisible, thème injecté.
///
/// ## Audio de note : opt-in strict
///
/// Une note peut porter un audio déjà produit ([ZNoteAudio]). Le lecteur ne
/// **joue** rien par lui-même : il monte un [ZNoteAudioPlayer] uniquement quand
/// l'appelant fournit un [ZAudioPlaybackPort] disponible **et** que la note
/// porte réellement une source. Sans port — le défaut — l'arbre rendu est
/// **exactement** celui d'un lecteur sans audio : un unique [ZMarkdownReader],
/// sans conteneur ajouté.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import '../domain/z_note_audio.dart';
import '../domain/z_smart_note.dart';
import 'z_note_audio_player.dart';

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
    this.audioPort,
    super.key,
  });

  /// Note dont on lit le corps riche.
  final ZSmartNote note;

  /// Texte affiché quand le corps est vide (AD-10). `null` ⇒ défaut du lecteur.
  final String? placeholder;

  /// Moteur de lecture audio apporté par l'appelant, ou `null`.
  ///
  /// `null` par défaut : le lecteur rend alors **exactement** ce qu'il rendait
  /// sans cette capacité. Renseigné, un mini-lecteur apparaît au-dessus du
  /// corps **si et seulement si** le port se déclare disponible et que la note
  /// porte une source audio typée. Le port n'est jamais disposé ici : il
  /// appartient à l'appelant.
  final ZAudioPlaybackPort? audioPort;

  @override
  Widget build(BuildContext context) {
    // Pont IDENTITÉ : `note.content` EST la valeur neutre — aucune
    // transformation, codec `ZDeltaCodec` (identité). `label` = titre de la note
    // pour la sémantique.
    final Widget body = ZMarkdownReader(
      value: note.content,
      codec: const ZDeltaCodec(),
      label: note.title,
      placeholder: placeholder ?? _kDefaultPlaceholder,
    );
    final ZAudioPlaybackPort? port = audioPort;
    final ZAudioSource? source = ZNoteAudioPlayer.canPlay(note, port)
        ? ZNoteAudioPlayer.sourceOf(note)
        : null;
    // INERTIE : aucune des trois conditions réunies ⇒ on rend le lecteur riche
    // SEUL, sans le moindre conteneur ajouté (arbre identique à l'existant).
    if (source == null || port == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZNoteAudioPlayer(source: source, port: port),
        Expanded(child: body),
      ],
    );
  }
}

/// Placeholder par défaut du corps vide (parité avec `ZMarkdownReader`).
const String _kDefaultPlaceholder = 'Aucun contenu';

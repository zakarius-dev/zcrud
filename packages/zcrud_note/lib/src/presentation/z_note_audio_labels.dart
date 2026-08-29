/// Libellés et formatage du **mini-lecteur audio** de note — fichier de
/// RÉFÉRENCE unique.
///
/// ## Pourquoi un fichier séparé
///
/// Le widget de lecture ne porte **aucun** littéral affichable : tout ce qui
/// peut apparaître à l'écran (libellés, séparateur d'horodatage) est déclaré
/// **ici**, en un seul endroit auditable. Un hôte qui veut traduire ou
/// reformuler n'a donc rien à chercher dans le code du widget.
///
/// ## Chaîne de résolution d'un libellé
///
/// 1. `ZcrudScope(labels:)` — surcharge applicative par clé (priorité haute) ;
/// 2. `ZcrudLocalizations` — table générique du delegate, si l'hôte la fournit
///    pour ces clés ;
/// 3. le **défaut** de ce fichier ([kZNoteAudioDefaultLabels]).
///
/// La chaîne ne lève jamais et ne rend jamais `null` : une clé inconnue rend la
/// clé elle-même, ce qui reste lisible et diagnostiquable.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Clé du libellé de l'action « démarrer la lecture ».
const String kZNoteAudioPlayLabelKey = 'note.audio.play';

/// Clé du libellé de l'action « suspendre la lecture ».
const String kZNoteAudioPauseLabelKey = 'note.audio.pause';

/// Clé du libellé de l'état « préparation de la source en cours ».
const String kZNoteAudioLoadingLabelKey = 'note.audio.loading';

/// Clé du libellé de l'état « la source n'a pas pu être lue ».
const String kZNoteAudioFailedLabelKey = 'note.audio.failed';

/// Clé du libellé du curseur de déplacement dans la piste.
const String kZNoteAudioSeekLabelKey = 'note.audio.seek';

/// Clé du libellé sémantique de l'horodatage « position sur durée ».
const String kZNoteAudioElapsedLabelKey = 'note.audio.elapsed';

/// Séparateur affiché entre la position et la durée totale.
///
/// Déclaré ici — et non dans le widget — pour que le fichier du lecteur reste
/// **littéralement** vide de texte affichable.
const String kZNoteAudioTimeSeparator = ' / ';

/// Libellés **par défaut** du mini-lecteur, en français.
///
/// Ce sont des valeurs de repli : elles ne s'appliquent que lorsque ni
/// `ZcrudScope(labels:)` ni `ZcrudLocalizations` ne fournissent la clé.
const Map<String, String> kZNoteAudioDefaultLabels = <String, String>{
  kZNoteAudioPlayLabelKey: 'Lire l’audio de la note',
  kZNoteAudioPauseLabelKey: 'Mettre l’audio en pause',
  kZNoteAudioLoadingLabelKey: 'Préparation de l’audio…',
  kZNoteAudioFailedLabelKey: 'Audio indisponible',
  kZNoteAudioSeekLabelKey: 'Position dans l’audio',
  kZNoteAudioElapsedLabelKey: 'Écoulé',
};

/// Résout le libellé de [key] pour [context], selon la chaîne documentée.
///
/// Ne lève jamais. Une clé absente des trois niveaux rend [key] telle quelle.
String zResolveNoteAudioLabel(BuildContext context, String key) {
  final String? scoped = ZcrudScope.maybeOf(context)?.labels?.maybeResolve(key);
  if (scoped != null) return scoped;
  final String? localized = ZcrudLocalizations.maybeOf(context)?.maybeResolve(
    key,
  );
  if (localized != null) return localized;
  return kZNoteAudioDefaultLabels[key] ?? key;
}

/// Formate [duration] en horodatage neutre `m:ss` (ou `h:mm:ss` au-delà d'une
/// heure), sans dépendre d'une locale.
///
/// Une durée négative est ramenée à zéro : la tête de lecture d'un moteur ne
/// recule jamais avant le début, et un affichage négatif n'aurait aucun sens.
String zFormatNoteAudioTime(Duration duration) {
  final int totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String ss = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$ss';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
}

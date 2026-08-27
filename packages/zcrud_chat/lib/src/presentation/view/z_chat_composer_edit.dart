/// **L'unique site d'écriture** de la saisie ouvert par les gestes du composer.
///
/// ## Pourquoi un site unique
///
/// La saisie de l'utilisateur est ce qu'un composer peut lui faire perdre de
/// plus précieux. Chaque chemin qui y écrit est un endroit où du texte peut
/// disparaître sans qu'on l'ait voulu — et le défaut ne se voit qu'après.
///
/// Les gestes de contexte (rappel d'historique, insertion d'un candidat) ont
/// donc **un seul** verbe d'écriture, et il ne sait faire qu'une chose :
/// remplacer un intervalle, en **préservant** tout ce qui est en dehors.
/// Aucun appelant n'écrit `composer.text = …` ni `composer.clear()`.
library;

import 'package:flutter/widgets.dart';

/// Remplace `[start, end)` de la saisie par [text], et pose le curseur juste
/// après l'insertion.
///
/// Les bornes sont **ramenées** dans le texte réel plutôt que levées : une
/// correspondance calculée avant une frappe concurrente ne doit pas faire
/// tomber la saisie (invariant AD-10). Tout ce qui est hors de l'intervalle
/// est conservé à l'octet près.
void zChatReplaceComposerRange(
  TextEditingController composer, {
  required int start,
  required int end,
  required String text,
}) {
  final String courant = composer.text;
  final int fin = end.clamp(0, courant.length);
  final int debut = start.clamp(0, fin);
  final String neuf =
      courant.substring(0, debut) + text + courant.substring(fin);
  composer.value = TextEditingValue(
    text: neuf,
    selection: TextSelection.collapsed(offset: debut + text.length),
  );
}

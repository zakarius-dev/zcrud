/// `ZCrudTitles` — porte-titres de la surface d'édition, **défini dans
/// `zcrud_core`** et ré-exporté ici.
///
/// Le type a rejoint le cœur pour qu'un **onglet** (`ZListTab.titles`) puisse
/// porter ses propres intitulés : un écran segmenté par entité affiche alors
/// « Nouveau dossier » sur un onglet et « Nouvelle pièce » sur le suivant,
/// sans que le cœur ait à connaître l'écran assemblé.
///
/// Rien ne change pour les consommateurs : `ZCrudTitles` reste visible depuis
/// `package:zcrud_screen/zcrud_screen.dart`, à l'identique.
library;

export 'package:zcrud_core/zcrud_core.dart' show ZCrudTitles;

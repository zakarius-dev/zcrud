/// Détection de cycle sur un graphe orienté quelconque.
///
/// **Un graphe n'est pas un arbre.** Les compétences se relient dans les deux
/// sens, se recoupent, se répondent : la structure qui les porte doit admettre
/// des cycles. Seules certaines natures de lien ne le peuvent pas — rien ne
/// peut se précéder ni se contenir soi-même — et c'est à l'appelant de dire
/// lesquelles.
///
/// Ces primitives ne connaissent aucun type d'arête : elles reçoivent des
/// projections `from`/`to`. Elles servent aussi bien aux compétences qu'à
/// n'importe quel graphe qu'un hôte voudrait contrôler.
library;

import 'package:zcrud_core/domain.dart';

/// `Right(unit)` si le graphe décrit par [edges] est **acyclique**,
/// `Left(ZDomainFailure)` au premier cycle rencontré.
///
/// [fromIdOf] et [toIdOf] projettent les extrémités d'une arête. Une arête
/// dont une extrémité est vide est **ignorée** : elle ne relie rien.
///
/// Contrat :
/// - une boucle sur soi (`a → a`) est un cycle ;
/// - un graphe **non connexe** est parcouru en entier — un cycle dans une
///   composante isolée est trouvé comme les autres ;
/// - la terminaison est garantie par le marquage des sommets : chaque arête
///   est empruntée au plus une fois, y compris sur une entrée cyclique ;
/// - le message d'échec nomme le sommet où la remontée s'est refermée, pour
///   que l'appelant puisse pointer la donnée fautive.
ZResult<Unit> zDetectCycle<T>(
  Iterable<T> edges, {
  required String Function(T edge) fromIdOf,
  required String Function(T edge) toIdOf,
}) {
  final successors = <String, List<String>>{};
  for (final edge in edges) {
    final from = fromIdOf(edge);
    final to = toIdOf(edge);
    if (from.isEmpty || to.isEmpty) continue;
    (successors[from] ??= <String>[]).add(to);
    successors[to] ??= <String>[];
  }

  // Parcours en profondeur itératif à trois couleurs : blanc (absent),
  // gris (`enCours` — sur la pile courante), noir (`termines`). Une arête
  // vers un sommet gris ferme un cycle. L'itératif plutôt que le récursif :
  // un graphe importé peut être profond, et une pile native n'a pas de
  // borne qu'on maîtrise.
  final termines = <String>{};
  final enCours = <String>{};

  for (final depart in successors.keys) {
    if (termines.contains(depart)) continue;
    final pile = <_Etape>[_Etape(depart)];
    enCours.add(depart);
    while (pile.isNotEmpty) {
      final etape = pile.last;
      final voisins = successors[etape.sommet] ?? const <String>[];
      if (etape.index >= voisins.length) {
        enCours.remove(etape.sommet);
        termines.add(etape.sommet);
        pile.removeLast();
        continue;
      }
      final voisin = voisins[etape.index++];
      if (enCours.contains(voisin)) {
        return Left<ZFailure, Unit>(
          ZDomainFailure(
            'Cycle détecté dans le graphe : « ${etape.sommet} » '
            'revient sur « $voisin ».',
          ),
        );
      }
      if (termines.contains(voisin)) continue;
      enCours.add(voisin);
      pile.add(_Etape(voisin));
    }
  }
  return const Right<ZFailure, Unit>(unit);
}

/// Sommet en cours d'exploration et rang du prochain voisin à emprunter.
class _Etape {
  _Etape(this.sommet);

  final String sommet;
  int index = 0;
}

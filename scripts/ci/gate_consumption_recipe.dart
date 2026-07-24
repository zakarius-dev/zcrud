// Gate : la recette de consommation en dépendance git DOIT lister TOUS les
// paquets `zcrud_*` du dépôt.
//
// 🔴 Le défaut qu'il ferme (CR-LEX-40, constaté par lex après coup).
// En scindant `zcrud_export` (paquet léger `zcrud_export_pdf`), le handoff
// affirmait « la surface publique est inchangée : aucun hôte ne casse ». C'était
// **faux au SOLVEUR** : les arêtes internes `zcrud_*` sont `hosted`, donc tout
// nouveau paquet interne doit apparaître dans le `dependency_overrides` RACINE
// du consommateur. Sans cela, `pub` va le chercher sur pub.dev, où rien n'est
// publié :
//
//     could not find package `zcrud_export_pdf` at pub.dev
//
// Le raisonnement portait sur la surface d'API — exacte — et l'extrapolait à la
// RÉSOLUTION, qui n'avait pas été exécutée. Un gate ferme cette classe d'erreur
// une fois pour toutes : ajouter un paquet sans l'inscrire à la recette
// **échoue au merge**, au lieu d'être découvert par l'hôte.
import 'dart:io';

void main() {
  final recette = File('docs/private-git-consumption.md');
  if (!recette.existsSync()) {
    stderr.writeln('❌ docs/private-git-consumption.md introuvable.');
    exit(1);
  }
  final texte = recette.readAsStringSync();

  final paquets = Directory('packages')
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
      .where((n) => n.startsWith('zcrud_'))
      .toList()
    ..sort();

  if (paquets.isEmpty) {
    stderr.writeln('❌ aucun paquet trouvé — contrôle positif en échec, le '
        'gate se serait déclaré vert sans rien vérifier.');
    exit(1);
  }

  // ⚠️ On cherche une DÉCLARATION, pas une mention. Une première version de ce
  // gate testait `texte.contains(nom)` : elle passait au vert alors que le
  // paquet n'était cité que dans un paragraphe d'avertissement. Un gate qui
  // accepte de la prose ne garde rien. Le motif ci-dessous ne peut apparaître
  // que dans une entrée `dependency_overrides` réelle, et il discrimine
  // `zcrud_export` de `zcrud_export_pdf` (accolade fermante incluse).
  final absents = paquets
      .where((p) => !texte.contains('path: packages/$p }'))
      .toList();
  if (absents.isNotEmpty) {
    stderr.writeln(
      '❌ ${absents.length} paquet(s) absent(s) de la recette de consommation :\n'
      '   ${absents.join(', ')}\n\n'
      '   Un paquet `zcrud_*` non listé est un piège pour le consommateur : son\n'
      '   arête interne est `hosted`, donc il DOIT figurer dans le\n'
      '   `dependency_overrides` racine, sinon `pub` le cherche sur pub.dev.\n'
      '   Ajoutez-le à docs/private-git-consumption.md.',
    );
    exit(1);
  }

  stdout.writeln(
      'consumption-recipe OK — les ${paquets.length} paquets `zcrud_*` sont '
      'listés dans la recette de consommation.');
}

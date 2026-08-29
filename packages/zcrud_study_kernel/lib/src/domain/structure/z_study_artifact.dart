/// `ZStudyArtifact` — protocole partagé par tout ce qui **se rattache** à la
/// structure d'étude (dossiers, notes, cartes, documents…).
///
/// Ce n'est **pas une racine d'héritage** : aucune entité du noyau n'en
/// descend, et rien n'oblige un type à l'implémenter. C'est la forme commune
/// que prend le rattachement quand un type choisit de l'offrir — trois
/// accesseurs, une sémantique unique, et les mêmes primitives de portée
/// utilisables sur n'importe quel porteur.
///
/// Les trois accesseurs :
/// - [ownerRef] : qui possède l'artefact (un mandant, une organisation, un
///   groupe…). `null` = possession non déclarée (mode personnel) ;
/// - [primaryScopeRef] : la portée principale, celle qu'un affichage montre
///   quand il n'en montre qu'une. `null` = artefact hors portée ;
/// - [bindings] : tous les rattachements, y compris celui qui redit la portée
///   principale. Le noyau n'impose **aucune** cohérence entre les deux : un
///   artefact peut déclarer une portée principale absente de [bindings], et
///   inversement.
///
/// L'implémenteur reste libre de sa persistance : le protocole ne prescrit ni
/// clé, ni ordre, ni cardinalité.
library;

import 'z_study_binding.dart';
import 'z_study_constants.dart';
import 'z_study_ref.dart';

/// Protocole de rattachement d'un artefact à la structure d'étude.
mixin ZStudyArtifact {
  /// Propriétaire de l'artefact, `null` si non déclaré.
  ZStudyRef? get ownerRef;

  /// Portée principale de l'artefact, `null` si hors portée.
  ZStudyRef? get primaryScopeRef;

  /// Rattachements de l'artefact, jamais `null` (liste vide = aucun).
  List<ZStudyBinding> get bindings;

  /// Cibles distinctes de tous les rattachements, portée principale comprise
  /// si elle est déclarée, dans un ordre stable (portée principale d'abord,
  /// puis l'ordre de [bindings]).
  ///
  /// Les rattachements de propagation `none` sont **inclus** : ils désignent
  /// bien une cible, ils n'en étendent simplement pas la portée.
  List<ZStudyRef> get scopeRefs {
    final out = <ZStudyRef>[];
    final seen = <String>{};
    void add(ZStudyRef ref) {
      // Clé de dédoublonnage locale à cet appel : le préfixe de longueur
      // rend l'encodage injectif, donc sans collision possible entre un
      // type contenant le séparateur et un identifiant qui le contient.
      final key = '${ref.type.length}:${ref.type}:${ref.id}';
      if (seen.add(key)) out.add(ref);
    }

    final primary = primaryScopeRef;
    if (primary != null) add(primary);
    for (final binding in bindings) {
      add(binding.targetRef);
    }
    return List<ZStudyRef>.unmodifiable(out);
  }

  /// `true` si l'artefact est rattaché à [ref] — par sa portée principale ou
  /// par un rattachement dont la propagation n'est pas `none`.
  ///
  /// Si [at] est fourni, seuls les rattachements valides à cet instant
  /// comptent ; la portée principale, elle, n'est pas datée et compte
  /// toujours. Comparaison sur l'identité seule (`type` + `id`) :
  /// l'instantané d'affichage n'entre jamais dans la décision.
  bool isBoundTo(ZStudyRef ref, {DateTime? at}) {
    final primary = primaryScopeRef;
    if (primary != null && primary.sameTarget(ref)) return true;
    for (final binding in bindings) {
      if (binding.propagation == kZStudyPropagationNone) continue;
      if (!binding.targetRef.sameTarget(ref)) continue;
      if (at != null && !binding.isActiveAt(at)) continue;
      return true;
    }
    return false;
  }
}

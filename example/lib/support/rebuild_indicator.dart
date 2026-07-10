import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Journal GRANULAIRE des reconstructions par champ (démo SM-1, AC6).
///
/// Chaque compteur est incrémenté UNIQUEMENT depuis le `builder` d'un
/// [RebuildBadge] scellé sur la tranche `ValueListenable` d'UN champ (via
/// [ZFieldListenableBuilder]). Une frappe dans le champ A notifie SA tranche →
/// le badge de A rebuild (+1) ; les badges voisins, abonnés à d'AUTRES tranches,
/// ne bougent pas. Aucune écoute du `notifyListeners()` global du contrôleur :
/// l'indicateur SM-1 est lui-même granulaire (contrainte AD-2/SM-1).
class RebuildLog {
  final Map<String, int> _counts = <String, int>{};

  /// Incrémente et retourne le compteur du champ [name] (appelé au build du badge).
  int bump(String name) {
    final next = (_counts[name] ?? 0) + 1;
    _counts[name] = next;
    return next;
  }

  /// Compteur courant du champ [name] (0 si jamais construit). Lu par les tests.
  int countOf(String name) => _counts[name] ?? 0;
}

/// Badge affichant le nombre de reconstructions du champ [name]. Il n'écoute
/// QUE la tranche de [name] : c'est la preuve visuelle de la granularité SM-1.
class RebuildBadge extends StatelessWidget {
  /// Construit un badge scellé sur la tranche de [name].
  const RebuildBadge({
    required this.controller,
    required this.name,
    required this.log,
    super.key,
  });

  /// Contrôleur détenant la tranche observée.
  final ZFormController controller;

  /// Nom du champ dont on compte les reconstructions.
  final String name;

  /// Journal partagé des compteurs.
  final RebuildLog log;

  @override
  Widget build(BuildContext context) => ZFieldListenableBuilder(
        controller: controller,
        name: name,
        builder: (context, _, __) {
          final n = log.bump(name);
          final theme = Theme.of(context);
          return Semantics(
            label: 'Reconstructions du champ $name : $n',
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.autorenew, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'rebuilds($name): $n',
                    textAlign: TextAlign.start,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

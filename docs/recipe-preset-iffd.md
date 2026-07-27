# Recette : préréglage visuel décoratif

`example/lib/demos/iffd_visual_preset.dart` fournit une recette d'hôte stable :
elle déclare les cinq paires de dégradés light et les cinq paires dark du
parcours de démonstration, sans recopier leurs hex ici. Ces dégradés sont
décoratifs ; ils ne sont pas la charte navy/gold/teal de l'application source.
Les hex décoratifs de cette recette n'apparaissent que dans `example/`, jamais
dans un package sous `packages/`.

La recette associe aussi la célébration à un burst de cinq secondes, 50
particules, une fréquence de `0.03` et une gravité de `0.15`. Elle est injectée
avec les seuls barrels publics :

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';

ZcrudScope(
  theme: iffdVisualTheme,
  gradientResolver: iffdVisualGradientResolver,
  child: ZSessionSummaryView(
    celebrationSpec: iffdCelebrationSpec,
    // autres paramètres requis…
  ),
)
```

`zResolveGradient` consulte uniquement le `gradientResolver` fourni par l'hôte
et peut rendre `null`. `zDerivedGradientResolver` est donc un choix explicite,
pas un repli automatique : sans injection, le rendu historique à accent uni
reste intact.

Les constantes de la recette sont définies hors de `build`. Cette stabilité
d'identité est nécessaire : `ZcrudScope.updateShouldNotify` compare notamment
`theme` et `gradientResolver` avec `identical`.

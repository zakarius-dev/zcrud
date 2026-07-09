/// Oracle commun de parité de rebuild granulaire (E2-9, AD-15 / SM-1).
///
/// origine: matérialisation exécutable d'AD-15 (« un même controller fonctionne à
/// l'identique sous les quatre configs ») et de l'objectif produit n°1 (SM-1 :
/// taper N caractères ne reconstruit que le champ courant, zéro perte de focus).
/// Le corps de test est FIGÉ ; seul le `wrap` (le scope du binding, ou
/// `ZcrudScope` seul) varie — donc toute divergence de granularité entre configs
/// trahirait une réimplémentation de la réactivité par un binding (interdit).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Signature d'un enveloppeur de scope : reçoit l'arbre du formulaire et le
/// place SOUS le scope à tester (`ZcrudScope` seul, ou un scope de binding qui
/// monte le conteneur du manager puis un `ZcrudScope` porteur d'un resolver
/// manager-backed). C'est le SEUL point de variation entre les 4 configs.
typedef ZScopeWrap = Widget Function(Widget child);

/// Nombre de mutations de champ appliquées dans l'assertion de granularité.
///
/// ≥ 20 (AC6) : borne le « ×N » de `setValue`/saisie et garantit qu'aucune de ces
/// N mutations ne fuit vers le voisin ou le canal global.
const int kZParityMutationCount = 25;

/// Sonde consommatrice de `ZcrudScope.of(context)` — mesure la STABILITÉ du
/// resolver du scope (fermeture du trou de couverture MEDIUM-1, E2-9).
///
/// Établit, comme n'importe quel widget du cœur résolvant un seam applicatif,
/// une **dépendance InheritedWidget** au `ZcrudScope` (lecture de son
/// `resolver`) et incrémente [onBuild] à chaque (re)build. La sonde est
/// **instanciée une seule fois** par le test et repassée à l'identique à chaque
/// rebuild du parent : le framework court-circuite alors la reconstruction d'un
/// widget identique — elle ne peut donc reconstruire QUE si
/// `ZcrudScope.updateShouldNotify` renvoie `true`, ce qui trahit un binding qui
/// **recrée son resolver** (identité instable) à chaque `build()`.
class ZScopeConsumerProbe extends StatelessWidget {
  /// Construit la sonde. [onBuild] est appelé à chaque (re)build.
  const ZScopeConsumerProbe({required this.onBuild, super.key});

  /// Notifié à chaque (re)build de la sonde.
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    // Lit le resolver via ZcrudScope.of → enregistre la dépendance à l'
    // InheritedWidget (exactement comme un champ du cœur résolvant un seam).
    ZcrudScope.of(context).resolver;
    onBuild();
    return const SizedBox.shrink();
  }
}

/// Contrôleur espion : signale son `dispose()` (utilisé par les tests de cycle
/// de vie des bindings pour prouver l'absence de fuite ; réexporté ici car le
/// besoin est commun aux 3 bindings).
class ZDisposeSpyFormController extends ZFormController {
  /// Construit l'espion en déléguant à [ZFormController].
  ZDisposeSpyFormController({super.initialValues, super.visibleFields});

  /// Passe à `true` dès que [dispose] est invoqué (par le manager du binding).
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// Enregistre la SUITE de parité de rebuild granulaire sous le [label] donné,
/// l'arbre étant enveloppé par [wrap].
///
/// Invoquée 4× avec le MÊME corps et les MÊMES assertions ; seul [wrap] change :
/// - bare `ZcrudScope` (référence, aucun manager) ;
/// - `ZcrudGetScope` / `ZcrudRiverpodScope` / `ZcrudProviderScope`.
///
/// Assertions (identiques sous chaque config — preuve d'AD-15) :
/// 1. après montage, chaque champ est construit exactement une fois ;
/// 2. `setValue('a')` ×N ⇒ le compteur de `'a'` vaut `1 + N`, celui de `'b'`
///    reste `1` (zéro rebuild croisé), le compteur STRUCTUREL global reste `1`
///    (aucun `notifyListeners()` global — invariant SM-1) ;
/// 3. variante `EditableText` réelle : saisie caractère par caractère ⇒ focus
///    jamais perdu, curseur/sélection non réinitialisés, voisin jamais reconstruit.
void runZFormGranularRebuildParitySuite({
  required String label,
  required ZScopeWrap wrap,
}) {
  group('parité rebuild granulaire — $label', () {
    testWidgets(
      'setValue(a) ×$kZParityMutationCount : seul a reconstruit ; b et global inchangés',
      (tester) async {
        final controller = ZFormController(initialValues: {'a': '', 'b': ''});
        addTearDown(controller.dispose);
        var buildsA = 0;
        var buildsB = 0;
        var buildsGlobal = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: wrap(
              Column(
                children: [
                  ZFieldListenableBuilder(
                    controller: controller,
                    name: 'a',
                    builder: (context, value, child) {
                      buildsA++;
                      return Text('a=$value');
                    },
                  ),
                  ZFieldListenableBuilder(
                    controller: controller,
                    name: 'b',
                    builder: (context, value, child) {
                      buildsB++;
                      return Text('b=$value');
                    },
                  ),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, child) {
                      buildsGlobal++;
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        // Montage initial : un build par sous-arbre.
        expect(buildsA, 1, reason: '[$label] a construit une fois au montage');
        expect(buildsB, 1, reason: '[$label] b construit une fois au montage');
        expect(buildsGlobal, 1,
            reason: '[$label] canal global construit une fois au montage');

        for (var i = 0; i < kZParityMutationCount; i++) {
          controller.setValue('a', 'v$i');
          await tester.pump();
        }

        expect(buildsA, 1 + kZParityMutationCount,
            reason: '[$label] a reconstruit à chaque mutation (granularité)');
        expect(buildsB, 1,
            reason: '[$label] le champ voisin ne reconstruit JAMAIS');
        expect(buildsGlobal, 1,
            reason: '[$label] AUCUN rebuild global (0 notifyListeners) — SM-1');
      },
    );

    testWidgets(
      'EditableText réel : focus conservé, curseur non réinitialisé, voisin jamais reconstruit',
      (tester) async {
        final controller = ZFormController(initialValues: {'a': '', 'b': ''});
        final focusA = FocusNode();
        final editingA = TextEditingController();
        addTearDown(controller.dispose);
        addTearDown(focusA.dispose);
        addTearDown(editingA.dispose);
        var buildsB = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: wrap(
              Column(
                children: [
                  // Sens unique : onChanged → setValue (JAMAIS de ré-injection `.text=`).
                  ZFieldListenableBuilder(
                    controller: controller,
                    name: 'a',
                    builder: (context, value, child) => EditableText(
                      controller: editingA,
                      focusNode: focusA,
                      style: const TextStyle(),
                      cursorColor: const Color(0xFF000000),
                      backgroundCursorColor: const Color(0xFF000000),
                      onChanged: (v) => controller.setValue('a', v),
                    ),
                  ),
                  ZFieldListenableBuilder(
                    controller: controller,
                    name: 'b',
                    builder: (context, value, child) {
                      buildsB++;
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        focusA.requestFocus();
        await tester.pump();
        expect(focusA.hasFocus, isTrue, reason: '[$label] focus acquis');

        const text = 'bonjour';
        for (var i = 1; i <= text.length; i++) {
          await tester.enterText(
              find.byType(EditableText), text.substring(0, i));
          await tester.pump();
          expect(focusA.hasFocus, isTrue,
              reason: '[$label] focus jamais perdu pendant la saisie');
        }

        expect(controller.valueOf('a'), text,
            reason: '[$label] valeur propagée au controller');
        expect(buildsB, 1,
            reason: '[$label] le voisin ne reconstruit jamais pendant la saisie');
        expect(editingA.selection.baseOffset, text.length,
            reason: '[$label] curseur en fin de texte (non réinitialisé)');
        expect(focusA.hasFocus, isTrue,
            reason: '[$label] focus toujours présent en fin de saisie');
      },
    );

    testWidgets(
      'consommateur de ZcrudScope.of : $kZParityMutationCount rebuilds du scope '
      'sans recréer le resolver ⇒ 0 rebuild superflu (stabilité du resolver)',
      (tester) async {
        // Déclencheur de rebuild DU SCOPE (indépendant du ZFormController) : à
        // chaque tick, `wrap(...)` est reconstruit → le scope du binding
        // reconstruit. Un binding qui recrée son resolver à ce moment fait
        // renvoyer `true` à `ZcrudScope.updateShouldNotify` et sur-reconstruit
        // TOUS les consommateurs de `ZcrudScope.of` (asymétrie AD-15 interdite).
        final scopeTick = ValueNotifier<int>(0);
        addTearDown(scopeTick.dispose);
        var buildsScopeConsumer = 0;

        // Sonde MÉMOÏSÉE (identité stable) : ne reconstruit que via la
        // dépendance InheritedWidget de ZcrudScope, jamais par le rebuild parent.
        final probe = ZScopeConsumerProbe(
          onBuild: () => buildsScopeConsumer++,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ListenableBuilder(
              listenable: scopeTick,
              builder: (context, _) => wrap(probe),
            ),
          ),
        );

        expect(buildsScopeConsumer, 1,
            reason: '[$label] la sonde est construite une fois au montage');

        for (var i = 0; i < kZParityMutationCount; i++) {
          scopeTick.value++;
          await tester.pump();
        }

        expect(
          buildsScopeConsumer,
          1,
          reason: '[$label] le consommateur de ZcrudScope.of ne reconstruit '
              'JAMAIS malgré $kZParityMutationCount rebuilds du scope : le '
              'resolver garde une identité STABLE à travers les rebuilds '
              '(parité AD-15). Un binding qui recrée son resolver à chaque '
              'build ferait exploser ce compteur (1 + $kZParityMutationCount).',
        );
      },
    );
  });
}

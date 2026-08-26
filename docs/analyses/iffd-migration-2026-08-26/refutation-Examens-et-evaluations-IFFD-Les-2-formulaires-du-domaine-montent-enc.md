# Réfutation — « `presentFormEdition` sait déjà monter les 2 formulaires du domaine Examens (IFFD) »

> ⚠️ **Nom de fichier tronqué.** Le nom demandé (item complet + besoin) faisait 344 octets : il
> dépasse la limite POSIX de 255, et contenait deux `/` (« features/flashcards », « test/examen
> blanc ») impossibles dans un nom de fichier. Le contenu, lui, n'est pas tronqué.
>
> * **Item** : Examens et évaluations (IFFD) — 3 quartiers : examen-échéance (administration +
>   ExamModel + ZBackedExamRepository), épreuve (features/flashcards, runtime test/examen blanc),
>   correction (notation IA 1-5). 26 fichiers de production, 9 913 lignes ; 12 fichiers de tests,
>   3 364 lignes.
> * **Besoin** : les 2 formulaires du domaine montent encore leur Scaffold+AppBar+bouton
>   Enregistrer+ZEditionSubmitController à la main.

**Verdict : RÉFUTÉE.** Le canal existe, il est exporté, il est atteignable depuis IFFD, sa signature
est bien celle annoncée — et il **ne rend pas la même carte de sortie** que le code hôte qu'il est
censé remplacer. Le contrat observable des deux formulaires, figé par des gardes `testWidgets` de
l'hôte, casse. Trois autres écarts s'y ajoutent.

Périmètre lu : `zcrud_screen` / `zcrud_navigation` / `zcrud_core` (lecture seule stricte sur `iffd`).
Aucun test lancé, dans aucun dépôt. Code du socle lu **identique au tag `v3.21.0`** qu'IFFD épingle :
`git diff --quiet v3.21.0 -- present_form_edition.dart z_form_only.dart z_form_values.dart z_submission.dart` → RC=0.

---

## 1. Ce qui TIENT (vérifié sur disque, à ne pas jeter)

| Affirmation | Mesure |
|---|---|
| Le canal existe à l'endroit cité | `packages/zcrud_screen/lib/src/presentation/present_form_edition.dart`, 430 l. ; signature `:234`→`:257` (l'affirmation écrit `:234-256` ; `:256` = `String? formId,`, `:257` = `}) {`) |
| Corps cité | `ZFormOnlyController` `:274-279` ; `void submit()` `:285-297` — `controller.submit()` `:286`, `if (values == null) return;` `:289`, `markPristine()` `:295`, `Navigator.of(ctx).pop(values)` `:296`. L'affirmation écrit `:274-295` : borne basse juste, borne haute courte de 2 l. |
| « 22 params » | 1 positionnel (`context`) + **21 nommés** = 22. Compté ligne à ligne `:235-256`. ✅ |
| Exporté par le barrel | `packages/zcrud_screen/lib/zcrud_screen.dart:24` — `export 'src/presentation/present_form_edition.dart';` |
| Dépendance déclarée d'IFFD | `iffd/pubspec.yaml:524-528` (`zcrud_screen`, git, `ref: v3.21.0`) + `dependency_overrides` `:695-699`. **16** `import 'package:zcrud_screen…'` dans `iffd/lib`. |
| Précédent d'hôte | **16 appels** de `presentFormEdition(` dans **15 fichiers** de `iffd/lib` — chiffre exact de l'affirmation ✅. Le site cité, `auditeur_account_zcrud_edition.dart`, appelle en `:149` (la fonction englobante commence bien en `:143`). |
| Bornes hôte | `exam_zcrud_edition.dart:424-513` = `_ExamZcrudEditionScreenState`, **90 l.**, dont `build` `:479-513` = **35 l.** ✅ ; `test_exam_filter_zcrud_screen.dart:311-376` = `_TestExamFilterZcrudScreenState`, **66 l.** ✅ |
| Bonus annoncé | Réel : conteneur adaptatif (`zcrud_navigation/lib/src/presentation/present_edition.dart:155-271`) et garde d'abandon (`ZDiscardGuardHost.wrap`, `z_edition_scaffold.dart:388-401`). |

Rien de tout cela n'est en cause. Ce qui suit l'est.

---

## 2. RÉFUTATION n°1 (décisive) — la carte de sortie n'est pas la même, et 4 gardes de l'hôte rougissent

### La divergence, à l'octet

Les deux écrans hôtes soumettent par `ZEditionSubmitController` :

`zcrud_core/lib/src/presentation/edition/z_submission.dart:233`
```dart
final values = controller.values; // snapshot PUR (jamais Widget/callback).
```

`ZFormController.values` = **toutes les tranches**, sans filtre
(`zcrud_core/lib/src/presentation/z_form_controller.dart:269-273`) :
```dart
Map<String, Object?> get values => Map<String, Object?>.unmodifiable(
      <String, Object?>{ for (final e in _slices.entries) e.key: e.value.value },
    );
```
…et une tranche est créée pour **chaque clé** d'`initialValues`, champ déclaré ou pas
(`z_form_controller.dart:47-52`) :
```dart
initialValues.forEach((name, value) {
  _slices[name] = ValueNotifier<Object?>(value);
  _baseline[name] = value;
});
```

`presentFormEdition`, lui, rend `ZFormOnlyController.submit()` → `values` →
`zNormalizeFormValues` (`z_form_values.dart:253-284`), qui **n'itère que le catalogue déclaré** :
```dart
for (final field in fields) {              // :261
  if (field.readOnly) continue;            // :262
  if (!zIsFieldActive(field, …)) continue; // :263-270
  out[field.name] = zNormalizeFieldValue(field, controller.valueOf(field.name));
}
```

⇒ **toute clé semée qui n'est pas un `ZFieldSpec` déclaré, actif et non-readOnly disparaît de la
sortie.** Ce n'est pas une nuance de type : c'est une perte de clés.

### Ce que cela coûte, chiffré, sur les deux formulaires

**Examen** — 4 `ZFieldSpec` déclarés (`exam_zcrud_edition.dart:131`, `:141`, `:147`, `:156`) contre
**9 clés semées** (`test/w7j/exam_zcrud_test.dart:51-61`, `persistedExamMap()`) :

| Clé semée | Champ déclaré ? | Sort aujourd'hui | Sort via `presentFormEdition` |
|---|---|---|---|
| `title`, `folderId`, `date`, `enableReminder` | oui | ✅ | ✅ |
| `id` | **non** | ✅ | ❌ **perdue** |
| `accademicYear` | **non** | ✅ | ❌ **perdue** |
| `userId` | **non** | ✅ | ❌ **perdue** |
| `reminderDays` | **non** | ✅ | ❌ **perdue** |
| `reminderTime` | **non** | ✅ | ❌ **perdue** |

**5 clés perdues sur 9** — **6 sur 9** quand `accademicYear == null`, cas où `folderId` n'est pas
déclaré (`exam_zcrud_edition.dart:141`, sous condition `withFolder`) : l'examen **perd son dossier**
à l'enregistrement.

`id` perdue est le point dur : la carte est relue par `fromMap<ExamModel>` **hors de l'écran**, chez
l'appelant (`exames_dialogs.dart:116`) — une entité sans identité y devient une création, pas une
mise à jour.

**Filtre « Mise en place du test »** — 6 noms déclarés (`test_exam_filter_zcrud_screen.dart:117`,
`:147`, `:157`, `:165`, `:173`, `:181`), dont **3 sous condition** (`if (tagChoices.isNotEmpty)`
`:163`, `if (documentChoices.isNotEmpty)` `:171`, `if (noteChoices.isNotEmpty)` `:179`). Le contrat
figé exige en toutes lettres que **toute autre clé d'`initialData` traverse inchangée**
(`test/w7f/test_exam_filter_legacy_test.dart:22` et `:239`). Sources vides ⇒ `tagsIds` /
`documentsIds` / `notesIds` semées à `[]` ne sont plus déclarées ⇒ **3 clés supplémentaires perdues**.

### Les gardes de l'hôte qui rougissent

| Fichier:ligne | Assertion | Pourquoi elle casse |
|---|---|---|
| `test/w7j/exam_zcrud_test.dart:670-673` | `expect(out['userId'], 'user-1')`, `out['reminderDays'] is List<String>`, `out['reminderTime'] is null` | 3 clés non déclarées ⇒ absentes |
| `test/w7j/exam_zcrud_test.dart:682-695` | « une valeur SEMÉE et JAMAIS TOUCHÉE traverse INCHANGÉE » | idem |
| `test/w7f/test_exam_filter_zcrud_test.dart:335-346` | `initialData['extra'] = 'garde'` → `expect(h.submittedItem!['extra'], 'garde')` | clé arbitraire ⇒ absente |
| `test/w7f/test_exam_filter_legacy_test.dart:241-253` | jumelle legacy du même contrat | idem |

Ce sont des `testWidgets` qui **montent l'écran réel** (`pumpZcrudFilter`,
`test_exam_filter_zcrud_test.dart:73` ; `pumpZcrud`, `exam_zcrud_test.dart:112`) : elles mesurent
exactement la voie qu'on remplacerait.

### Le socle n'offre AUCUN échappatoire (greps négatifs MONTRÉS)

```
$ grep -n "passthrough\|passThrough\|mergeSeed\|rawValues\|includeUnknown\|extraKeys\|snapshot" \
    packages/zcrud_screen/lib/src/presentation/present_form_edition.dart
RC=1   (aucune occurrence)

$ grep -rn "controller.values" packages/zcrud_screen/lib packages/zcrud_navigation/lib
RC=1   (aucune occurrence)
```
Aucun paramètre de `presentFormEdition` ne rend le snapshot complet, et **aucune** fonction de
`zcrud_screen` / `zcrud_navigation` ne lit `controller.values`. La sortie est figée sur la projection
par catalogue. `bodyBuilder` n'y change rien : la fermeture est faite par la closure `submit()`
interne (`:285-297`), que l'appelant ne peut pas remplacer tant que le chrome porte le bouton
(`readOnly: true` le supprime — au prix de rendre **tous** les champs non éditables).

### Remède possible, et pourquoi il ne sauve pas l'affirmation

L'hôte peut re-fusionner au site d'appel : `adaptExamZcrudOutput({...seed, ...?values}, seed: seed)`.
C'est **du code hôte AJOUTÉ**, pas supprimé — l'inverse du gain annoncé. Et ce n'est pas iso : un
champ **masqué par condition** ou **readOnly** reprendrait sa valeur *semée* au lieu de sa tranche
courante, là où `controller.values` rend la tranche. L'affirmation présente une couverture **totale**
là où la couverture est **partielle et conditionnée à une compensation hôte**.

---

## 3. RÉFUTATION n°2 — `formController` et `initialValues` s'EXCLUENT ; le cycle de vie ne part pas

L'affirmation s'appuie sur `formController` pour conclure « ⇒ `ExamTitleDeriver` SURVIT ». Le relais
existe bien (`present_form_edition.dart:277`, `form: formController`). Mais son effet de bord n'est
pas dit :

`packages/zcrud_screen/lib/src/presentation/z_form_only.dart:56-58` (dartdoc) et `:68-73` (code) :
```dart
  : _ownsForm = form == null,
    form = form ??
        ZFormController(
          initialValues: initialValues,
          visibleFields: <String>[for (final f in fields) f.name],
        );
```
Quand `formController` est fourni : **`initialValues` est ignoré en silence**, et `visibleFields`
n'est **pas** posé par le socle. Deux des 22 paramètres vantés sont donc **mutuellement exclusifs**,
et l'hôte doit continuer de faire lui-même ce que fait aujourd'hui
`exam_zcrud_edition.dart:440-443` :
```dart
_controller = ZFormController(
  initialValues: _seed,
  visibleFields: <String>[for (final f in _fields) f.name],
);
```
…plus l'`attach()` du deriver (`:446-451`), son `detach()` (`:471`) et le `dispose()` (`:473`). Pour
le formulaire d'examen, **le cycle de vie du contrôleur reste chez l'hôte** : seuls le
`Scaffold`+`AppBar`+bouton et le `ZEditionSubmitController` disparaissent.

---

## 4. RÉFUTATION n°3 — le formulaire d'examen n'est montable que sous `bodyBuilder`, jamais dit

`ExamZcrudEditionScreen.build` enveloppe **obligatoirement** le formulaire dans
`IffdZcrudScope(relationSources: _registry, …)` (`exam_zcrud_edition.dart:487-489`), commentaire à
l'appui `:480-486` : « Un écran hors scope perd tout cela EN SILENCE ». Or `presentFormEdition` ouvre
une **route** : le corps est construit sous le `Navigator`, pas sous le sous-arbre appelant — un
`InheritedWidget` posé par l'appelant n'y est pas visible.

Le patron qui règle cela est déjà celui de l'hôte : `bodyBuilder:` + `IffdZcrudScope` + `ZFormOnly`
— **16 occurrences de `bodyBuilder` dans 13 fichiers** de `iffd/lib` (mesuré ; p. ex.
`auditeur_iffd_zcrud_edition.dart:211-218`). La migration est donc possible, mais :
* elle passe obligatoirement par `bodyBuilder`, que le « gain » ne mentionne pas ;
* sous `bodyBuilder`, **`sections` et `layout` sont ignorés** (préséance AD-10, documentée
  `present_form_edition.dart:169-176`, appliquée `:325-327`) ;
* le corps redevient à la charge de l'hôte, ce qui annule une partie de la simplification annoncée.

---

## 5. RÉFUTATION n°4 — le chrome n'est pas iso-rendu, et les 2 harnais tapent un icône qui n'existe plus

| Point | Hôte aujourd'hui | Socle |
|---|---|---|
| Bouton enregistrer | `IconButton(icon: Icon(Icons.save_outlined))` (`exam_zcrud_edition.dart:504`, `test_exam_filter_zcrud_screen.dart:367`) | **action textuelle** `Text(label)` — `z_edition_scaffold.dart:551-556`, libellé `label(context,'save')` (`:335`) |
| En-tête, mode `page` | `AppBar` fixe | `SliverAppBar(floating: true, pinned: false)` — **se replie au scroll** (`z_edition_scaffold.dart:174-176`) |
| Action d'abandon | absente | `leading` toujours monté (`z_edition_scaffold.dart:182-187`) |

Conséquence **mesurée** : les deux harnais soumettent par
`await tester.tap(find.byIcon(Icons.save_outlined));`
(`test/w7f/test_exam_filter_zcrud_test.dart:51`, `test/w7j/exam_zcrud_test.dart:90`).
Les deux suites cassent **au geste**, indépendamment du contrat de sortie — et les deux écrans
disparaissant en tant que widgets, `find.byType(TestExamFilterZcrudScreen)`
(`test/w7f/test_exam_filter_routing_test.dart:69`, `:87`, `:97`) tombe aussi.

Ce n'est pas un défaut du socle ; c'est le coût que l'affirmation omet en annonçant un gain net.

---

## 6. Ce que le gain vaut réellement

Retirable : `build` de l'examen (`:479-513`, 35 l.) + son `ZEditionSubmitController` (`:428`,
`:455-467`, `:472`, `:477` ≈ 16 l.) ; `build` du filtre (`:352-376`, 25 l.) + son
`ZEditionSubmitController` (≈ 14 l.). Soit **≈ 90 l.**

À rajouter : `bodyBuilder` + `IffdZcrudScope` pour l'examen (≈ 8 l.), re-fusion de graine aux deux
sites (≈ 4 l.). **Gain net ≈ 75-80 l.**, pas ~100 — et **à condition** d'accepter la compensation de
la §2, plus la réécriture des harnais des suites `w7f` et `w7j`.

---

## 7. Verdict

**RÉFUTÉE.** Le canal est réel, exporté, atteignable, et fait ce que sa dartdoc annonce. Il ne couvre
pas le besoin réel : il rend une **projection du catalogue déclaré**, là où les deux formulaires du
domaine Examens rendent un **snapshot complet des tranches**, contrat figé et asserté par 4 gardes
`testWidgets` de l'hôte. Le socle n'offre aucun paramètre pour cela (greps négatifs §2). Migrable
oui, **à l'identique non**.

### CR socle suggérée (hors périmètre de cette réfutation)

Un paramètre de `presentFormEdition` du genre `passthroughSeed: bool` / `valuesProjection:` —
rendant `{...initialValues, ...zNormalizeFormValues(...)}` — fermerait l'écart pour tout hôte qui
édite un sous-ensemble de champs d'une entité persistée. Le motif n'a rien d'IFFD : il vaut pour
n'importe quel formulaire partiel.

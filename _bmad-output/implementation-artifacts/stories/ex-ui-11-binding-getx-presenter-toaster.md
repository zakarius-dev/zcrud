---
baseline_commit: 9e405a0
---

# Story EX-UI.11 : [BINDING] Présentateur GetX (`ZGetFormPresenter`) + toaster GetX (`ZGetToaster`) dans `zcrud_get` — DERNIÈRE story de l'epic EX-UI

Status: review

- **Clé sprint-status** : `ex-ui-11-binding-getx-presenter-toaster`
- **Epic** : EX-UI (infrastructure UI transverse — responsive / navigation / ui-kit) — **DERNIÈRE story de l'epic** (clôt le workstream binding, débloque la rétrospective EX-UI).
- **Taille** : **M** (package DÉJÀ livré `zcrud_get` : 2 fichiers source **NEUFS** disjoints implémentant 2 ports externes en idiome GetX + éventuel helper seam + **2 lignes/blocs d'`export`** dans le barrel + **2 arêtes de dépendance AJOUTÉES** au `pubspec.yaml` ; 0 codegen, 0 entité persistée, **0 écriture de `zcrud_core`/`zcrud_navigation`/`zcrud_ui_kit`**).
- **Parallélisation** : **SÉQUENTIELLE — en aval d'EX-UI.6 (port `ZFormPresenter` + `ZAdaptivePresenter` + seam `ZFormPresenterScope`, livrés) ET EX-UI.8 (port `ZToaster` + `ZScaffoldMessengerToaster` + seam `ZToasterScope`, livrés)**. Aucun autre workstream en vol (P1/P2/P3 terminés). N'écrit qu'`zcrud_get` ; aucune contention de `zcrud_core`.
- **Package écrit (disjoint)** : `packages/zcrud_get/` **UNIQUEMENT** (2 fichiers source neufs + tests neufs + `export`s barrel + 2 deps au `pubspec.yaml`). ⛔ **N'ÉCRIT PAS** `zcrud_core`, `zcrud_navigation`, `zcrud_ui_kit`, `zcrud_responsive` (tous LECTURE SEULE — impls externes qui prouvent la pluggabilité **sans modifier** les packages purs). ⛔ **NE TOUCHE PAS** `pubspec.yaml` racine, `melos.yaml` (les 2 packages consommés sont déjà déclarés au `workspace:`).
- **AD delta** : **AD-30** (les présentateurs **manager** — GetX `Get.to`/`Get.bottomSheet`/`Get.dialog` — implémentent le **même port** `ZFormPresenter` mais vivent **exclusivement** dans le binding `zcrud_get`, jamais dans `zcrud_navigation` qui n'importe **ni `get` ni `go_router`** ; la résolution du présentateur effectif passe par le **seam** `ZFormPresenterScope`, défaut = présentateur pur-Flutter `ZAdaptivePresenter`) + **AD-32** (le **toast est un port** `ZToaster` défini dans `zcrud_ui_kit` ; l'**implémentation concrète GetX snackbar** vit dans le binding, substituée via le seam `ZToasterScope`) + **AD-15** (code manager-spécifique `get` **exclusivement** ici, jamais dans un package pur). **AD hérités** : **AD-4** (ports **`abstract interface class`, jamais `sealed`** ⇒ implémentables **hors package** ; ces 2 impls externes le **prouvent**), **AD-1/NFR-U1** (acyclique, `CORE OUT=0` : les 2 arêtes AJOUTÉES `zcrud_get → zcrud_navigation` et `zcrud_get → zcrud_ui_kit` sont **SORTANTES depuis le binding-puits**, jamais entrantes au cœur ; `graph_proof.py` reste **ACYCLIQUE**), **AD-13/NFR-U4/U5** (toaster GetX : couleur **dérivée du `ColorScheme` injecté** jamais hex, **icône + texte** couleur jamais seul canal, action a11y, directionnel), **AD-10/NFR-U10** (défauts sûrs : `switch` exhaustif sur les 3 modes / 4 sévérités, jamais de throw), **NFR-U7** (**enums > booléens** : consomme `ZEditionPresentation` + `ZToastSeverity`, n'introduit **aucun** `bool` multi-état), **NFR-U11** (aucun `@ZcrudModel` ⇒ `melos run generate` no-op, gate `codegen-distribution` non concernée), **AD-2/NFR-U2** (le binding réutilise la réactivité du cœur, ne la réimplémente pas ; seul `get` est autorisé, et seulement ici).

---

## Story

**As a** développeur d'une app GetX (DODLP, IFFD),
**I want** une **implémentation GetX du port `ZFormPresenter`** (`ZGetFormPresenter` : `page → Get.to(fullscreenDialog:)` / `sheet → Get.bottomSheet` / `dialog → Get.dialog`) **et du port `ZToaster`** (`ZGetToaster` : `Get.snackbar` mappé sur `ZToastSeverity`), livrées dans `zcrud_get` et **substituables aux défauts pur-Flutter via les seams existants** (`ZFormPresenterScope` / `ZToasterScope`),
**so that** je (1) **prouve concrètement que les ports EX-UI.6/EX-UI.8 sont réellement pluggables hors de leur package** (AD-4/AD-30/NFR-U9), (2) offre aux apps GetX un présentateur/toaster de **référence** en idiome natif du manager, **tout le code `get` restant confiné au binding** (AD-15), sans jamais toucher les packages purs — **clôturant l'epic EX-UI**.

---

## Contexte — vérifié sur disque (pas sur la seule foi de l'épic)

### Ports à implémenter (LECTURE SEULE — signatures EXACTES relevées sur disque)

Vérifié dans les sources livrées :

**Port présentateur** — `packages/zcrud_navigation/lib/src/presentation/z_form_presenter.dart` :
```dart
abstract interface class ZFormPresenter {
  Future<T?> present<T>(
    BuildContext context, {
    required WidgetBuilder builder,          // contenu OPAQUE, form-agnostique (jamais inspecté)
    required ZEditionPresentation mode,      // enum { page, sheet, dialog } — jamais un bool
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
  });
}
```
- `enum ZEditionPresentation { page, sheet, dialog }` (`z_edition_presentation.dart`, valeurs camelCase, domaine pur).
- Défaut pur-Flutter **livré** : `ZAdaptivePresenter` (`z_adaptive_presenter.dart`) — table de mapping de référence à **répliquer en idiome GetX** :

  | `mode`   | Défaut pur-Flutter (`ZAdaptivePresenter`)                    | ⇒ Idiome GetX (`ZGetFormPresenter`)                       |
  |----------|-------------------------------------------------------------|-----------------------------------------------------------|
  | `page`   | `Navigator.push(MaterialPageRoute(fullscreenDialog: true))` | `Get.to<T>(() => …, fullscreenDialog: true)`              |
  | `sheet`  | `showModalBottomSheet(isScrollControlled: true, …)`         | `Get.bottomSheet<T>(…, isScrollControlled: true)`         |
  | `dialog` | `showDialog(→ Dialog + ConstrainedBox aux tailles max)`     | `Get.dialog<T>(Dialog + ConstrainedBox, barrierDismissible:)` |

- Seam de substitution **livré** : `ZFormPresenterScope` (`z_form_presenter_scope.dart`, `InheritedWidget` local) — `ZFormPresenterScope.of(context)` retourne le présentateur injecté, **défaut sûr** `const ZAdaptivePresenter()` (jamais de throw). Substitution : `ZFormPresenterScope(presenter: ZGetFormPresenter(), child: …)`.

**Port toaster** — `packages/zcrud_ui_kit/lib/src/domain/z_toaster.dart` :
```dart
abstract interface class ZToaster {
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,   // enum { info, success, warning, error }
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,                            // action affichée SSI actionLabel != null && onAction != null
  });
}
```
- `enum ZToastSeverity { info, success, warning, error }` (`z_toast_severity.dart`, camelCase, UI-pur non persisté).
- Défaut pur-Flutter **livré** : `ZScaffoldMessengerToaster` (`z_scaffold_messenger_toaster.dart`) — table couleur/icône de référence à **répliquer** (couleur **dérivée du `ColorScheme`, JAMAIS de hex**, dark-mode-aware) :

  | Sévérité  | Fond (rôle `ColorScheme`)                              | Avant-plan (texte/icône) | Icône                      |
  |-----------|--------------------------------------------------------|--------------------------|----------------------------|
  | `info`    | `scheme.primary`                                       | `scheme.onPrimary`       | `Icons.info_outline`       |
  | `success` | `scheme.tertiary`                                      | `scheme.onTertiary`      | `Icons.check_circle_outline` |
  | `warning` | `scheme.secondary`                                     | `scheme.onSecondary`     | `Icons.warning_amber_outlined` |
  | `error`   | `ZcrudTheme.of(context).errorColor ?? scheme.error`    | `scheme.onError`         | `Icons.error_outline`      |

- Seam de substitution **livré** : `ZToasterScope` (`z_toaster_scope.dart`, `InheritedWidget` local) + helper `zToast(context, …)` — `ZToasterScope.of(context)` retourne le toaster injecté, **défaut sûr** `const ZScaffoldMessengerToaster()`. Substitution : `ZToasterScope(toaster: ZGetToaster(), child: …)`.

### État réel du package `zcrud_get` (vérifié sur disque)

- `packages/zcrud_get/pubspec.yaml` : `version: 0.2.0`, `resolution: workspace`, `publish_to: none`, `environment.sdk: ^3.12.2`. `dependencies` actuelles = **`zcrud_core: ^0.2.0` + `zcrud_study_kernel: ^0.2.0` + `flutter` + `get: ^4.7.2` + `get_it: ^8.0.3` + `reflectable: ^5.2.3`** ; `dev_dependencies` = `flutter_test` + `binding_conformance: ^0.0.1`.
  ⇒ EX-UI.11 **AJOUTE au bloc `dependencies`** : `zcrud_navigation: ^0.2.0` **et** `zcrud_ui_kit: ^0.2.0` (2 arêtes `zcrud_*` SORTANTES). `get` est **déjà** présent (aucun nouveau paquet manager). Actualiser le commentaire d'en-tête (invariant deps) pour mentionner les 2 nouvelles arêtes UI et la préservation de `CORE OUT=0`.
- Barrel `packages/zcrud_get/lib/zcrud_get.dart` (`library;`) exporte déjà (LECTURE, à ÉTENDRE, ne rien retirer/réordonner) : `src/data/codecs/reflectable_codec.dart`, `src/presentation/{z_get_api,z_get_resolver,zcrud_get_scope}.dart`, `src/study/{z_session_config_key,z_study_get}.dart`. ⇒ EX-UI.11 **ajoute** les `export` des 2 (ou 3 avec le helper seam) fichiers neufs + un **paragraphe dartdoc EX-UI.11**. ⛔ Ne PAS ré-exporter `zcrud_core`/`zcrud_navigation`/`zcrud_ui_kit`.
- **Layout des fichiers** : la métadonnée épic suggère `lib/src/ui/`, **mais** la structure réelle du package place la présentation sous **`lib/src/presentation/`** (`z_get_api`, `z_get_resolver`, `zcrud_get_scope` y vivent). ⇒ **placer les fichiers neufs sous `lib/src/presentation/`** pour la cohérence intra-package (décision D6 ; le dev peut créer `lib/src/ui/` s'il juge la séparation « pont UI » utile, mais par défaut : `presentation/`).
- Les 2 packages consommés sont **déjà déclarés** au bloc `workspace:` du `pubspec.yaml` racine ⇒ **rien à ajouter à la racine** ; `melos list` **inchangé** (aucun nouveau package).

### Patrons internes DÉJÀ établis (binding `zcrud_get`, à réutiliser — cohérence stricte)

Vérifié dans les sources livrées :
- **`get` autorisé UNIQUEMENT ici** (`zcrud_get_scope.dart` importe `package:get/get.dart`, `package:get_it/get_it.dart`) — c'est l'unique lieu du monorepo où `get` peut être importé (AD-15). Les impls neuves suivent ce patron.
- **Le binding est un PUITS** (fan-in) : ses arêtes `zcrud_*` sont **sortantes** (`→ zcrud_core`, `→ zcrud_study_kernel`) ; jamais un package pur ne dépend de `zcrud_get`. Les 2 arêtes UI ajoutées respectent ce sens.
- **Réutilisation, jamais réimplémentation** (`ZcrudGetScope` réutilise `ZFormController` du cœur, AD-2) : ici, on **réutilise** les tables de mapping couleur/mode des défauts pur-Flutter (mêmes rôles `ColorScheme`, mêmes icônes) — on ne réinvente pas la sémantique, on la **transpose** à l'idiome GetX.
- **Seam via `InheritedWidget`** : le binding branche déjà le cœur via `ZcrudScope`/`ZGetResolver`. Ici, la substitution passe par les seams **déjà fournis** par les packages UI (`ZFormPresenterScope`, `ZToasterScope`) — **inutile d'inventer un nouveau seam**, il suffit de les monter (éventuellement via un helper de convenance `ZcrudGetUiScope` qui monte les deux d'un coup).

### Best-of-breed à NEUTRALISER (LECTURE SEULE — apps hors périmètre, ne PAS copier tel quel)

- **dodlp** `lib/modules/data_crud/forms_utils.dart` `showPushedDialog<T>()` (~331-394) — 3 branches GetX : `if (fullscreenDialog) Get.to<T>(() => builder, fullscreenDialog:…)` / `if (dialog) Get.dialog<T>(…, barrierDismissible: true, barrierColor: …)` / sinon `Get.bottomSheet<T>(…)` avec `maxHeight`/`maxWidth` calculés depuis `Get.height`/`Get.width`. **À neutraliser** : (1) ⛔ les **2 booléens ad hoc** `dialog`/`fullscreenDialog` → l'**enum `ZEditionPresentation`** (le mapping des 3 branches est **conservé**, c'est exactement l'idiome GetX cible) ; (2) ⛔ `Get.height`/`Get.width` → `MediaQuery.sizeOf(context)` (le port reçoit `context`) ; (3) ⛔ la détection heuristique `isEditionScreen` (`builder is DynamicEditionScreen`) → **supprimée** : le port est **form-agnostique**, `builder` est opaque (jamais inspecté) ; (4) ⛔ `barrierColor: Colors.black…` en dur → laisser le défaut GetX / dérivé du thème (jamais de hex introduit). **Conserver** : la logique des 3 surfaces GetX — c'est la substance best-of-breed légitime de cette story.
- **iffd** `lib/src/utils/functions/forms_utils.dart:631-739` — même `showPushedDialog<T>()` (variante avec `showDialog(context: Get.context!, …)` déjà à moitié neutralisée). ⛔ `Get.context!` → utiliser le `context` **reçu** en paramètre (jamais `Get.context!`, cf. dartdoc du port). Même neutralisation des booléens → enum.
- **dodlp** `ToastService` (GetX, `Get.snackbar` — méthodes ad hoc `showErrorToast`/`showSuccessToast`/`showInfoToast`) — **À neutraliser** : (1) ⛔ les **3 méthodes ad hoc** + tout `bool isError` → l'**enum `ZToastSeverity`** (une seule méthode `show(...)`, sévérité en paramètre) ; (2) ⛔ toute **couleur hex** en dur du service → couleur **dérivée du `ColorScheme`** selon la table de référence (jamais hex). **Conserver** : le recours à `Get.snackbar` comme surface d'affichage (idiome GetX natif, c'est le point de la story).

### ⛔ Hors périmètre (défini ailleurs / différé — NE PAS implémenter ici)

- **DW-EXUI-2 — présentateur/toaster go_router (`zcrud_riverpod`)** : **DÉFÉRÉ** hors EX-UI (`go_router` pas encore dépendance de `zcrud_riverpod`, à pinner en session d'intégration lex_douane). EX-UI.11 ne livre **que** l'impl **GetX** (`get` déjà présent, risque nul).
- **DW-EXUI-1 — adoption in-place dans les apps** (remplacement réel des ~79 call-sites `showPushedDialog` / du `ToastService` dans dodlp/iffd) : **sessions dédiées**, hors monorepo. EX-UI.11 ne livre que les impls génériques de port dans le binding — **aucune modification d'app**.
- **Toute écriture des packages purs** : `zcrud_navigation`, `zcrud_ui_kit`, `zcrud_responsive`, `zcrud_core` restent **STRICTEMENT inchangés** (les impls externes prouvent la pluggabilité **sans** les modifier — c'est l'exigence AD-4/NFR-U9).
- **Politique de choix du mode** (`ZPresentationPolicy`, breakpoint → mode) : appartient à EX-UI.5/EX-UI.6 (`zcrud_navigation`). `ZGetFormPresenter` **exécute** un mode déjà choisi, il ne le **calcule** pas.
- **Câblage réel dans un `GetMaterialApp` d'app** : l'app monte les seams ; ici on livre les impls + éventuel helper + les tests qui **prouvent** la substitution.

---

## ⚠️ Décisions de conception — CHAQUE prescription confrontée au code

> Le dev ne rejoue pas ces décisions, mais **doit** les remettre en cause si le code réel les contredit (et le dire dans les Completion Notes).

### D1 — Deux arêtes `zcrud_*` AJOUTÉES, acycliques, `CORE OUT=0` intact (AD-1/NFR-U1)

`pubspec.yaml` de `zcrud_get` : **ajouter** `zcrud_navigation: ^0.2.0` + `zcrud_ui_kit: ^0.2.0` au bloc `dependencies`. Ce sont **2 arêtes SORTANTES** depuis le binding-puits (`zcrud_get → zcrud_navigation`, `zcrud_get → zcrud_ui_kit`) ; `zcrud_navigation` tire transitivement `zcrud_responsive` (donc `zcrud_get → zcrud_responsive` **transitivement**, cf. AC3). Aucune de ces arêtes n'entre dans `zcrud_core` ⇒ **`CORE OUT=0` inchangé** (le cœur ne dépend toujours de rien) et le graphe reste **ACYCLIQUE** (un puits ne crée jamais de cycle). `get`/`get_it`/`reflectable`/`flutter` ne sont **pas** des `zcrud_*` → non comptés par `graph_proof.py`. Confirmer par `python3 scripts/dev/graph_proof.py` (AC5).

### D2 — `ZGetFormPresenter implements ZFormPresenter` : signature IDENTIQUE, 3 branches GetX (AD-30/AD-4)

Fichier `lib/src/presentation/z_get_form_presenter.dart`. `class ZGetFormPresenter implements ZFormPresenter` (`const` ctor si sans état). **La signature `present<T>` est reprise à l'identique** du port (mêmes paramètres nommés, mêmes défauts) — sinon l'`@override` ne compile pas (preuve de conformité par le compilateur). `switch (mode)` **exhaustif** sur les 3 valeurs (jamais de `default`, jamais de throw — AD-10) :

```dart
@override
Future<T?> present<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  required ZEditionPresentation mode,
  double? maxWidth,
  double? maxHeight,
  bool useSafeArea = true,
  bool barrierDismissible = true,
}) {
  switch (mode) {
    case ZEditionPresentation.page:
      // Route pleine page — tailles max IGNORÉES (occupe l'écran), comme ZAdaptivePresenter.
      return Get.to<T>(() => Builder(builder: builder), fullscreenDialog: true);
    case ZEditionPresentation.sheet:
      final screen = MediaQuery.sizeOf(context);           // ⛔ jamais Get.height/Get.width
      final effectiveMaxHeight = maxHeight ?? screen.height * 0.9;
      return Get.bottomSheet<T>(
        _constrained(builder, maxWidth: maxWidth, maxHeight: effectiveMaxHeight, useSafeArea: useSafeArea),
        isScrollControlled: true,
      );
    case ZEditionPresentation.dialog:
      final screen = MediaQuery.sizeOf(context);
      final effectiveMaxWidth = maxWidth ?? (screen.width < 560 ? screen.width : 560);
      return Get.dialog<T>(
        Dialog(child: _constrained(builder, maxWidth: effectiveMaxWidth, maxHeight: maxHeight, useSafeArea: useSafeArea)),
        barrierDismissible: barrierDismissible,
      );
  }
}
```

- **Contexte du `builder`** : `Get.to`/`Get.bottomSheet`/`Get.dialog` prennent un `Widget` (ou `() => Widget`) **sans** transmettre le `context` d'appel. Envelopper `builder` dans un **`Builder(builder: builder)`** fournit un `BuildContext` frais et **honore la signature `WidgetBuilder`** sans inspecter le contenu (form-agnostique).
- **`context` reçu**, jamais `Get.context!` : la mesure `MediaQuery.sizeOf(context)` utilise le `context` **du paramètre** (le port l'exige ; dartdoc du port interdit `Get.context!`/`Get.width`).
- **`_constrained(...)`** : helper privé enveloppant `Builder(builder:)` d'un `ConstrainedBox(BoxConstraints(maxWidth, maxHeight))` + `SafeArea` si `useSafeArea` — **réplique l'intention** de `ZAdaptivePresenter` (mêmes bornes : dialog ≤ 560 dp, sheet ≤ 90 % hauteur). Constantes de défaut alignées sur `ZAdaptivePresenter` (documentées, non hex).
- **`useSafeArea`/`barrierDismissible`/`maxWidth`/`maxHeight`** : tous **honorés** (pas ignorés) — sauf tailles max en mode `page` (route pleine, comme le défaut). ⛔ **Aucun** paramètre positionnel `bool`, **aucun** flag ad hoc réintroduit.
- **Valeur de retour** : renvoyer **directement** le `Future<T?>` de la primitive GetX (elle complète sur `Get.back(result:)` / fermeture de la surface), comme le défaut renvoie celui de `Navigator.push`/`showDialog`/`showModalBottomSheet`.
- ⛔ **Aucune** détection `runtimeType`/`is …EditionScreen` (form-agnostique) ; ⛔ **aucun** `barrierColor` hex en dur.

### D3 — `ZGetToaster implements ZToaster` : `Get.snackbar` mappé sur `ZToastSeverity` (AD-32/AD-13)

Fichier `lib/src/presentation/z_get_toaster.dart`. `class ZGetToaster implements ZToaster` (`const` ctor). `show(...)` **signature identique** au port (`@override`). `switch (severity)` **exhaustif** sur les 4 valeurs (jamais de throw). Résolution `(Color background, Color foreground, IconData icon)` par la **table de référence** (mêmes rôles `ColorScheme` que `ZScaffoldMessengerToaster`, `error` réutilisant `ZcrudTheme.of(context).errorColor ?? scheme.error` — donc **import `zcrud_core`** pour `ZcrudTheme`, arête `→ zcrud_core` **déjà existante**, aucune nouvelle arête). Puis :

```dart
Get.snackbar(
  '',                                   // pas de titre métier en dur — message porté par messageText
  message,
  messageText: Row(children: [Icon(icon, color: foreground), SizedBox(width: 12), Expanded(child: Text(message, textAlign: TextAlign.start, style: TextStyle(color: foreground)))]),
  backgroundColor: background,          // ⛔ jamais hex — dérivé du ColorScheme injecté
  colorText: foreground,
  icon: Icon(icon, color: foreground),  // canal NON-couleur (icône) + texte — couleur jamais seul canal
  duration: duration ?? const Duration(seconds: 4),
  mainButton: (actionLabel != null && onAction != null)
      ? TextButton(onPressed: onAction, child: Text(actionLabel, style: TextStyle(color: foreground)))
      : null,
  snackPosition: SnackPosition.BOTTOM,  // cohérent avec la SnackBar par défaut ; documenté
);
```

- **Couleur TOUJOURS dérivée du `ColorScheme` courant** (`Theme.of(context).colorScheme`), **jamais un littéral hex** (AD-13/NFR-U5, dark-mode-aware). Table identique au défaut pur-Flutter (info→primary, success→tertiary, warning→secondary, error→errorColor).
- **Sévérité perceptible sans la couleur** : `icon` + texte (WCAG/AD-13/NFR-U4 — couleur jamais seul canal), à l'image de `ZScaffoldMessengerToaster` (`Icon` + `Semantics(liveRegion:)`). Pour l'a11y, envelopper le contenu d'un `Semantics(liveRegion: true, label: message)` si praticable sous `Get.snackbar` (le widget de contenu est libre).
- **Action facultative** : affichée **SSI** `actionLabel != null && onAction != null` (mêmes conditions que le port), via `mainButton` (`TextButton`).
- **Directionnel** : `TextAlign.start`, `EdgeInsetsDirectional` si padding — ⛔ jamais `TextAlign.left/right` ni `EdgeInsets.only(left/right)`.
- ⛔ **Aucune** méthode `showError`/`showSuccess`/`showInfo` réintroduite (une seule `show`, sévérité en enum).

### D4 — Câblage au seam : réutiliser `ZFormPresenterScope`/`ZToasterScope` (AD-6/AD-15)

La substitution ne requiert **aucun nouveau seam** : les packages UI fournissent déjà `ZFormPresenterScope(presenter:)` et `ZToasterScope(toaster:)`. Une app GetX substitue les défauts en montant :
```dart
ZFormPresenterScope(
  presenter: const ZGetFormPresenter(),
  child: ZToasterScope(
    toaster: const ZGetToaster(),
    child: monApp,
  ),
);
```
**Helper de convenance (recommandé, optionnel)** : `ZcrudGetUiScope({required Widget child, ZFormPresenter presenter = const ZGetFormPresenter(), ZToaster toaster = const ZGetToaster()})` — `StatelessWidget` qui **monte les deux `InheritedWidget` d'un coup** (imbriqués), pour qu'une app GetX câble « en une ligne ». À livrer **seulement s'il reste trivial** (sinon consigner en extension future — la substitution directe via les 2 scopes suffit à satisfaire l'AC3). ⛔ **Ne PAS** créer un seam concurrent ni modifier `ZcrudScope` du cœur (D8/`CORE OUT=0`). Si le helper est livré, l'exporter au barrel.

### D5 — Défauts sûrs, jamais de throw (AD-10/NFR-U10)

- `present` : `switch` **total** sur `ZEditionPresentation` (3 cas) — jamais de `default`/throw.
- `show` : `switch` **total** sur `ZToastSeverity` (4 cas) — jamais de throw ; `duration == null` → défaut sûr (4 s) ; action absente → pas de bouton (pas d'erreur).
- Impls `const` sans état (aucune référence manager conservée en champ — le port est de **présentation**, il reçoit `context` à l'appel).

### D6 — Barrel = SEULE API publique ; fichiers sous `presentation/` ; clôture EX-UI.11 (AD-15)

`lib/zcrud_get.dart` **ajoute** : `export 'src/presentation/z_get_form_presenter.dart';` + `export 'src/presentation/z_get_toaster.dart';` (+ `export 'src/presentation/zcrud_get_ui_scope.dart';` si le helper D4 est livré) + un **paragraphe dartdoc EX-UI.11** (présentateur + toaster GetX, impls des ports EX-UI.6/8, confinement `get`). ⛔ Ne PAS ré-exporter `zcrud_core`/`zcrud_navigation`/`zcrud_ui_kit` ; ⛔ ne PAS retirer/réordonner les exports existants. Fichiers neufs sous `lib/src/presentation/` (cohérence intra-package, cf. Contexte).

### D7 — Aucun codegen, aucune sérialisation (NFR-U11)

`ZGetFormPresenter`, `ZGetToaster`, helper seam sont **UI-pur / impls de port**, **non persistés** → **aucun `@ZcrudModel`/`@JsonSerializable`/`part`** ⇒ pas de `*.g.dart`, `melos run generate` **no-op** pour `zcrud_get`, gate `codegen-distribution` **non concernée**. Confirmer le no-op (AC5).

### D8 — Approche de test GetX : `Get.testMode` + `GetMaterialApp` (AC-tests)

Tester `get` **exige un harnais Get** (les primitives `Get.to`/`Get.dialog`/`Get.bottomSheet`/`Get.snackbar` s'appuient sur le `Navigator`/l'overlay de `GetMaterialApp` et l'état global `Get`). Approche **documentée et imposée** :
- Poser **`Get.testMode = true;`** en tête de chaque test GetX (évite certains asserts de navigation en test).
- Envelopper dans un **`GetMaterialApp`** (fournit le `Navigator`/overlay GetX), avec un `Builder`/bouton déclencheur qui capture un **vrai `BuildContext`** puis appelle `presenter.present(context, …)` / `toaster.show(context, …)`.
- **Présentateur** : après `tester.tap(bouton)` + `pumpAndSettle`, asserter la surface ouverte — `page` : le widget de contenu poussé est trouvé (`find.byKey(contenuKey)`) et `Get.currentRoute`/pile changée ; `dialog` : contenu trouvé **dans un `Dialog`** (`find.ancestor(of: contenu, matching: find.byType(Dialog))`) ; `sheet` : contenu trouvé, `Get.isBottomSheetOpen == true`. Vérifier que le `Future<T?>` complète avec la valeur passée à `Get.back(result: v)` (fermeture programmatique).
- **Toaster** : après déclenchement, `pump()` (laisser l'overlay s'insérer) puis asserter par sévérité — `find.text(message)`, présence de l'**icône attendue** (`find.byIcon(Icons.error_outline)` etc.), `Get.isSnackbarOpen == true`, et **couleur de fond = rôle `ColorScheme` attendu** (récupérer le `GetSnackBar`/container et comparer `backgroundColor` à `scheme.primary`/`tertiary`/… du thème de test — **jamais** un hex). Action : fournir `actionLabel`+`onAction`, taper le bouton, vérifier le callback ; puis un cas **sans** action → pas de bouton.
- **Substitution au seam (AC3)** : monter `ZFormPresenterScope(presenter: const ZGetFormPresenter(), child: …)` et asserter `identical(ZFormPresenterScope.of(context), <l'instance>)` **est de type `ZGetFormPresenter`** (le défaut `ZAdaptivePresenter` est **écarté**) ; idem `ZToasterScope.of(context) is ZGetToaster`. Prouve la pluggabilité **sans** modifier les packages purs (AD-4/NFR-U9).
- **Confinement `get` (AC1/AC4)** : test **statique** scannant les **directives `import`** des sources de `zcrud_navigation/lib/` **et** `zcrud_ui_kit/lib/` → **aucune** ne contient `package:get/` (ni `go_router`) ; scanner que `package:get/` **n'apparaît que** dans `zcrud_get/lib/` (AD-15). Scanner les `import` uniquement (pas la prose dartdoc, dette EX-UI.9/EX-UI.10).

---

## Acceptance Criteria

### AC1 — `ZGetFormPresenter implements ZFormPresenter` exécute les 3 modes en idiome GetX (AD-30/AD-4/AD-15)
**Given** le port `ZFormPresenter` de `zcrud_navigation` (LECTURE SEULE),
**When** `ZGetFormPresenter` l'implémente,
**Then** sa méthode `present<T>` reprend la **signature exacte** du port (compile en `@override`) et, selon `ZEditionPresentation`, exécute `page → Get.to<T>(…, fullscreenDialog: true)` / `sheet → Get.bottomSheet<T>(…, isScrollControlled: true)` / `dialog → Get.dialog<T>(Dialog + ConstrainedBox, barrierDismissible:)` via un `switch` **exhaustif** (jamais de throw), en mesurant l'écran par **`MediaQuery.sizeOf(context)`** (⛔ jamais `Get.width`/`Get.height`/`Get.context!`), **sans inspecter** le `builder` (form-agnostique, `Builder(builder:)`),
**And** le fichier vit **exclusivement dans `zcrud_get`** — `zcrud_navigation/lib/` ne contient **aucun** `import 'package:get/…'` (ni `go_router`).

### AC2 — `ZGetToaster implements ZToaster` mappe `ZToastSeverity` sur `Get.snackbar`, couleur dérivée jamais seul canal (AD-32/AD-13/NFR-U4/U5)
**Given** le port `ZToaster` de `zcrud_ui_kit` (LECTURE SEULE),
**When** `ZGetToaster` l'implémente,
**Then** `show(...)` reprend la **signature exacte** du port et, pour chacune des **4 sévérités** (`info`/`success`/`warning`/`error`), appelle `Get.snackbar` avec un `backgroundColor` **dérivé du `ColorScheme` injecté** (`primary`/`tertiary`/`secondary`/`errorColor??error`, **jamais un hex**), une **icône** dédiée **+** le texte (la couleur **n'est jamais le seul canal**), un `colorText` lisible, et une action (`mainButton`) affichée **SSI** `actionLabel != null && onAction != null`, via un `switch` **exhaustif** (jamais de throw),
**And** le rendu est **directionnel** (`TextAlign.start`) et n'introduit **aucune** méthode ad hoc `showError`/`showSuccess`/`showInfo` ni `bool isError` (NFR-U7).

### AC3 — Substitution au seam prouvée, sans modifier les packages purs (AD-6/AD-4/NFR-U9)
**Given** les 2 impls + les seams existants `ZFormPresenterScope`/`ZToasterScope`,
**When** on monte `ZFormPresenterScope(presenter: const ZGetFormPresenter(), child: …)` et `ZToasterScope(toaster: const ZGetToaster(), child: …)` (ou le helper `ZcrudGetUiScope` s'il est livré),
**Then** `ZFormPresenterScope.of(context)` **est un `ZGetFormPresenter`** (le défaut `ZAdaptivePresenter` est **écarté**) et `ZToasterScope.of(context)` **est un `ZGetToaster`** (défaut `ZScaffoldMessengerToaster` écarté),
**And** `zcrud_navigation` **et** `zcrud_ui_kit` restent **STRICTEMENT inchangés** (les impls externes prouvent la pluggabilité **sans** toucher les packages purs — les ports non-`sealed` compilent hors de leur package).

### AC4 — `get` confiné au binding ; graphe acyclique, `CORE OUT=0`, 2 arêtes ajoutées (AD-15/AD-1/NFR-U1/U2)
**Given** l'extension `zcrud_get`,
**When** on inspecte les imports et le graphe,
**Then** `package:get/` **n'apparaît que** dans `zcrud_get/lib/` (jamais dans `zcrud_navigation`/`zcrud_ui_kit`/`zcrud_responsive`/`zcrud_core`), le `pubspec.yaml` de `zcrud_get` ajoute **exactement** `zcrud_navigation: ^0.2.0` + `zcrud_ui_kit: ^0.2.0` (2 arêtes `zcrud_*` **SORTANTES** depuis le binding-puits ; `zcrud_responsive` tiré **transitivement**),
**And** `graph_proof.py` reste **ACYCLIQUE** et **`CORE OUT=0`** (aucune arête n'entre dans `zcrud_core` ; le puits ne crée aucun cycle).

### AC5 — Vérif verte, gates verts, barrel étendu, codegen no-op, epic clôturé (NFR-U1/U11/U8)
**Given** l'extension `zcrud_get`,
**When** on rejoue les gates,
**Then** `melos run generate` est **no-op** pour `zcrud_get` (aucun `@ZcrudModel` — NFR-U11, gate `codegen-distribution` non concernée) ; `dart analyze packages/zcrud_get` **RC=0** ; `flutter test` (package) **tous verts** (existants + neufs) ; `gate:secrets` vert (zéro secret — AD-12/NFR-U8) ; `melos list` **inchangé** (aucun nouveau package) ; le barrel `lib/zcrud_get.dart` **exporte** les fichiers neufs + dartdoc EX-UI.11 **sans** retirer/réordonner l'existant ni ré-exporter un package pur,
**And** `melos run analyze` **ET** `melos run verify` **repo-wide** (délégués au gate de commit d'epic de l'orchestrateur) restent **verts** — EX-UI.11 étant la **dernière** story de l'epic EX-UI (débloque la rétrospective).

---

## Tasks / Subtasks

- [x] **T0 — Dépendances** (AC4, D1) — `packages/zcrud_get/pubspec.yaml`
  - [x] T0.1 Ajouter au bloc `dependencies` : `zcrud_navigation: ^0.2.0` et `zcrud_ui_kit: ^0.2.0`. Mettre à jour le commentaire d'en-tête (invariant deps : 2 arêtes UI sortantes ; `CORE OUT=0` préservé ; `get` toujours l'unique idiome manager). `dart pub get` RC=0.

- [x] **T1 — Présentateur GetX** (AC1, D2, D5) — `lib/src/presentation/z_get_form_presenter.dart`
  - [x] T1.1 `class ZGetFormPresenter implements ZFormPresenter` (`const` ctor). `@override present<T>` signature identique au port ; `switch (mode)` exhaustif → `Get.to`(page, fullscreenDialog) / `Get.bottomSheet`(sheet, isScrollControlled) / `Get.dialog`(dialog, Dialog+ConstrainedBox, barrierDismissible).
  - [x] T1.2 `MediaQuery.sizeOf(context)` pour les bornes sheet/dialog (⛔ jamais `Get.*`) ; helper privé `_constrained` (`Builder`+`ConstrainedBox`+`SafeArea?`) ; renvoie le `Future<T?>` de la primitive GetX. Dartdoc : form-agnostique, `context` reçu, bornes alignées sur `ZAdaptivePresenter`, aucun `runtimeType`/`barrierColor` hex.

- [x] **T2 — Toaster GetX** (AC2, D3, D5) — `lib/src/presentation/z_get_toaster.dart`
  - [x] T2.1 `class ZGetToaster implements ZToaster` (`const` ctor). `@override show(...)` signature identique ; `switch (severity)` exhaustif → `(background, foreground, icon)` dérivés du `ColorScheme` (table de référence ; `error` → `ZcrudTheme.of(context).errorColor ?? scheme.error`).
  - [x] T2.2 `Get.snackbar(message, backgroundColor:, colorText:, icon:, messageText: Row(icône+texte), duration:, mainButton: action SSI actionLabel&&onAction)`. Directionnel (`TextAlign.start`), a11y (`Semantics(liveRegion:)` si praticable), ⛔ jamais hex, ⛔ jamais de méthode ad hoc.

- [x] **T3 — Helper seam (optionnel, si trivial)** (AC3, D4) — `lib/src/presentation/zcrud_get_ui_scope.dart`
  - [x] T3.1 `class ZcrudGetUiScope extends StatelessWidget` : monte `ZFormPresenterScope(presenter: …, child: ZToasterScope(toaster: …, child: child))`. Défauts `const ZGetFormPresenter()` / `const ZGetToaster()`. ⛔ Ne PAS créer un seam concurrent ni modifier `ZcrudScope`. Sinon : consigner en extension future (substitution directe via les 2 scopes suffit à AC3).

- [x] **T4 — Barrel** (AC5, D6) — `lib/zcrud_get.dart`
  - [x] T4.1 Ajouter `export 'src/presentation/z_get_form_presenter.dart';` + `export 'src/presentation/z_get_toaster.dart';` (+ export du helper si livré) + paragraphe dartdoc EX-UI.11. Exports existants intacts ; pas de ré-export de package pur.

- [x] **T5 — Tests** (AC1..AC4) — `packages/zcrud_get/test/`
  - [x] T5.1 `test/z_get_form_presenter_test.dart` (widget, harnais GetX D8) : `Get.testMode=true` + `GetMaterialApp` ; les 3 modes ouvrent la bonne surface (`page`→route poussée + contenu ; `dialog`→contenu dans `Dialog` + `Get.isDialogOpen` ; `sheet`→`Get.isBottomSheetOpen`) ; `Future` complète sur `Get.back(result:)` ; `MediaQuery.sizeOf` utilisé (pas `Get.*`).
  - [x] T5.2 `test/z_get_toaster_test.dart` (widget, harnais GetX) : les **4 sévérités** → `Get.snackbar` avec `backgroundColor` = rôle `ColorScheme` attendu (jamais hex) + icône attendue (`find.byIcon`) + texte ; action affichée SSI `actionLabel`+`onAction` (tap → callback) ; cas sans action → pas de bouton.
  - [x] T5.3 `test/ex_ui_11_seam_test.dart` (widget) : `ZFormPresenterScope.of(context) is ZGetFormPresenter` (défaut écarté) ; `ZToasterScope.of(context) is ZGetToaster` (défaut écarté) ; (si livré) `ZcrudGetUiScope` monte les deux.
  - [x] T5.4 `test/ex_ui_11_confinement_test.dart` (statique) : scan des directives `import` de `zcrud_navigation/lib/` **et** `zcrud_ui_kit/lib/` → **aucun** `package:get/` ni `go_router` ; `package:get/` présent uniquement dans `zcrud_get/lib/` (scan imports only, hors prose). Robuste au cwd (racine repo ou package).

- [x] **T6 — Vérif verte + graphe** (AC4, AC5)
  - [x] T6.1 `dart pub get` RC=0 ; `dart run melos run generate` → SUCCESS (no-op : 0 `.g.dart` ajouté dans `zcrud_get`).
  - [x] T6.2 `dart analyze packages/zcrud_get` RC=0 (No issues found). `melos analyze`/`verify` **repo-wide** → orchestrateur (gate de commit d'epic).
  - [x] T6.3 `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK** (2 arêtes sortantes ajoutées `zcrud_get → zcrud_navigation`/`zcrud_ui_kit` ; `zcrud_responsive` transitif).
  - [x] T6.4 `flutter test` (package) → tous verts (existants + neufs EX-UI.11).

---

## Dev Notes

### Fichiers à créer / modifier (chemins cibles)

| Fichier | Nature |
|---|---|
| `packages/zcrud_get/pubspec.yaml` | **UPDATE** — +2 deps (`zcrud_navigation`, `zcrud_ui_kit`) + commentaire invariant |
| `packages/zcrud_get/lib/src/presentation/z_get_form_presenter.dart` | NEW — `ZGetFormPresenter implements ZFormPresenter` (3 modes GetX) |
| `packages/zcrud_get/lib/src/presentation/z_get_toaster.dart` | NEW — `ZGetToaster implements ZToaster` (`Get.snackbar` × 4 sévérités) |
| `packages/zcrud_get/lib/src/presentation/zcrud_get_ui_scope.dart` | NEW (optionnel D4) — helper montant les 2 seams |
| `packages/zcrud_get/lib/zcrud_get.dart` | **UPDATE** — +2/3 `export` + dartdoc EX-UI.11 |
| `packages/zcrud_get/test/z_get_form_presenter_test.dart` | NEW — widget (3 modes, harnais `GetMaterialApp`) |
| `packages/zcrud_get/test/z_get_toaster_test.dart` | NEW — widget (4 sévérités, couleurs/icônes/action) |
| `packages/zcrud_get/test/ex_ui_11_seam_test.dart` | NEW — substitution au seam |
| `packages/zcrud_get/test/ex_ui_11_confinement_test.dart` | NEW — statique (`get` confiné au binding) |

⛔ **NE PAS TOUCHER** : `packages/zcrud_navigation/**`, `packages/zcrud_ui_kit/**`, `packages/zcrud_responsive/**`, `packages/zcrud_core/**` (tous LECTURE SEULE), `pubspec.yaml` racine, `melos.yaml`, les fichiers `zcrud_get` existants (`z_get_api`, `z_get_resolver`, `zcrud_get_scope`, `reflectable_codec`, study).

### Références de code (LECTURE SEULE)

- **Ports à implémenter** : `packages/zcrud_navigation/lib/src/presentation/z_form_presenter.dart` (signature `present<T>`) + `z_form_presenter_scope.dart` (seam) + `z_adaptive_presenter.dart` (table de mapping de référence) + `src/domain/z_edition_presentation.dart` (enum). `packages/zcrud_ui_kit/lib/src/domain/z_toaster.dart` + `z_toast_severity.dart` + `src/presentation/z_toaster_scope.dart` (seam + `zToast`) + `z_scaffold_messenger_toaster.dart` (table couleur/icône de référence).
- **Binding `zcrud_get`** (cohérence à suivre) : `lib/src/presentation/zcrud_get_scope.dart` (patron `import 'package:get/get.dart';` autorisé ici seulement ; seam via `InheritedWidget`/`ZcrudScope` ; réutilisation du cœur) ; barrel `lib/zcrud_get.dart` (blocs d'export).
- **best-of-breed (LECTURE SEULE, à neutraliser)** : dodlp `lib/modules/data_crud/forms_utils.dart` `showPushedDialog` (~331-394) + `ToastService` ; iffd `lib/src/utils/functions/forms_utils.dart:631-739`. (`explore/dodlp.md` § Cap.1, `explore/iffd.md` § Cap.2.)

### Invariants AD applicables (rappel ciblé)

- **AD-30** : présentateur **manager GetX** implémente le port `ZFormPresenter`, vit **exclusivement** dans `zcrud_get` ; `zcrud_navigation` n'importe **ni `get` ni `go_router`** ; résolution via seam `ZFormPresenterScope`, défaut = pur-Flutter.
- **AD-32** : toast = **port** `ZToaster` (défini dans `zcrud_ui_kit`) ; impl concrète **GetX snackbar** dans le binding, substituée via `ZToasterScope`.
- **AD-15 / NFR-U2** : code manager `get` **exclusivement** dans `zcrud_get` (jamais dans un package pur).
- **AD-4 / NFR-U9** : ports **`abstract interface class`, jamais `sealed`** ⇒ implémentables **hors package** ; ces 2 impls externes le **prouvent** sans modifier les packages purs.
- **AD-1 / NFR-U1** : 2 arêtes **sortantes** ajoutées depuis le puits binding ; `CORE OUT=0` intact ; `graph_proof.py` **ACYCLIQUE**.
- **AD-13 / NFR-U4/U5** : toaster GetX — couleur **dérivée du `ColorScheme` injecté** (jamais hex), **icône + texte** (couleur jamais seul canal), action a11y, directionnel (`TextAlign.start`).
- **AD-10 / NFR-U10** : `switch` exhaustif (3 modes / 4 sévérités), jamais de throw ; défauts sûrs (durée, action absente).
- **NFR-U7 (enums > booléens)** : consomme `ZEditionPresentation` + `ZToastSeverity` ; **aucun** `bool` multi-état ni méthode ad hoc réintroduits.
- **NFR-U11** : pas de codegen — confirmer le no-op de `melos run generate`. **AD-12/NFR-U8** : zéro secret.

### Project Structure Notes

- Fichiers neufs sous `lib/src/presentation/` (la métadonnée épic dit `lib/src/ui/` mais le package place déjà toute la présentation sous `presentation/` — cohérence intra-package retenue ; cf. D6).
- Barrel = seule API publique ; EX-UI.11 **clôt l'epic EX-UI** (dernière story). Après `done` + vérif verte, l'orchestrateur enchaîne la **rétrospective EX-UI** (P1/P2/P3 + binding terminés), puis le commit unique de fin d'epic (incluant les `*.g.dart` régénérés le cas échéant — ici aucun).

### Dépendances aval (ce que cette story débloque)

`done` sur EX-UI.11 **complète le binding GetX de l'epic EX-UI** ⇒ **rétrospective EX-UI** consommable. `ZGetFormPresenter`/`ZGetToaster` servent l'intégration DODLP (E7) : l'app GetX monte `ZFormPresenterScope`/`ZToasterScope` (ou `ZcrudGetUiScope`) pour brancher les surfaces natives GetX derrière les ports zcrud, remplaçant à terme `showPushedDialog`/`ToastService` (DW-EXUI-1, sessions dédiées).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-ui-2026-07-16/epics.md` § Story EX-UI.11 (l.408-434 : `ZGetFormPresenter` via `Get.to(fullscreenDialog:)`/`Get.bottomSheet`/`Get.dialog` même signature/`ZEditionPresentation` ; `ZGetToaster` mappe `ZToastSeverity` sur snackbars GetX couleur injectée jamais seul canal ; substitution au seam sans modifier les packages purs ; graphe puits acyclique CORE OUT=0 ; tests 3 modes sous `GetMaterialApp` + 4 sévérités + `zcrud_navigation`/`zcrud_ui_kit` sans `get`), § Capability→Story Map (l.72 : présentateur+toaster GetX → `zcrud_get`, AD-30/AD-15), § Séquencement (l.99-101, l.462-464 : EX-UI.11 séquentielle en aval de 6+8, GetX planifié / go_router déféré), § NFR-U1/U2/U4/U5/U7/U9/U10/U11, § Deferred DW-EXUI-1/DW-EXUI-2 (l.442-446)]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-ui-2026-07-16/architecture.md` § AD-30 (l.94-97 : présentateurs manager GetX/go_router implémentent le même port `ZFormPresenter` mais vivent exclusivement dans les bindings ; `zcrud_navigation` n'importe ni `get` ni `go_router` ; port pluggable jamais `sealed` ; résolution par seam, défaut pur-Flutter), § AD-32 (l.104-107 : toast = port `ZToaster` défini dans `zcrud_ui_kit`, impls concrètes GetX snackbar dans les bindings via seam), § AD-2/AD-15 (l.56 : aucun manager dans les 3 packages, code GetX confiné à `zcrud_get`), § binds AD-4/AD-6 (ports pluggables, seams défaut sûr)]
- [Source: ports à implémenter (LECTURE SEULE) — `packages/zcrud_navigation/lib/src/presentation/{z_form_presenter.dart (signature `present<T>` exacte), z_form_presenter_scope.dart (seam défaut `ZAdaptivePresenter`), z_adaptive_presenter.dart (table page/sheet/dialog)}` + `src/domain/z_edition_presentation.dart` (enum page/sheet/dialog) ; `packages/zcrud_ui_kit/lib/src/domain/{z_toaster.dart (signature `show` exacte), z_toast_severity.dart (info/success/warning/error)}` + `src/presentation/{z_toaster_scope.dart (seam + zToast), z_scaffold_messenger_toaster.dart (table couleur/icône ColorScheme)}`]
- [Source: `packages/zcrud_get/{pubspec.yaml (deps `zcrud_core`+`zcrud_study_kernel`+`flutter`+`get`+`get_it`+`reflectable` ; version 0.2.0), lib/zcrud_get.dart (barrel blocs export), lib/src/presentation/zcrud_get_scope.dart (patron import `get` autorisé ici seul, seam InheritedWidget)}` (état livré du binding)]
- [Source: `_bmad-output/implementation-artifacts/stories/ex-ui-10-alphabet-index-transitions.md` (story modèle : structure header/ACs/Tasks/Dev Notes, no-op codegen, `graph_proof`, barrel séquentiel, scan d'`import` vs prose pour la dette de confinement, neutralisation best-of-breed)]
- [Source: best-of-breed LECTURE SEULE — dodlp `lib/modules/data_crud/forms_utils.dart` `showPushedDialog` (3 branches `Get.to`/`Get.dialog`/`Get.bottomSheet`, `Get.height/width`, heuristique `isEditionScreen` → neutraliser) + `ToastService` (`Get.snackbar`, méthodes ad hoc → enum sévérité) ; iffd `lib/src/utils/functions/forms_utils.dart:631-739` (`Get.context!` → context reçu) (`explore/dodlp.md` § Cap.1/2, `explore/iffd.md` § Cap.2)]
- [Source: `CLAUDE.md` — Key Don'ts (AD-2/AD-15 : jamais de manager hors binding, `get`/`get_it` idiomes exclusifs de `zcrud_get` ; AD-13 : primitives directionnelles, `Semantics`, couleur jamais seul canal, thème injecté ; naming préfixe `Z` ; gates CI secrets/anti-reflectable/codegen ; enums > booléens ; commit unique fin d'epic incluant `*.g.dart` régénérés)]

---

## Stratégie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Widget (harnais GetX)** | `present(page)`→route poussée+contenu ; `present(dialog)`→contenu dans `Dialog`+`Get.isDialogOpen` ; `present(sheet)`→`Get.isBottomSheetOpen` ; `Future` complète sur `Get.back(result:)` ; `MediaQuery.sizeOf` (pas `Get.*`) | AC1 |
| **Widget (harnais GetX)** | 4 sévérités → `Get.snackbar` `backgroundColor` = rôle `ColorScheme` (jamais hex) + icône attendue + texte ; action SSI `actionLabel`+`onAction` (tap→callback) ; sans action→pas de bouton | AC2 |
| **Widget** | `ZFormPresenterScope.of(context) is ZGetFormPresenter` (défaut écarté) ; `ZToasterScope.of(context) is ZGetToaster` (défaut écarté) ; (si livré) `ZcrudGetUiScope` monte les deux | AC3 |
| **Statique** | scan `import` de `zcrud_navigation/lib/` + `zcrud_ui_kit/lib/` → **aucun** `package:get/`/`go_router` ; `package:get/` uniquement dans `zcrud_get/lib/` (imports only, hors prose) | AC1, AC4 |
| **Graphe / gates** | `graph_proof` ACYCLIQUE / CORE OUT=0 (2 arêtes sortantes `→ zcrud_navigation`/`zcrud_ui_kit`, `zcrud_responsive` transitif) ; `dart analyze` RC=0 ; `generate` no-op ; barrel +exports ; `melos list` inchangé ; `gate:secrets` vert | AC4, AC5 |

**Approche de test GetX (imposée, cf. D8)** : `Get.testMode = true` en tête ; `GetMaterialApp` fournit le `Navigator`/overlay ; un `Builder`/bouton capture un **vrai `BuildContext`** et appelle `present`/`show` ; assertions via l'état global `Get` (`Get.isDialogOpen`/`isBottomSheetOpen`/`isSnackbarOpen`, `Get.currentRoute`) + `find.byType(Dialog)`/`find.byIcon(...)`/`find.text(...)` ; couleurs comparées aux **rôles `ColorScheme`** du thème de test (jamais un hex).

**Definition of Done** : AC1→AC5 verts · `pubspec.yaml` de `zcrud_get` : **+2 deps** `zcrud_navigation`/`zcrud_ui_kit` (2 arêtes sortantes, `CORE OUT=0` intact, `graph_proof` ACYCLIQUE) · `ZGetFormPresenter implements ZFormPresenter` (3 modes GetX, signature exacte, `switch` exhaustif, `MediaQuery.sizeOf` jamais `Get.*`/`Get.context!`, form-agnostique) · `ZGetToaster implements ZToaster` (`Get.snackbar` × 4 sévérités, couleur dérivée `ColorScheme` jamais hex, icône+texte jamais seul canal, action a11y, directionnel, aucune méthode ad hoc) · substitution au seam **prouvée** (`ZFormPresenterScope`/`ZToasterScope`, défauts pur-Flutter écartés) **sans modifier** `zcrud_navigation`/`zcrud_ui_kit` · `get` **confiné** à `zcrud_get/lib/` (scan `import`) · barrel étendu (+exports + dartdoc EX-UI.11, existant intact, pas de ré-export de package pur) · `melos run generate` (no-op) + `dart analyze` RC=0 + `flutter test` verts ; `melos run analyze`/`verify` **repo-wide** délégués à l'orchestrateur · **DERNIÈRE story de l'epic EX-UI** → rétrospective débloquée · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story).

### Debug Log References

- Harnais de test `GetSnackBar` : les 6 tests toaster échouaient initialement (fuite de ticker à la finalisation de l'overlay + assertion `elapsedInSeconds >= 0.0`). Cause = animation d'entrée du snackbar non pilotée à t=0 et overlay disposé ticker actif. Correctif harnais (test-only, aucune modif d'impl) : (1) `pump()` nu supplémentaire avant la frame temporisée (démarre l'anim à t=0) ; (2) `Get.closeAllSnackbars(); pumpAndSettle()` en fin de chaque test (dispose propre du ticker). Validé par variante scratch avant application.
- `dart pub get` racine RC=69 : le workspace des 14 packages résout (`Got dependencies!`) mais l'app standalone `./example` (hors `packages/`, LECTURE SEULE) échoue faute d'overrides `path` transitifs pour `zcrud_navigation`/`zcrud_ui_kit` (non hostés sur pub.dev). `flutter test` (pub get implicite) contourné via `--no-pub`. Voir « Questions pour l'orchestrateur ».

### Completion Notes List

- ✅ AC1 — `ZGetFormPresenter implements ZFormPresenter` : `present<T>` signature exacte (`@override` compile), `switch` exhaustif 3 modes → `Get.to(fullscreenDialog:)` / `Get.bottomSheet(isScrollControlled:)` / `Get.dialog(Dialog+ConstrainedBox, barrierDismissible:)`, `MediaQuery.sizeOf(context)` (jamais `Get.*`/`Get.context!`), form-agnostique (`Builder(builder:)`, aucun `runtimeType`), aucun `barrierColor` hex. Repli sûr `Future<T?>.value()` sur `Get.to` nullable.
- ✅ AC2 — `ZGetToaster implements ZToaster` : `switch` exhaustif 4 sévérités, couleur dérivée du `ColorScheme` (`primary`/`tertiary`/`secondary`/`errorColor??error`, jamais hex), icône + texte (couleur jamais seul canal), `Semantics(liveRegion:)`, `TextAlign.start`, action `mainButton` SSI `actionLabel && onAction`, aucune méthode ad hoc.
- ✅ AC3 — Substitution prouvée : `ZFormPresenterScope.of() is ZGetFormPresenter` / `ZToasterScope.of() is ZGetToaster` (défauts pur-Flutter écartés) ; helper `ZcrudGetUiScope` monte les 2 seams. Aucun package pur modifié.
- ✅ AC4 — `get` confiné : test statique scan `import` → aucun `package:get/`/`go_router` dans `zcrud_navigation`/`zcrud_ui_kit`, présent uniquement dans `zcrud_get`. `pubspec.yaml` +2 arêtes sortantes ; `graph_proof.py` ACYCLIQUE, CORE OUT=0.
- ✅ AC5 — `melos run generate` no-op (0 outputs) ; `dart analyze packages/zcrud_get` RC=0 (No issues found) ; `flutter test --no-pub` 54/54 verts ; barrel étendu (+3 exports + dartdoc EX-UI.11) sans retrait/ré-export de package pur.
- Décision D3/Q3 : `Get.snackbar` retenu (idiome `ToastService` dodlp), `messageText`/`icon` via widgets libres → `Semantics(liveRegion:)` praticable. D4 : helper `ZcrudGetUiScope` livré (trivial). D6 : fichiers sous `lib/src/presentation/`.

### File List

- `packages/zcrud_get/pubspec.yaml` (UPDATE — +2 deps `zcrud_navigation`/`zcrud_ui_kit` + commentaire invariant)
- `packages/zcrud_get/lib/zcrud_get.dart` (UPDATE — +3 exports + dartdoc EX-UI.11)
- `packages/zcrud_get/lib/src/presentation/z_get_form_presenter.dart` (NEW)
- `packages/zcrud_get/lib/src/presentation/z_get_toaster.dart` (NEW)
- `packages/zcrud_get/lib/src/presentation/zcrud_get_ui_scope.dart` (NEW)
- `packages/zcrud_get/test/z_get_form_presenter_test.dart` (NEW)
- `packages/zcrud_get/test/z_get_toaster_test.dart` (NEW — harnais GetSnackBar corrigé)
- `packages/zcrud_get/test/ex_ui_11_seam_test.dart` (NEW)
- `packages/zcrud_get/test/ex_ui_11_confinement_test.dart` (NEW)

### Questions pour l'orchestrateur (à remonter si besoin)

1. **Emplacement des fichiers** : la métadonnée épic dit `lib/src/ui/` ; la story retient `lib/src/presentation/` (cohérence avec le package existant). Confirmer si `ui/` est préféré.
2. **Helper `ZcrudGetUiScope`** : livrable **optionnel** (la substitution directe via les 2 scopes suffit à AC3). L'imposer dès EX-UI.11 ou le différer en extension future ?
3. **`Get.snackbar` vs `Get.showSnackbar(GetSnackBar(...))`** : `Get.showSnackbar` donne un contrôle plus fin (a11y `Semantics(liveRegion:)`, `snackStyle`) mais est plus verbeux. Le dev tranche selon la testabilité (assertion couleur/icône) ; par défaut `Get.snackbar` (idiome dodlp `ToastService`). → **Tranché : `Get.snackbar`** (a11y `Semantics(liveRegion:)` obtenue via `messageText` widget libre).
4. **`dart pub get` racine RC=69 — app `./example` (hors périmètre, LECTURE SEULE)** : l'ajout des 2 arêtes transitives `zcrud_navigation`/`zcrud_ui_kit` casse la résolution de `example/pubspec.yaml`, qui — par convention documentée du fichier (voir overrides `zcrud_study_kernel`/`zcrud_annotations`) — exige un `dependency_overrides: { zcrud_navigation: {path: ../packages/zcrud_navigation}, zcrud_ui_kit: {path: ../packages/zcrud_ui_kit} }`. **NON appliqué par le dev** (scope non-négociable = `packages/zcrud_get` uniquement ; `example` = app LECTURE SEULE). Le workspace des 14 packages résout (`Got dependencies!`) ; `flutter test` joué en `--no-pub`. **Action orchestrateur requise avant le `melos`/pub gate d'epic repo-wide** : ajouter ces 2 overrides `path` à `example/pubspec.yaml` (purement consommateur, aucun package sous `packages/` modifié, `melos list`=14 et `graph_proof` inchangés).

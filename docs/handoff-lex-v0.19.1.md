# Handoff → session `lex_douane` · zcrud **v0.19.1** — CR-52, CR-53

> **Tag à épingler : `v0.19.1`**
> Vos deux CR sont livrées. **Additif et non cassant** : si vous ne touchez à rien,
> rien ne bouge. Vous pouvez passer de `v0.19.0` à `v0.19.1` sans modifier une ligne.

| CR | Sévérité | État |
|---|---|---|
| **CR-52** — `ZPageScaffold` inadoptable (ni FAB, ni tiroir, ni barre basse) | 🔴 **BLOQUANT (adoption)** | ✅ **LIVRÉE** |
| **CR-53** — `ZSectionedStudyLayout` sans slot d'en-tête | MAJEUR | ✅ **LIVRÉE** |

---

## 0. Vous aviez raison, et c'était notre erreur — pas une évolution

Ces deux défauts sont des **erreurs de conception** dans des widgets que nous vous
avions livrés **une heure plus tôt**. Nous ne les traitons pas comme des demandes
d'évolution : nous n'aurions jamais dû vous livrer un shell qui s'approprie le
`Scaffold` sans en rendre les capacités.

Mesuré de notre côté avant de corriger : **8 de vos écrans d'étude** portent un
`floatingActionButton` (`study_screen`, `study_folder_screen`, `studies_catalog`,
`study_mindmap`, `study_tags`, `reading_plan`, `code_details`, `feedback_list`).
Votre « inadoptable sur 21 de nos 21 écrans » est exact.

---

## 1. CR-52 — deux voies, parce qu'une seule n'aurait pas suffi

### (a) Le pass-through — débloque le cas courant

```dart
ZPageScaffold(
  title: 'Étudier',
  tabs: [...],
  floatingActionButton: FloatingActionButton(onPressed: …, child: Icon(Icons.add_rounded)),
  floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
  drawer: …, endDrawer: …, bottomNavigationBar: …, persistentFooterButtons: […],
  bottomSheet: …, backgroundColor: …, resizeToAvoidBottomInset: false,
  extendBody: true, extendBodyBehindAppBar: true,
);
```

**11 slots**, tous optionnels, défauts identiques à ceux de `Scaffold` ⇒ **le rendu
par défaut est strictement inchangé**.

Le jeu n'est pas arbitraire : les 6 que vous exigiez, plus `bottomSheet`, plus
trois que nous avons **mesurés dans votre code** (`backgroundColor`, très fréquent ;
`extendBodyBehindAppBar` sur `qr_scanner_screen`/`web_login_scanner_screen` ;
`endDrawer` sur `domain_main_screen.dart:67`), plus `resizeToAvoidBottomInset` que
demandait votre §Demande. **Écartés faute d'usage mesuré** : `drawerScrimColor`,
`onDrawerChanged`, `floatingActionButtonAnimator`, `primary` — dites-le nous si
l'un vous manque, nous ne gonflons pas la surface publique par précaution.

### (b) `ZPageShellBody` — parce que le pass-through reste une liste finie

```dart
Scaffold(                    // VOTRE Scaffold, vos règles
  floatingActionButton: …,
  body: ZPageShellBody(title: …, actions: […], search: …, tabs: […]),
);
```

Le pass-through ne couvre **pas** l'hôte dont le `Scaffold` est **enveloppé**
(`code_details_screen.dart:371` : `PopScope(child: Scaffold(...))`) ni celui qui
en **aiguille plusieurs selon l'état** (`study_mindmap_screen` : 4 `Scaffold` pour
loading/error/notFound/succès ; `valuation_screen` : 4 aussi). Pour ces cas,
`ZPageShellBody` vous donne la **valeur** du shell — app-bar morphante repliable
et onglets — **sans aucun `Scaffold`**.

⚠️ **Livré EN PLUS, jamais à la place.** Retirer le `Scaffold` de `ZPageScaffold`
aurait été cassant. Les deux coexistent, et `ZPageScaffold` **délègue** son corps
sliver à `ZPageShellBody` : un seul rendu dans la bibliothèque, zéro duplication.

ℹ️ `ZPageShellBody` en mode `fixed` dans un corps défilant se replie sur `pinned`
et le documente (AD-10, jamais de `throw`). Pour un app-bar réellement fixe,
`ZSearchableAppBar` est déjà publique et se pose directement en `appBar:`.

### Deux notes d'implémentation qui vous concernent

- Les 3 `Scaffold` du fichier étaient des **branches exclusives**, pas des
  imbrications. Il n'y a désormais qu'**un seul site de construction**
  (`_scaffold({appBar, body})`) : la duplication de slots est **structurellement
  impossible**, au lieu d'être « évitée par discipline ». Vos slots restent hors
  zone défilante — le FAB survit au scroll (garde dédiée).
- `ZPageScaffold` est passé `StatefulWidget` → `StatelessWidget`. **Non cassant**,
  vérifié contre le tag `v0.19.0` : sa `State` était **privée**
  (`_ZPageScaffoldState`), jamais exportée. Le constructeur `const` est inchangé.
- `extendBodyBehindAppBar` est **sans objet en mode sliver** (l'app-bar y est dans
  le corps) — documenté plutôt que silencieusement ignoré.

---

## 2. CR-53 — l'en-tête est dans le même défilement

```dart
ZSectionedStudyLayout(
  header: MonCtaReviser(dueCount: n),   // ou vos chips, filtres, bandeau…
  sections: […],
  footer: MesSujetsConnexes(),
);
```

Et la voie jusqu'à la page-détail, **par sous-dossier sélectionné** :

```dart
ZStudyFolderDetail(
  materialSectionsBuilder: (id) => […],
  materialHeaderBuilder: (context, id) => CtaReviser(subfolderId: id),
  materialFooterBuilder: (context, id) => SujetsConnexes(subfolderId: id),
);
```

- L'en-tête est rendu **dans le même `ListView.builder`** que les sections : un
  seul défilement, **virtualisation préservée**. Un slot `null` ne réserve **aucun
  item** (pas de `SizedBox.shrink` fantôme).
- Les slots sont invoqués **dans le `ValueListenableBuilder<String?>` existant** :
  aucun élargissement du périmètre de rebuild (AD-2/SM-1).
- Les sections gardent leur `ValueKey('section:<id>')`, **indépendante de l'index**
  et de la présence des slots.

### 🔵 `ZMaterialSectionsBuilder` est INCHANGÉ — vérifié bit à bit

Nous avons ajouté un **typedef coexistant** (`ZMaterialSlotBuilder`) et deux
paramètres optionnels, plutôt que d'élargir le vôtre. Raison : les slots sont une
capacité **orthogonale** (AD-4), pas une extension du contrat « sections ». Un
builder agrégé (header+sections+footer) aurait forcé **tous** les hôtes à migrer ;
deux paramètres mutuellement exclusifs gardés par `assert` auraient introduit un
mode d'échec à l'exécution.

**Pourquoi `Widget?` au niveau layout mais un `builder` au niveau page-détail** :
au layout, un `WidgetBuilder` fabriquerait une instance neuve à chaque rebuild et
détruirait le court-circuit `Element.updateChild` (une garde le mesure). Au niveau
page-détail, le contenu **dépend de la sélection**, état détenu par le widget —
vous ne pouvez pas le pré-construire, d'où le builder, confiné à cette tranche.

---

## 3. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (10 gates) · `graph_proof`
**ACYCLIQUE + CORE OUT=0** · `zcrud_ui_kit` **157** (+37) · `zcrud_study` **630** (+10).

**R3 — 18 régressions ré-injectées, 18 rouges.** Les slots sont prouvés
**fonctionnels**, pas seulement présents : FAB **tapé** (compteur), tiroirs
**réellement ouverts** (`openDrawer`/`openEndDrawer` + contenu affiché), position
du FAB vérifiée **géométriquement**, le tout sur les **3 branches**.

⚠️ **Une garde ne mordait pas, et nous vous le disons plutôt que de la garder** :
`expect(find.byType(SliverToBoxAdapter), findsNothing)` restait **VERT** sous la
régression — un sliver d'extension nulle est *offstage*, donc invisible au finder
par défaut (mesuré par sonde : `SliverToBoxAdapter=0` alors que le code en
construisait un). Reformulée en `skipOffstage: false` + assertion structurelle sur
`CustomScrollView.slivers`. Elle rougit désormais.

---

## 4. Ce que ces deux CR nous ont appris

Notre revue adversariale avait pour consigne **explicite** de traquer « toute API
publique nouvellement exportée qui serait un piège pour l'hôte ». Elle est passée
à côté des deux.

La cause est nette : **elle n'a testé la composition qu'entre nos propres widgets**,
jamais contre un écran hôte réel. Un shell qui se compose parfaitement avec nos
autres widgets peut être totalement inadoptable chez vous — et c'est exactement ce
qui s'est produit. Le harnais de validation doit désormais composer contre une
reconstitution d'écran hôte (FAB, contenu au-dessus des sections, `Scaffold`
enveloppé), pas seulement contre nous-mêmes.

Merci pour ces deux CR : elles ont trouvé en une heure ce que sept lentilles de
revue avaient manqué.

# zcrud_ui_kit

Kit de widgets UI transverses de zcrud — états de contenu, confirmation,
notification et page-shell, tous à thème/l10n injectés, sans jamais tirer
de gestionnaire d'état (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2)).

## Aperçu {#apercu}

`zcrud_ui_kit` factorise les patterns UI génériques qu'une application CRUD
Flutter réécrit sinon dans chacun de ses écrans : l'état d'un contenu
asynchrone en enum ([ZContentState]) plutôt qu'en combinaisons de `bool`,
la tonalité d'une confirmation ([ZConfirmTone]), la sévérité d'un toast
([ZToastSeverity]) servie par un port pluggable ([ZToaster]), une garde
anti-perte de saisie ([ZDiscardChangesGuard]), un index alphabétique
cliquable ([ZAlphabetIndexBar]), des transitions de route RTL-aware, et un
**page-shell déclaratif** ([ZPageScaffold] / [ZPageShellBody] /
[ZSearchableAppBar]) qui factorise l'app-bar recherchable, repliable et
à onglets.

Ce paquet **dépend de `zcrud_core`** et **consomme** ses seams
(`ZcrudScope` / `ZcrudTheme` / `ZcrudLocalizations`) en lecture seule,
toujours avec un repli sur `Theme.of(context)` /
`MaterialLocalizations.of(context)` quand aucun scope n'est monté. Il ne
redéclare ni ne ré-exporte aucun symbole de `zcrud_core`, et n'importe
aucun gestionnaire d'état, routeur ou bibliothèque UI tierce.

**Utilisez ce paquet** pour un écran qui a besoin d'un état de chargement/
vide/erreur cohérent, d'une confirmation destructive, d'un toast, d'une
garde de sortie de formulaire, ou d'une app-bar recherchable + onglets +
dégradé d'identité. **N'utilisez pas ce paquet** si vous cherchez la
grille adaptative (`zcrud_responsive`) ou le rendu de liste
(`zcrud_list`) : ce sont des rôles de satellites dédiés.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

// Route un état de contenu vers le bon widget (exhaustif, replis sûrs).
Widget contentBody(ZContentState state, List<String> items) {
  return ZContentStateView(
    state: state,
    loading: const ZLoadingState(),
    empty: ZEmptyState(
      icon: Icons.inbox_outlined,
      message: 'Aucun élément', // libellé injecté par l'hôte
    ),
    error: ZErrorState(
      message: 'Une erreur est survenue',
      retryLabel: 'Réessayer',
      onRetry: () {},
    ),
    successBuilder: (context) => ListView(children: items.map(Text.new).toList()),
  );
}

// Demande une confirmation dark-mode-aware (sans gestionnaire d'état).
Future<void> onDelete(BuildContext context) async {
  final ok = await showZConfirmDialog(
    context,
    title: 'Supprimer ?',
    message: 'Cette action est irréversible.',
    tone: ZConfirmTone.destructive,
  );
  if (ok) {
    // supprimer
  }
}

// Page-shell : app-bar recherchable + onglets, un seul Scaffold construit.
Widget page() => const ZPageScaffold(
      title: 'Titre',
      body: SizedBox.shrink(),
    );
```

## Concepts clés {#concepts-cles}

- **Enums plutôt que booléens** — [ZContentState] (5 valeurs),
  [ZConfirmTone], [ZToastSeverity] et [ZPageAppBarMode] remplacent chacun
  des combinaisons de `bool` ambiguës par un espace d'états explicite et
  exhaustif : un `switch` sans `default` détecte à froid tout palier
  oublié.
- **Rebuild granulaire (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** — l'état de recherche du page-shell
  et l'état *dirty* de [ZDiscardChangesGuard] sont détenus localement ou
  consommés en lecture seule via `ValueListenable` : la frappe dans la
  recherche ne rebâtit que la tranche app-bar, jamais le corps de la page.
- **Port de notification pluggable** — [ZToaster] est un
  `abstract interface class` (jamais `sealed`, invariant
  [AD-4](../../docs/site/concepts/invariants.md#ad-4)) ; [ZScaffoldMessengerToaster] en est l'implémentation
  par défaut pur-Flutter, substituable par [ZToasterScope] sans que ce
  paquet importe de dépendance tierce.
- **Une pastille de comptage dit *combien*, pas seulement « il y en a »** —
  [ZCountBadge] traite les trois pièges que chaque recopie du motif retrouve :
  le nombre laissé **muet** (un lecteur d'écran lit « 3 », sans dire trois
  quoi — d'où `semanticsLabel`), la cible tactile **rétrécie** par la pastille
  collée sur une icône (48 dp imposés dès qu'elle est cliquable), et la couleur
  **écrite en dur** qui devient illisible en mode sombre (tout vient du
  `ColorScheme`). Elle ne compte jamais elle-même : elle affiche le nombre
  qu'on lui donne.
- **Page-shell : deux formes pour une même valeur** — [ZPageScaffold]
  construit son propre `Scaffold` (slots exposés en pass-through) ;
  [ZPageShellBody] rend la même app-bar morphante repliable + onglets
  **sans posséder de `Scaffold`**, à poser dans celui de l'hôte quand il
  l'enveloppe déjà (`PopScope`…) ou en aiguille plusieurs selon l'état.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **États de contenu** | |
| `ZContentState` | État d'un contenu asynchrone en enum (`idle`/`loading`/`empty`/`error`/`success`). |
| `ZEmptyState` / `ZLoadingState` / `ZErrorState` | Widgets d'état `const`, thème/couleurs dérivés, `Semantics`, cibles ≥ 48 dp. |
| `ZContentStateView` | Aiguilleur `switch` exhaustif de `ZContentState` vers le bon widget, replis sûrs. |
| **Confirmation** | |
| `ZConfirmTone` | Tonalité de confirmation en enum (`neutral`/`destructive`). |
| `ZConfirmDialog` / `showZConfirmDialog` | Dialog de confirmation dark-mode-aware, `Future<bool>`, sans gestionnaire d'état. |
| **Notification** | |
| `ZToastSeverity` | Sévérité d'un toast en enum (`info`/`success`/`warning`/`error`). |
| `ZToaster` / `ZToasterScope` / `zToast` | Port de notification pluggable et son seam d'injection par l'app. |
| `ZScaffoldMessengerToaster` | Implémentation par défaut pur-Flutter du port `ZToaster`. |
| **Garde de saisie** | |
| `ZDiscardChangesGuard` | `PopScope` interceptant la sortie tant qu'un `ValueListenable<bool>` *dirty* est vrai. |
| **Comptage** | |
| `ZCountBadge` | Pastille de comptage : seule ou posée sur un contenu, nombre **annoncé**, cible ≥ 48 dp si cliquable, couleurs dérivées du `ColorScheme`, placement directionnel. |
| **Index et transitions** | |
| `ZAlphabetIndexBar` / `kZDefaultAlphabet` | Index vertical A→Z cliquable, jeu de lettres injectable. |
| `ZRouteTransition` / `zSlideBeginOffset` / `zPageRoute` / `ZPageTransitionsBuilder` | Transitions de route RTL-aware, découplées de tout routeur. |
| **Page-shell déclaratif** | |
| `ZAppBarAction` / `ZAppBarSearchConfig` / `ZPageTab` / `ZPageAppBarMode` | Action, recherche et onglet d'app-bar en données ; mode d'app-bar en enum. |
| `ZSearchableAppBar` | App-bar recherchable `PreferredSizeWidget`, état de recherche détenu, rebuild granulaire. |
| `ZPageScaffold` | Assemblage titre/actions/recherche/onglets + `Scaffold` complet, slots en pass-through. |
| `ZPageShellBody` | La même valeur, sans posséder de `Scaffold` — à poser dans celui de l'hôte. |

## Cas limites et invariants {#cas-limites}

- **Défaut strictement inchangé** — sans paramètre ni jeton de typographie,
  aucune enveloppe de style n'entre dans l'arbre du page-shell : le rendu
  est celui d'une app-bar Material nue.
- **Métriques seules, jamais la couleur** — un style de titre/onglet fourni
  au page-shell voit sa couleur **ignorée** : le titre doit rester hérité
  du `foregroundColor` (lisibilité sous dégradé d'identité), et `TabBar`
  dérive sa couleur de sélection de `labelStyle?.color`, qu'un style
  coloré supprimerait.
- **Un seul `Scaffold`, quel que soit le mode** — `ZPageScaffold` factorise
  le rendu entre app-bar fixe et `SliverAppBar` repliable ; aucun slot
  n'est jamais dupliqué.
- **Accessibilité (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** — cibles tactiles ≥ 48 dp, `Semantics`
  explicites, layout directionnel (`EdgeInsetsDirectional`,
  `TextAlign.start`/`end`) sur toute la surface du paquet ; un état ne
  repose jamais sur la seule couleur.
- **Zéro dépendance tierce** — ce paquet n'importe ni gestionnaire d'état
  (invariants [AD-2](../../docs/site/concepts/invariants.md#ad-2)/[AD-15](../../docs/site/concepts/invariants.md#ad-15)), ni routeur, ni bibliothèque UI tierce : chaque
  port ([ZToaster]) laisse un hôte substituer une implémentation riche
  sans que ce paquet en dépende.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_ui_kit.md`](../../docs/site/paquets/zcrud_ui_kit.md)
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_core` — `ZFormController`, `ZcrudTheme`, résolution de libellés.
- `zcrud_responsive` — grille adaptative complémentaire (cartes d'items).
- `zcrud_get` — implémentations `ZToaster` spécifiques à GetX.

## Licence {#licence}

MIT — voir la racine du dépôt.

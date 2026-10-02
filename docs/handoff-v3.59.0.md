# Handoff v3.59.0 — suites Lex 144-153 et dépendances résolubles

Release du 2026-10-02, tag `v3.59.0`. Origine : Lex CR-144 à CR-153, suites des coutures livrées en v3.58.0, plus la montée des dépendances externes jusqu'au plus récent graphe qui résout encore. Aucun document déjà persisté n'est invalidé.

Les compensations de `docs/handoff-v3.58.0.md` qui n'ont pas encore été retirées le restent : cette note ne les annule pas.

## Hôte passif

Un hôte qui n'appelle pas les coutures nouvelles compile encore. Les paramètres ajoutés ont un défaut.

Trois changements se voient sans code :

- La surface de menu par défaut a un rayon, une marge interne, une ombre si le thème a une couleur de libellé, et une largeur maximale. Un libellé long passe sur deux lignes. Le focus est demandé à l'ouverture, même si un champ le tient déjà.
- Un menu qui dépassait de l'écran et se fermait au tap choisit maintenant l'entrée. Le décalage déplace la boîte suiveuse, pas son contenu.
- La pile Syncfusion passe de `^34.1.31` à `^35.1.37` (`datagrid`, `pdf`, `xlsio`, `chat`, et le `core` partagé). Un hôte qui épingle Syncfusion `^34` ne résout plus contre ces paquets. Il faut monter la pile ensemble.

`pinput` reste en 6.x (`>=6.0.2 <7.0.0`). La 7.0.0 exige un `Material` de `package:material_ui`, type distinct de celui de Flutter : sous un `Scaffold` ordinaire, le champ PIN lève en debug.

Le générateur accepte analyzer 13 et refuse analyzer 14 (`>=12.0.0 <14.0.0`). Analyzer 14 tire `source_gen` 4.3. Les hôtes qui partagent analyzer 13 avec `reflectable_builder` 1.2.3 et `riverpod_generator` ^4 restent sur cette fenêtre. Le workspace résout analyzer 13.3.0.

## Hôte qui compensait

Retirer la compensation, sinon elle s'additionne au correctif.

| Compensation locale | Retrait |
|---|---|
| Identité du tour adopté lue sur `activeRequests` après l'appel, fil réadopté quand le futur se termine | `onStarted` reçoit le jeton tout de suite. Le futur se termine toujours à la fin du flux. `settle: false` n'insère pas de réponse. `adoptMessages` remplace le fil pendant ce tour. |
| Coquille de liste pour poser une bulle par rôle | `itemFrameBuilder(context, message, tile)` sur la vue et l'écran. `message` est `null` pour un tour en vol. Une coquille tierce construit encore sa propre liste : ce créneau ne la traverse pas. |
| Menu Material local (marge, rayon, focus volé au champ, libellé borné) | La surface par défaut, ou `menuBuilder` / `pickerMenuBuilder`. Le déclencheur `+` du catalogue n'a plus besoin d'être remonté à la main. |
| Feuille de transformations parce que la barre n'est pas au clavier | Les entrées sont focalisables et activables. `sectionHeaderBuilder` remplace le titre de section. |
| Panneau de sources maison pour l'en-tête, le nom des imports et la hauteur | `headerBuilder`, `importingNames`, `shrinkWrap`. |
| Génération de portée maison pour le niveau, `extra`, et le refus typé | `generate(modelId:, providerId:, languageTag:, extra:)`. Le refus est un `ZChatScopeBusyFailure`. Une reprise partielle des écritures reste à l'hôte. |
| Store de compte qui échoue sans scope, compte les usages, et réessaie une ouverture | `unsignedReadsAreEmpty: false`. `dispose` ne ferme la box qu'au dernier store différé du même nom. Une ouverture en échec est un `Left`, retentée ensuite. |
| Reprise maison qui ne fermait pas la box du compte, ne créait pas la box absente, gardait la plus récente, et isolait `isMine` | `adoptUnscoped` fait ces quatre choses. `isMine` doit rester faux tant que le propriétaire n'est pas établi. |
| Dépôt construit à la main pour passer `isForeign` | `isForeign` sur `buildUserScopedStudyRepository` et `buildFolderScopedStudyRepository`. |

## Dépendances qui ne montent pas

Le solveur s'arrête avant ces dernières versions. Aucun `dependency_overrides` ne les force.

| Paquet | Tenu | Dernière | Pourquoi |
|---|---|---|---|
| `file_picker` | 10.3.10 | 13.1.0 | `windows_file_picker` 2 veut `win32` ^6, qui veut `hooks` ^1 et `code_assets` ^1. Le graphe a déjà `hooks` 2 et `code_assets` 2. |
| `geolocator` | 14.0.2 | 14.1.1 | `geolocator_linux` 0.2.6 veut `package_info_plus` ^10, donc le même `win32` ^6. |
| `device_info_plus` / `package_info_plus` | 11.5.0 / 9.0.1 | 13.3.0 / 10.2.2 | Même plafond `win32` ^6. |
| `melos` | 8.6.0 | 8.9.0 | 8.9.0 veut `platform` `<3.2.0`. Le graphe résout `platform` 3.2.0. |
| `analyzer` (générateur) | 13.3.0 | 14.4.0 | Fenêtre partagée avec les hôtes. `source_gen` 4.3 exige analyzer 14. |
| `test` | 1.31.1 | 1.32.0 | Le SDK Flutter épingle `test_api` 0.7.12. |
| `pinput` | 6.0.2 | 7.0.0 | `material_ui`, voir plus haut. |

## CR-144 — jeton pendant le tour

```dart
controller.adoptTurn(
  events,
  requestId: 'tour-1',
  settle: false,
  onStarted: (ZChatRequestToken token) {
    // zChatStreamingMessageId(token.requestId) est connu ici.
  },
);
controller.adoptMessages(filDeLHote);
```

## CR-145 — cadre par rôle

```dart
ZChatConversationView(
  controller: controller,
  itemFrameBuilder: (context, message, tile) => encadrer(message, tile),
)
```

## CR-150 — tap du menu recalé

`ZChatClampShift` porte le `LayerLink` et applique le décalage à `CompositedTransformFollower.offset`.

## Versions

Les 42 versions de packages et leurs dépendances internes sont alignées sur `3.59.0`. La recette `docs/private-git-consumption.md` épingle `v3.59.0`. Les outils `tool/binding_conformance` et `tool/reserved_keys_gate` restent en `0.0.1`. Pas de publication pub.dev, pas de dépôt hôte, pas de site.

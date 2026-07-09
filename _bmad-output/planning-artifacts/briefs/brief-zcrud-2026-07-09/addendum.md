---
title: "Addendum — Product Brief zcrud"
status: draft
created: 2026-07-09
updated: 2026-07-09
parent: brief.md
grounding: ../../../../docs/technical-inventory.md
language: fr
---

# Addendum — zcrud

Contexte de profondeur qui déborde du brief mais éclaire le PRD, l'architecture et le design de solution. La référence factuelle exhaustive (catalogue des types de champs, refs `fichier:ligne`, cause racine du bug de rebuild, risques d'extraction par package) est dans **`docs/technical-inventory.md`** — non recopiée ici.

## 1. Les trois sources : trois générations, un même ADN

| | DLCFTI | DODLP | IFFD |
|---|---|---|---|
| Rôle | Legacy, à ne pas reprendre comme source | **Catalogue de référence** + consommateur n°1 | Référence d'architecture moderne (état, editor riche) |
| Dispatch de champ | `Type` Dart natif (`case const (num)`) — non sérialisable | enum `EditionFieldTypes` (~37 types) | enum `EditionFieldTypes` (~19/26 réels) |
| État | GetX + reflectable | get_it + GetX + provider + reflectable | **Riverpod 3 + freezed + codegen** |
| Data layer | Extension `FirebaseFirestoreX` (aucune abstraction) | Abstraction partielle | **`CrudRepository<T>` propre + stub Supabase** |
| Rich text | HTML-only legacy | Quill (import fantôme `flutter_quill_delta_from_html`) | **Quill unifié + embeds LaTeX/tables** (source retenue) |

Ligne directrice d'extraction : **catalogue et champs spécialisés depuis DODLP**, **architecture d'état et editor riche depuis IFFD**, **rien depuis DLCFTI** (validation croisée seulement).

## 2. Alternatives considérées et écartées

- **Un seul package `zcrud` monolithique** — écarté : imposerait Quill, Syncfusion, Google Maps et Firebase à tout consommateur. La modularité melos est le cœur de la demande utilisateur (« qu'un projet puisse importer `zcrud_markdown` alors qu'un autre l'ignore »).
- **Conserver `reflectable`** — écarté : impose `initializeReflectable()` par point d'entrée + codegen par fichier, **incompatible avec Riverpod 3 / lex_douane**, et n'automatise même pas la (dé)sérialisation (le registre manuel reste à écrire). IFFD prouve que le moteur tourne sans réflexion (sur `Map<String,dynamic>`).
- **Corriger le bug de rebuild par un simple `debounce`** — insuffisant : la cause est structurelle (`setState` global + closures recréées dans `build()` + absence de `key`/controllers stables). Seule une réécriture en widgets de champ isolés + état Riverpod granulaire l'élimine.
- **Remplacer le module « Étudier » de lex_douane par `zcrud_flashcard`/`zcrud_mindmap`** — écarté : lex_douane a un module mature à schéma **verrouillé** (offline-first Hive+Firestore, SM-2). zcrud s'y **adapte** (widgets paramétrés par l'entité de l'app), il ne le remplace pas.
- **`pub workspaces` natifs (Dart 3.6+)** — non retenu à ce stade au profit de **melos** (choix utilisateur : outillage de release/versioning plus riche). À ré-examiner si l'outillage se simplifie.

## 3. Tension centrale : schéma dérivé vs schéma verrouillé

Deux mondes doivent cohabiter :
- **Génération** (idéal zcrud) : le modèle annoté `@ZcrudModel/@ZcrudField` **génère** le `DynamicFormField` + la (dé)sérialisation → source unique de vérité.
- **Adaptation** (contrainte lex_douane / DODLP) : lex_douane a des entités `@JsonSerializable` **pures** à schéma verrouillé ; DODLP a `reflectable` + un god-object `DodlpController`. On ne peut pas leur imposer un 2ᵉ modèle concurrent.

→ Décision d'architecture attendue : un **codec/registre injectable** (`ZcrudRegistry`) offrant deux voies — enregistrement généré (greenfield) **et** adaptateur sur schéma existant (`ReflectableCodec` pour DODLP, `JsonSerializableAdapter` pour lex_douane). C'est le point de conception n°1 du PRD.

**Directive utilisateur (session d'init, mise à jour) :** le schéma **canonique** de zcrud est **porté des modèles les plus avancés de lex_douane** (module « Étude », **en développement actif** — donc portage d'un état vivant, à re-synchroniser). Ces modèles définissent le socle verrouillé ; **chaque application consommatrice doit pouvoir étendre** modèles _et_ fonctionnalités (champs, types, comportements) tout en profitant du partagé. L'**extensibilité** devient une exigence architecturale de premier ordre (pas un simple adaptateur de compat) :
- Modèles canoniques ouverts à l'extension : composition/mixins, sous-types `sealed`, ou champs additionnels déclarés par l'app via le registre — sans casser la (dé)sérialisation ni le schéma générés.
- Le canonique ne doit pas figer prématurément un module encore mouvant : prévoir une stratégie de versionnage/re-portage des modèles « Étude » de lex_douane.
- Corollaire : ce n'est plus « s'adapter à lex_douane » mais « **lex_douane fournit le canonique, tous étendent** » — y compris lex_douane lui-même pour ses champs spécifiques.

## 4. Injection framework-neutre (le vrai défi transverse)

Le moteur doit s'injecter dans **deux contextes incompatibles** :
- **Riverpod** (IFFD, lex_douane) : *seams* = providers qui `throw` par défaut, overridés dans `ProviderScope` (pattern déjà présent IFFD `core_providers.dart:8` + `main.dart:150`).
- **Locator / GetX** (DODLP, sans Riverpod) : un `ZcrudScope` (`InheritedWidget`) fournissant `CrudResolver`, `ZcrudPermissions`, `ZcrudToast`, `ZcrudConfig`, délégant à `getIt<DodlpController>()`.

→ Piste : `zcrud_core` ne dépend d'aucun conteneur ; un `zcrud_riverpod` **optionnel** relie les *seams* à Riverpod. À valider en architecture (question ouverte n°3).

## 5. Séquencement de valeur (pourquoi cet ordre)

1. **DODLP d'abord** : couplage entrant sain (180 fichiers consommateurs), parité fonctionnelle mesurable, rétro-compatibilité prouvable (adaptateur mince, bootstrap inchangé). Meilleur banc d'essai pour durcir `zcrud_core`.
2. **Rich forms lex_douane ensuite** : plus grand vide réel (~87 écrans hand-rolled), stack moderne (intégration greenfield sans dette d'adaptation d'état).
3. **Flashcards/mindmaps/geo/export** : différés — spécifiques, dépendances lourdes, et côté lex_douane surtout additifs.

## 6. Contraintes non négociables des cibles (extraits)

- **lex_douane** : `ConsumerWidget`/`ConsumerStatefulWidget` uniquement, `Either<Failure,T>` (dartz), full RTL (`EdgeInsetsDirectional`), a11y ≥48 dp + `Semantics`, `*.g.dart` générés, **zéro dépendance** de zcrud à `lex_localizations`/`go_router`, **reflectable exclu**. Vérifier le dry-run de résolution de deps (flutter_quill + awesome_select + analyzer) **avant** tout code.
- **DODLP** : préserver l'init 2 apps Firebase + reflectable + GetX ; l'injection zcrud doit être framework-neutre.

## 7. Dettes/bugs relevés à corriger à l'extraction (non exhaustif)

Bug `limit` Firestore sans réassignation ; batch/transaction incohérents avec `catch(_){}` ; pagination `SfDataPager` cosmétique ; sélection multiple désactivée (`_dataGridController` commenté) ; conversions Markdown↔Delta par regex (fragiles) ; `country` déprécié/buggé ; fausses langues (`class En extends Fr {}`) ; typos d'API publique (`searchInpuCtrl`, `childreen`, `crudActionsButtionsBuilder`) à renommer proprement dès la conception du package. Détails et refs dans l'inventaire §2–§7.

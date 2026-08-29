# Handoff v3.31.0 — la structure d'étude entre dans les écrans et dans Firestore

> **Date** : 2026-08-29. **Portée** : `zcrud_study`, `zcrud_firestore`, `zcrud_generator`.
> **Plan** : Partie III, Vague 3. _(en cours de rédaction)_

## 1. Ce que le socle livre

| Lot | Paquet | Livré |
|---|---|---|
| **P0b-B** | `zcrud_study` | `ZStudyUnitPicker` (sélecteur arborescent sur **valeur immuable** — forêt de `ZStudyRef`, jamais un port ; indentation par `depth`, feuille dès que la capability `hierarchical` manque, pastille signature sous `legacy`, recherche locale, virtualisé) ; `ZStudyPathBar` (segments = `ZStudyContext`, snapshot-first, directionnel, débordement en menu) ; `ZStudyScopeBar` (puces retirables par axe, `onScopeChanged` au filtre réduit exact) ; `zFilterByScope` + `scopeFilter/scopeArtifactOf/scopeSnapshot/scopeAt` sur `ZFlashcardListView`. Constat : `ZFlashcard` n'est **pas** un `ZStudyArtifact` — la portée sur les cartes exige la projection `scopeArtifactOf`, sans elle le paramètre est **inerte et documenté**, rien d'inventé |
| **P0b-C** | `zcrud_firestore` | `buildStudyStructureRepositories(...)` → **23 dépôts** sur le générique + les registrars du kernel, **zéro ligne de (dé)sérialisation spécifique** (garde de source calée sur les `ZFieldSpec` du kernel — pas de liste à elle) ; `kZStudyAncestorIdsKey`/`zStudyAncestorFilter`/`zStudyAncestorRequest` en `ZFilter`/`ZDataRequest` **neutres** (une signature exposant `Query` a été refusée — AD-5) ; `ancestor_ids` prouvé persisté et visé par la clé que `toMap()` émet réellement ; e2e `FakeFirebaseFirestore` |
| **P2-G-1** | `zcrud_generator` | **GEN-2, l'héritage collecté** : les champs annotés des super-classes et mixins entrent dans `toMap`/`fromMap`/`copyWith`/`$FieldSpecs` en ordre de **linéarisation Dart** (masquage au plus proche ; constructeur qui n'expose pas un champ hérité ⇒ échec de build explicite prescrivant `super.<champ>`) ; **GEN-3, les `Map`** : clé `String` ou enum (persistée en `.name`), valeurs scalaires/`DateTime`/enum/sous-modèle/`List`, `null` préservé, décodage défensif AD-10, refus explicites (`List<Map<…>>`, clé d'un autre type). **Inertie absolue prouvée** : `melos run generate` ⇒ 0 `.g.dart` modifié sur le dépôt entier. Changement de contrat mineur : un champ `Map` non annoté ne fait plus échouer le build (aucun modèle existant concerné). GEN-1 (slot `extension` en membres) exclu : il réécrirait tous les `.g.dart` — P2-G-2 avec handoff de rupture |

**Constat d'environnement corrigé** : la suite du generator n'est **plus** environnementalement
rouge (`dart test` : 168 verts, zéro `Isolate.packageConfig`) — le rouge résiduel des balayages
venait du harnais `flutter test` sur un paquet pur-Dart. Les balayages suivants le lancent en
`dart test`.

## 2. Administration de la structure — la recette (P0b-D, requalifié)

Aucun code socle n'était nécessaire : les 23 entités de structure portent leurs `$FieldSpecs` et
leurs registrars. Un hôte monte l'administration complète ainsi :

```dart
final registry = buildStudyStructureRegistry();          // zcrud_firestore
final repos = buildStudyStructureRepositories(
  firestore: FirebaseFirestore.instance,
  collectionPathOf: (kind) => 'study_$kind',
);
// Un écran par entité — ex. les organisations :
ZcrudScope(acl: monAcl, child: ZCrudScreen<ZStudyOrganization>(
  title: 'Organisations',
  source: ZCrudSource.repository(repos.organizations),
  registry: registry,
));
```

Le sélecteur de parent d'une unité se déclare via le `ZStudyUnitPicker` en champ widget libre si
l'hôte veut mieux qu'un champ texte. Un lot socle ne rouvrira ce sujet que sur un manque **mesuré**
à l'usage.

## 3. Ce qui change pour un hôte

**Hôte passif : rien** — les surfaces n'existaient pas (aucune compensation possible), les
paramètres sont `null` par défaut, inertie prouvée par égalité stricte.

## 4. Vérification

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_study` | 1 780 | **1 806** (analyze 72 infos préexistantes) |
| `zcrud_firestore` | 821 | **837** (analyze 1 info préexistante) |
| `zcrud_generator` (`dart test`) | 154 | **168** (analyze 0) |

| Contrôle | Résultat |
|---|---|
| `melos run generate` | SUCCESS — **0 `.g.dart` modifié sur le dépôt entier** (inertie du générateur prouvée) |
| `melos run analyze` repo-wide | **RC=0** (4 infos préexistants) |
| `melos run verify` (12 gates), avant **et** après le bump | **RC=0** |
| Balayage des 41 paquets | **40 verts** ; `zcrud_generator` non vert sous `flutter test` uniquement — artefact de harnais sur un paquet pur-Dart (168 verts en `dart test`), script de balayage corrigé |
| Résidus d'injection R3 | **0** marqueur |

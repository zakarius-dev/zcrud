# Handoff **v0.90.0** — enum `name` masqué refusé au build, `kindOf<T>()` au registre

> **Tag à épingler : `v0.90.0`** — répond à deux CR DODLP du 2026-08-12 :
> `cr-generator-enum-name-masque` et `cr-registry-type-vers-kind`.
> Paquets porteurs : **`zcrud_generator`** (garde enum), **`zcrud_core`** (registre),
> **`zcrud_annotations`** (documentation). Les autres paquets sont bumpés sans changement.

---

## 1. CR enum `name` masqué — **échec de build (option 1) + doc (option 3)**

Un champ `@ZcrudField` dont le type est un enum qui **redéclare `name`** (champ ou getter —
libellé d'affichage typiquement) est désormais un **échec de build**, y compris en
`List<enum>`. Le message nomme chaque champ fautif et son enum, et cite les remèdes :
renommer le membre (ex. `label`), ou `@ZcrudIgnore` + canal manuel.

Pourquoi le build et pas un contournement d'émission (votre option 2) : changer le chemin
d'encodage aurait touché le contrat des parcs sains. Et l'asymétrie mesurée chez nous est
pire que celle décrite dans votre CR : le **décodeur** émis (`_$enumFromName<T extends
Enum>`) résout `.name` sur l'extension SDK **non masquable** (borne générique), donc
compare toujours le nom technique — toute valeur écrite avec masquage (« Agent DODLP »)
serait **définitivement illisible** au retour. Le build est le seul endroit où crier.

- **Hôte passif** (aucun enum ne redéclare `name`) : rien à faire. Mesure d'étalonnage :
  0 enum masquant sur les 21 modèles du monorepo.
- **Hôte ayant compensé** (votre cas : `@ZcrudIgnore` + canal manuel `enumToString` sur
  `ProvenanceAgent` et consorts) : votre parade reste **valide telle quelle** — le champ
  étant `@ZcrudIgnore`, la nouvelle garde ne le voit pas. Vous pouvez soit la garder,
  soit renommer le membre en `label` et revenir au codegen ; vos fixtures
  (`douanes_codegen_equivalence_test.dart`) arbitrent le retrait, comme pour `fieldRename`.
- La dartdoc de `@ZcrudField` porte désormais la règle (« l'encodage enum passe par
  `.name` ; un membre `name` redéclaré est refusé au build »).

## 2. CR registre `Type → kind` — **options 1 + 2**

L'association `T ↔ kind`, connue au point d'enregistrement, n'est plus jetée.
Sur `ZcrudRegistry` :

- **`String? kindOf<T>()`** — le kind si l'association est univoque ; `null` si `T` n'est
  pas enregistré ; **`StateError`** actionnable (type + kinds en jeu + voie par-kind) si
  `T` est enregistré sous **plusieurs** kinds. Ce dernier cas reste **permis à
  l'enregistrement** — un modèle partagé par deux collections est légitime — mais
  l'ambiguïté est désormais explicite à la lecture au lieu d'être un silence.
- **`encodeOf<T>(T value)`** / **`decodeOf<T>(map)`** — les variantes typées pour un
  moteur générique : résolution du kind en interne, mêmes contrats d'erreur (type non
  enregistré ou ambigu → `StateError` explicite, jamais un repli muet), `decodeOf` rend
  `T` directement.

Votre table manuelle `kDodlpZcrudKinds` (48 entrées) et ses accesseurs
`dodlpKindOf`/`dodlpTryKindOf` deviennent **la dette à retirer** : `kindOf<T>()` (strict :
`StateError` si ambigu, `null` si absent) et le couple `encodeOf`/`decodeOf` couvrent les
deux usages. Votre test d'exhaustivité bidirectionnelle est le tripwire parfait pour ce
retrait — il rougira précisément quand la table locale et le registre divergeront pour la
dernière fois.

Le **générateur n'a pas changé** : les registrars émis appelaient déjà
`registry.register<T>('kind', …)` typé — vérifié sur les `.g.dart` du monorepo. Aucune
régénération requise chez vous au-delà du bump.

## 3. État des vérifications

`melos run generate` RC=0 (zéro `*.g.dart` modifié), `melos run analyze` RC=0,
`melos run verify` RC=0 (14 gates), tests rejoués depuis le dossier de chaque paquet
touché, workstreams au repos : generator **154**, core **1768**, annotations **10** —
tous verts. Gardes prouvées mordantes par injection des régressions exactes (rouges par
assertion : 4 pour la garde enum, 8+1 pour la table du registre), restaurations par copie
vérifiées par sha256, résidus prouvés absents par grep négatif.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
ci-dessus constitue la ligne de défense de cette release.

# Handoff → session `lex_douane` · zcrud **v0.6.0** — dérivation déclarative de champ

> **Tag à épingler : `v0.6.0`**
> **Aucune CR lex ouverte.** Ce handoff vous informe d'une capacité neuve du cœur et d'un
> avertissement qui vous concerne directement.

---

## 1. ⚠️ Avertissement — une recommandation que nous avons faite était dangereuse

Le handoff `v0.4.6` (§4) recommandait de retirer les contournements app-side préservant la
distinction `null` / `''`, au motif que `preserveAbsenceUnder` la prenait en charge.

**C'était faux pour tout hôte qui consomme les entités directement**, et le retrait aurait détruit
de la donnée silencieusement : cette option n'existe **qu'au codec de migration**
(`ZStudyLegacyCodec`), vérifié — deux fichiers dans tout le dépôt, aucun dans une entité.

Vous n'avez pas d'adaptateur de mapping et vos données sont canoniques d'origine : **vous n'êtes
probablement pas concernés**. Mais si vous avez, quelque part, un contournement de ce type, ne le
retirez pas sur la foi de ce paragraphe.

La capacité existe désormais **aussi sur le chemin entité** (`zMarkAbsent` / `zNullFieldsOf` /
`zRestoreAbsentString`, dans `zcrud_core`), avec la même clé de survie que le codec.

---

## 2. `ZDerivation` — « le champ B dérive du champ A », déclarativement

Émis par IFFD, mais **cela touche `ZFieldSpec`**, donc cela vous concerne.

```dart
ZFieldSpec(
  name: 'titre',
  derivedFrom: ZDerivation(
    sources: <String>['dossierId'],
    overwrite: ZDerivationOverwrite.always,   // ⚠️ OBLIGATOIRE — aucun défaut
    value: (v) async => 'Examen: ${await titreDu(v['dossierId'])}',
  ),
)
```

Quatre cibles, toutes optionnelles : `value`, `options`, `visible`, `bounds`.

**Ce que le socle prend en charge, et qui justifie que ce soit là plutôt que chez vous** :

- **la sérialisation des résolutions asynchrones** — jeton de génération **par champ cible** :
  deux sélections rapprochées qui se résolvent dans le désordre ne s'écrasent plus ;
- **les cycles** — `assert` nommant le cycle en debug, garde de réentrance en release ;
- **la politique d'écrasement** — `always` ou `ifPristine`, **obligatoire à la déclaration**.

**Rien à migrer** : `derivedFrom` est `null` par défaut.

### Ce que l'investigation a montré, et qui peut vous intéresser

Nous avons instruit le motif dans les quatre applications. Chez vous, **trois occurrences** sur
trois formulaires distincts (établi par recherche, pas par impression) :

- `apps/lex_douane_admin/…/send_user_notification_dialog.dart:84` — `type` → titre **et** corps ;
- `apps/lex_douane_admin/…/hierarchy_level_builder.dart:45` — niveau coché → entrée de numérotation ;
- `packages/lex_ui/…/objective_selection_step.dart:143` — `type` → valeur **et bornes** de validateur.

Un détail qui nous a frappés : `send_user_notification_dialog.dart:76` sait mesurer si
l'utilisateur a touché le champ (`_isDirty`) — mais ne s'en sert **que** pour le garde-fou de
fermeture, pas pour freiner la dérivation. C'est exactement ce que `ZDerivationOverwrite.ifPristine`
exprime désormais en une ligne.

Vos trois cas relèvent de `value` + `bounds` et sont exprimables tels quels.

---

## 3. ⚠️ Cinq limites, déclarées

1. **`ZStepperEdition` n'applique pas `visible`** (il est le seul écrivain de `visibleFields`) —
   un `assert` nomme les champs ignorés. `value`/`options`/`bounds` y fonctionnent normalement.
2. Les **bornes de DATE** dérivées passent par le même canal mais **n'ont pas été exécutées**.
3. Le **buffer texte n'est réécrit que hors focus** — divergence connue avec le comportement
   legacy, non traitée.
4. `derivedFrom` **n'est pas émis par le générateur** (closures) : spec à la main ou `copyWith`.
5. `bounds` ne couvre que **min/max**.

---

## 4. Aussi dans ce tag

Trois correctifs sur `ZStudyToolsItemCard` (`zcrud_study`), sans effet si vous ne l'utilisez pas :
le slot `progress` ne lève plus sur un indicateur linéaire nu ; la forme de la carte respecte
`CardThemeData.shape` ; l'éviction de `trailing` pendant un traitement devient une politique
surchargeable.

---

## 5. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates) · `zcrud_core` **1063/1063** ·
`zcrud_study` **540/540** · `zcrud_document` **204/204**.

---

## 6. Si vous voyez une affirmation invérifiable, dites-le

Sept affirmations écrites de notre côté sans avoir été exécutées ont été corrigées par les CR
d'IFFD — dont une instruction d'écriture en production (§1) et une décision d'architecture
entière (AD-57, cf. `docs/handoff-lex-v0.5.1.md`). Le même réflexe de votre part vaut mieux que
notre relecture.

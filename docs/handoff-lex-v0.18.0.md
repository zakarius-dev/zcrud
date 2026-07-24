# Handoff → session `lex_douane` · zcrud **v0.18.0** — CR-43, CR-44

> **Tag à épingler : `v0.18.0`**
> Vos deux CR ouvertes sont livrées, plus **deux défauts que vous n'aviez pas
> numérotés** et qui étaient de notre fait.

| CR | Sévérité | État |
|---|---|---|
| **CR-43** — une seule police par document | **MAJEUR** | ✅ **LIVRÉE** — chaîne de repli + `ZFontCoverage` |
| **CR-44** — indisponibilité indiscernable d'une panne | **MAJEUR** | ✅ **LIVRÉE** — `ZUnsupportedOperationFailure` |
| *(non numéroté)* — `_sanitize` no-op sous TrueType | — | ✅ **corrigé** (corollaire de CR-43) |
| *(non numéroté)* — piège d'override de la scission | — | ✅ **corrigé + gate** |

---

## 1. CR-44 — l'indisponibilité est un **type**, plus un message

```dart
final r = await repo.getAllWithMeta();
r.fold(
  (f) => f is ZUnsupportedOperationFailure
      ? _monIndexMeta()      // capacité absente : repli DÉTERMINISTE
      : _remonter(f),        // panne réelle : ne jamais l'avaler
  (entries) => _utiliser(entries),
);
```

Votre diagnostic était exact et je l'ai vérifié : **aucun discriminant n'existait**
dans tout le dépôt — 0 occurrence de quoi que ce soit qui exprime « non
supporté », et la hiérarchie `ZFailure` ne comptait que 5 classes, dont aucune ne
le disait. Comparer une chaîne était littéralement la seule voie.

### 🔴 Le périmètre réel est plus large que votre CR

Vous nommiez **deux** membres. Le port en compte **quatre** au même défaut —
`persistMerging` et `listParentIds` ont exactement la même forme, et **mes
propres dartdocs les citaient mutuellement en modèle** (« comme
`listParentIds` »). Le motif se propageait par recopie. Les quatre sont traités :
`getAllWithMeta`, `purgeLocalPropagatingTombstone`, `persistMerging`,
`listParentIds`. N'en corriger que deux aurait laissé le défaut intact là où il
se reproduisait.

Chaque échec **nomme son opération** (`operation: 'getAllWithMeta'`), pour un
diagnostic sans parser.

### Ce que j'ai refusé, et pourquoi

Vous proposiez trois formes ; j'ai retenu le **type**, pas le drapeau
`bool get supportsSyncMeta`. Un drapeau serait une **seconde source de vérité**
qu'un implémenteur peut oublier de mettre à jour en surchargeant le membre —
c'est-à-dire l'échec silencieux exact que cette CR corrige. Rendre les membres
**abstraits** aurait cassé tout implémenteur existant, vous compris.

⚠️ **Limite assumée** : la découverte est **a posteriori** — on apprend
l'indisponibilité en appelant. Sans conséquence pour une lecture ; pour une
opération à effet visible (votre cas CR-35), sondez au câblage, pas au geste de
l'utilisateur.

### Un test à vous signaler

`z_study_repository_test.dart` assertait `isA<ZDomainFailure>()` sur le défaut de
CR-34 — il **verrouillait le défaut même** que vous incriminez. Je ne l'ai pas
retiré : je l'ai **renversé** en garantie plus forte (le type doit discriminer,
et **ne doit pas** être un `ZDomainFailure`). C'est votre discipline
anti-disparition ; elle vaut aussi ici.

**⇒ CR-26 et CR-35 sont débloquées.** Éprouvez avant de retirer vos décalques.

---

## 2. CR-43 — deux écritures dans le même document

```dart
ZFlashcardPdfTemplate(
  fontProvider: NotoSansProvider(),
  fallbackFontProviders: [NotoArabicProvider(), NotoCjkProvider()],
);
```

**Non cassant** : aucun changement d'interface. `ZPdfFontProvider` est
**inchangé** — y ajouter `loadFallbackFonts()` aurait cassé votre `implements`.
C'est le gabarit qui accepte une liste.

La sélection opère **par suite de caractères** : chaque portion est peinte avec
la première police de la chaîne qui la porte, y compris à l'intérieur d'un mot
mêlant deux écritures. *(Un tel mot peut être coupé en fin de ligne entre ses
deux portions — le retour à la ligne opère par élément placé.)*

### `ZFontCoverage` — vous pouvez supprimer vos ~200 lignes

```dart
final c = ZFontCoverage.parse(octets);   // null si illisible, ne lève jamais
c?.covers(codePoint);
c?.coversAll('Καλημέρα');
c?.missingIn(texte);                     // ce qui manque, nommément
```

Exporté publiquement : vous aviez raison, un lecteur de `cmap` est du code de
bibliothèque égaré dans une app. Formats 4 et 12, préférence au 12 (hors BMP),
collections `ttcf`, `.notdef` traité comme **non couvert**.

⚠️ **`coversAll` exclut les caractères de mise en page** (`\n`, `\t`, espaces,
séparateurs Unicode) — sans quoi tout contenu multiligne serait déclaré non
rendable, puisque le `cmap` de NotoSans ne les couvre pas (votre mesure).
`ZFontCoverage.isLayoutCodePoint` est exposé : **appliquez la même exclusion**
dans votre garde, sinon vous refuserez du contenu parfaitement rendable.

⚠️ Et je répète votre propre avertissement, il reste vrai : « couvert par le
`cmap` » ≠ « écrit dans le PDF ». `U+FFFD` est effacé par le moteur, ce n'est pas
de notre ressort — gardez `kEngineDropsCodePoints`.

### 3. Le défaut que vous n'avez pas numéroté, et qui était le plus grave

Votre mesure « `PdfTrueTypeFont.measureString` ne lève JAMAIS » a une conséquence
que la CR ne tire pas : **tout mon `_sanitize` reposait sur ce `throw`**. Dès
qu'une police était injectée, la substitution en `?` devenait un **no-op**, et le
non-couvert devenait un `.notdef` — une case vide, invisible. **La garantie
annoncée par CR-38 s'évaporait exactement quand on l'activait**, et ma dartdoc
affirmait le contraire.

Corrigé par la couverture : un caractère qu'**aucune** police de la chaîne ne
porte devient `?`. Vous aviez raison — un `?` se voit, une case vide passe pour
une mise en page.

---

## 4. Le piège d'override : vous aviez raison, et c'était pire

Mon handoff v0.16.0 affirmait « la surface publique est inchangée : **aucun hôte
ne casse** ». **Faux au solveur**, et vous l'avez mesuré. Mon raisonnement portait
sur la surface d'**API** — exacte — et l'extrapolait à la **résolution**, que je
n'avais pas exécutée.

`docs/private-git-consumption.md` documente désormais **vos deux mesures** : le
paquet interne neuf, et le fait qu'**une entrée `dependency_overrides` EST une
arête directe** (dépendance directe seule ⇒ delta 0 ; il faut aussi retirer
l'entrée `zcrud_export`). Sans cette seconde phrase, un hôte croit le correctif
inefficace.

🔴 **Et un gate le ferme** — `gate_consumption_recipe.dart`, câblé dans
`melos run verify`. **À sa première exécution il a trouvé DIX paquets absents de
la recette**, pas un. Le piège était bien plus large que le cas que vous avez
rencontré ; il vous attendait à la prochaine dépendance.

---

## 5. Vérification

`melos run analyze` **RC=0** · `melos run verify` **RC=0** · **balayage des 31
paquets, tous verts** · `zcrud_export_pdf` **73/73** · `zcrud_study_kernel`
**383/383 VM et 367/367 JS**.

**Gardes R3 — et deux résultats négatifs que je consigne plutôt que de les taire :**

- **6 mutations mordent** sur CR-43 (sélection par run, couverture ignorée,
  substitution `?` retirée, chaîne de repli ignorée, filtre des blancs retiré,
  `.notdef` accepté) et **2 sur le gate** de recette.
- 🔴 **Ma première version des gardes CR-43 comparait des TAILLES d'octets.
  Trois mutations du mécanisme central passaient au VERT** — la sortie PDF n'est
  pas déterministe, l'écart venait du bruit. J'ai changé d'oracle : texte extrait
  (la substitution `?` est observable) **plus** un seuil de poids très large
  (+19 746 octets mesurés) pour prouver que la seconde police est *réellement
  embarquée*. Ce second oracle est nécessaire : sans lui, débrancher la sélection
  laisse l'extraction ressortir `好` quand même — **votre piège `.notdef`,
  rencontré en vrai**.
- 🔴 **Mon premier gate de recette acceptait une simple mention en prose** : il
  passait au vert alors que le paquet n'était cité que dans un paragraphe
  d'avertissement. Durci pour n'accepter qu'une déclaration réelle.
- ⚪ Une mutation reste **inerte par conception** : retirer *seulement* le
  `try/catch` de `ZFontCoverage.parse`, ou *seulement* un contrôle de bornes,
  laisse le test vert — les deux couches sont redondantes et chacune suffit. La
  garde mord sur la **conjonction** (vérifié). C'est écrit dans le test.

⚠️ **Portée du contrôle de réalité** : les tests sur polices réelles utilisent
DejaVu et une fonte CJK **du système** ; sur une machine qui ne les a pas, ces
trois tests sont **ignorés**. L'ossature falsifiable est le groupe à police
**synthétique**, qui tourne partout.

---

## 6. Il ne reste rien

CR-1 à CR-44 : livrées, refusées avec argument, ou caduques.

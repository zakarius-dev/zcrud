# Prochaine itération « Formulaire » — périmètre (capture des consignes owner)

> Statut : **capture de périmètre**, pas encore un brief/PRD. Alimente le futur cycle BMAD de
> planification, ancré sur l'étude d'intégration `STUDY.md` (exploration DODLP en cours).
> Ne rien implémenter ad-hoc ici : chaque item devient une **story BMAD** (les touches à
> `zcrud_core` restent sérialisées, une story à la fois).

## Décisions VERROUILLÉES par le owner (2026-07-18)

1. **`awesome_select` = FORK.** On adopte `awesome_select` via un **fork maintenu par nous**
   (élimine le risque du `ref: master` flottant non-pub.dev), enveloppé derrière un
   `ZFieldWidgetBuilder` dans un satellite (jamais `zcrud_core`, AD-1). Mécanique exacte
   (fork GitHub épinglé vs vendoring dans un package du monorepo) = décision de la phase architecture.
2. **PARITÉ DODLP TOTALE.** Objectif : **supporter TOUT ce qui était possible dans DODLP**. Il n'y a
   plus de gap « optionnel / basse priorité » — chaque type de champ et chaque variante rendus par
   DODLP entrent dans le périmètre : couleur (roue/opacité/multiple via `flex_color_picker`), média
   (`image_picker`+`image_cropper`+`camera`+`video_thumbnail`), fichier (`file_picker`+`open_file`),
   **rich-text HTML WYSIWYG** (`html_editor_enhanced`) + rendu HTML (`flutter_html`), PIN (`pinput`),
   autocomplétion, table éditable (`editable`), tags (`flutter_tags`), signature, `dateRange`,
   réordonnancement (`drag_and_drop_lists`), et `awesome_select` (select/radio/relation/multiselect).
   La livraison peut être **phasée** (MVP champs de base → média/rich/WYSIWYG → finitions), mais la
   **parité totale est l'état-cible non négociable**, pas un sous-ensemble.

## Consignes owner (verbatim condensé, 2026-07-17)

1. **Harnais de parité visuelle bout-en-bout** : répliquer **≥ 6 formulaires fonctionnels de DODLP**
   dans l'**app Exemple** (`example/`) pour vérifier de bout en bout la **non-modification visuelle** à la
   migration.
2. **Page « showcase » exhaustive** : une nouvelle page de l'app Exemple qui **couvre TOUTES les
   fonctionnalités de zcrud avec toutes les variantes possibles** (référence de complétude + parité).
3. **Champ `dateRange` manquant** : à **ajouter** à zcrud (absent confirmé, grep négatif RC=1).

---

## 1. Harnais de parité — 6 formulaires DODLP (shortlist PROVISOIRE)

> À **finaliser après l'exploration** (`STUDY.md`) : elle dira quels formulaires exercent le plus
> richement `flutter_form_builder` / `awesome_select` / `intl_phone_number_input` / `country_picker` /
> `flutter_switch` / aération. Objectif de sélection : **couverture maximale de types de champs** sur 6 forms.
> DODLP = 54 entités `DynamicModel` ; module CRUD `lib/modules/data_crud/` (repo `dodlp-otr`, LECTURE SEULE).

| # | Formulaire DODLP (entité) | Module | Types de champs saillants (à confirmer) |
|---|---|---|---|
| 1 | **Cargaison** | `pia` | text, select, dateTime, subItems (conteneurs), relation |
| 2 | **DemandeDepotage / DepotageArticle** | `vido` | subItems, relation (`crudDataSelect`), number, switch |
| 3 | **Consignee / BoatService** | `bmd` | phone, country, dateTime, switch, select |
| 4 | **AuthProfileData** | `auth/profile` | phone, country, image/file, text |
| 5 | **ArticleBep / Cotation** | `sse` | number, select, relation, markdown |
| 6 | **ConvocationBmd / Event / Task** | `bmd`/`workflow` | dateTime, **dateRange (candidat)**, relation, multiSelect |

Contraintes du harnais :
- Vit dans **`example/`** (app de démonstration), jamais dans un package.
- Reproduit le **rendu visuel** DODLP (aération incluse, cf. spacing spec de l'étude) via les adaptateurs
  de champs issus de l'étude d'intégration — **aucune régression visuelle** = critère d'acceptation.
- Données **fictives** (aucune dépendance backend DODLP), aucun secret.

## 2. Page « showcase » exhaustive — matrice de couverture

Une page de l'app Exemple montant **chaque `EditionFieldType` × chaque variante**. Source de vérité de
l'enum : `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`.

Couverture attendue (au moins) — chaque ligne = ≥ 1 champ démontré, avec variantes :
- **text** (simple, préfixe/suffixe, obscurci) · **multiline** (min/maxLines) · **number/integer/float**
  (bornes, pas) · **boolean** (switch DODLP vs Material) · **dateTime** · **time** · **`dateRange` (NOUVEAU)**
- **select / radio / checkbox** (options statiques) · **relation** (`crudDataSelect`, source runtime) ·
  **rowChips** · **tags** · **multiSelect** (awesome_select multi)
- **subItems** (mini-CRUD imbriqué) · **dynamicItem** (sous-formulaire) · **file / image / document**
- Champs spécialisés satellites : **markdown** (zcrud_markdown) · **phone** (zcrud_intl) · **country**
  (zcrud_intl) · **geo/geofence** (zcrud_geo)
- États transverses par champ : **read-only**, **désactivé**, **erreur de validation**, **valeur initiale**,
  **conditionnel** (visibilité dépendante), **RTL**, **thème clair/sombre**.

Sert de **preuve de complétude** ET de banc SM-1 (taper 100 caractères ne reconstruit que le champ courant).

## 3. Champ `dateRange` — notes d'ajout (future story, touche `zcrud_core`)

Absence confirmée (`grep -rniqF dateRange packages/*/lib` → RC 1). Patron d'ajout (aligné sur `dateTime`) :

- **Enum** : ajouter `dateRange` à `EditionFieldType` (`.../domain/edition/edition_field_type.dart`),
  près de `dateTime`/`time`. Valeur d'enum en camelCase.
- **Valeur** : une paire `(début, fin)` — modéliser proprement (ex. un `ZDateRange{start, end}` sérialisable,
  ISO-8601, désérialisation défensive AD-10 ; `end >= start` validé, `null` toléré si champ optionnel).
- **Widget** : famille dans `.../presentation/edition/families/` (patron `z_date_field_widget.dart`),
  monté sous `ZFieldListenableBuilder` (SM-1, rebuild granulaire) ; picker de plage (parité DODLP à vérifier —
  DODLP a-t-il un `dateRange` natif ? sinon c'est un **gain** de zcrud, pas une parité). Directionnel AD-13.
- **Spec / génération** : le générateur (`zcrud_generator`) doit produire le `ZFieldSpec` pour ce type
  (validateurs, (dé)sérialisation) ; test de rétro-compat de sérialisation (gate CI).
- **Showcase + harnais** : le champ `dateRange` apparaît dans la page showcase (variantes : ouvert/borné,
  min/max, optionnel) et là où un formulaire DODLP l'appelle (form #6 candidat).

> ⚠️ `dateRange` modifie `zcrud_core` (enum + widget + spec) → **story BMAD dédiée**, sérialisée
> (une seule story touche `zcrud_core` à la fois). À planifier dans le futur epic, pas en marge de me-2/me-3.

---

## Séquencement proposé (à valider par le owner au moment du brief)

1. Terminer le cycle ME en cours (**me-2** en review, **me-3** à suivre) — indépendant de cette itération.
2. **Exploration DODLP** → `STUDY.md` (en cours) = reconnaissance d'intégration des packages + spacing spec.
3. Cycle BMAD de planification de l'itération « Formulaire » : brief → PRD → architecture → epics/stories,
   **incluant** : (a) adaptateurs de champs issus de l'étude, (b) `dateRange`, (c) page showcase exhaustive,
   (d) harnais de parité 6 formulaires DODLP dans `example/`.
4. Implémentation story par story (cycle strict), `zcrud_core` sérialisé.

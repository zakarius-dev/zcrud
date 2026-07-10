# Code Review — E11a-2 : `zcrud_intl` (téléphone / pays / adresse)

- **Story** : `e11a-2-zcrud-intl-telephone-pays-adresse.md` (12 ACs)
- **Statut** : review
- **Baseline** : `fe203b90bb95a659063452af4cf584f66e7bab0f`
- **Skill** : `bmad-code-review` (invoqué via le tool `Skill` ; step-01 chargé). Revue adversariale — 3 couches (isolation lib, neutralité valeur form, défensif réel).
- **Vérifs rejouées** : `flutter analyze` (zcrud_intl) → **No issues found (RC=0)** ; 1 seul import réel `phone_numbers_parser` (grep `^import`) confiné à `z_phone_codec.dart` ; `countries.json` = **245** pays, 0 flag/dialCode/name manquant, 0 ISO dupliqué ; 0 littéral `Color(`/`Colors.` dans `lib/src`.

## Verdicts synthétiques

| Contrôle | Verdict |
|---|---|
| Isolation lib téléphone (AD-1) | **OUI** |
| Valeur form neutre (E.164 / ISO String / ZPostalAddress) | **OUI** |
| No-secret / no-réseau / no-badCert (AD-12) | **OUI** |
| SM-1 réellement prouvé (voisin figé + focus) | **OUI** |
| Défensif cas réels (AD-10) | **OUI** |
| Anti-fuite instance-par-montage | **OUI** |
| Frontière E11a-2 (pas d'E11b / pas de géocodage réseau) | **OUI** |

**Aucun finding HIGH / MAJEUR.** Les invariants critiques (isolation, neutralité, secrets, SM-1, défensif, cycle de vie) sont réellement tenus et testés. Restent 2 MEDIUM et quelques LOW.

## Findings

### MEDIUM-1 — `ZCountryCatalog.load()` sans dé-duplication de la charge en vol
`packages/zcrud_intl/lib/src/data/z_country_catalog.dart:76-95`

**Preuve.** `load()` ne mémoïse pas le `Future` en cours : la seule garde est `if (_cache != null) return`, qui n'est vraie qu'**après** résolution. Or `ZCountryPickerField.initState` (`z_country_picker_field.dart:81-85`) appelle `catalog.load()` **sans l'attendre**. Deux pickers montés dans la même frame et **partageant le même catalogue asset-backed** (cas normal DODLP : un champ `phoneNumber` **ou** `country` autonome + le picker pays interne au champ `address`) voient tous deux `_cache == null`, incrémentent `_assetReads` (→ 2) et exécutent chacun `rootBundle.loadString` + `_parse` des 245 pays.

**Impact.** Double (voire triple) lecture/parse de l'asset — l'invariant documenté « chargé **une seule fois** (paresseux + cache) » (doc de classe, AC4) est violé dès que ≥2 champs intl coexistent dans un formulaire. Pas de corruption (les commits sont idempotents, le cache final est cohérent), donc MEDIUM et non MAJEUR. **Non testé** : le seul test multi-montage (`z_intl_field_widgets_test.dart:273` « 2 champs téléphone ») utilise `fromList` (préchargé) → la branche asset concurrente n'est jamais exercée ; `assetReads` n'y est pas observé.

**Remède.** Mémoïser la charge en vol : `Future<List<ZCountryInfo>>? _loading;` retourné aux appelants concurrents, effacé à la résolution — et ajouter un test qui monte deux pickers partageant un catalogue `bundle:` et asserte `assetReads == 1`.

### MEDIUM-2 — Cibles `Semantics(button/textField)` rendues inopérables par `ExcludeSemantics`
`packages/zcrud_intl/lib/src/presentation/z_country_picker_field.dart:133-172` (trigger), `:221-234` (items de liste) ; `packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart:201-224` (champ numéro)

**Preuve.** Le patron employé est `Semantics(button: true, label: …, value: …) > ExcludeSemantics(child: InkWell(onTap: _toggle))` (idem `ListTile(onTap:)` pour les items, et `Semantics(textField: true) > ExcludeSemantics(child: TextField)` pour le numéro). `ExcludeSemantics` retire du sous-arbre l'action sémantique de tap/édition de l'`InkWell`/`ListTile`/`TextField`, mais le nœud `Semantics` englobant **ne câble aucun `onTap`** (ni `onTapHint`). Il en résulte un nœud « bouton » **sans action d'activation** exposée.

**Impact (AD-13).** Les cibles sont bien ≥48 dp visuellement, mais un utilisateur de lecteur d'écran ne peut **pas activer** le sélecteur de pays ni choisir un item (le double-tap d'activation n'a pas d'action), et le champ numéro n'expose pas ses sémantiques éditables (valeur/curseur). C'est un défaut d'**opérabilité** a11y, pas seulement cosmétique. Les tests AC8 n'assertent que la **présence du label** (`bySemanticsLabel`) et la **taille** (`getSize`), jamais les actions → gap réel non couvert.

**Remède.** Soit fournir l'action sur le nœud englobant (`Semantics(button: true, onTap: _toggle, …)`), soit remplacer `ExcludeSemantics` par `MergeSemantics` (fusion de l'action native de l'`InkWell`/`TextField` avec le label). Ajouter un test d'action sémantique (`SemanticsAction.tap`).

### LOW-1 — Factories `.builder()` créent un catalogue par défaut distinct si `catalog` omis
`z_phone_field_widget.dart:70`, `z_country_field_widget.dart:59`, `z_address_field_widget.dart:57`

Chaque `.builder()` sans `catalog` fait `catalog ?? ZCountryCatalog()` → si l'app enregistre les 3 kinds sans injecter un catalogue partagé, elle obtient **3 instances distinctes** ⇒ 3 lectures d'asset. La story recommande l'injection (et les tests l'injectent partagé), donc acceptable, mais l'API invite au gaspillage. Envisager une note de doc ou un catalogue partagé par défaut.

### LOW-2 — `ZPhoneCodec._isoOf` : scan linéaire de `IsoCode.values` à chaque appel
`z_phone_codec.dart:24-31`

`dialCodeOf` (et `parse`) balaient les ~250 `IsoCode.values` à chaque invocation ; `parse` rappelle `dialCodeOf` (double scan). Négligeable à l'échelle d'une frappe, mais une petite `Map<String,IsoCode>` mémoïsée serait plus propre.

### LOW-3 — Asymétrie de clé `iso` vs alias `isoCode` dans `ZCountryInfo`
`z_country_info.dart:43-48` vs `:55/61`

`toMap` écrit la clé `'iso'` / `'flag'` tandis que `fromMapSafe` accepte `iso`|`isoCode` et `flag`|`flagEmoji`. Le round-trip interne est stable (testé), mais l'asymétrie écriture/lecture pourrait dérouter un consommateur externe. Nit.

### Nit — Rechargement d'un numéro persisté « e164 seul »
`z_phone_field_widget.dart:104-106` — `initState` ne peuple le champ numéro que depuis `nationalNumber`. Un `ZPhoneNumber` persisté sans `nationalNumber` (e164 seul, interop) afficherait un champ vide malgré une valeur stockée. Le codec renseigne `nationalNumber` pour tout numéro valide, donc le cas est marginal. Optionnel : dériver l'affichage depuis `e164` en dernier recours.

## Points vérifiés positivement (adversarial)

- **Isolation (AD-1)** : `phone_numbers_parser` déclaré au seul `pubspec.yaml` de `zcrud_intl`, **1 seul importateur réel** (`z_phone_codec.dart`, gate positif `hasLength(1)` réel). Aucun type `PhoneNumber`/`IsoCode` en signature publique ni en valeur de tranche (`_isoOf` privé). Barrel n'exporte pas le pont (`z_phone_codec` non exporté, testé). `zcrud_core/pubspec.yaml` sans lib intl (gate + assertion). CORE OUT=0 (rapport orchestrateur).
- **Valeur form neutre** : `country` → `String` ISO alpha-2 (`z_country_field_widget.dart:110`) ; `phoneNumber` → `ZPhoneNumber` E.164 (`.international` sans espaces confirmé par test vert `+33612345678`) ; `address` → `ZPostalAddress`. Aucun objet de lib écrit dans le `ZFormController`.
- **No-secret (AD-12)** : gate regex (clé Google `AIza…`, `badCertificateCallback`, `https?://`) rejoué vert ; MVP hors-ligne (asset local + parse), zéro réseau.
- **SM-1 réel (AD-2)** : test AC6 #1 prouve par **compteur de build du voisin inchangé** (`buildB == buildBBefore`) + `initA == 1` + `focusNode.hasFocus` après ≥2 frappes ; #2 rejoue le focus via le **vrai dispatch `DynamicEdition`**. Non-proxy. Sync guardée hors focus (`if (_hasNumberFocus) return`, `if (_hasFocus) return`) correcte.
- **Défensif cas RÉELS (AD-10)** : numéro « abc », pays « ZZ », map adresse corrompue (`{'line1':99,'city':[1]}`), tranche `null`, `String` absurde, asset absent (throw bundle), JSON malformé, JSON non-liste, entrées non conformes → tous couverts, `returnsNormally`/`takeException() == null`. `fromMapSafe` non-map → `null` partout.
- **Anti-fuite / instance-par-montage** : tous les `TextEditingController`/`FocusNode` disposés (3 widgets + picker) ; test « 2 champs téléphone → contrôleurs distincts » (`identical == false`) ; démontage post-frappe sans exception. Catalogue immuable partagé légitimement (lecture seule).
- **Registre** : kinds `phoneNumber`/`country`/`address` alignés sur `field.type.name` ; registre peuplé → widget intl (×3), registre vide → `ZUnsupportedFieldWidget` sans crash. Aucun fichier `zcrud_core` touché.
- **AD-13** : thème via `ZcrudTheme.of` (repli `Theme.of`), `label()` l10n, insets/aligns directionnels (gate RTL statique rejoué), rendu des 3 champs sous `Directionality.rtl` sans exception, cibles ≥48 dp (gate `getSize`). *(cf. MEDIUM-2 pour l'opérabilité a11y.)*
- **Frontière** : téléphone/pays/adresse uniquement ; pas de devise/états/provinces (E11b), pas de géocodage réseau. `zcrud_markdown`/`example` non touchés.

## Finding le plus grave

Le catalogue pays (`ZCountryCatalog.load`) ne dé-duplique pas la charge en vol : deux champs intl partageant le même catalogue dans un formulaire (cas normal DODLP) déclenchent chacun une lecture+parse de l'asset des 245 pays, violant l'invariant « chargé une seule fois » — sans corruption, mais non couvert par les tests (le multi-montage testé utilise un catalogue préchargé).

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MEDIUM | ✅ **corrigé** | `ZCountryCatalog.load()` mémoïse le `Future` en vol (`_loading`, effacé à la résolution) → appels concurrents reçoivent le MÊME Future. Test : 2 `load()` concurrents → `identical(f1,f2)`, `stringLoads==1`, `assetReads==1` ; 3ᵉ sert le cache. |
| 2 | MEDIUM | ✅ **corrigé** | A11y opérable (AD-13) : action recâblée sur le `Semantics` englobant (`onTap`, `SemanticsAction.tap`) pour le picker pays + items ; champ tél expose la sémantique éditable native du TextField. 3 tests : action tap **déclenchable** (ouvre picker/sélectionne) + champ éditable exposé. |
| 3 | LOW-1 | ✅ corrigé | `sharedDefaultCountryCatalog()` (instance module-level lazy) partagée par les 3 `.builder()` → 1 lecture d'asset pour les 3 kinds. |
| 4 | LOW-2 | ✅ corrigé | Index `nom→IsoCode` mémoïsé 1× dans `ZPhoneCodec` (remplace le scan linéaire). |
| 5 | LOW-3 | ✅ doc+test | Clés canoniques `iso`/`flag` verrouillées + round-trip symétrique testé. |
| 6 | nit | 🟡 documenté | Affichage amorcé depuis `nationalNumber` ; pas de dé-normalisation E.164 au montage (éviterait double indicatif). |

**Vérif verte rejouée (orchestrateur, ciblée zcrud_intl)** : `flutter analyze` **0 issue** (APIs a11y migrées non-dépréciées) · `flutter test` **59/59** (53→59, +6) · **CORE OUT=0** · dry-run OK.

**Verdict final** : 2 MEDIUM + 3 LOW corrigés (tests à l'appui) + nit documenté. Story E11a-2 → **done**.

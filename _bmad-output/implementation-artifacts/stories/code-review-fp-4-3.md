# Code-review — fp-4-3 (HTML WYSIWYG) — correction des findings

Périmètre corrigé : `packages/zcrud_html/` UNIQUEMENT. Aucun autre package touché.
Aucun commit, aucun `git checkout/restore/stash`, aucun `dart format`.

## Tableau finding × statut × preuve

| Finding | Sévérité | Statut | Preuve |
|---|---|---|---|
| **MED-1** — `dispose()` jette le commit débouncé en attente (perte de données) | MEDIUM (R3 confirmé) | **CORRIGÉ** | `z_html_commit_debouncer.dart` : `dispose()` appelle désormais `flush()` (commit du `_pending`) AVANT le nettoyage. Test porteur ajouté (`dispose FLUSHE le commit débouncé en attente`) : **ROUGE avant** correctif (`Expected ['<p>dernier</p>']` / `Actual: []`, prouvé en réintroduisant l'ancien `dispose`), **VERT après**. Test d'idempotence ajouté (dispose après flush ⇒ pas de double commit). |
| **MED-2** — prose « HTML corrompu ⇒ éditeur/rendu vide » FAUSSE | MEDIUM (la prose ment) | **CORRIGÉ (prose)** | Comportement INCHANGÉ (passthrough best-effort correct, AD-10 tient : jamais de throw). Prose corrigée aux emplacements : `z_html_view.dart` (invariant AD-10 l.6-7 + dartdoc `html`), `z_html_editor_field.dart` (l.18 dartdoc + `_incoming` + commentaire `initialText`), `z_html_wysiwyg_registration.dart` (commentaire lecteur-prioritaire). Nouveau libellé : « non-`String`/`null` ⇒ vide ; HTML malformé (`String`) ⇒ best-effort, jamais throw ». |
| **LOW-3** — la garde de confinement ne teste pas AD-40 (aucun type tiers en surface publique) | LOW | **CORRIGÉ** | `z_html_confinement_test.dart` : nouveau **volet 3** scanne `lib/zcrud_html.dart` (barrel) — (a) aucun ré-export direct de `html_editor_enhanced`/`flutter_html` ; (b) aucun symbole `show`é qui soit un type tiers banni (`HtmlEditorController`, `Html`, `Style`…). Contre-preuve R12 : un `show HtmlEditorController` synthétique ⇒ la garde rougit ; un ré-export direct tiers ⇒ rougit ; surface saine ⇒ verte ; export commenté ⇒ rien. Anti-vacuité : le barrel doit déclarer ≥1 export. |

## Vérification verte (rejouée réellement sur disque)

- `dart analyze packages/zcrud_html` → **RC=0** (3 `info` `prefer_initializing_formals` PRÉ-EXISTANTS sur le constructeur non touché — non-fatals, langage interdit le formal init d'un param nommé privé).
- `flutter test packages/zcrud_html` → **RC=0, 26/26 verts** (21 initiaux + 3 debouncer [MED-1 non-perte, MED-1 idempotence, existants] + 2 confinement volet 3 [LOW-3]).
- `flutter test .../z_html_confinement_test.dart` isolé → RC=0, 6/6 (volets 1+2+3).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK, CORE OUT=0 OK** (inchangé).

## Notes

- MED-1 : `flush()` est idempotent/sûr après `cancel` — `_commitPending` no-op si `_pending == null` ou valeur déjà `_lastSynced`. Le double-nettoyage (`_handle=null; _pending=null`) après `flush()` reste défensif mais redondant.
- MED-2 : aucune modification de comportement runtime — la coercion `_sanitize`/`_incoming` ne portait que sur le TYPE (non-`String`/`null`→vide) ; un HTML malformé `String` passait déjà verbatim (flutter_html/Summernote best-effort). Seule la prose mentait.
- LOW-3 : le volet 3 est un scan textuel du barrel (ré-exports directs + symboles `show`) — falsifiable par les deux témoins R12 ; complète (sans remplacer) le grep négatif de `z_html_view_test.dart`.

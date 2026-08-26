# Réfutation — SmartNotes / M-1 « Générer des flashcards depuis une note »

- **Domaine** : Notes intelligentes (SmartNotes) — IFFD @ `65d1af9` vs zcrud `v3.21.0` (`cc276c15`)
- **Affirmation attaquée** : « le socle sait déjà le faire » — toute la chaîne existe
  (port + contrôleur + feuille + aperçu + tags + anti-double-tap), gain annoncé **~225 lignes**.
- **Verdict** : 🔴 **DÉMENTIE**. Les canaux existent, sont exportés et atteignables — mais la
  couverture du besoin **réel** de l'hôte est **partielle et présentée comme totale**, et
  l'inventaire de preuve **rate le site SmartNotes lui-même**.

---

## 1. Ce qui RÉSISTE (vérifié ligne à ligne)

Toutes les citations côté zcrud sont exactes. Rien à redire sur l'existence.

| Symbole | Emplacement vérifié | Statut |
|---|---|---|
| `ZFlashcardGenerationPort` | `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:289` ; `generateFlashcards` `:292` | ✅ conforme |
| `ZFlashcardGenerationRequest` | même fichier `:113` — **9 champs** (`content, count, languageTag, provenance, typesDistribution, instructions, modelId, resolvedSources, extra`) ; `extra` filtré par `zSanitizeExtra` `:209` | ✅ conforme |
| `ZNoteSource` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:93` ; `fromJson` décode `kind=='note'` `:65-66` | ✅ conforme |
| `ZFlashcardGenerationController` | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart:84` | ✅ corps lu intégralement |
| — anti-double-tap | `:149-151` | ✅ |
| — jeton de péremption | `:152` (`++_generation`), `_isStale` `:197` équivalent | ✅ |
| — résolveurs à la SOUMISSION | `:158-184` | ✅ |
| — `catch` sur port qui lève | `:188-195` | ✅ |
| — `Right([])` traité comme échec | `:202-205` | ✅ |
| — cartes éphémères `id: null` | `:263-264` | ✅ |
| — aucune écriture base | `:242` (`onGenerated?.call`) + commentaire `:243` | ✅ |
| `ZFlashcardGenerationSheet` | `z_flashcard_generation_sheet.dart:214` — **12 paramètres** (+`key`) ; `contextSources` `:265` ; controllers créés une seule fois en `initState` `:300-320` | ✅ conforme |
| `ZGenerationSourceOption(resolveContent:)` | même fichier `:62-85` | ✅ conforme |
| `ZResolvedGenerationSource` | `z_flashcard_generation_port.dart:43` | ✅ existe |
| `ZFlashcardGenerationLauncher` | `z_flashcard_generation_sheet.dart:868` ; `resolvedPort` `:893` ; `SizedBox.shrink()` sans port `:902-904` | ✅ conforme |
| `zDefaultGenerationCount` / `zClampGenerationCount` | `z_flashcard_generation_defaults.dart:30` / `:39` | ✅ conforme |

**Atteignabilité — OK.** Barrels :
`packages/zcrud_study/lib/zcrud_study.dart:20,26,126,127` et
`packages/zcrud_flashcard/lib/zcrud_flashcard.dart:180` exportent l'ensemble.
`zcrud_study` (`pubspec.yaml:391`) et `zcrud_flashcard` (`:328`) sont des **dépendances déclarées**
d'IFFD, épinglées `ref: v3.21.0`.

**Constat côté hôte — OK.** `ai_generation_zcrud.dart` est bien **absent** (le répertoire
`lib/src/presentation/features/flashcards/zcrud/` existe et contient 12 autres fichiers zcrud,
mais pas celui-là). Et les 10 symboles de génération rendent **0 ligne dans `lib/`** :

```
ZFlashcardGenerationPort      : total=0  dans_lib=0
ZFlashcardGenerationRequest   : total=0  dans_lib=0
ZFlashcardGenerationController: total=0  dans_lib=0
ZFlashcardGenerationSheet     : total=2  dans_lib=0   (commentaires du test de parité)
ZGenerationSourceOption       : total=1  dans_lib=0
ZResolvedGenerationSource     : total=1  dans_lib=0
ZFlashcardGenerationLauncher  : total=0  dans_lib=0
ZNoteSource                   : total=0  dans_lib=0
zDefaultGenerationCount       : total=0  dans_lib=0
zClampGenerationCount         : total=0  dans_lib=0
```

Le test `test/qa-w2/ai_generation_parity_test.dart` fait bien **231 lignes**, recense **4 capacités**,
et `grep -n 'couvertParLeSocle: false'` rend **RC=1**. Il dit lui-même `:57-66` :
« ⚠️ LE BRANCHEMENT RESTE À FAIRE […] Confondre "le socle offre" et "nous consommons" est
précisément le motif "offert, non passé", compté vingt-et-une fois sur ce chantier. »

**C'est exactement le motif que l'affirmation reproduit.**

---

## 2. R1 — L'inventaire de preuve RATE le site SmartNotes (le domaine même de M-1)

L'affirmation cite quatre blocs « vivants supprimés » : `popup_menu_helpers.dart`,
`explain_ai_page.dart`, `chatbot_conversation_screen.dart`,
`ai_flashcards_generator_dialog_widget.dart`.

Aucun n'est un fichier SmartNotes. Le **vrai** site note → flashcards est :

```
lib/src/presentation/features/smartnotes/widgets/smartnote_actions_dialog_widget.dart:100
```

Recensement complet de `generateFlashcardsFromNotes` dans `lib/` — **5 sites, pas 4** :

| # | Site | Lignes mesurées (équilibre de parenthèses) | Cité ? |
|---|---|---|---|
| 1 | `smartnotes/widgets/smartnote_actions_dialog_widget.dart:100-164` | **65** | 🔴 **NON** |
| 2 | `core/widgets/popup_menu_helpers.dart:292-341` | 50 | oui (50 ✔) |
| 3 | `explain_ai/pages/explain_ai_page.dart:661-730` | 70 | oui (70 ✔) |
| 4 | `ai_assistant/screens/chatbot_conversation_screen.dart:807-983` | **177** | oui, annoncé **« ~55 »** 🔴 |
| 5 | `flashcards/widgets/ai_flashcards_generator_dialog_widget.dart:1061-1107` | 47 | oui (~50, ✔) |

**Total réel : 409 lignes**, pas 225. L'affirmation sous-mesure le bloc chatbot de **122 lignes**
et **omet entièrement** le seul bloc qui relève du domaine annoncé.

---

## 3. R2 — Le socle n'a AUCUN chemin correspondant au geste réel de l'hôte

Le geste IFFD SmartNotes (`smartnote_actions_dialog_widget.dart:95-165`) est **un seul tap** :
un `ListTile` « Générer des flashcards » → `Get.back()` → `loadingCallback(true)` →
`generateFlashcardsFromNotes(subject: item.title, notes: item.content, onComplete:)` →
décodage → `saveFolderFlashcards(...)` → `loadingCallback(false)`.
**Aucune feuille, aucun aperçu, aucune confirmation de tags, aucun réglage.**

Le socle n'offre que le chemin inverse. `onGenerated` est appelé **depuis un seul site** :

```
z_flashcard_generation_controller.dart:242   onGenerated?.call(handed, …)
```

… à l'intérieur de `confirmTags`, gardé `:234` par `if (_status != confirmingTags) return;`.
Ce statut n'est atteignable que par `proceedToTagConfirmation()` (`:210-213`), lui-même gardé sur
`preview`. Le lot ne SORT donc jamais du socle sans traverser **aperçu → confirmation de tags**.

**GREP NÉGATIF** — aucun raccourci « one-shot » :

```
$ grep -rn 'quickGenerate\|generateAndCommit\|oneShot\|generateDirect\|skipTagConfirmation\|autoConfirm' \
        packages/zcrud_study/lib/ packages/zcrud_flashcard/lib/
RC=1
```

⇒ Adopter le socle **remplacerait 1 tap par ≥ 4 interactions**. Ce n'est pas « le socle sait déjà
le faire » : c'est « le socle sait faire autre chose ».

---

## 4. R3 — Le contenu de la note ne peut pas être PRÉ-CHARGÉ dans la feuille

`_contentController = TextEditingController();` (`z_flashcard_generation_sheet.dart:304`) — créé
**vide**. Et c'est bien lui qui alimente la requête : `content: _contentController.text` (`:380`).

**GREP NÉGATIF** — aucun paramètre de pré-remplissage dans tout `zcrud_study` :

```
$ grep -rn 'initialContent\|initialNotes\|initialText' packages/zcrud_study/lib/
RC=1
```

La seule voie restante est `contextSources` + `resolveContent`. Mais elle n'est **pas
pré-sélectionnée** : `_selectedContextSources = ValueNotifier(const <ZGenerationSourceOption>{})`
(`:317-318`), et seules les sources **acquises** sont cochées d'office (`:455`, dans `_acquire`).

**GREP NÉGATIF** — aucun paramètre de pré-sélection :

```
$ grep -rn 'preselect\|initialSelect\|selectedContextSources' \
        packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart \
   | grep -v '_selectedContextSources'
RC=1
```

⇒ Pour M-1, l'utilisateur qui vient d'ouvrir le menu **de cette note précise** devrait
**cocher lui-même** cette même note dans une liste. Régression fonctionnelle non signalée.

---

## 5. R4 — `ZNoteSource` est offert mais NON CONSOMMABLE par le mapper canonique d'IFFD

IFFD transporte `noteId` par `extra`, pas par `source` :

- `z_backed_flashcard_repository.dart:154` — `static const String kExtraNoteId = 'iffd_note_id';`
- `:176` — `if (card.noteId != null) kExtraNoteId: card.noteId,`
- `:124` (tableau de correspondance) — `` | `noteId` | `iffd_note_id` | **extra** | aucun homologue de schéma | ``

**GREP NÉGATIF** — le mapper canonique ignore totalement `source` :

```
$ grep -n 'ZNoteSource\|ZFlashcardSource\|source:' \
        lib/src/data/repositories/z_backed_flashcard_repository.dart
RC=1
```

`ZFlashcard.source` existe pourtant et round-trip bien
(`z_flashcard.dart:214`, `toMap` `:258-259`, `fromMap` `:125`, clé réservée `'source'` `:363`).
Mais `fromCanonical` ne le lit **jamais**.

⇒ Si le socle estampille `provenance: ZNoteSource(noteId: note.id)`, la valeur est **silencieusement
perdue** à la frontière IFFD. Conséquence mesurable : les compteurs du filtre de dossier qui
comptent sur `noteId` afficheraient `(0)` —
`folder_flashcards_filter_zcrud_edition.dart:311` et `:516` (`flashcards.where((f) => f.noteId == note.id).length`).
La migration exige donc d'**ajouter** du code hôte, pas d'en supprimer.

---

## 6. R5 — Incompatibilité de contrat : rappel progressif vs `Future<Either>`

Contrat hôte (`lib/src/domain/repositories/ai_repository.dart:316-327`) :

```dart
Future<void> generateFlashcardsFromNotes({
  IffdAiRouterModel? aiRouter, required String subject, required String notes,
  AppUserData? userData, CycleIFFD cycle = CycleIFFD.superieur,
  String? parentSubject, String? generationInstructions,
  Map<QuestionType, double> questionsCounts = const {},
  void Function(AiResponse result, bool completed, {bool hasError}) onComplete,
});
```

`onComplete` est **rappelé plusieurs fois** — l'implémentation le prouve :
`iffd_ai_repository_impl.dart:146` (incrémental), `:160` (`onDone: () => onComplete?.call(`),
`:168`, `:194`… Le drapeau `completed` existe précisément parce que le flux est progressif.

Contrat socle : `Future<ZResult<List<ZFlashcard>>> generateFlashcards(request)` (`port:292-294`).

**GREP NÉGATIF** — aucune notion de flux dans la chaîne de génération :

```
$ grep -rn 'Stream<\|onChunk\|onPartial\|onProgress' \
    packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart \
    packages/zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart \
    packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart
RC=1
```

⇒ Un adaptateur hôte (`Completer` + agrégation) doit être **écrit**. Le rendu progressif est perdu.

---

## 7. R6 — `id: null` forcé contre `id: e.id` aux 5 sites

Le contrôleur force `card.copyWith(id: null, source: provenance)` (`:263-264`).
Les 5 sites hôtes conservent au contraire l'identifiant produit par l'IA :

```
smartnote_actions_dialog_widget.dart:124      id: e.id,
popup_menu_helpers.dart:309                   id: e.id,
popup_menu_helpers.dart:724                   id: e.id ?? randomString(),
explain_ai_page.dart:685                      id: e.id,
chatbot_conversation_screen.dart:920          id: e.id,
ai_flashcards_generator_dialog_widget.dart:1080/1160  id: e.id ?? randomString(),
```

Changement de comportement de persistance non signalé par l'affirmation.

---

## 8. R7 — Ce qui reste vraiment aux sites (le gain annoncé ne tient pas)

L'affirmation concède elle-même que `normalizedJsonString` + `json.decode` + `fromMapList`
**descendent** dans le corps du port. Ce qui **survit à chaque site** et n'est pas mutualisable,
parce que différent à chaque fois :

| Site | Persistance | État de chargement | Champs de contexte |
|---|---|---|---|
| smartnote | `saveFolderFlashcards(subject:/folder:)` | `loadingCallback` | `subjectId`, `creatorId`, `noteId` |
| popup_menu | `saveFolderFlashcards(subject:/folder:)` | `loadingCallback` | `subjectId`, `creatorId`, `noteId` |
| explain_ai | **`batchSet(items:)`** | `updateFlashcardsGenerating` | `subjectId`, `folderId`, `subFolderId`, `creatorId` |
| chatbot | (bloc de 177 l.) | **`setNotesFlashcardsGenerating(notesId:, isGenerating:)`** | `folderIds` du contrôleur de chat |
| generator dialog | — | — | `id: e.id ?? randomString()` |

Le bloc chatbot porte en plus une **réparation JSON spécifique** — `data.replaceAll(r'\%', r'\\%')`
avec `try/catch` imbriqués (`chatbot_conversation_screen.dart:~843-870`) — que le corps unique du
port devrait absorber sans la perdre.

⇒ Le « ~225 lignes supprimées » mélange **suppression** et **déplacement**, et sur une base
d'inventaire fausse (409 lignes réelles, site SmartNotes manquant).

---

## 9. Conclusion

Les onze canaux cités **existent**, sont **exportés**, sont **atteignables**, et le contrôleur fait
bien ce que son corps promet (vérifié ligne à ligne, pas sur la dartdoc). Sur ce plan précis
l'affirmation est honnête, y compris dans son avertissement sur le décodage JSON.

Mais l'affirmation dit « **le socle sait déjà le faire** » pour **M-1 SmartNotes**, or :

1. son inventaire de preuve **ne contient pas le site SmartNotes** (65 l., `:100-164`) ;
2. le socle **n'a aucun chemin** pour le geste réel — un tap → génération → persistance
   (GREP NÉGATIF RC=1 sur tout raccourci ; `onGenerated` verrouillé derrière `confirmingTags`) ;
3. le contenu de la note **ne peut pas être pré-chargé** ni la source **pré-sélectionnée**
   (deux GREP NÉGATIFS RC=1) ;
4. `ZNoteSource` est **ignoré** par le mapper canonique d'IFFD (GREP NÉGATIF RC=1) — la migration
   ajoute du code hôte au lieu d'en retirer ;
5. le contrat est **progressif côté hôte**, **non-progressif côté socle** (GREP NÉGATIF RC=1) ;
6. le chiffrage est faux : **409 lignes** réelles, dont l'essentiel **descend** dans le port.

C'est une **couverture partielle présentée comme totale** — la définition même d'une réfutation
selon le protocole. Et c'est le motif « offert, non passé » que le test de parité de l'hôte nomme
lui-même à `:57-66`.

**Reformulation qui, elle, tiendrait** : « Le socle porte les BRIQUES d'un flux de génération
sheet-driven (port neutre, contrôleur robuste, feuille, aperçu, tags, acquisition de sources).
Il ne porte AUCUN chemin one-tap note → cartes persistées, qui est le geste réel des 5 sites IFFD.
M-1 est un **assemblage manquant**, pas une migration : il demande soit un raccourci socle
(pré-remplissage du contenu + pré-sélection de source + saut de l'étape tags), soit un pilotage
sans tête du contrôleur, plus un adaptateur `onComplete` → `ZResult` et une projection
`noteId` ↔ `ZNoteSource` côté hôte. »

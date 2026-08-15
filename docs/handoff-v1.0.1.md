# Handoff **v1.0.1** — un widget peut enfin lire le formulaire qui l'entoure

> **Tag à épingler : `v1.0.1`** — débloque le dernier écran de votre chantier d'édition (un
> écran d'authentification). Paquet porteur : **`zcrud_core`**. Additive : un widget qui ne
> lit rien n'est abonné à rien de plus qu'avant.

---

## 1. Un ornement `.widget` n'était pas aveugle par conception — il l'était par accident

Un ornement `leading`/`prefix`/`suffix` de type `.widget` recevait `null` en guise de valeur,
alors que **le socle tenait déjà celle du champ décoré**. Le commentaire du code affirmait que
l'application devait lire l'état elle-même ; c'était une justification après coup, pas une
décision.

L'ornement reçoit désormais la **valeur courante** de la tranche qu'il orne, et la voit
**changer** avec elle — y compris hissé dans la fiche d'un champ `large`. Il reste un
**affichage** : son `onChanged` demeure inerte, comme vous le demandiez. *Lire n'est pas
écrire.*

Votre cas — un suffixe « Réauthentifier » qui n'a de sens qu'une fois l'ancien mot de passe
renseigné — fonctionne sans détenir l'état hors du formulaire.

## 2. `valueOf` — lire un autre champ, par nom

`ZFieldWidgetContext.valueOf` donne à un champ `EditionFieldType.widget` (ou `custom`), comme à
un ornement, la lecture **par nom** des autres champs du formulaire :

```dart
registre.register('reauth', (context, ctx) {
  final ancien = ctx.valueOf?.call('ancienMotDePasse');
  final actif = ancien != null && '$ancien'.isNotEmpty;
  return TextButton(
    onPressed: actif ? _reauthentifier : null,
    child: const Text('Réauthentifier'),
  );
});
```

Nous avons retenu votre variante plutôt que la publication du `ZFormController` : elle n'expose
que la lecture, et le mécanisme était déjà éprouvé dans le paquet.

**La lecture est réactive et ciblée** : le socle observe les noms que votre builder consulte
réellement, et ne reconstruit que ce champ quand l'une de ces valeurs change. Modifier un champ
que le widget **ne lit pas** ne le reconstruit pas — c'est vérifié par un compteur de builds,
et c'est ce qui distingue une lecture ciblée d'un abonnement global.

**Ce que `valueOf` ne fait pas**, volontairement : pas d'écriture, pas d'accès à l'état complet,
pas de contrôleur publié dans l'arbre. Un nom inconnu rend `null` sans jamais lever. Hors
formulaire (composition manuelle, prévisualisation), `valueOf` vaut `null` — appelez-le avec
`?.call(...)` et prévoyez le repli.

## 3. Une difficulté qui mérite d'être dite

La transposition littérale du mécanisme existant (`ZChoicesResolver`) **a échoué à la mesure**,
et c'est instructif : ce résolveur est une fonction **pure**, appelable immédiatement, tandis
qu'un builder du registre s'exécute au build de *son* widget — **après** que la fenêtre de
traçage s'est refermée. La première tentative rendait donc les gardes de réactivité rouges.

La mécanique retenue inverse le principe : **la lecture est l'inscription**. Le premier appel à
`valueOf(nom)` abonne le champ à cette tranche ; le désabonnement suit le cycle de vie du champ.
Aucun second mécanisme n'a été ajouté, et le contrôleur reste privé.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire. Un widget qui n'utilise ni la valeur d'ornement ni `valueOf`
  se comporte exactement comme avant.
- **Hôte ayant compensé** : si vous **réinjectiez** une valeur depuis un ornement, retirez cette
  écriture — l'ornement est en lecture par contrat, et votre compensation s'ajouterait au socle.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **2028** (+7 gardes), `zcrud_screen` **259** (inchangé).

Six injections R3, toutes rouges **par assertion**. Deux ont dû être **refaites** et le sont :
l'une s'auto-annulait (la lecture d'une tranche la crée, ce qui neutralisait le test), l'autre
ne compilait pas. Restauration par copie vérifiée par sha256 sur cinq fichiers, plus une
comparaison intégrale de l'arborescence, et grep négatif des résidus.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.

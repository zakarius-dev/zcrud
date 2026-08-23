# Handoff v3.7.0 — la feuille de réglages, riche par défaut

> **Date** : 2026-08-23. **Portée** : `zcrud_chat_material`. **Traite** : CR-IFFD-88, émise le
> jour même contre v3.6.0 (IFFD avait épinglé le tag quelques heures après sa publication).

## 1. Ce que v3.6.0 avait laissé

Le point ① de CR-IFFD-87 — « la feuille austère » — a reçu en v3.6.0 une réponse **partielle**, et
l'hôte l'a dit avec exactitude : la partie livrée (`ZChatToolCatalog` + `ZChatMaterialToolsSheet`)
est la bonne pour les **outils d'hôte**, mais les **neuf familles standard** de `ZChatSettingsSheet`
(`header`, `presets`, `responseLength`, `lengthBias`, `computeBudget`, `revealThinking`,
`capabilities`, `corpus`, `unknownEntry`) restaient rendues par les défauts du **cœur** — texte,
graisse, soulignement — et `zcrud_chat_material` n'en habillait qu'une (`zChatMaterialBudgetSlider`).

Constats vérifiés sur disque avant délégation : neuf créneaux (`this.*Builder`, grep) ; un seul
builder Material pour eux ; `ZChatMaterialComposer` ne fait que relayer `onOpenTools` ; les tuiles
du lot C sont liées à `ZChatToolController` et ne servent pas aux familles standard.

🔴 **Le piège évité par l'hôte, à nommer** : IFFD avait écrit un catalogue d'outils qui redéclarait
ses six réglages standard comme `ZChatToolEntry` — **deux états pour un même réglage, dont un seul
part dans la requête** (B-58, déjà vécu deux fois). Retiré avant commit. Cette version rend le
détour inutile : les builders lisent et écrivent `ZChatSettingsController`, et une garde interdit
tout `ZChatTool*` dans les builders standard.

## 2. Ce qui change pour un hôte

### Changement de défaut (hôte passif) — VOULU
Un hôte qui ouvre la feuille par l'assemblage Material sans rien déclarer obtient la feuille
**riche**. C'est l'effet demandé par la CR et par le principe d'owner : *le socle offre le plus de
fonctionnalités partagées complètes possible, pour que les applications écrivent le moins de code
possible.*

### Hôte ayant compensé avec ses propres builders
Ses builders **gagnent** (priorité paramètre > défaut). Rien ne s'additionne. Il peut les retirer
un par un et comparer.

### Ce que l'hôte garde
Les libellés (FR-26 — libellé absent ⇒ affordance absente, jamais un texte du socle), les
catalogues (corpus, capacités, préréglages), `onClose`, et le remplacement de n'importe quel builder.

### Ce que `notebook_settings_iffd.dart` devient : 176 lignes → **31**

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart'
    show ZChatCorpusOption, ZChatSettingsController, ZChatSettingsLabel,
        ZChatSettingsSection, kZChatSettingsSectionCorpus, kZChatSettingsSectionGeneration;
import 'package:zcrud_chat_material/zcrud_chat_material.dart'
    show ZChatMaterialSettingsLabels, ZChatMaterialSettingsSheet;

const List<ZChatCorpusOption> kIffdCorpusCatalog = <ZChatCorpusOption>[
  ZChatCorpusOption(key: 'codeGATT', label: 'Code du GATT'),
  ZChatCorpusOption(key: 'tecCedeao', label: 'TEC CEDEAO'),
  ZChatCorpusOption(key: 'cdcCedeao', label: 'Code des douanes CEDEAO'),
  ZChatCorpusOption(key: 'cdnTogo', label: 'Code des douanes — Togo'),
  ZChatCorpusOption(key: 'cdnNiger', label: 'Code des douanes — Niger'),
  ZChatCorpusOption(key: 'cgiTogo', label: 'Code général des impôts — Togo'),
];

Widget buildIffdNotebookSettingsSheet(
  ZChatSettingsController controller, {
  VoidCallback? onClose,
}) =>
    ZChatMaterialSettingsSheet(
      controller: controller,
      onClose: onClose,
      corpusCatalog: kIffdCorpusCatalog,
      labels: const ZChatMaterialSettingsLabels(all: 'Tous'),
      sections: const <ZChatSettingsSection>[
        ZChatSettingsSection(id: kZChatSettingsSectionGeneration, title: ZChatSettingsLabel.text('Génération')),
        ZChatSettingsSection(id: kZChatSettingsSectionCorpus, title: ZChatSettingsLabel.text('Sources documentaires')),
      ],
    );
```



### Types publics
`ZChatMaterialSettingsSheet` (neuf défauts remplaçables) · `ZChatMaterialSettingsLabels` · `ZChatMaterialSettingsReference` · `ZChatMaterialSettingsSectionHeader` · `zChatMaterialUnknownEntryTile` · primitives `z_chat_material_settings_chips/switches/header`, `z_chat_material_corpus_chips`.

### ⚠️ Précision sur le « changement de défaut »
Il ne joue **que** pour l'hôte qui monte `ZChatMaterialSettingsSheet` (nouveau). `ZChatSettingsSheet` du cœur est **intouchée** : un hôte qui ne change rien ne voit rien changer. La puce « Tous » exige désormais `labels.all` (sur la feuille du cœur elle venait du registre).

### Besoins signalés à `zcrud_chat` (non traités ici)
1. Un `sectionHeaderBuilder` (en-tête de section seul) — faute de quoi le titre est posé au-dessus de la première tuile rendue.
2. Un jeton de raison sur `ZChatCorpusOption`/`ZChatSettingsHostOption.enabled` (résolu ici par clé).
3. 🔴 `ZChatSettingsSheet` **reconstruit tout son corps à chaque changement de tranche** : les abonnements par tranche des builders ne portent que montés seuls. C'est une entorse AD-2 dans le cœur, à traiter dans un lot dédié.

## 3. Vérification
Rejouée par l'orchestrateur, au repos : `zcrud_chat_material` `analyze` propre, **96 tests en 6 s** (72 → +24) ; garde inter-paquets `IconTheme.merge` de `zcrud_core` 6/6 ; 20 injections R3, 20 rouges par assertion, sha256 identiques ; `melos run generate` 0 `.g.dart` modifié ; `melos run verify` **RC=0** (douze gates) sur l'arbre bumpé à 3.7.0.

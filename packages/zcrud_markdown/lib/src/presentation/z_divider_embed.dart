/// Embed **filet horizontal** (`divider`) et **repli d'embed inconnu**.
///
/// ## Le défaut mesuré, et pourquoi il était invisible
///
/// `ZMarkdownCodec` déclare `divider` parmi ses `_kNativeEmbedTypes` : un
/// `---` / `***` / `___` de Markdown produit bien l'op
/// `{"insert": {"divider": "hr"}}`, et l'encodeur sait la réécrire. Le pont
/// existait des deux côtés — **mais aucun `EmbedBuilder` ne savait le RENDRE**.
///
/// Conséquence mesurée en montant `ZMarkdownReader` sur le fragment `***` :
///
/// ```text
/// UnimplementedError: Embeddable type "divider" is not supported by supplied
/// embed builders. […]
/// puis, en cascade :
/// _TypeError: type 'RenderErrorBox' is not a subtype of type
/// 'RenderContentProxyBox?' in type cast   (x4)
/// ```
///
/// Cinq exceptions, écran rouge. Le défaut ne touchait pas que le chat : il
/// frappait **toute** voie rich-text du paquet — lecteur, éditeur, plein-écran —
/// dès qu'un document contenait un filet horizontal. Il est resté invisible
/// parce que les gardes existantes éprouvaient le **codec** (qui, lui, produit
/// l'op correctement) et jamais le **rendu** de l'op produite : un embed déclaré
/// natif par le codec doit avoir un builder, et cela se vérifie au rendu.
///
/// Le filet horizontal est par ailleurs **omniprésent** dans ce que produisent
/// les modèles de langage — ce qui en fait un cas à couvrir en priorité.
///
/// ## Les deux moitiés de la réparation
///
/// 1. [ZDividerEmbedBuilder] rend le `divider` pour de bon (filet thémé).
/// 2. [kZUnknownEmbedBuilder] est le **repli TOTAL** (AD-10) : n'importe quel
///    type d'embed qu'aucun builder ne connaît — un type d'un hôte, un type
///    d'une version future, une op corrompue — dégrade en un rendu discret au
///    lieu de lever. Le premier point corrige le cas connu ; le second ferme la
///    **classe** de défauts, et c'est lui qui compte.
///
/// aucune couleur codée en dur (thème injecté, repli `Theme.of`).
/// AD-13 : `Semantics` explicite, insets DIRECTIONNELS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Clé/type Delta de l'embed filet horizontal — op
/// `{"insert": {"divider": "hr"}}`, produite par `MarkdownToDelta` depuis `hr`.
const String kDividerEmbedType = 'divider';

/// `EmbedBuilder` de rendu du filet horizontal (`---`, `***`, `___`).
///
/// Sans état ⇒ instance `const` STABLE (AD-2 : aucune allocation par
/// (re)build de tranche), comme les builders LaTeX/tableau/média.
class ZDividerEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état, aucune ressource à disposer).
  const ZDividerEmbedBuilder();

  @override
  String get key => kDividerEmbedType;

  /// Rendu BLOC : le filet occupe sa propre ligne.
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final Color color =
        ZcrudTheme.of(context).fieldBorderColor ??
        Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 6),
      child: Divider(height: 1, thickness: 1, color: color),
    );
  }
}

/// Libellé a11y du repli d'embed inconnu (AD-13).
@visibleForTesting
const String kUnknownEmbedLabel = 'contenu non pris en charge';

/// Repli **TOTAL** (AD-10) pour tout type d'embed sans builder.
///
/// Branché sur `QuillEditorConfig.unknownEmbedBuilder`. Sans lui, Quill lève un
/// `UnimplementedError` en pleine phase de build, ce qui n'est pas rattrapable
/// par l'appelant : l'écran rouge est déjà peint, et la cascade de
/// `RenderErrorBox` qui suit rend la trace illisible.
///
/// Le repli n'invente pas de contenu : il rend un espace **annoncé** au lecteur
/// d'écran, pour que la perte soit perceptible plutôt que silencieuse.
class ZUnknownEmbedBuilder extends EmbedBuilder {
  /// Builder `const` (sans état).
  const ZUnknownEmbedBuilder();

  /// Jamais consulté par Quill pour ce rôle (il sert de repli), mais l'API
  /// l'exige : une clé qui ne peut entrer en collision avec aucun type réel.
  @override
  String get key => 'zcrudUnknownEmbed';

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    return Semantics(
      label: kUnknownEmbedLabel,
      child: const SizedBox(width: 1, height: 1),
    );
  }
}

/// L'instance `const` partagée du repli — référence STABLE.
const EmbedBuilder kZUnknownEmbedBuilder = ZUnknownEmbedBuilder();

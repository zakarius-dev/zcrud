/// Seam IA **progressif** d'explication — le pendant en flux de
/// `ZAiExplanationPort`.
///
/// ## Pourquoi un second port plutôt qu'un `explain` qui rendrait un flux
///
/// Le port one-shot existe, il est implémenté chez des hôtes, et une
/// explication courte n'a rien à gagner à être diffusée. Changer sa signature
/// casserait tout le monde pour un bénéfice qui ne concerne qu'une partie des
/// appels. Le progressif est donc un **contrat séparé et optionnel** : un hôte
/// qui ne l'implémente pas garde exactement le comportement qu'il avait, et un
/// consommateur qui n'en reçoit pas passe par le one-shot sans le savoir.
///
/// ## Ce que le port ne fait pas
///
/// Aucun prompt, endpoint, clé ni détail de transport (invariant AD-12) : la
/// requête est la **même** que celle du one-shot ([ZAiExplanationRequest]), et
/// le style comme l'opération y sont des clés opaques du vocabulaire de
/// l'hôte.
library;

import 'package:zcrud_core/domain.dart';

import 'z_ai_explanation_port.dart';

/// Avancement immuable d'une génération progressive (value object,
/// `==`/`hashCode` par valeur).
///
/// [text] est **cumulatif** : il porte tout le texte produit depuis le début
/// de la génération, jamais le seul fragment qui vient d'arriver. Un
/// consommateur affiche donc `text` tel quel, sans jamais concaténer
/// lui-même — deux consommateurs ne peuvent pas diverger sur l'accumulation,
/// et un événement rejoué ou perdu ne décale pas le rendu.
///
/// [isDone] dit que la génération est **terminée** et que [text] est le texte
/// final. Un flux peut aussi se terminer sans avoir jamais émis `isDone` : le
/// dernier [text] reçu fait alors foi.
class ZGenerationProgress {
  /// Construit un avancement portant le texte cumulé [text].
  const ZGenerationProgress({required this.text, this.isDone = false});

  /// Texte **cumulatif** produit jusqu'ici (jamais le seul delta).
  final String text;

  /// `true` sur l'ultime événement : [text] est le texte final.
  final bool isDone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZGenerationProgress &&
          text == other.text &&
          isDone == other.isDone;

  @override
  int get hashCode => Object.hash(text, isDone);
}

/// Port neutre d'explication **progressive** (invariant AD-5 : domaine
/// backend-agnostique).
///
/// Rend un `Stream<ZResult<ZGenerationProgress>>` — un **flux nu**, jamais
/// enveloppé dans un `Future` : c'est le flux lui-même qui est le résultat, et
/// chaque événement porte son propre succès ou son propre échec. Un `Left` ne
/// termine pas le flux de force : c'est au consommateur de décider s'il
/// abandonne (c'est ce que fait le contrôleur de ce paquet).
///
/// [isAvailable] permet à un hôte de brancher **une seule** implémentation et
/// d'en couper le progressif à chaud (quota, réglage, capacité du modèle
/// courant) sans avoir à retirer le port de l'arbre. Un consommateur qui le
/// voit à `false` retombe sur le one-shot.
abstract interface class ZAiExplanationStreamPort {
  /// Diffuse l'explication de [request], texte cumulé par événement.
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  );

  /// `true` si le progressif est utilisable **maintenant**.
  bool get isAvailable;
}

/// Port progressif **inerte** : disponible nulle part, ne diffuse rien.
///
/// Sert de valeur par défaut à un hôte qui veut câbler la fente sans encore
/// avoir de transport, et de sujet neutre aux tests. `isAvailable` valant
/// `false`, un consommateur correct ne l'appelle jamais ; s'il l'appelle
/// quand même, il reçoit un flux vide qui se termine immédiatement — jamais
/// une exception, jamais une attente infinie.
class ZInertAiExplanationStreamPort implements ZAiExplanationStreamPort {
  /// Construit le port inerte (`const` : une seule instance suffit).
  const ZInertAiExplanationStreamPort();

  @override
  bool get isAvailable => false;

  @override
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  ) =>
      const Stream<ZResult<ZGenerationProgress>>.empty();
}

/// Rendu de référence d'un artefact de notebook : un titre et un corps.
///
/// Un questionnaire, un guide ou une carte mentale restent des rendus
/// d'hôte. Ce widget montre le texte que l'hôte a déjà produit, sans
/// l'interpréter.
library;

import 'package:flutter/widgets.dart';

/// Titre et corps d'un artefact.
class ZNotebookArtifactView extends StatelessWidget {
  /// Construit la vue.
  const ZNotebookArtifactView({
    required this.title,
    required this.body,
    super.key,
  });

  /// Titre affiché.
  final String title;

  /// Corps texte, non interprété.
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, textAlign: TextAlign.start),
        Text(body, textAlign: TextAlign.start),
      ],
    );
  }
}

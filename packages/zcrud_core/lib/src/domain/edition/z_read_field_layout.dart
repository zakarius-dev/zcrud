/// `ZReadFieldLayout` — **la forme** que prend un champ présenté en
/// consultation.
///
/// Le *mode de consultation* dit **qu'un** champ est consulté ; cette
/// énumération dit **comment** il est présenté. Les deux descendent par le même
/// canal (`ZReadModeScope`), se déclarent au niveau d'une surface d'édition et
/// se surchargent champ par champ (`ZFieldSpec.readLayout`).
///
/// ## Choisir sa forme
///
/// | Forme | Hauteur d'un champ court | Ce qu'elle apporte | Ce qu'elle coûte |
/// |---|---|---|---|
/// | [card] | 72 | la forme de référence, entièrement pilotée par les jetons | la plus haute des cinq |
/// | [listTile] | 72 | la ligne Material native, densités et RTL compris | forme figée par Material |
/// | [definition] | 54 | la valeur domine le libellé — la lecture d'un dossier rempli | libellés discrets, moins repérables |
/// | [inlineRow] | 36 | deux colonnes alignées, excellentes à l'impression | une largeur fixe prise par les libellés |
/// | [compact] | 28 | la densité maximale pour une fiche longue | pas de bouton de copie visible |
///
/// Les hauteurs sont celles d'un couple libellé/valeur d'une ligne, avec les
/// jetons par défaut et la typographie Material 3 ; elles bougent dès qu'un
/// jeton `read*` est déclaré.
///
/// **Pur-données `const`** (couche `domain`, pur-Dart — AD-1, garde
/// `domain_purity_test.dart`) : aucune dépendance Flutter. Valeurs en camelCase
/// (canonique §5).
library;

/// Forme d'un champ présenté en consultation (défaut [card]).
enum ZReadFieldLayout {
  /// **Fiche** : le libellé au-dessus de la valeur, dans une carte dont le
  /// fond, le filet, les marges et la typographie sont pilotés par les jetons
  /// `read*` de `ZcrudTheme`.
  ///
  /// C'est la forme **par défaut**, et la seule entièrement paramétrable : les
  /// autres formes empruntent les mêmes jetons quand ils sont déclarés, mais
  /// leur structure, elle, ne se règle pas.
  ///
  /// **Quand l'employer** : partout où la consultation doit rester réglable par
  /// le thème de l'application — c'est-à-dire par défaut. Sans aucun réglage,
  /// elle rend un rang **posé à plat** (ni fond ni filet), haut de 72, libellé
  /// en corps de texte et valeur en gris — la présentation d'un document qu'on
  /// lit et qu'on imprime.
  ///
  /// **Ce qu'elle coûte** : la hauteur. 72 par champ, c'est huit champs par
  /// écran de téléphone ; sur une fiche de trente champs, préférer [definition]
  /// ou [compact]. À l'impression, un rang de 72 aère bien mais consomme la
  /// page.
  ///
  /// **Retrouver l'encadré** (fiche cernée d'un filet sur un fond légèrement
  /// contrasté) : déclarer les deux jetons correspondants dans le thème, sans
  /// changer de forme :
  ///
  /// ```dart
  /// ZcrudTheme(readFillColor: scheme.surfaceContainerLow, readBorderWidth: 1)
  /// ```
  card,

  /// **Ligne Material** : un `ListTile` dont le `title` porte le libellé et le
  /// `subtitle` la valeur.
  ///
  /// **Quand l'employer** : quand la consultation doit se fondre dans une liste
  /// Material déjà présente (mêmes hauteurs, mêmes retraits, mêmes densités,
  /// même comportement RTL), ou pour retrouver au pixel près la présentation
  /// d'un moteur d'édition antérieur bâti sur `ListTile`.
  ///
  /// **Ce qu'elle coûte** : la structure appartient à Material. Les jetons de
  /// mesure `read*` ne s'y appliquent pas — seuls les styles de texte sont
  /// suivis s'ils sont déclarés. C'est un choix de conformité, pas de réglage.
  listTile,

  /// **Liste de définitions** : le libellé, discret et menu, au-dessus d'une
  /// valeur mise en avant. Aucun cadre, aucun fond.
  ///
  /// La hiérarchie y est **inversée** par rapport à [card] : c'est la valeur
  /// qui porte le corps de texte et le libellé qui s'efface. La forme vient des
  /// listes de définitions du web (le motif « description list » de Tailwind
  /// UI, les `Descriptions` verticales d'Ant Design).
  ///
  /// **Quand l'employer** : sur un dossier **rempli**, qu'on parcourt pour
  /// lire des valeurs et non pour retrouver des libellés — état civil, entête
  /// de déclaration, récapitulatif avant envoi.
  ///
  /// **Ce qu'elle coûte** : des libellés moins repérables. Sur une fiche à
  /// beaucoup de champs vides ou aux libellés proches, l'œil met plus de temps
  /// à s'orienter — préférer alors [inlineRow], dont les libellés sont
  /// alignés.
  definition,

  /// **Ligne à deux colonnes** : le libellé dans une colonne de largeur fixe au
  /// début, la valeur alignée à la fin de la ligne.
  ///
  /// Tous les libellés commencent au même endroit et toutes les valeurs
  /// finissent au même endroit : la fiche se lit comme un tableau sans traits.
  /// La forme vient des fiches techniques du web (`Descriptions` bordées d'Ant
  /// Design, `structured list` d'IBM Carbon).
  ///
  /// **Quand l'employer** : quand la fiche est **imprimée** ou exportée. Deux
  /// colonnes alignées divisent la hauteur par deux par rapport à [card] et
  /// donnent au lecteur deux points d'ancrage verticaux, ce qu'aucune forme
  /// empilée ne fait.
  ///
  /// **Ce qu'elle coûte** : une largeur réservée aux libellés
  /// (`readRowLabelWidth`, 160 par défaut), perdue pour les valeurs. Sur une
  /// surface plus étroite que `readRowMinWidth` (360 par défaut), la ligne se
  /// **replie** d'elle-même en présentation empilée : sur téléphone, on retombe
  /// donc sur le rendu de [definition].
  inlineRow,

  /// **Ligne dense** : le libellé et la valeur sur une seule ligne, sans
  /// colonne fixe, avec un rythme vertical resserré.
  ///
  /// Le libellé s'efface juste assez pour se distinguer de la valeur qui le
  /// suit ; rien n'est aligné d'un champ à l'autre, chaque ligne prend la
  /// largeur qu'il lui faut. C'est le motif des panneaux de propriétés des
  /// outils de développement et des suiveurs de tickets.
  ///
  /// **Quand l'employer** : sur une fiche **longue** qu'on veut voir d'un seul
  /// écran, ou dans un panneau latéral étroit. À 28 par champ, elle tient deux
  /// fois et demie plus de champs que [card] à hauteur égale.
  ///
  /// **Ce qu'elle coûte** : deux choses. Les libellés ne sont pas alignés, donc
  /// la fiche se parcourt moins bien qu'en [inlineRow]. Et le **bouton de copie
  /// visible disparaît** : le maintenir aurait imposé une cible tactile de 48,
  /// c'est-à-dire annulé la densité. La copie reste offerte par appui long et
  /// par une action annoncée aux lecteurs d'écran.
  compact,
}

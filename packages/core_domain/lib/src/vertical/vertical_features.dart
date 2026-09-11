/// Feature flagovi vertikale — šta se uopšte prikazuje u aplikaciji.
///
/// Tabela po vertikali: `docs/05-vertical-packs.md` §5. Zubar nema galeriju "before/after"
/// i nema "bilo koji dostupan", frizer nema recall — to nije podešavanje ukusa nego razlika
/// koja vertikalu čini uvjerljivom.
///
/// Oblik prati `vertical_packs.feature_flags` JSONB.
class VerticalFeatures {
  const VerticalFeatures({
    required this.gallery,
    required this.prices,
    required this.anyStaff,
    required this.team,
    required this.socialLinks,
    required this.noShowTracking,
    required this.recall,
  });

  /// `generic` red iz `docs/05 §5`.
  static const VerticalFeatures fallback = VerticalFeatures(
    gallery: false,
    prices: true,
    anyStaff: true,
    team: true,
    socialLinks: true,
    noShowTracking: true,
    recall: false,
  );

  /// Galerija radova — beauty i barber da, zdravstvo ne.
  final bool gallery;
  final bool prices;

  /// Izbor "bilo koji dostupan radnik". Prati `requireStaffChoice` iz booking pravila.
  final bool anyStaff;
  final bool team;
  final bool socialLinks;
  final bool noShowTracking;

  /// Kontrolni pregled na 6 mjeseci — dentalna feature koja donosi prihod (`docs/05 §6.2`).
  /// Još nije implementirana; flag postoji da ekrani ne moraju znati za vertikale.
  final bool recall;

  factory VerticalFeatures.fromJson(Map<String, dynamic> json) {
    bool read(String key, bool fallbackValue) {
      final value = json[key];
      return value is bool ? value : fallbackValue;
    }

    return VerticalFeatures(
      gallery: read('gallery', fallback.gallery),
      prices: read('prices', fallback.prices),
      anyStaff: read('anyStaff', fallback.anyStaff),
      team: read('team', fallback.team),
      socialLinks: read('socialLinks', fallback.socialLinks),
      noShowTracking: read('noShowTracking', fallback.noShowTracking),
      recall: read('recall', fallback.recall),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VerticalFeatures &&
          other.gallery == gallery &&
          other.prices == prices &&
          other.anyStaff == anyStaff &&
          other.team == team &&
          other.socialLinks == socialLinks &&
          other.noShowTracking == noShowTracking &&
          other.recall == recall;

  @override
  int get hashCode => Object.hash(
    gallery,
    prices,
    anyStaff,
    team,
    socialLinks,
    noShowTracking,
    recall,
  );
}

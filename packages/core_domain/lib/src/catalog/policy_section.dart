import 'package:freezed_annotation/freezed_annotation.dart';

part 'policy_section.freezed.dart';
part 'policy_section.g.dart';

/// Pravni dokument kojem sekcija pripada — `public.policy_document`.
enum PolicyDocument {
  /// „Pravila korištenja" (`SPEC.md` 5o). Sastavljena od platformskih i salonskih sekcija.
  terms,

  /// „Politika privatnosti". **Uvijek u cijelosti platformska** —
  /// `docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md`.
  privacy;

  /// Vrijednost kako stoji u bazi. Ista je kao ime konstante, ali se ne izvodi iz `name`:
  /// preimenovanje konstante ne smije tiho promijeniti upit.
  String get wireValue => switch (this) {
    PolicyDocument.terms => 'terms',
    PolicyDocument.privacy => 'privacy',
  };
}

/// Jedna numerisana sekcija pravnog dokumenta — jedan red iz `app_policies` ili
/// `salon_policies` (`SPEC.md` 5o, `15-pravila-koristenja.png`).
///
/// **Jedan model nad dvije tabele.** Tabele su dvije zato što je vlasništvo nad tekstom
/// različito (ADR-0009), ali ekran crta jednu listu i ne smije znati odakle je koja sekcija
/// stigla. Razliku nosi jedino [salonId], i to zbog jednog razloga: kad se dvije sekcije
/// nađu na istom [sortOrder]-u, platformska ide prva, pa redoslijed ostane isti između dva
/// otvaranja ekrana.
///
/// **Broj sekcije („01", „02") nije ovdje i ne čuva se u bazi.** Računa se iz pozicije u
/// spojenoj listi — upisan broj bi se razišao sa prikazanim čim salon doda sekciju iznad.
///
/// **Read-only.** Klijentska app nad obje tabele ima samo `select`; pisanje ide iz admina.
@freezed
abstract class PolicySection with _$PolicySection {
  const factory PolicySection({
    required String id,

    /// Redoslijed unutar dokumenta. Rijedak namjerno (10, 20, 30…) da salonska sekcija
    /// stane između platformskih bez preračunavanja cijele liste.
    @JsonKey(name: 'sort_order') required int sortOrder,

    required String title,

    /// Tijelo sekcije. Smije nositi placeholdere (`{minCancelHours}`, `{phone}`, `{email}`,
    /// `{appointmentSingular}`) koje ekran popunjava iz živih podataka —
    /// v. [applyPolicyPlaceholders].
    ///
    /// Paragrafi su razdvojeni praznim redom, kao u seedu.
    required String body,

    /// Kad je sekcija zadnji put mijenjana. „Zadnja izmjena" na ekranu je najveći od ovih
    /// datuma preko cijelog dokumenta, ne datum jedne sekcije.
    @JsonKey(name: 'updated_at') required DateTime updatedAt,

    /// `null` za platformske sekcije (`app_policies` nema tu kolonu).
    @JsonKey(name: 'salon_id') String? salonId,
  }) = _PolicySection;

  const PolicySection._();

  factory PolicySection.fromJson(Map<String, dynamic> json) =>
      _$PolicySectionFromJson(json);

  /// Piše li ovu sekciju platforma. Salon ne smije mijenjati legal tekst (ADR-0009).
  bool get isPlatform => salonId == null;

  /// Paragrafi tijela — prazan red razdvaja, višak praznih redova se ignoriše.
  ///
  /// Razdvajanje stoji ovdje, a ne u ekranu, jer je to oblik podatka: ekran koji sam
  /// parsira tijelo je drugi ekran koji će to uraditi malo drugačije.
  List<String> get paragraphs => [
    for (final dio in body.split(RegExp(r'\n\s*\n')))
      if (dio.trim().isNotEmpty) dio.trim(),
  ];
}

/// Vrijednosti kojima ekran puni placeholdere u tijelu sekcije.
///
/// Postoji zato što bi slobodan tekst odlutao od onoga što baza stvarno provodi: handoff
/// piše „najkasnije 2 sata prije početka", a `cancel_appointment` čita
/// `salon_settings.min_cancel_hours` — 3 za barbera, 6 za beauty. Pravno obavezujući ekran
/// koji piše drugi broj od onog koji baza provodi laže korisniku.
@immutable
class PolicyPlaceholders {
  const PolicyPlaceholders({
    this.minCancelHours,
    this.phone,
    this.email,
    this.appointmentSingular,
  });

  /// `salon_settings.min_cancel_hours`.
  final int? minCancelHours;

  /// `salons.phone`. Prazan string se tretira kao da ga nema.
  final String? phone;

  /// `salons.email`.
  final String? email;

  /// `vertical.terms.appointmentSingular` — „Termin" / „Pregled".
  final String? appointmentSingular;

  Map<String, String?> get _byName => {
    'minCancelHours': minCancelHours?.toString(),
    'phone': phone,
    'email': email,
    'appointmentSingular': appointmentSingular,
  };
}

/// Zamjenjuje `{ime}` u tijelu sekcije stvarnom vrijednošću.
///
/// **Nepoznat ili prazan placeholder ostaje vidljiv kao `{ime}`.** To je namjerno i nije
/// propust: tiho brisanje daje rečenicu bez roka („Termin možete otkazati najkasnije prije
/// početka"), koja izgleda ispravno a ne znači ništa. Vidljiv `{minCancelHours}` je kvar
/// koji neko prijavi; nevidljiv je kvar koji niko ne vidi.
String applyPolicyPlaceholders(String body, PolicyPlaceholders values) {
  final vrijednosti = values._byName;

  return body.replaceAllMapped(RegExp(r'\{(\w+)\}'), (podudaranje) {
    final vrijednost = vrijednosti[podudaranje.group(1)]?.trim();
    return vrijednost == null || vrijednost.isEmpty
        ? podudaranje.group(0)!
        : vrijednost;
  });
}

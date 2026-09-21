import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Pravila korištenja i politika privatnosti (`SPEC.md` 5o, `15-pravila-koristenja.png`).
///
/// Radi **bez prijave**, i to je uslov a ne pogodnost: store review otvara „Pravila
/// korištenja" na svježe instaliranoj aplikaciji, prije ijedne prijave. Politike
/// `public_read` i `public_active` zato daju `select` roli `anon`.
///
/// ## Dvije tabele, jedna lista
///
/// `app_policies` nosi platformske sekcije (obavezuju firmu pod čijim imenom app stoji u
/// storeu), `salon_policies` salonske (mijenjaju se po tenantu) —
/// `docs/adr/0009-pravila-u-dvije-tabele-legal-tekst-pise-platforma.md`. Ekran o toj podjeli
/// ne zna ništa: dobija jednu sortiranu listu i numeriše je `01..NN`.
///
/// PostgREST ne radi `union` preko dvije tabele, pa su to **dva upita koja idu paralelno**.
/// Serijski bi bila dva puna kruga mreže za ekran koji je sav statičan tekst.
///
/// **Samo čitanje.** Klijent nad obje tabele ima jedino `select`; pisanje ide iz admina.
class PolicyRepository {
  const PolicyRepository(this._client);

  final SupabaseClient _client;

  /// `app_policies` nema `salon_id` — to je cijela poenta te tabele, pa se ne traži.
  static const _appColumns = 'id, sort_order, title, body, updated_at';
  static const _salonColumns =
      'id, salon_id, sort_order, title, body, updated_at';

  /// Sekcije „Pravila korištenja" za dati salon, spojene i sortirane.
  ///
  /// **Prazna lista je moguća i nije greška** — salon bez ijedne svoje sekcije dobija samo
  /// platformske. Prazna do kraja bi značila da migracija nije prošla, i ekran to crta kao
  /// prazno stanje, ne kao izuzetak: pravni ekran koji pukne je gori od pravnog ekrana koji
  /// kaže da teksta nema.
  Future<List<PolicySection>> terms(String salonId) => guard(() async {
    final (platformske, salonske) = await (
      _client
          .from('app_policies')
          .select(_appColumns)
          .eq('document', PolicyDocument.terms.wireValue),
      _client
          .from('salon_policies')
          .select(_salonColumns)
          .eq('salon_id', salonId),
    ).wait;

    return mergePolicySections(
      [for (final row in platformske) policySectionFromRow(row)],
      [for (final row in salonske) policySectionFromRow(row)],
    );
  });

  /// Sekcije politike privatnosti. Jedan upit — ovaj dokument je u cijelosti platformski.
  ///
  /// Nema `salonId` parametra namjerno: potpis koji ga traži sugerisao bi da salon može
  /// imati svoju verziju, a `check (document = 'terms')` u bazi to izričito ne dopušta.
  ///
  /// **Redoslijed slaže [mergePolicySections], ne PostgREST**, iako je ovdje samo jedna
  /// lista. Razlog je zamka koju `ServiceRepository` već nosi zapisanu:
  /// `PostgrestTransformBuilder.order` ima **`ascending = false`** kao default, pa
  /// `.order('sort_order')` vraća dokument **naopako** — i to se ne vidi ni u jednom testu
  /// koji mapira redove, nego tek na ekranu, gdje „Kontakt" ispadne sekcija `01`.
  /// Ovako poredak ima jedan izvor i za `/terms` i za `/privacy`.
  Future<List<PolicySection>> privacy() => guard(() async {
    final rows = await _client
        .from('app_policies')
        .select(_appColumns)
        .eq('document', PolicyDocument.privacy.wireValue);

    return mergePolicySections([
      for (final row in rows) policySectionFromRow(row),
    ], const []);
  });

  /// Sekcije pravila **koje piše salon** — samo `salon_policies`, za admin ekran.
  ///
  /// Razlikuje se od [terms] time što **ne spaja platformske**: admin uređuje samo svoje,
  /// a lista koja bi pokazala i tuđe redove nudila bi dugme „Uredi" nad tekstom koji
  /// `super_manage` neće pustiti da se promijeni.
  Future<List<PolicySection>> salonSections(String salonId) => guard(() async {
    final rows = await _client
        .from('salon_policies')
        .select(_salonColumns)
        .eq('salon_id', salonId);

    return mergePolicySections(const [], [
      for (final row in rows) policySectionFromRow(row),
    ]);
  });

  /// Dodaje ili mijenja salonsku sekciju pravila.
  ///
  /// **Ovo ide direktno nad tabelom, bez `rpc`, i to je odluka a ne previd.** Nad
  /// `salon_policies` `staff_manage` već daje CRUD uz grant, a mimo `check` constrainta
  /// koji stoje (`sort_order > 0`, neprazan naslov i tijelo) nema šta da se validira —
  /// funkcija bi bila prosljeđivanje koje sakriva politiku umjesto da je pojača. Razlika
  /// naspram `services`, `employees` i `working_hours`, gdje `rpc` postoji jer nosi
  /// pravila, zapisana je u `.claude/docs/security.md`.
  ///
  /// **`app_policies` se odavde ne dira nikad** (ADR-0009): Zakazivanje, Cijene i „Vaši
  /// podaci" obavezuju firmu pod čijim imenom app stoji u storeu, i `super_manage` ih
  /// drži van dohvata salona.
  Future<PolicySection> saveSalonSection({
    required String salonId,
    String? sectionId,
    required int sortOrder,
    required String title,
    required String body,
  }) => guard(() async {
    final vrijednosti = {
      'salon_id': salonId,
      'sort_order': sortOrder,
      'title': title.trim(),
      'body': body.trim(),
    };

    final row = sectionId == null
        ? await _client
              .from('salon_policies')
              .insert(vrijednosti)
              .select(_salonColumns)
              .single()
        : await _client
              .from('salon_policies')
              .update(vrijednosti)
              // Uz `id` i `salon_id`: RLS već drži granicu, ali filter koji je ponovi
              // znači da greška u politici ne postane tiha izmjena tuđeg reda.
              .eq('id', sectionId)
              .eq('salon_id', salonId)
              .select(_salonColumns)
              .single();

    return policySectionFromRow(row);
  });

  /// Briše salonsku sekciju pravila.
  Future<void> deleteSalonSection({
    required String salonId,
    required String sectionId,
  }) => guard(
    () async => _client
        .from('salon_policies')
        .delete()
        .eq('id', sectionId)
        .eq('salon_id', salonId),
  );
}

/// Spaja platformske i salonske sekcije u redoslijed kojim ih ekran numeriše.
///
/// Sortira po `sort_order`; **kad je isti, platformska ide prva**. Tie-break postoji da
/// redoslijed bude determinističan: bez njega bi dva otvaranja istog ekrana mogla dati dva
/// poretka, a na pravno obavezujućem dokumentu to izgleda kao da se tekst promijenio.
///
/// `sort` u Dartu je stabilan, pa se ulazni poredak unutar iste grupe zadržava.
@visibleForTesting
List<PolicySection> mergePolicySections(
  List<PolicySection> platformske,
  List<PolicySection> salonske,
) {
  final spojene = [...platformske, ...salonske]
    ..sort((a, b) {
      final poPoziciji = a.sortOrder.compareTo(b.sortOrder);
      if (poPoziciji != 0) return poPoziciji;
      if (a.isPlatform == b.isPlatform) return 0;
      return a.isPlatform ? -1 : 1;
    });

  return spojene;
}

/// Mapira red `app_policies` ili `salon_policies` na [PolicySection].
///
/// Izdvojeno iz repozitorija da se mapiranje testira bez lažiranja PostgREST builder lanca —
/// isti obrazac kao `salonFromRow`.
@visibleForTesting
PolicySection policySectionFromRow(Map<String, dynamic> row) {
  try {
    return PolicySection.fromJson(row);
  } catch (error) {
    throw MappingError('Neispravan red pravila', cause: error);
  }
}

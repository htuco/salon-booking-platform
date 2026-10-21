/// Postavke lokacije na dvije širine — `3i`, plus granica prema `app_policies`.
library;

import 'dart:typed_data';

import 'package:admin/src/core/theme/theme.dart';
import 'package:admin/src/core/widgets/slika_polje.dart';
import 'package:admin/src/features/appointments/appointments_providers.dart';
import 'package:admin/src/features/settings/settings_providers.dart';
import 'package:admin/src/features/settings/settings_screen.dart';
import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pristupacnost.dart';

const _salonId = '550e8400-e29b-41d4-a716-446655440000';
const _desktop = Size(1440, 900);
const _telefon = Size(402, 874);

const _vlasnik = StaffMember(
  id: 'u1',
  name: 'Emir Bešić',
  email: 'emir@test.invalid',
  role: 'salon_admin',
  salonId: _salonId,
);

final _salon = Salon(
  id: _salonId,
  name: 'Barber Studio Vitez',
  slug: 'barberstudiovitez',
  city: 'Vitez',
  address: 'Stjepana Radića 4',
  phone: '030 711 220',
);

const _postavke = SalonSettings(
  id: 's1',
  salonId: _salonId,
  minCancelHours: 3,
  bufferMinutes: 5,
);

/// Salonska sekcija — `salonId` je popunjen, pa [PolicySection.isPlatform] je `false`.
final _mojaSekcija = PolicySection(
  id: 'p1',
  salonId: _salonId,
  sortOrder: 20,
  title: 'Otkazivanje',
  body: 'Termin otkažite najkasnije {minCancelHours} sata prije početka.',
  updatedAt: DateTime(2026, 9, 21),
);

Widget _screen({
  Salon? salon,
  SalonSettings? postavke,
  List<PolicySection> sekcije = const [],
  Object? greska,
  TextScaler? skala,
  List<Override> dodatno = const [],
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    currentStaffProvider.overrideWith(
      (ref) => Stream<StaffMember?>.value(_vlasnik),
    ),
    adminSalonProvider.overrideWith((ref) async => _salon),
    pendingCountProvider.overrideWith((ref) async => 0),
    postavkeSalonProvider.overrideWith((ref) async {
      if (greska != null) throw greska;
      return salon ?? _salon;
    }),
    postavkeBookingProvider.overrideWith((ref) async {
      if (greska != null) throw greska;
      return postavke ?? _postavke;
    }),
    postavkeSekcijeProvider.overrideWith((ref) async => sekcije),
    postavkeGalerijaProvider.overrideWith((ref) async => const <String>[]),
    ...dodatno,
  ],
  child: MaterialApp(
    theme: buildAdminTheme(),
    home: skala == null
        ? const AdminSettingsScreen()
        : MediaQuery(
            data: MediaQueryData(textScaler: skala),
            child: const AdminSettingsScreen(),
          ),
  ),
);

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

/// Ekran je duži od obje širine, a `ListView` gradi samo vidljivo — bez skrolanja test
/// ne bi tvrdio da nečega nema, nego samo da nije vidljivo bez skrolanja.
Future<void> _doVidljivog(WidgetTester tester, Finder cilj) async {
  await tester.dragUntilVisible(
    cilj,
    find.byType(ListView),
    const Offset(0, -220),
  );
  await tester.pumpAndSettle();
}

void main() {
  pristupacnostEkrana('Postavke', _screen);
  _slikeTestovi();

  testWidgets('desktop `3i` crta osnovne podatke popunjene iz baze', (
    tester,
  ) async {
    await _pumpAt(tester, _desktop, _screen());

    // `3i` nema naslov „Osnovni podaci" — kartica počinje naslovnom fotografijom.
    expect(find.text('Osnovni podaci'), findsNothing);
    expect(find.text('Naslovna fotografija'), findsOneWidget);
    // Jedno „SAČUVAJ" u top baru; original ostaje u `semanticsLabel`.
    expect(find.text('SAČUVAJ'), findsOneWidget);
    // Vrijednosti su iz `salons`, ne placeholder tekst: polje koje se ne popuni izgleda
    // isto kao prazno, a vlasnik bi prvim snimanjem obrisao svoje podatke.
    expect(find.widgetWithText(TextFormField, 'Barber Studio Vitez'), findsOne);
    expect(find.widgetWithText(TextFormField, 'Vitez'), findsOne);
    expect(find.widgetWithText(TextFormField, '030 711 220'), findsOne);
  });

  testWidgets('naziv je samo za čitanje i objašnjava novi store build', (
    tester,
  ) async {
    await _pumpAt(tester, _desktop, _screen());

    final naziv = find.widgetWithText(TextFormField, 'Barber Studio Vitez');
    final unos = tester.widget<EditableText>(
      find.descendant(of: naziv, matching: find.byType(EditableText)),
    );
    expect(unos.readOnly, isTrue);
    expect(
      find.text(
        'Naziv aplikacije mijenja se kroz konfiguraciju i novi store build.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('objašnjenje naziva stane na telefonu s povećanim tekstom', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      _telefon,
      _screen(skala: const TextScaler.linear(1.6)),
    );

    const poruka =
        'Naziv aplikacije mijenja se kroz konfiguraciju i novi store build.';
    final helper = tester.widget<Text>(find.text(poruka));
    expect(helper.maxLines, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telefon `3t` pokaže isti ekran, bez desktop ljuske', (
    tester,
  ) async {
    await _pumpAt(tester, _telefon, _screen());

    expect(find.text('Naslovna fotografija'), findsOneWidget);
    // Naslov „Postavke lokacije" je samo desktop; telefon ga nosi u zaglavlju.
    expect(find.text('Postavke lokacije'), findsNothing);
    // „Zakazivanje" je i kartica i platformska sekcija — prva je kartica.
    await _doVidljivog(tester, find.text('Zakazivanje').first);
    expect(find.text('Obavijesti klijentima'), findsOneWidget);
  });

  testWidgets('booking pravila stižu iz `salon_settings`, ne iz defaulta', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(
        postavke: const SalonSettings(
          id: 's1',
          salonId: _salonId,
          minCancelHours: 12,
          bufferMinutes: 25,
        ),
      ),
    );

    await _doVidljivog(tester, find.text('Rezervacija i otkazivanje'));
    await _doVidljivog(tester, find.widgetWithText(TextFormField, '12'));
    expect(find.widgetWithText(TextFormField, '12'), findsOne);
    expect(find.widgetWithText(TextFormField, '25'), findsOne);
  });

  testWidgets('rok otkazivanja kaže da vrijedi odmah', (tester) async {
    // DoD taska 36 traži da promjena `min_cancel_hours` odmah mijenja klijentsko
    // otkazivanje. Baza to provodi (`014_postavke_lokacije.test.sql`); ekran to mora i
    // **reći**, jer vlasnik inače pretpostavi da pravilo vrijedi tek za nove termine.
    await _pumpAt(tester, _desktop, _screen());

    final poruka = find.textContaining(
      'Vrijedi odmah — i za već zakazane termine.',
    );
    await _doVidljivog(tester, poruka);
    expect(poruka, findsOneWidget);
  });

  testWidgets('primjer uz rok otkazivanja prati upisani broj', (tester) async {
    // Task 44: primjer se računa iz onoga što je **upisano**, ne iz snimljenog — vlasnik
    // vidi posljedicu prije „Sačuvaj". `_postavke` nosi rok 3 h.
    await _pumpAt(tester, _desktop, _screen());

    final sa3 = find.textContaining('najkasnije u 6:00');
    await _doVidljivog(tester, sa3);
    expect(sa3, findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '3'), '12');
    await tester.pump();

    expect(find.textContaining('najkasnije u 6:00'), findsNothing);
    expect(
      find.textContaining('najkasnije prethodnog dana u 21:00'),
      findsOneWidget,
    );
  });

  testWidgets('Facebook polje je stranica salona, ne prijava', (tester) async {
    // ADR-0011: prijava preko Facebooka ne postoji. Labela „Facebook" bez ove dopune je
    // poziv da neko doda login koji je odbijen.
    await _pumpAt(tester, _desktop, _screen());

    await _doVidljivog(tester, find.text('Facebook stranica'));
    expect(
      find.text('Stranica salona, ne prijava Facebookom.'),
      findsOneWidget,
    );
  });

  testWidgets('platformske sekcije su vidljive i zaključane', (tester) async {
    // **Ovo je ekranska strana ADR-0009.** Tri sekcije obavezuju firmu i salon ih ne
    // može mijenjati; da ih ekran prećuti, vlasnik bi prijavio da mu „fale pravila".
    await _pumpAt(tester, _desktop, _screen());

    await _doVidljivog(tester, find.text('Pravila platforme'));
    for (final naslov in const ['Zakazivanje', 'Cijene', 'Vaši podaci']) {
      expect(find.text(naslov), findsWidgets);
    }
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(3));
    // Nijedna od njih nema dugme za izmjenu — jedino salonske sekcije ga imaju.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets('salon bez svojih sekcija dobije uredno prazno stanje', (
    tester,
  ) async {
    // ADR-0009: salon bez ijedne svoje sekcije je predviđeno stanje, ne greška —
    // `/terms` tada prikazuje samo platformske.
    await _pumpAt(tester, _desktop, _screen());

    await _doVidljivog(tester, find.text('Dodaj sekciju'));
    expect(find.textContaining('Nema vaših sekcija'), findsOneWidget);
  });

  testWidgets('salonska sekcija ima „Uredi", platformska nema', (tester) async {
    await _pumpAt(tester, _desktop, _screen(sekcije: [_mojaSekcija]));

    await _doVidljivog(tester, find.text('Otkazivanje'));
    expect(find.text('Otkazivanje'), findsOneWidget);
    // Tačno jedan — sekcija je jedna, a platformske se ne uređuju.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.textContaining('Nema vaših sekcija'), findsNothing);
  });

  testWidgets('greška u učitavanju ne ostavlja praznu formu', (tester) async {
    // Prazna forma nad neuspjelim upitom je gora od poruke: prvo snimanje bi upisalo
    // prazne vrijednosti preko stvarnih podataka salona.
    await _pumpAt(
      tester,
      _desktop,
      _screen(greska: const ServerError('pao upit')),
    );

    expect(find.text('Postavke se ne mogu učitati.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  _podsjetniciTestovi();

  testWidgets('uvećan sistemski font ne preliva telefon', (tester) async {
    await _pumpAt(
      tester,
      _telefon,
      _screen(skala: const TextScaler.linear(1.6)),
    );

    expect(tester.takeException(), isNull);
  });
}

/// Bilježi šta bi „Sačuvaj" poslao, bez baze.
class _LazeAkcije extends SettingsActions {
  _LazeAkcije(super.ref);

  final slike = <(SalonImage, String?)>[];
  final pravila = <BookingSettingsInput>[];

  @override
  Future<void> sacuvajKontakt(ContactInput unos) async {}

  @override
  Future<void> sacuvajPravila(BookingSettingsInput unos) async =>
      pravila.add(unos);

  @override
  Future<void> sacuvajSliku(SalonImage vrsta, String? url) async =>
      slike.add((vrsta, url));
}

class _LaziMedia implements MediaRepository {
  @override
  Future<String> upload({
    required String salonId,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    String? ownerId,
  }) async => 'https://example.invalid/$salonId/${kind.name}/nova.jpg';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _slikeTestovi() {
  late _LazeAkcije akcije;
  List<Override> overrides() => [
    adminSalonIdProvider.overrideWithValue(_salonId),
    settingsActionsProvider.overrideWith((ref) => akcije = _LazeAkcije(ref)),
    mediaRepositoryProvider.overrideWithValue(_LaziMedia()),
    izborSlikeProvider.overrideWithValue(
      () async => IzabranaSlika(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF]),
        contentType: 'image/jpeg',
      ),
    ),
  ];

  testWidgets('nova naslovna ide u bazu na „Sačuvaj", netaknut logo ne ide', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(
        salon: _salon.copyWith(logoUrl: 'https://example.invalid/logo.png'),
        dodatno: overrides(),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('postavke-cover')),
        matching: find.byKey(const Key('slika-izaberi')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAČUVAJ'));
    await tester.pumpAndSettle();

    expect(akcije.slike, [
      (SalonImage.cover, 'https://example.invalid/$_salonId/cover/nova.jpg'),
    ]);
  });

  testWidgets('uklonjen logo se briše kao null', (tester) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(
        salon: _salon.copyWith(logoUrl: 'https://example.invalid/logo.png'),
        dodatno: overrides(),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('postavke-logo')),
        matching: find.byKey(const Key('slika-ukloni')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAČUVAJ'));
    await tester.pumpAndSettle();

    expect(akcije.slike, [(SalonImage.logo, null)]);
  });

  testWidgets('logo kaže da ikonu aplikacije ne mijenja', (tester) async {
    await _pumpAt(tester, _desktop, _screen(dodatno: overrides()));

    expect(
      find.textContaining('Ikona aplikacije i početni ekran'),
      findsOneWidget,
    );
    expect(find.textContaining('uskoro'), findsNothing);
  });
}

/// Podsjetnici (task 56, ADR-0033): dva prekidača i izbor N, snimaju se kroz „Sačuvaj".
void _podsjetniciTestovi() {
  late _LazeAkcije akcije;
  List<Override> overrides() => [
    adminSalonIdProvider.overrideWithValue(_salonId),
    settingsActionsProvider.overrideWith((ref) => akcije = _LazeAkcije(ref)),
  ];

  /// `Semantics` reda prekidača — nosi `toggled` i `enabled` (v. `_PrekidacRed`).
  SemanticsProperties red(WidgetTester tester, String naslov) => tester
      .widget<Semantics>(
        find
            .ancestor(
              of: find.text(naslov),
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.toggled != null,
              ),
            )
            .first,
      )
      .properties;

  testWidgets('prekidači podsjetnika pokazuju stanje iz baze i rade', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(
        postavke: _postavke.copyWith(
          remindersEnabled: true,
          hourlyReminderEnabled: false,
          hourlyReminderHours: 5,
        ),
        dodatno: overrides(),
      ),
    );

    await _doVidljivog(tester, find.text('Podsjetnik dan prije'));
    // Ništa od „uskoro": prekidači su stvarni. (Lista čekanja u kartici Zakazivanje je
    // i dalje „uskoro" — task 54 odlučuje o njoj.)
    expect(find.textContaining('Klijent bi dobio podsjetnik'), findsNothing);
    expect(find.textContaining('Podsjetnici stižu uskoro'), findsNothing);
    expect(find.text('Podsjetnik 5 sati prije'), findsOneWidget);

    final dnevni = red(tester, 'Podsjetnik dan prije');
    expect(dnevni.toggled, isTrue);
    expect(dnevni.enabled, isTrue);
    final satni = red(tester, 'Podsjetnik 5 sati prije');
    expect(satni.toggled, isFalse);
    expect(satni.enabled, isTrue);
    // Ugašen satni ne nudi izbor N.
    expect(find.byKey(const Key('postavke-sati-podsjetnika')), findsNothing);
  });

  testWidgets('„Sačuvaj" šalje oba prekidača i izabrani N', (tester) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(postavke: _postavke, dodatno: overrides()),
    );

    // Polazno: oba uključena, N = 3 (defaulti iz baze).
    await _doVidljivog(tester, find.text('Podsjetnik dan prije'));
    await tester.tap(find.text('Podsjetnik dan prije'));
    await tester.pumpAndSettle();

    final izbor = find.byKey(const Key('postavke-sati-podsjetnika'));
    await _doVidljivog(tester, izbor);
    await tester.tap(izbor);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 sati').last);
    await tester.pumpAndSettle();

    expect(find.text('Podsjetnik 5 sati prije'), findsOneWidget);
    expect(
      find.text(
        'Klijent dobija obavijest 5 sati prije termina. Termin zakazan '
        'kasnije od toga je ne dobija.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('SAČUVAJ'));
    await tester.pumpAndSettle();

    expect(akcije.pravila, hasLength(1));
    final poslano = akcije.pravila.single;
    expect(poslano.remindersEnabled, isFalse);
    expect(poslano.hourlyReminderEnabled, isTrue);
    expect(poslano.hourlyReminderHours, 5);
  });

  testWidgets('izbor N nudi tačno 1–12 sati', (tester) async {
    await _pumpAt(
      tester,
      _desktop,
      _screen(postavke: _postavke, dodatno: overrides()),
    );

    final izbor = find.byKey(const Key('postavke-sati-podsjetnika'));
    await _doVidljivog(tester, izbor);
    await tester.tap(izbor);
    await tester.pumpAndSettle();

    final stavke = tester
        .widgetList<DropdownMenuItem<int>>(find.byType(DropdownMenuItem<int>))
        .map((s) => s.value)
        .toSet();
    expect(stavke, {for (var n = 1; n <= 12; n++) n});
  });

  testWidgets('isključen satni sakrije izbor N, i snima se isključen', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      _telefon,
      _screen(postavke: _postavke, dodatno: overrides()),
    );

    await _doVidljivog(tester, find.text('Podsjetnik 3 sata prije'));
    await tester.tap(find.text('Podsjetnik 3 sata prije'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('postavke-sati-podsjetnika')), findsNothing);

    await tester.tap(find.text('Sačuvaj').first);
    await tester.pumpAndSettle();

    expect(akcije.pravila.single.hourlyReminderEnabled, isFalse);
    expect(akcije.pravila.single.hourlyReminderHours, 3);
    expect(akcije.pravila.single.remindersEnabled, isTrue);
  });
}

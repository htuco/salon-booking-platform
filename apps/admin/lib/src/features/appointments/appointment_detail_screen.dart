/// Detalj termina — prikaz `3n`.
///
/// Otvara se tapom na termin u rasporedu ili u listi, i **čita bazu iznova** umjesto da mu
/// se termin proslijedi: ista adresa stoji u bookmarku i, jednog dana, u push obavijesti,
/// kad nijedna lista nije učitana. Uz to, poslije akcije svježe čitanje pokazuje ono što
/// stvarno piše u bazi, a ne ono što je ekran mislio da će se upisati.
///
/// ## Canvas crta samo telefon
///
/// `3n` je mobilni prikaz; desktop detalja nema. Ovdje je isti ekran u obje ljuske — na
/// desktopu u radnoj površini, ograničen po širini, jer je detalj **jedan zapis**, a red od
/// 1900 px između labele i vrijednosti se ne čita.
///
/// ## Šta canvas traži, a ovdje nije nacrtano
///
/// - **„Pozovi" i „Poruka"** — `tel:` i `sms:` traže `url_launcher`, kojeg admin nema u
///   zavisnostima. Broj telefona zato stoji ispisan i može se kopirati.
/// - **„Profil" i „Zadnji dolasci"** — istorija klijenta je modul iz taska 35.
/// - **„11 dolazaka"** uz ime — isto.
/// - **„Pomjeri"** — pomjeranje termina nema RPC putanju; `set_appointment_status` mijenja
///   status, ne vrijeme.
/// - **„Zakazano 16.05."** — `appointments` nema `created_at`; ostaje samo odakle je došao
///   (`source`), što se zna.
library;

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/datum.dart';
import '../../core/format/tekst.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import 'appointment_actions_bar.dart';
import 'appointments_providers.dart';
import 'status_pill.dart';

/// Najveća širina detalja na desktopu — jedan zapis, ne tabela.
///
/// **Ovo ograničenje namjerno ostaje** i poslije prelaska admina na fluidnu širinu
/// (FE-406). Detalj termina je tekst u jednoj koloni — ime, bilješka, historija — a duga
/// linija teksta se teško čita i teško prati u novi red: mjera od oko 720 px drži red na
/// 70–90 znakova. Tabela nema taj problem i zato nema ni ovo ograničenje.
///
/// Sadržaj je i dalje poravnat na vrh i **lijevo** unutar radne površine, ne centriran:
/// centriran blok na 2560 px ostavlja prazninu s obje strane i odvaja detalj od sidebara
/// uz koji pripada.
const double _maxSirina = 720;

class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termin = ref.watch(terminProvider(appointmentId));

    return AdminScaffold(
      title: 'Termin',
      aktivna: AdminRoute.appointments,
      sopstvenoZaglavlje: true,
      body: termin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _Poruka(
          tekst: 'Termin se ne može učitati.',
          onNazad: () => _nazad(context),
        ),
        // Obrisan termin i tuđi termin izgledaju isto, i to je namjerno: poruka „nemate
        // pravo" bi potvrdila da taj termin postoji u nekom drugom salonu.
        data: (termin) => termin == null
            ? _Poruka(
                tekst: 'Ovaj termin više ne postoji.',
                onNazad: () => _nazad(context),
              )
            : _Detalj(termin: termin),
      ),
    );
  }

  static void _nazad(BuildContext context) {
    // `canPop` pa `go`: detalj otvoren iz liste se vraća na nju, a otvoren iz adrese nema
    // kuda nazad — `pop` bi tada zatvorio aplikaciju na Androidu.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AdminRoute.appointments.path);
    }
  }
}

class _Detalj extends ConsumerWidget {
  const _Detalj({required this.termin});

  final Appointment termin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usluga = ref.watch(uslugePoIdProvider)[termin.serviceId];
    final radnik = termin.employeeId == null
        ? null
        : ref.watch(radniciPoIdProvider)[termin.employeeId];

    // **Ograničenje ide oko sadržaja, ne oko cijelog ekrana.** Zaglavlje i traka radnji
    // crtaju svoju površinu i hairline granicu; kad su stajali unutar `ConstrainedBox`-a,
    // ta površina je na 1920 i 2560 px prestajala na 720 px i kroz stranicu je išao
    // uspravan šav. Pozadina pripada radnoj površini, mjera čitljivosti tekstu u njoj.
    return Column(
      children: [
        _Zaglavlje(termin: termin),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxSirina),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AdminShell.gutterOf(context),
                  AdminSpacing.lg,
                  AdminShell.gutterOf(context),
                  AdminSpacing.xxl,
                ),
                children: [
                  _Klijent(termin: termin),
                  const SizedBox(height: AdminSpacing.lg),
                  _Podaci(termin: termin, usluga: usluga, radnik: radnik),
                  if (termin.customerNote case final napomena?
                      when napomena.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _Naslov('Napomena'),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Text(
                          napomena,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: context.adminColors.textSecondary,
                                height: 1.55,
                              ),
                        ),
                      ),
                    ),
                  ],
                  // Obrazloženje otkazivanja piše onaj ko je otkazao i klijent ga vidi —
                  // vlasnik mora vidjeti isti tekst, inače ne zna šta je klijentu rečeno.
                  if (termin.cancelReason case final razlog?
                      when razlog.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _Naslov(
                      termin.status == AppointmentStatus.cancelled
                          ? 'Razlog otkazivanja'
                          : 'Obrazloženje',
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Text(
                          razlog,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: context.adminColors.textSecondary,
                              ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _Podnozje(termin: termin),
      ],
    );
  }
}

/// „‹ Termini", statusna pilula i naslov `14:20 · Haris Delić`.
class _Zaglavlje extends StatelessWidget {
  const _Zaglavlje({required this.termin});

  final Appointment termin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AdminShell.gutterOf(context),
        AdminSpacing.sm,
        AdminShell.gutterOf(context),
        AdminSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _UzSadrzaj(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => AppointmentDetailScreen._nazad(context),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    label: const Text('Termini'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.only(right: AdminSpacing.md),
                      foregroundColor: context.adminColors.accentInk,
                    ),
                  ),
                  const Spacer(),
                  AppointmentStatusPill(status: termin.status),
                ],
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                '${vrijemeHhMm(termin.startTime)} · ${termin.customerName}',
                style: theme.textTheme.displaySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drži sadržaj zaglavlja i trake radnji u istoj koloni kao i tijelo ekrana.
///
/// **Površina je puna, sadržaj nije.** Zaglavlje i podnožje crtaju pozadinu preko cijele
/// radne površine — bez toga kroz stranicu ide uspravan šav na 720 px, što se i vidjelo na
/// 1920 i 2560 px. Ali njihov *sadržaj* mora ostati u istoj koloni kao podaci ispod, inače
/// se na 2560 px pilula statusa odvoji skroz desno, a dugmad „Potvrdi" i „Odbij" razvuku
/// preko 2324 px dok tabela pored njih stoji na 720.
class _UzSadrzaj extends StatelessWidget {
  const _UzSadrzaj({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxSirina),
        child: child,
      ),
    );
  }
}

/// Kartica klijenta: ime i, ako ga ima, telefon.
class _Klijent extends StatelessWidget {
  const _Klijent({required this.termin});

  final Appointment termin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final telefon = termin.customerPhone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.adminColors.neutralTint,
                shape: BoxShape.circle,
              ),
              // Inicijal umjesto fotografije: `customers` nema sliku, a placeholder iz
              // canvasa ne ulazi u bundle (`SPEC.md`).
              child: Text(
                _inicijal(termin.customerName),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: context.adminColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    termin.customerName,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (telefon != null && telefon.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    // Mono, jer je broj podatak koji se čita cifru po cifru — i jedini
                    // način da se danas pozove, dok „Pozovi" nema `url_launcher`.
                    SelectableText(
                      telefon,
                      style: AdminText.time.copyWith(
                        color: context.adminColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _inicijal(String ime) {
    final ocisceno = ime.trim();
    return ocisceno.isEmpty ? '?' : ocisceno.characters.first.toUpperCase();
  }
}

/// Tabela zapisa iz `3n`: datum, vrijeme, usluga, cijena, majstor, izvor.
class _Podaci extends StatelessWidget {
  const _Podaci({
    required this.termin,
    required this.usluga,
    required this.radnik,
  });

  final Appointment termin;
  final Service? usluga;
  final Employee? radnik;

  @override
  Widget build(BuildContext context) {
    final redovi = <(String, String)>[
      (
        'Datum',
        datumSaGodinom(
          DateTime(termin.date.year, termin.date.month, termin.date.day),
        ),
      ),
      (
        'Vrijeme',
        '${vrijemeHhMm(termin.startTime)}–${vrijemeHhMm(termin.endTime)}'
            ' · ${trajanjeKratko(termin.durationMinutes)}',
      ),
      (
        'Usluga',
        termin.serviceName ?? usluga?.name ?? 'usluga nije u cjenovniku',
      ),
      if ((termin.servicePrice ?? usluga?.price) case final cijena?)
        ('Cijena', iznosKm(cijena)),
      ('Majstor', termin.employeeName ?? radnik?.name ?? 'bilo ko'),
      ('Zakazano', _izvor(termin.source)),
      if (termin.cancelledBy case final ko? when ko.isNotEmpty)
        ('Otkazao', ko == 'customer' ? 'klijent' : 'salon'),
    ];

    return Card(
      child: Column(
        children: [
          for (final (labela, vrijednost) in redovi)
            _Red(
              labela: labela,
              vrijednost: vrijednost,
              zadnji: (labela, vrijednost) == redovi.last,
            ),
        ],
      ),
    );
  }

  /// `source` je `app` ili `admin` — ko je termin upisao.
  static String _izvor(String source) => switch (source) {
    'app' => 'klijent kroz aplikaciju',
    'admin' => 'salon, ručni unos',
    _ => source,
  };
}

class _Red extends StatelessWidget {
  const _Red({
    required this.labela,
    required this.vrijednost,
    required this.zadnji,
  });

  final String labela;
  final String vrijednost;
  final bool zadnji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: zadnji
            ? null
            : Border(
                bottom: BorderSide(
                  color: context.adminColors.separator,
                  width: AdminSize.hairline,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labela,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.adminColors.textSecondary,
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Text(
              vrijednost,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Traka radnji u dnu (`3n`). Zatvoren termin je nema — nema šta da se uradi.
class _Podnozje extends StatelessWidget {
  const _Podnozje({required this.termin});

  final Appointment termin;

  @override
  Widget build(BuildContext context) {
    if (termin.status.isClosed) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        AdminShell.gutterOf(context),
        AdminSpacing.md,
        AdminShell.gutterOf(context),
        AdminSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          top: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _UzSadrzaj(
          child: AppointmentActionsBar(termin: termin, veliko: true),
        ),
      ),
    );
  }
}

class _Naslov extends StatelessWidget {
  const _Naslov(this.tekst);

  final String tekst;

  @override
  Widget build(BuildContext context) =>
      Text(tekst, style: Theme.of(context).textTheme.headlineSmall);
}

class _Poruka extends StatelessWidget {
  const _Poruka({required this.tekst, required this.onNazad});

  final String tekst;
  final VoidCallback onNazad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: context.adminColors.textMuted,
            ),
            const SizedBox(height: AdminSpacing.lg),
            Text(tekst, textAlign: TextAlign.center),
            const SizedBox(height: AdminSpacing.lg),
            FilledButton(
              onPressed: onNazad,
              child: const Text('Nazad na termine'),
            ),
          ],
        ),
      ),
    );
  }
}

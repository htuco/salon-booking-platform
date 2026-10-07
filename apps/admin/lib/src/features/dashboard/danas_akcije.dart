/// Radnje Danas ekrana — potvrdi, odbij, „Završeno", „Nije došao" i otvaranje termina.
///
/// Isti tok sa svakog mjesta na ekranu: blok zahtjeva, blok „je li došao?" i kontekstni
/// panel zovu ove funkcije, pa toast i „Poništi" ne mogu izgledati drugačije u panelu nego
/// u redu.
library;

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/datum.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_toast.dart';
import '../appointments/appointment_actions_bar.dart' show tekstGreskeAkcije;
import '../appointments/appointment_card.dart';
import '../appointments/appointments_providers.dart';
import '../appointments/odgodjene_akcije.dart';
import 'danas.dart';
import 'danas_providers.dart';
import 'kontekst_panel.dart';
import 'odbij_dijalog.dart';
import '../../core/router/admin_router.dart';

/// „Nedim Hodžić · danas 15:00".
String _koKada(Appointment termin, DateTime sada) =>
    '${termin.customerName} · ${danZahtjeva(termin.date, sada)} '
    '${vrijemeHhMm(termin.startTime)}';

/// Zakaže akciju sa rokom i pokaže toast sa „Poništi".
void _odgodi(
  BuildContext context,
  WidgetRef ref,
  Appointment termin,
  OdgodjenaVrsta vrsta,
) {
  final sada = DateTime.now();
  final odgodjene = ref.read(odgodjeneAkcijeProvider.notifier);
  // Toast se pokazuje kroz korijenski overlay, pa ga treba uzeti **sada**: red koji je
  // pokrenuo akciju nestaje iz stabla čim stanje kaže da je zahtjev potvrđen.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);

  odgodjene.zakazi(
    termin,
    vrsta,
    naGresku: (greska) {
      if (overlay == null || !overlay.mounted) return;
      AdminToast.prikazi(overlay, AdminToastVrsta.greska, switch (vrsta) {
        OdgodjenaVrsta.potvrda => 'Zahtjev nije potvrđen',
        OdgodjenaVrsta.zavrseno => 'Termin nije označen kao završen',
        OdgodjenaVrsta.nijeDosao => 'Nedolazak nije upisan',
      }, opis: '${termin.customerName}: ${tekstGreskeAkcije(greska)}');
    },
  );

  final (naslov, opis) = switch (vrsta) {
    OdgodjenaVrsta.potvrda => (
      'Zahtjev potvrđen',
      '${_koKada(termin, sada)} · klijent dobija obavijest za 5 s',
    ),
    OdgodjenaVrsta.zavrseno => ('Termin završen', _koKada(termin, sada)),
    OdgodjenaVrsta.nijeDosao => ('Upisano: nije došao', _koKada(termin, sada)),
  };

  if (overlay == null) return;
  AdminToast.prikazi(
    overlay,
    AdminToastVrsta.uspjeh,
    naslov,
    opis: opis,
    akcija: AdminToastAkcija('Poništi', () {
      if (odgodjene.ponisti(termin.id)) return;
      // Toast stoji duže od roka kad ga hover zaustavi; tada je akcija već u bazi.
      AdminToast.prikazi(
        overlay,
        AdminToastVrsta.info,
        'Prekasno za poništavanje',
        opis: 'Promjenu napravite u detalju termina.',
      );
    }),
  );
}

void potvrdiZahtjev(BuildContext context, WidgetRef ref, Appointment termin) =>
    _odgodi(context, ref, termin, OdgodjenaVrsta.potvrda);

void oznaciZavrsen(BuildContext context, WidgetRef ref, Appointment termin) =>
    _odgodi(context, ref, termin, OdgodjenaVrsta.zavrseno);

void oznaciNijeDosao(BuildContext context, WidgetRef ref, Appointment termin) =>
    _odgodi(context, ref, termin, OdgodjenaVrsta.nijeDosao);

/// Odbijanje: dijalog sa razlogom (`6l`), pa upis **odmah** — bez „Poništi".
Future<void> odbijZahtjev(
  BuildContext context,
  WidgetRef ref,
  Appointment termin,
) async {
  final opis = opisTermina(
    termin,
    usluge: ref.read(uslugePoIdProvider),
    radnici: ref.read(radniciPoIdProvider),
    saCijenom: false,
  );
  final razlog = await pitajOdbijanje(
    context,
    opis: [
      termin.customerName,
      ?opis.usluga,
      '${danZahtjeva(termin.date, DateTime.now())} ${vrijemeHhMm(termin.startTime)}',
      if (opis.majstor case final m?) prvoIme(m),
    ].join(' · '),
  );
  if (razlog == null || !context.mounted) return;

  try {
    await ref
        .read(appointmentActionsProvider)
        .odbij(termin.id, razlog: razlog.isEmpty ? null : razlog);
    if (!context.mounted) return;
    AdminToast.uspjeh(
      context,
      'Zahtjev odbijen',
      opis: '${termin.customerName} dobija obavijest.',
    );
  } on ApiError catch (greska) {
    if (!context.mounted) return;
    AdminToast.greska(context, tekstGreskeAkcije(greska));
  }
}

/// Klik na red: panel na ≥ 1920, drawer na desktopu ispod toga, detalj na telefonu.
void otvoriTermin(BuildContext context, WidgetRef ref, Appointment termin) {
  if (!AdminShell.jeDesktop(context)) {
    otvoriDetaljTermina(context, termin.id);
    return;
  }
  ref.read(izabraniTerminProvider.notifier).izaberi(termin.id);
  if (imaStalniPanel(context)) return;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Zatvori',
    barrierColor: context.adminColors.ink.withValues(alpha: 0.32),
    transitionDuration: AdminDuration.normal,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: kSirinaPanela,
        height: double.infinity,
        child: Material(
          color: context.adminColors.surface,
          child: KontekstPanel(onZatvori: () => Navigator.of(context).pop()),
        ),
      ),
    ),
    transitionBuilder: (context, animacija, _, dijete) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animacija, curve: Curves.easeOutCubic)),
      child: dijete,
    ),
  );
}

import 'package:core_api/core_api.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/appointments_providers.dart';
import '../navigation/admin_destinations.dart';
import '../router/admin_router.dart';
import '../theme/theme.dart';
import 'admin_wordmark.dart';

/// Širine na kojima admin mijenja oblik.
///
/// **Jedno mjesto za sve pragove.** Prag izveden u ekranu znači raspored koji se mijenja na
/// jednoj širini, a razmak na drugoj — greška vidljiva samo u uskom pojasu između te dvije.
abstract final class AdminBreakpoint {
  /// 840 — ispod nje donja navigacija, od nje sidebar.
  ///
  /// **Canvas ne daje ovaj broj**, i to je namjerno: `SPEC.md` crta 1440 i 402, a tablet
  /// „nije posebno nacrtan" uz izričit zahtjev da se raspored mijenja *na breakpointu, ne
  /// skaliranjem desktopa*. Broj je zato uzet iz Material `expanded` praga, koji je
  /// najbliža postojeća konvencija: tablet u portretu (768–834) dobija mobilni raspored,
  /// koji je za dodir ionako ispravniji, a sidebar se pojavi tek kad ima mjesta za 236 px
  /// plus radnu površinu.
  ///
  /// Ovaj prag je **stariji od pojaseva ispod i nezavisan od njih**: on bira ljusku
  /// (sidebar ili donja navigacija), a [AdminWidthBand] bira koliko kolona stane u radnu
  /// površinu. Novi pojasevi ga namjerno ne gaze — [AdminWidthBand.compact] ide do 900,
  /// dakle obuhvata i pojas 840–900 u kojem sidebar već stoji.
  static const double desktop = 840;

  /// 900 — ispod nje se sadržaj preslaže u jednu kolonu.
  static const double compact = 900;

  /// 1440 — širina koju canvas crta; od nje radna površina ima mjesta za treću kolonu.
  static const double wide = 1440;

  /// 1920 — od nje se sadržaj ne razvlači dalje nego što mu treba.
  static const double ultraWide = 1920;
}

/// Pojas širine u kojem se sadržaj trenutno crta.
///
/// Handoff traži četiri pojasa (< 900, 900–1440, 1440–1920, > 1920). Ekran ih ne izvodi sam
/// nego pita [AdminShell.bandZa] ili [AdminShell.bandOf] — v. obrazloženje uz
/// [AdminBreakpoint].
enum AdminWidthBand {
  /// < 900 — jedna kolona.
  compact,

  /// 900–1440 — raspored iz canvasa.
  regular,

  /// 1440–1920 — ima mjesta za još jednu kolonu.
  wide,

  /// >= 1920 — puna širina.
  ultraWide;

  bool get jeCompact => this == AdminWidthBand.compact;

  /// Koliko kolona stane u mrežu kartica ovog pojasa.
  int get kolone => switch (this) {
    AdminWidthBand.compact => 1,
    AdminWidthBand.regular => 2,
    AdminWidthBand.wide => 3,
    AdminWidthBand.ultraWide => 4,
  };
}

/// Šta ljuska zna o širini, za ekran koji stoji u njoj.
///
/// Postoji da ekran ne izvodi isti prag na svom mjestu. Drugi prag u ekranu bi značio
/// raspored koji se mijenja na jednoj širini, a razmak na drugoj — greška koja se vidi samo
/// u uskom pojasu između te dvije.
///
/// **Statičke metode nad `MediaQuery`, a ne `InheritedWidget`.** Ljusku pravi
/// [AdminScaffold], a ekran svoje tijelo gradi *prije* nego što ga ljuska primi — pogled
/// naviše iz ekrana bi promašio ljusku i uvijek vratio telefonske vrijednosti. Ta greška
/// prolazi analizu i vidi se tek na 1440.
abstract final class AdminShell {
  static bool jeDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AdminBreakpoint.desktop;

  /// Horizontalni razmak sadržaja: 28 na desktopu, 20 na telefonu.
  static double gutterOf(BuildContext context) => jeDesktop(context)
      ? AdminSpacing.gutterDesktop
      : AdminSpacing.gutterMobile;

  /// Pojas širine za datu **dostupnu** širinu.
  ///
  /// Uzima `double`, a ne `BuildContext`, baš zato da ekran proslijedi `constraints.maxWidth`
  /// iz `LayoutBuilder`-a: ekran u sidebar rasporedu ima [AdminSize.sidebarWidth] manje
  /// mjesta nego što `MediaQuery` kaže, pa bi pojas izveden iz širine prozora dao kolonu
  /// viška. Za ljusku i ekrane bez `LayoutBuilder`-a postoji [bandOf].
  static AdminWidthBand bandZa(double sirina) {
    if (sirina < AdminBreakpoint.compact) return AdminWidthBand.compact;
    if (sirina < AdminBreakpoint.wide) return AdminWidthBand.regular;
    if (sirina < AdminBreakpoint.ultraWide) return AdminWidthBand.wide;
    return AdminWidthBand.ultraWide;
  }

  /// Pojas širine iz `MediaQuery`, umanjen za sidebar kad on stoji.
  ///
  /// **Nije zamjena za `LayoutBuilder`.** Oduzima sidebar jer zna da ga ljuska crta, ali ne
  /// zna za ostale okvire oko sadržaja. Ekran koji već ima `constraints` zove [bandZa].
  static AdminWidthBand bandOf(BuildContext context) {
    final sirina = MediaQuery.sizeOf(context).width;
    return bandZa(
      jeDesktop(context) ? sirina - AdminSize.sidebarWidth : sirina,
    );
  }
}

/// Ljuska admin ekrana: sidebar na desktopu, donja navigacija na telefonu.
///
/// **Jedan route model, dvije ljuske.** Obje čitaju `kAdminDestinations`; nema dva stabla
/// ekrana i nema ekrana koji postoji samo na jednoj širini. Prelaz ide na
/// [AdminBreakpoint.desktop] — horizontalno skaliran desktop nije mobilni layout
/// (`SPEC.md`, „Raspored i komponente").
class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    required this.title,
    required this.body,
    this.aktivna,
    this.actions,
    this.floatingActionButton,
    this.sopstvenoZaglavlje = false,
    this.podstranica = false,
    super.key,
  });

  final String title;
  final Widget body;

  /// Ruta koju ovaj ekran predstavlja, za oznaku u navigaciji.
  ///
  /// Prosljeđuje je ekran, a **ne čita se iz `GoRouterState`**: čitanje iz routera veže
  /// svaki admin ekran za router stablo, pa se ne može podići u widget testu bez pravog
  /// `GoRouter`-a. Test koji mora graditi router da bi provjerio listu termina testira
  /// navigaciju, ne listu.
  final AdminRoute? aktivna;

  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// Ekran sam crta zaglavlje na telefonu, pa ljuska ne stavlja `AppBar`.
  ///
  /// `3k` iznad sadržaja crta **veliki naslov u tijelu** („Danas", 30 px, ispod njega
  /// datum i broj termina), a ne 56-pikselnu traku sa sitnim naslovom. Ljuska to ne može
  /// nacrtati sama jer podnaslov zna samo ekran. Desktop ovim nije dotaknut: tamo top bar
  /// pripada ljusci, jer nosi breadcrumb i akcije koje su iste za sve ekrane.
  final bool sopstvenoZaglavlje;

  /// Ekran je podstranica ispod „Još" na telefonu, pa nema donju navigaciju.
  ///
  /// `3s` crta „‹ Još" i vlastitu traku sa „Sačuvaj" na dnu; donja navigacija ispod nje
  /// bi dala dvije trake na dnu ekrana. Desktop ovim nije dotaknut.
  final bool podstranica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell.jeDesktop(context)
        ? _desktop(context, ref)
        : _telefon(context, ref);
  }

  /// 1440: tamni sidebar lijevo, top bar iznad radne površine.
  Widget _desktop(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(aktivna: aktivna),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: title, actions: actions),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  /// 402: `AppBar` iznad, četiri ćelije ispod.
  ///
  /// `AppBar` ostaje iz taska 23 — handoff (`3k`) umjesto njega crta veliki naslov u
  /// tijelu ekrana, ali to je oblik **ekrana**, ne ljuske, i pripada tasku 30. Ovaj task
  /// mijenja navigaciju, ne zaglavlja.
  Widget _telefon(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: sopstvenoZaglavlje
          ? null
          : AppBar(
              title: Text(title),
              actions: [...?actions, const AdminNalogDugme(ikona: true)],
            ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: podstranica
          ? null
          : _DonjaNavigacija(aktivna: aktivna),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop
// ---------------------------------------------------------------------------

/// Tamni sidebar iz `3b` — 236 px: wordmark, kartica salona, osam stavki, nalog na dnu.
///
/// **Šta iz `3b` ovdje nema:** strelicu `▾` na kartici salona i „‹ Nazad na mrežu". Oba
/// vode na `3a` (pregled mreže lokacija), koji nema ni rutu ni podatak — admin dobija
/// tačno jedan salon iz membershipa (ADR-0016, `prototype/CLAUDE.md`). Strelica koja ne
/// otvara ništa i link koji vodi nigdje su gori od praznog mjesta.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({this.aktivna});

  final AdminRoute? aktivna;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clan = ref.watch(currentStaffProvider).valueOrNull;
    final salon = ref.watch(adminSalonProvider).valueOrNull;

    return Container(
      width: AdminSize.sidebarWidth,
      color: context.adminColors.sidebarBackground,
      padding: const EdgeInsets.only(top: 22, bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminWordmark(velicinaZnaka: 28),
                // `3b`: „6 lokacija" ispod wordmarka. Broj je **stvaran**, ne iz canvasa:
                // membership daje jedan salon, pa piše „1 lokacija".
                if (salon != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '1 lokacija',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.adminColors.sidebarMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (salon != null) ...[
            _SalonKartica(salon: salon),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final cilj in kAdminDestinations)
                  _SidebarStavka(cilj: cilj, izabrana: cilj.route == aktivna),
              ],
            ),
          ),
          const Spacer(),
          if (clan != null) _SidebarPodnozje(clan: clan),
        ],
      ),
    );
  }
}

/// Kartica salona ispod wordmarka (`3b`): slika 28 × 28 i ime, na `sidebarRaised`.
class _SalonKartica extends StatelessWidget {
  const _SalonKartica({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.adminColors.sidebarRaised,
        borderRadius: BorderRadius.circular(AdminRadius.base),
      ),
      child: Row(
        children: [
          _Slika(url: salon.logoUrl, strana: 28, krug: false),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              salon.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: context.adminColors.sidebarAccentForeground,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slika salona ili člana, sa placeholderom kad je nema.
///
/// Placeholder je **preliv**, kako ga `3b` crta (`canvas/assets/ph*.png`), a ne inicijal:
/// siv kvadrat sa slovom izgleda kao greška u učitavanju slike, preliv kao mjesto za nju.
class _Slika extends StatelessWidget {
  const _Slika({required this.url, required this.strana, required this.krug});

  final String? url;
  final double strana;
  final bool krug;

  @override
  Widget build(BuildContext context) {
    final boje = context.adminColors;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        shape: krug ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: krug ? null : BorderRadius.circular(AdminRadius.small),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [boje.sidebarMuted, boje.sidebarSelected],
        ),
      ),
    );

    final adresa = url;
    final slika = adresa == null || adresa.isEmpty
        ? placeholder
        : Image.network(
            adresa,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );

    return SizedBox(
      width: strana,
      height: strana,
      child: krug
          ? ClipOval(child: slika)
          : ClipRRect(
              borderRadius: BorderRadius.circular(AdminRadius.small),
              child: slika,
            ),
    );
  }
}

/// Jedan red sidebara. `3b`: verzal bez ikone, 37 px visine, izabrana `#373A40`.
class _SidebarStavka extends ConsumerWidget {
  const _SidebarStavka({required this.cilj, required this.izabrana});

  final AdminDestination cilj;
  final bool izabrana;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boja = izabrana
        ? context.adminColors.sidebarAccentForeground
        : context.adminColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: izabrana
            ? context.adminColors.sidebarSelected
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminRadius.base),
        child: InkWell(
          onTap: () => context.go(cilj.putanja),
          borderRadius: BorderRadius.circular(AdminRadius.base),
          child: Container(
            // `3b` crta 37 px; FE-502 traži 44 — stavka je meta i na dodirnom
            // laptopu i u tablet pojasu, a razlika su 63 px na devet stavki.
            height: AdminSize.touchTarget,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // **Bez ikone** — `3b` ih u sidebaru ne crta. Ikone ostaju u donjoj
                // navigaciji telefona (`3k`), gdje ih izvoz crta.
                Expanded(
                  child: Text(
                    // **Verzal je stil, ne podatak.** `cilj.label` ostaje „Danas", a
                    // velika slova dolaze iz `toUpperCase()` ovdje — donja navigacija na
                    // telefonu čita isti label i crta ga malim slovima (`3k`).
                    cilj.label.toUpperCase(),
                    semanticsLabel: cilj.label,
                    style: AdminText.navigation.copyWith(
                      color: boja,
                      fontWeight: izabrana ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (cilj.brojac != null) _Pilula(brojac: cilj.brojac!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar, ime i uloga prijavljenog, ispod linije na dnu sidebara (`3b`).
///
/// **Odjava je u meniju ovog reda**, ne ikona pored njega: `3b` ikonu ne crta, a odjava
/// mora postojati. Red je zato dugme — klik otvara meni sa mailom i „Odjavi se", isti
/// sadržaj kao `AdminNalogDugme` na telefonu.
class _SidebarPodnozje extends ConsumerWidget {
  const _SidebarPodnozje({required this.clan});

  final StaffMember clan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.adminColors.sidebarDivider,
            width: AdminSize.hairline,
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Nalog',
        position: PopupMenuPosition.over,
        onSelected: (izbor) async {
          if (izbor == 'odjava') await odjavi(context, ref);
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(clan.email, style: theme.textTheme.bodySmall),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'odjava',
            child: Text('Odjavi se'),
          ),
        ],
        child: Container(
          // Ime i uloga u dva reda daju 40 px; meta mora imati 44 (FE-502).
          constraints: const BoxConstraints(minHeight: AdminSize.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const _Slika(url: null, strana: 32, krug: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clan.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: context.adminColors.sidebarAccentForeground,
                      ),
                    ),
                    // **Uloga, ne mail** (`3b`): ko si ovdje, a ne čime si se prijavio.
                    // Mail je u meniju. Nepoznata uloga ne ispisuje ništa.
                    if (labelaUloge(clan.role) case final uloga?)
                      Text(
                        uloga,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.adminColors.sidebarMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top bar iz `3b` — 66 px, breadcrumb lijevo, akcije ekrana desno.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Ime salona, ne ime proizvoda: `Vitez / Danas`. Dolazi iz `salons`, jer ga
    // `StaffMember` ne nosi — v. `adminSalonProvider`. Dok se ne učita (ili ako admin nije
    // vezan za salon), breadcrumb je sam naslov; kosa crta bez lijeve strane bi izgledala
    // kao greška u iscrtavanju.
    final salon = ref.watch(adminSalonProvider).valueOrNull;

    return Container(
      height: AdminSize.topBarHeight,
      decoration: BoxDecoration(
        color: context.adminColors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.adminColors.separator,
            width: AdminSize.hairline,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.gutterDesktop,
      ),
      child: Row(
        children: [
          // `Expanded`, ne `Flexible` + `Spacer`.
          //
          // Regresija koju je ovo popravilo: dugmad su stajala **na sredini** top bara,
          // sa velikom prazninom do desne ivice. Uzrok nije bio kod akcija nego ovdje —
          // `Flexible` i `Spacer` oba nose `flex: 1`, pa su **dijelili slobodan prostor
          // na pola**. Breadcrumb je uzimao polovinu koja mu ne treba i gurao akcije do
          // sredine.
          //
          // `Expanded` uzme sav ostatak, pa akcije sjednu uz desnu ivicu. Dugo ime salona
          // se i dalje reže (`Flexible` + `ellipsis` ispod), ne gura dugmad van ekrana.
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (salon != null) ...[
                  Flexible(
                    child: Text(
                      // **Grad, ne puno ime** — `3b` piše „Vitez / Danas". Puno ime salona
                      // stoji u kartici sidebara odmah lijevo; dvaput isto u istom redu
                      // pogleda je šum. Bez grada ostaje ime.
                      salon.city.trim().isEmpty ? salon.name : salon.city,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: context.adminColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Separator je ukras, ne tekst (FE-502): čitač ekrana bi ga izgovorio
                  // kao „kosa crta", a blijeda boja je namjerna, pa ga kontrast ne mjeri.
                  ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 11),
                      child: Text(
                        '/',
                        style: TextStyle(
                          color: context.adminColors.breadcrumbSeparator,
                        ),
                      ),
                    ),
                  ),
                ],
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telefon
// ---------------------------------------------------------------------------

/// Četiri ćelije iz `3k`: tri stavke sa vrha navigacije, pa „Još".
class _DonjaNavigacija extends ConsumerWidget {
  const _DonjaNavigacija({this.aktivna});

  final AdminRoute? aktivna;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final celije = [...adminPrimarne, kAdminJos];

    // Modul iza „Još" označava četvrtu ćeliju: ko je na `/services`, mora vidjeti gdje se
    // nalazi. Bez ovoga pet od osam ekrana stoji bez ijedne označene ćelije.
    final izabrani = celije.indexWhere((c) => c.route == aktivna);
    final krozJos = adminSporedne.any((c) => c.route == aktivna);
    final indeks = izabrani >= 0
        ? izabrani
        : krozJos
        ? celije.length - 1
        : 0;

    return NavigationBar(
      selectedIndex: indeks,
      destinations: [
        for (final cilj in celije)
          NavigationDestination(
            icon: cilj.brojac == null
                ? Icon(cilj.icon)
                : _IkonaSaBrojacem(cilj: cilj),
            label: cilj.label,
          ),
      ],
      onDestinationSelected: (i) {
        final cilj = celije[i];
        if (cilj.route != aktivna) context.go(cilj.putanja);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dijelovi koje dijele obje ljuske
// ---------------------------------------------------------------------------

/// Brojač uz „Zahtjeve" u sidebaru. Canvas: akcent, radius 20, mono 11.
class _Pilula extends ConsumerWidget {
  const _Pilula({required this.brojac});

  final ProviderListenable<AsyncValue<int>> brojac;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broj = ref.watch(brojac).valueOrNull ?? 0;
    // Nula se ne crta: pilula sa `0` kaže „ima ih nula", a prazno mjesto kaže isto i ne
    // traži čitanje.
    if (broj == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        // **Koralna, ne plava** (FE-401). Izmjereno iz `adminv2/export/3b`: pilula uz
        // „Zahtjeve" je `#EE6C4D`, dok je prije stajao `accent` (`#3D5A80`). Par
        // `action`/`onAction` već postoji i već je AA-provjeren — bijela na koralu pada
        // (3,05:1), pa je tekst `#2C2C2C`. Zato ovdje ne ide `onAccent`.
        color: context.adminColors.action,
        borderRadius: BorderRadius.circular(AdminRadius.pill),
      ),
      child: Text(
        '$broj',
        style: AdminText.dataInline.copyWith(
          color: context.adminColors.onAction,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Isti brojač, kao Material `Badge` u donjoj navigaciji.
///
/// **Nula se ne crta uopšte**, kao ni u sidebaru. Ranije je `Badge` uvijek bio vidljiv sa
/// praznim tekstom, a Material prazan `label` iscrta kao **tačku** — pa je salon bez ijednog
/// zahtjeva vidio crvenu tačku nad „Zahtjevima" i otvarao prazan ekran. Widget test to nije
/// uhvatio jer `Badge` i dalje postoji i `Text` je prazan; vidjelo se tek na uređaju.
class _IkonaSaBrojacem extends ConsumerWidget {
  const _IkonaSaBrojacem({required this.cilj});

  final AdminDestination cilj;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broj = ref.watch(cilj.brojac!).valueOrNull ?? 0;
    final ikona = Icon(cilj.icon);
    if (broj == 0) return ikona;

    return Badge(label: Text('$broj'), child: ikona);
  }
}

/// Meni naloga u `AppBar`-u telefona.
class AdminNalogDugme extends ConsumerWidget {
  const AdminNalogDugme({this.ikona = false, super.key});

  final bool ikona;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clan = ref.watch(currentStaffProvider).valueOrNull;

    return PopupMenuButton<String>(
      tooltip: 'Nalog',
      icon: ikona ? const Icon(Icons.account_circle_outlined) : null,
      onSelected: (izbor) async {
        if (izbor == 'odjava') await odjavi(context, ref);
      },
      itemBuilder: (context) => [
        if (clan != null)
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clan.name),
                Text(clan.email, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'odjava', child: Text('Odjavi se')),
      ],
    );
  }
}

/// Odjava, sa porukom kad ne prođe.
///
/// Stoji kao funkcija jer je zovu tri mjesta: meni u `AppBar`-u, meni podnožja sidebara i
/// „Još".
/// Preusmjeravanje na `/login` radi router kroz `currentStaffProvider`.
Future<void> odjavi(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(staffRepositoryProvider).signOut();
  } on ApiError {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odjava nije uspjela. Pokušajte ponovo.')),
      );
    }
  }
}

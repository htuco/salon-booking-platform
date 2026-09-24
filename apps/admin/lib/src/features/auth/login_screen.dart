/// Prijava osoblja — email i lozinka, po prikazima `3j` (desktop) i `3u` (telefon).
///
/// **Bez OTP-a i bez nativnih providera**, za razliku od klijentskog login ekrana. Admin
/// sjedi za pultom i prijavljuje se više puta dnevno; čekanje na mail pri svakoj prijavi je
/// tok za korisnika koji se prijavi jednom u tri mjeseca. Apple i Google ovdje nemaju svrhu
/// — nalog osoblja pravi salon, ne korisnik sam.
///
/// ## Šta iz canvasa namjerno **nije** nacrtano
///
/// Handoff crta i kontrole koje iza sebe nemaju ništa. Dugme koje ne radi je gore od
/// dugmeta kojeg nema: vlasnik ga pritisne jednom, ne desi se ništa, i od tog trenutka ne
/// vjeruje ni ostatku ekrana.
///
/// - **„Prijava kodom na telefon" (`3j`) i „Face ID" (`3u`)** — `SPEC.md`, „Funkcionalne
///   granice": prijava ostaje email + lozinka. Nema ni SMS providera ni `local_auth`
///   paketa u repou.
/// - **„Zaboravljena?"** — reset lozinke je tok sa svojom rutom (mail → link → nova
///   lozinka), ne labela. Dok te rute nema, link vodi u prazno; upisan je kao dug u
///   `tasks/sprint-3/README.md`.
/// - **„Ostani prijavljen na ovom računaru"** — `supabase_flutter` sesiju čuva **uvijek**,
///   a isključivanje toga nije opcija poziva nego drugi `AuthFlowType`. Kvačica koja ne
///   mijenja ništa je obećanje kontrole koje aplikacija ne drži.
/// - **„Trenutno na platformi: 6 lokacija · 19 majstora · 84 termina"** — to nisu demo
///   brojevi nego **tuđi podaci**: zbir preko svih salona, koji jedan `salon_admin` po
///   RLS-u ne smije vidjeti (`ADR-0003`). Ekran koji ih traži tražio bi ih neprijavljen.
/// - **Fotografija salona** — `SPEC.md`: „Fotografije u `canvas/assets/` su placeholderi.
///   Ne ulaze automatski u produkcijski bundle." Ostaje tamna ploha i gradijent, tj. oblik
///   kompozicije bez tuđe slike.
///
/// ## Jedna rečenica copy-ja je promijenjena
///
/// Canvas ispod naslova piše „Jedan račun za sve vaše lokacije." Aplikacija danas daje
/// **tačno jedan** salon iz membershipa, a višelokacijski pregled (`3a`) je izvan sprinta
/// — rečenica bi obećavala ono što proizvod nema. Ostaje „Upravljanje terminima vašeg
/// salona.", kao u tasku 23. Isti razlog kao u tasku 21, gdje handoff copy tvrdi da app
/// čuva broj telefona koji nikad ne traži.
library;

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/admin_wordmark.dart';

/// Širina bijele kolone sa formom na desktopu (`3j`: `width:560px;flex:0 0 560px`).
///
/// **Fiksna je, a tamna ploha pored nje raste.** To je razlog zašto ekran uopšte ima dvije
/// kolone: forma ostaje čitljiva i na 2560 px, umjesto da se polje za email razvuče preko
/// pola monitora. 1440 iz canvasa je mjesto gdje je crtano, ne maksimum na kojem se radi.
const double _formaSirina = 560;

/// Horizontalni padding forme unutar te kolone (`3j`: `padding:0 72px`).
const double _formaPadding = 72;

/// Širina ispod koje tamna ploha nestaje, a forma zauzima cijeli ekran.
///
/// **Namjerno nije [AdminBreakpoint.desktop] (840).** Taj prag bira ljusku — sidebar ili
/// donju navigaciju — a prijava nema ljusku: to je jedini ekran koji vidi neprijavljen
/// korisnik. Ovdje prag bira hoće li pored forme od [_formaSirina] (560 px) stajati i ploha.
/// Na 840 bi joj ostalo ~280 px, što je pretanko da nosi išta osim šare, a forma bi se
/// stiskala zbog nje. Na 1000 ploha dobije ~440 px i ima smisla.
const double kPragFotografije = 1000;

/// Ko uopšte može ući — jedina rečenica iz canvasa koja o tome govori (`3u`).
const String kPristupNapomena =
    'Pristup imaju samo vlasnik i majstori lokacije.';

/// Visina tamnog zaglavlja na telefonu (`3u`: `height:280px;flex:0 0 280px`).
const double _heroVisina = 280;

/// Ključ tamne plohe.
///
/// Postoji zbog testa, i to svjesno: ploha je obična `DecoratedBox`, a ekran ih ima više
/// (kvadrat logotipa je isto jedna). Test bez ključa bi mjerio prvu na koju naiđe i
/// prolazio nad pogrešnim widgetom — tačno ona vrsta zelenog testa koju je task 29 našao
/// kod guttera.
const Key kAdminLoginPlohaKey = ValueKey('admin-login-tamna-ploha');

/// Prijava osoblja.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _lozinka = TextEditingController();

  bool _uToku = false;
  bool _lozinkaVidljiva = false;
  String? _greska;

  @override
  void dispose() {
    _email.dispose();
    _lozinka.dispose();
    super.dispose();
  }

  Future<void> _prijavi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _uToku = true;
      _greska = null;
    });

    try {
      final clan = await ref
          .read(staffRepositoryProvider)
          .signIn(email: _email.text.trim(), password: _lozinka.text);

      if (!mounted) return;

      // `null` znaci: token je ispravan, ali reda u `public.users` nema. To **nije**
      // pogresna lozinka nego pogresno postavljen nalog, i mora imati svoju poruku —
      // inace vlasnik bezuspjesno pokusava lozinku koja je sve vrijeme bila tacna.
      if (clan == null || !clan.imaPristup) {
        await ref.read(staffRepositoryProvider).signOut();
        if (!mounted) return;
        setState(() {
          _uToku = false;
          _greska =
              'Prijava je uspjela, ali ovaj nalog nije vezan ni za jedan salon. '
              'Javite se podršci.';
        });
        return;
      }

      // Preusmjeravanje radi router kroz `currentStaffProvider` — ekran ne navigira sam.
      // Dva mjesta koja odlucuju gdje korisnik ide poslije prijave se raziđu prvi put kad
      // se doda jos jedan ulaz (deep link, istek sesije).
    } on ApiError catch (greska) {
      if (!mounted) return;
      setState(() {
        _uToku = false;
        _greska = _poruka(greska);
      });
    }
  }

  /// Prevodi `ApiError` u recenicu koju vlasnik salona moze procitati.
  ///
  /// Pogresni podaci se **ne razdvajaju** na „nema takvog emaila" i „pogresna lozinka":
  /// prva varijanta kaze napadacu koji email postoji u sistemu.
  String _poruka(ApiError greska) => switch (greska) {
    AuthRejectedError() => 'Pogrešan email ili lozinka.',
    NetworkError() => 'Nema veze sa internetom. Provjerite konekciju.',
    // GoTrue limitira pokusaje prijave. Bez svoje poruke bi ovo izgledalo kao da je
    // lozinka pogresna, pa bi vlasnik pokusavao dalje i produzavao blokadu.
    RateLimitError() =>
      'Previše pokušaja. Sačekajte minutu pa pokušajte ponovo.',
    _ => 'Prijava nije uspjela. Pokušajte ponovo.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bijela, ne radna siva: u oba prikaza forma stoji na plohi kartice, bez kartice.
      backgroundColor: context.adminColors.surface,
      // **Prijava ima svoj prag, i to je izuzetak sa razlogom.** Ostatak admina se prelama
      // na `AdminBreakpoint.desktop` (840), jer tamo prag bira *ljusku*. Ovdje nema ljuske:
      // prijava je jedini ekran koji vidi neprijavljen korisnik, nema ni sidebar ni donju
      // navigaciju. Prag bira hoće li tamna ploha stajati pored forme, a njoj ispod
      // ~1000 px ne ostane dovoljno širine da bude išta osim šare — forma bi se stisnula
      // da bi ploha dobila prostor koji joj ne treba.
      body: MediaQuery.sizeOf(context).width >= kPragFotografije
          ? _desktop(context)
          : _telefon(),
    );
  }

  /// `3j`: bijela kolona sa formom lijevo, tamna ploha koja zauzme ostatak širine.
  Widget _desktop(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _formaSirina,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: _formaPadding,
                vertical: AdminSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminWordmark(
                    naTamnom: false,
                    potpis: true,
                    velicinaZnaka: 36,
                  ),
                  const SizedBox(height: AdminSpacing.xxxl),
                  _forma(context),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: _TamnaPloha()),
      ],
    );
  }

  /// `3u`: tamno zaglavlje, forma ispod njega, primarna radnja fiksirana u dnu.
  ///
  /// Dugme je **izvan** skrola, kako ga canvas i crta (`border-top` pa `padding`): na
  /// telefonu sa otvorenom tastaturom forma skroluje, a „Prijavi se" ostaje na ekranu.
  Widget _telefon() {
    return Column(
      // `stretch`, ne default `center`: bez toga traka u dnu i „Prijavi se" u njoj dobiju
      // širinu svog teksta, pa dugme stoji kao mala pilula nasred ekrana. Widget test to
      // ne vidi — dugme postoji i tapa se — vidjelo se tek na snimku.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _heroVisina, child: _TamnaPloha(hero: true)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.gutterMobile,
              22,
              AdminSpacing.gutterMobile,
              AdminSpacing.xxl,
            ),
            child: Builder(builder: _forma),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminSpacing.gutterMobile,
            AdminSpacing.md,
            AdminSpacing.gutterMobile,
            30,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: context.adminColors.separator,
                width: AdminSize.hairline,
              ),
            ),
          ),
          child: _dugme(visina: 54),
        ),
      ],
    );
  }

  /// Naslov, polja i greška — isti sadržaj na obje širine.
  ///
  /// Na desktopu nosi i dugme, jer ga `3j` crta u koloni ispod polja; na telefonu dugme
  /// stoji u traci ispod skrola, pa ga ovdje nema.
  Widget _forma(BuildContext context) {
    final theme = Theme.of(context);
    // **Isti prag kao raspored, ne `AdminShell.jeDesktop`.** Ovo je bio pravi bug: dok je
    // raspored prešao na [kPragFotografije] (1000), forma je i dalje pitala prag ljuske
    // (840), pa je u pojasu 840–1000 dugme „Prijavi se" crtano **dvaput** — jednom ovdje,
    // jednom u traci ispod skrola. Vidjelo se tek u browseru na 960 px; nijedan test to
    // nije hvatao jer su testne širine (1440, 1920, 402) preskakale taj pojas.
    final jeDesktop = MediaQuery.sizeOf(context).width >= kPragFotografije;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prijava',
            style: jeDesktop
                ? theme.textTheme.displayLarge
                : theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Upravljanje terminima vašeg salona.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.adminColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          _Polje(
            labela: 'E-mail',
            controller: _email,
            enabled: !_uToku,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            validator: (vrijednost) {
              final unos = vrijednost?.trim() ?? '';
              if (unos.isEmpty) return 'Unesite email.';
              // Namjerno labava provjera: stroga regex validacija emaila odbija
              // ispravne adrese cesce nego sto hvata pogresne, a server ionako
              // odlucuje postoji li nalog.
              if (!unos.contains('@')) return 'Email nije ispravan.';
              return null;
            },
          ),
          const SizedBox(height: AdminSpacing.lg),
          _Polje(
            labela: 'Lozinka',
            controller: _lozinka,
            enabled: !_uToku,
            obscure: !_lozinkaVidljiva,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _uToku ? null : _prijavi(),
            // Canvas ovdje crta **tekst** („Prikaži"), ne ikonu oka: na 3u je to jedina
            // kontrola u polju i mora se pogoditi prstom.
            akcija: TextButton(
              onPressed: () =>
                  setState(() => _lozinkaVidljiva = !_lozinkaVidljiva),
              child: Text(_lozinkaVidljiva ? 'Sakrij' : 'Prikaži'),
            ),
            validator: (vrijednost) =>
                (vrijednost ?? '').isEmpty ? 'Unesite lozinku.' : null,
          ),
          if (_greska != null) ...[
            const SizedBox(height: AdminSpacing.lg),
            // Greska stoji **iznad** dugmeta, ne ispod: ispod je van vidnog polja
            // kad tastatura pokrije donji dio ekrana.
            Container(
              padding: const EdgeInsets.all(AdminSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AdminRadius.base),
              ),
              child: Text(
                _greska!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          if (jeDesktop) ...[
            const SizedBox(height: AdminSpacing.xxl),
            _dugme(visina: 52),
          ] else ...[
            // Na desktopu ista rečenica stoji na tamnoj plohi; ovdje je ispod polja, kako
            // je `3u` i crta.
            const SizedBox(height: AdminSpacing.xl),
            Text(
              kPristupNapomena,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.adminColors.textMuted,
                height: 1.6,
              ),
            ),
          ],
          // Task 45: radnik sa pozivom nema nalog, pa mu prijava sama ne pomaže.
          const SizedBox(height: AdminSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go(AdminRoute.pozivnica.path),
              child: const Text('Imam poziv od salona'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dugme({required double visina}) => SizedBox(
    height: visina,
    child: FilledButton(
      onPressed: _uToku ? null : _prijavi,
      // Dugme je **koralno sa tamnim tekstom** i to dolazi iz teme (`FilledButton` →
      // `action`/`onAction`), ne odavde: `3j` ga crta koralnim, a bijeli tekst na koralu
      // pada AA (3,05:1), pa je `#2C2C2C`. Raniji komentar je ovdje tvrdio da je dugme
      // „akcentna plava" po starom canvasu — to više ne važi (ADR-0016).
      child: _uToku ? const _IndikatorPrijave() : const Text('Prijavi se'),
    ),
  );
}

/// Indikator u toku prijave — **tri tačke, ne Material spinner.**
///
/// `CircularProgressIndicator` je Material potpis: debljina, tempo i luk se ne daju uskladiti
/// sa ostatkom admina, a na koralnom dugmetu je bijeli luk i padao AA. FE-205 ukida default
/// Flutter indikatore kroz cijelu aplikaciju; ovdje je uveden samo za dugme prijave, jer je
/// prijava **jedini ekran koji vidi neprijavljen korisnik** i indikator se tu najviše gleda.
///
/// Boja je `onAction` (`#2C2C2C`), ista kao tekst dugmeta — ne `onAccent`, koji je bijel.
class _IndikatorPrijave extends StatefulWidget {
  const _IndikatorPrijave();

  @override
  State<_IndikatorPrijave> createState() => _IndikatorPrijaveState();
}

class _IndikatorPrijaveState extends State<_IndikatorPrijave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontroler = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _kontroler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boja = context.adminColors.onAction;

    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: _kontroler,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              Opacity(
                // Tri tačke pulsiraju u nizu: svaka kasni trećinu ciklusa za prethodnom.
                opacity: _prozirnost((_kontroler.value + i / 3) % 1),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: boja,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Puna vidljivost na vrhu ciklusa, 0,3 na dnu — tačka nikad ne nestane sasvim, da se
  /// dugme ne čita kao da je izgubilo sadržaj.
  static double _prozirnost(double t) => 0.3 + 0.7 * (1 - (2 * t - 1).abs());
}

/// Polje sa labelom **iznad** okvira, kako ga canvas crta.
///
/// Material bi labelu po defaultu spustio u okvir i podigao je pri fokusu; handoff je drži
/// vani, sitnu i sivu, pa se polja čitaju kao lista parova labela–vrijednost.
class _Polje extends StatelessWidget {
  const _Polje({
    required this.labela,
    required this.controller,
    required this.validator,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.akcija,
  });

  final String labela;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final void Function(String)? onSubmitted;
  final Widget? akcija;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          labela,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.adminColors.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          autocorrect: false,
          onFieldSubmitted: onSubmitted,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            // 14 px horizontalno je iz canvasa; vertikalno daje okvir od ~50 px, koliko
            // `3j` i crta. Fiksna visina se ne postavlja — poruka validacije mora imati
            // gdje da stane.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            suffixIcon: akcija,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Tamna ploha: desna kolona na desktopu, zaglavlje na telefonu.
///
/// Umjesto fotografije iz canvasa nosi gradijent — v. „Šta iz canvasa namjerno nije
/// nacrtano" na vrhu fajla. Na telefonu (`3u`) na njoj stoji logotip, jer ga forma ispod
/// nema; na desktopu logotip stoji u formi, pa ploha nosi rečenicu o tome ko uopšte ima
/// pristup. **Isti blok na oba mjesta bi značio dva logotipa na jednom ekranu** — prvi
/// snimak je izgledao tačno tako.
class _TamnaPloha extends StatelessWidget {
  const _TamnaPloha({this.hero = false});

  /// `true` je telefonski oblik (`3u`): logotip stoji u dnu, uz donju ivicu.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: kAdminLoginPlohaKey,
      decoration: BoxDecoration(
        color: context.adminColors.sidebarBackground,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.adminColors.sidebarRaised,
            context.adminColors.sidebarBackground,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(hero ? AdminSpacing.xl : 48),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: hero
              ? const AdminWordmark(
                  naTamnom: true,
                  potpis: true,
                  velicinaZnaka: 36,
                )
              : Text(
                  kPristupNapomena,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.adminColors.sidebarText,
                    height: 1.6,
                  ),
                ),
        ),
      ),
    );
  }
}

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';

/// Prijava osoblja — email i lozinka.
///
/// **Bez OTP-a i bez nativnih providera**, za razliku od klijentskog login ekrana. Admin
/// sjedi za pultom i prijavljuje se više puta dnevno; čekanje na mail pri svakoj prijavi je
/// tok za korisnika koji se prijavi jednom u tri mjeseca. Apple i Google ovdje nemaju svrhu
/// — nalog osoblja pravi salon, ne korisnik sam.
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
      if (clan == null || !clan.isSalonAdmin) {
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            // Admin se otvara i na sirokom ekranu (web, tablet): forma preko cijele
            // sirine monitora je neprakticna za citanje i za tap.
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Prijava',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upravljanje terminima vašeg salona.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    enabled: !_uToku,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lozinka,
                    enabled: !_uToku,
                    obscureText: !_lozinkaVidljiva,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _uToku ? null : _prijavi(),
                    decoration: InputDecoration(
                      labelText: 'Lozinka',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _lozinkaVidljiva = !_lozinkaVidljiva,
                        ),
                        icon: Icon(
                          _lozinkaVidljiva
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        tooltip: _lozinkaVidljiva
                            ? 'Sakrij lozinku'
                            : 'Prikaži lozinku',
                      ),
                    ),
                    validator: (vrijednost) =>
                        (vrijednost ?? '').isEmpty ? 'Unesite lozinku.' : null,
                  ),
                  if (_greska != null) ...[
                    const SizedBox(height: 16),
                    // Greska stoji **iznad** dugmeta, ne ispod: ispod je van vidnog polja
                    // kad tastatura pokrije donji dio ekrana.
                    Container(
                      padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _uToku ? null : _prijavi,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _uToku
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Prijavi se'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

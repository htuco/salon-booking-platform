/// „Imam poziv" — radnik pravi nalog iz koda koji mu je poslao vlasnik (task 45, ADR-0023).
///
/// Radnik unosi samo ono što je njegovo: kod, email i lozinku. Uloga i salon stoje u pozivu
/// i ne mogu se promijeniti odavde. Poslije uspješnog poziva ekran odmah prijavljuje istim
/// podacima, pa se preusmjeravanje dešava kao i poslije svake prijave — kroz router.
library;

import 'package:core_api/core_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/poruka_greske.dart';
import '../../core/router/admin_router.dart';
import '../../core/theme/theme.dart';

class AdminPozivnicaScreen extends ConsumerStatefulWidget {
  const AdminPozivnicaScreen({this.kod, super.key});

  /// Iz linka `/pozivnica?kod=...` — radnik tada ne prepisuje kod.
  final String? kod;

  @override
  ConsumerState<AdminPozivnicaScreen> createState() =>
      _AdminPozivnicaScreenState();
}

class _AdminPozivnicaScreenState extends ConsumerState<AdminPozivnicaScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _kod;
  final _email = TextEditingController();
  final _lozinka = TextEditingController();
  bool _uToku = false;
  String? _greska;
  String? _info;

  @override
  void initState() {
    super.initState();
    _kod = TextEditingController(text: widget.kod ?? '');
  }

  @override
  void dispose() {
    _kod.dispose();
    _email.dispose();
    _lozinka.dispose();
    super.dispose();
  }

  Future<void> _napravi() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _uToku = true;
      _greska = null;
      _info = null;
    });
    final email = _email.text.trim();
    try {
      await ref
          .read(staffAccessRepositoryProvider)
          .acceptInvite(
            code: _kod.text.trim(),
            email: email,
            password: _lozinka.text,
          );
      final clan = await ref
          .read(staffRepositoryProvider)
          .signIn(email: email, password: _lozinka.text);
      if (!mounted) return;
      // Radnički pristup (`employee`) otvaraju taskovi 46 i 47. Do tada je nalog napravljen,
      // ali ga router ne pušta dalje od prijave — ekran to mora reći, ne ćutati.
      if (clan == null || !clan.isSalonAdmin) {
        await ref.read(staffRepositoryProvider).signOut();
        if (!mounted) return;
        setState(() {
          _uToku = false;
          _info =
              'Nalog je napravljen. Radnički pristup aplikaciji se uključuje '
              'uskoro — prijavićete se istim emailom i lozinkom.';
        });
      }
      // Vlasnika router sam odvodi na početnu, kao poslije svake prijave.
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _uToku = false;
        _greska = porukaGreske(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final boje = context.adminColors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AdminSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Imam poziv', style: theme.textTheme.headlineLarge),
                      const SizedBox(height: AdminSpacing.sm),
                      Text(
                        'Unesite kod koji vam je poslao salon, pa email i lozinku '
                        'kojom ćete se prijavljivati.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: boje.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.xl),
                      TextFormField(
                        controller: _kod,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Kod poziva',
                        ),
                        validator: (v) => (v ?? '').trim().length < 6
                            ? 'Upišite kod iz poruke.'
                            : null,
                      ),
                      const SizedBox(height: AdminSpacing.lg),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.newUsername],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch((v ?? '').trim())
                            ? null
                            : 'Email nije ispravan.',
                      ),
                      const SizedBox(height: AdminSpacing.lg),
                      TextFormField(
                        controller: _lozinka,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Lozinka',
                          helperText: 'Najmanje 8 znakova.',
                        ),
                        validator: (v) => (v ?? '').length < 8
                            ? 'Lozinka mora imati najmanje 8 znakova.'
                            : null,
                        onFieldSubmitted: (_) => _napravi(),
                      ),
                      if (_greska case final g?) ...[
                        const SizedBox(height: AdminSpacing.lg),
                        Text(g, style: TextStyle(color: boje.destructive)),
                      ],
                      if (_info case final i?) ...[
                        const SizedBox(height: AdminSpacing.lg),
                        Text(i, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: AdminSpacing.xl),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _uToku ? null : _napravi,
                          child: Text(
                            _uToku ? 'Pravim nalog…' : 'Napravi nalog',
                          ),
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      TextButton(
                        onPressed: () => context.go(AdminRoute.login.path),
                        child: const Text('Već imam nalog — prijava'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

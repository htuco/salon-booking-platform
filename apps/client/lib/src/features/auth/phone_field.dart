import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';

/// Stanje polja telefona: izabrani pozivni i lokalni broj.
///
/// Kontroler, a ne `onChanged`, iz istog razloga kao `TextEditingController`: forma čita
/// vrijednost tek na „Kreiraj račun", a ne prati svaki pritisak tipke.
class PhoneFieldController {
  PhoneFieldController() : broj = TextEditingController();

  final TextEditingController broj;
  String pozivni = phoneCountryCodes.first.code;

  /// Broj kakav ide u bazu („+387 61 123 456"), ili `null` dok lokalni dio nije ispravan.
  String? get vrijednost => isValidNationalNumber(broj.text)
      ? composePhone(pozivni, broj.text)
      : null;

  void dispose() => broj.dispose();
}

/// Telefon sa izborom pozivnog broja (task 66). **+387 je podrazumijevani**, jer je većina
/// klijenata iz BiH; dijaspora bira svoj, umjesto da kuca `+49` ispred broja.
///
/// Korisnik kuca broj onako kako ga zna lokalno („061 123 456"); vodeća nula otpada tek u
/// [PhoneFieldController.vrijednost]. Polje pušta samo cifre i znakove grupisanja, pa slovo
/// ne može ni ući.
class PhoneField extends StatefulWidget {
  const PhoneField({
    required this.controller,
    this.greska,
    this.enabled = true,
    this.fieldKey,
    super.key,
  });

  final PhoneFieldController controller;
  final String? greska;
  final bool enabled;

  /// Ključ samog tekstualnog polja, za testove.
  final Key? fieldKey;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = widget.controller;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('phone-country'),
            initialValue: c.pozivni,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.loginPhoneCountryLabel),
            // U zatvorenom polju samo pozivni; ime države je u meniju.
            selectedItemBuilder: (context) => [
              for (final p in phoneCountryCodes) Text(p.code),
            ],
            items: [
              for (final p in phoneCountryCodes)
                DropdownMenuItem(
                  value: p.code,
                  child: Text('${p.code}  ${p.country}'),
                ),
            ],
            onChanged: widget.enabled
                ? (v) => setState(() => c.pozivni = v ?? c.pozivni)
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: TextField(
            key: widget.fieldKey,
            controller: c.broj,
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9 /().-]')),
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              labelText: l10n.loginPhoneLabel,
              hintText: l10n.loginPhoneHint,
              helperText: l10n.loginPhoneHelper,
              helperMaxLines: 3,
              errorText: widget.greska,
              errorMaxLines: 2,
            ),
          ),
        ),
      ],
    );
  }
}

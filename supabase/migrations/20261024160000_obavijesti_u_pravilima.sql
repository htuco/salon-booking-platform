-- Platformska sekcija „Obavijesti" u Pravilima korištenja.
--
-- Salon više nema prekidač „Potvrda termina" (task 54): obavijest o prihvaćenom, odbijenom i
-- otkazanom zahtjevu `send-push` šalje uvijek i salon je ne može isključiti. Prekidač koji se
-- ne može pomjeriti nije ništa omogućavao, pa se ta činjenica sada kaže klijentu, u pravilima.
--
-- `sort_order = 15` stavlja sekciju odmah iza „Zakazivanja", koje se na obavijest poziva.
-- Salonske sekcije dijele isti brojni prostor, pa 15 ne smije biti zauzet; unique
-- (document, sort_order) to ionako brani.
--
-- **Verzija Uslova (`legal_versions()`) se ne podiže.** Sekcija ne mijenja prava ni obaveze
-- klijenta, nego opisuje ponašanje koje već postoji; podizanje bi svakog postojećeg klijenta
-- vratilo na „Dopuni profil". Ako se odluči drugačije, to je zasebna izmjena (ADR-0030).
--
-- `on conflict do nothing`: migracija se ne prepisuje preko ručno izmijenjenog teksta.

insert into public.app_policies(document, sort_order, title, body) values
('terms', 15, 'Obavijesti',
 'Svaki klijent aplikacije dobija obavijesti o svojim zahtjevima i terminima: kad salon prihvati, odbije ili otkaže vaš zahtjev ili termin. Te obavijesti se šalju uvijek i salon ih ne može isključiti.

Ako salon uključi podsjetnike, stiže i podsjetnik prije termina. Dobijate i obavijest kad se oslobodi termin za koji ste na listi čekanja, te poziv da ocijenite završen termin.

Obavijesti stižu samo ako ste aplikaciji dozvolili obavijesti na telefonu. Dozvolu možete povući u postavkama telefona.')
on conflict do nothing;

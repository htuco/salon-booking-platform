import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Povratak na ekran ispod, a kad ga nema — na [ruta].
///
/// Flow i prijava se otvaraju sa `push`, pa ispod stoji stvarni prethodni ekran: dugme
/// „Nazad" i iOS swipe sa lijeve ivice tada rade isto (`pop`). Ekran otvoren direktnim
/// linkom ili hladnim startom stoji sam na stacku; tada `pop` nema šta skinuti i ide se
/// na [ruta].
///
/// Ranije je dugme radilo `go` na prethodni korak, a naprijed se išlo isto sa `go`. Ekran
/// je zato uvijek bio sam na stacku, swipe nije imao šta vratiti, a dugme je „radilo"
/// jer je ponovo gradilo prethodni korak — razlika se vidjela samo na uređaju.
extension NazadIli on BuildContext {
  void nazadIli(String ruta) {
    if (canPop()) {
      pop();
    } else {
      go(ruta);
    }
  }
}

import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';

/// Kako `CachedNetworkImage` na webu dobija sliku — **isto na svakom mjestu u aplikaciji.**
///
/// Zadani `HtmlImage` pušta browser da dekodira sliku u `ImageBitmap`, a CanvasKit ga drži
/// kao teksturu. Kad je tab u `StatefulShellRoute`-u van ekrana, browser taj bitmap oslobodi,
/// i povratak na Početnu crta **crn okvir** (`WebGL: texImage2D: no image` u konzoli) —
/// viđeno na Flutteru 3.47, slike tima nestaju poslije Usluge → Početna.
///
/// `HttpGet` skida bajtove i dekodira ih u CanvasKitu, bez `ImageBitmap`-a, pa nema šta da
/// se oslobodi. Na Androidu i iOS-u se ova vrijednost ne čita.
///
/// Mora biti ista svuda: `CachedNetworkImageProvider ==` ne gleda ovo polje, pa mreža i
/// lightbox dijele isti unos u kešu bez obzira kojim su putem dekodirani.
const webImageRenderMethod = ImageRenderMethodForWeb.HttpGet;

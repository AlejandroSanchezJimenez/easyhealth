import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Banner adaptativo a todo el ancho, situado encima de la barra de
/// navegación.
///
/// Si no hay anuncio (sin red, ID de app pendiente, cuenta recién creada) se
/// colapsa a altura cero, así que nunca descuadra la pantalla.
///
/// El tamaño adaptativo depende del ANCHO, no de la orientación: al rotar hay
/// que pedir uno nuevo y recargar. Por eso se compara el ancho actual con el
/// del último banner mostrado.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  AdSize? _size;
  int _loadedForWidth = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded(MediaQuery.of(context).size.width.truncate());
  }

  void _ensureLoaded(int width) {
    if (!AdConfig.enabled || width <= 0) return;
    if (_loadedForWidth == width) return;

    _loadedForWidth = width; // se fija antes de await: evita dobles cargas
    _load(width);
  }

  Future<void> _load(int width) async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted || size == null) return;

    final previous = _ad;
    setState(() {
      _ad = null;
      _size = null;
    });
    previous?.dispose();

    // `late final` porque los callbacks se cierran sobre `ad` y solo se
    // ejecutan después de que exista (identical(_ad, ad) descarta respuestas
    // de un banner que ya se ha sustituido al rotar).
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        // El callback recibe un `Ad` genérico: se usa la instancia creada aquí,
        // que sí conoce su propio `size`.
        onAdLoaded: (_) {
          if (!mounted || !identical(_ad, ad)) return;
          setState(() => _size = size);
        },
        onAdFailedToLoad: (failed, _) {
          failed.dispose();
          if (!mounted || !identical(_ad, ad)) return;
          setState(() {
            _ad = null;
            _size = null;
          });
        },
      ),
    );

    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    final size = _size;
    if (ad == null || size == null) return const SizedBox.shrink();

    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
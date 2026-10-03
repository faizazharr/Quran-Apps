import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/ads_config.dart';
import '../../data/services/ads_service.dart';

/// Adaptive banner. Renders nothing until an ad is loaded, on unsupported
/// platforms, or when consent / load fails.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.ready.addListener(_onReady);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onReady();
  }

  void _onReady() => unawaited(_maybeLoad());

  Future<void> _maybeLoad() async {
    if (!AdsConfig.supported ||
        !AdsService.instance.ready.value ||
        _ad != null ||
        _loading) {
      return;
    }
    _loading = true;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) {
      _loading = false;
      return;
    }
    unawaited(
      BannerAd(
        adUnitId: AdsConfig.bannerUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _loading = false;
            if (!mounted) {
              unawaited(ad.dispose());
              return;
            }
            setState(() => _ad = ad as BannerAd);
          },
          onAdFailedToLoad: (ad, _) {
            _loading = false;
            unawaited(ad.dispose());
          },
        ),
      ).load(),
    );
  }

  @override
  void dispose() {
    AdsService.instance.ready.removeListener(_onReady);
    final old = _ad;
    if (old != null) unawaited(old.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

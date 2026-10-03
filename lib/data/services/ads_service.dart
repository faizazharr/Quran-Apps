import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/config/ads_config.dart';

/// Initialises the Mobile Ads SDK after gathering user consent (UMP / GDPR).
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  final ValueNotifier<bool> ready = ValueNotifier(false);
  bool _started = false;

  Future<void> init() async {
    if (!AdsConfig.supported || _started) return;
    _started = true;

    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        consentDone.complete();
      },
      (_) => consentDone.complete(), // consent check failed: fall through
    );
    await consentDone.future;

    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
      ready.value = true;
    }
  }
}

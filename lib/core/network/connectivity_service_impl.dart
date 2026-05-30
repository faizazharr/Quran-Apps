import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_service.dart';

/// Concrete implementation backed by `connectivity_plus`.
class ConnectivityServiceImpl implements IConnectivityService {
  final Connectivity _connectivity;

  ConnectivityServiceImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

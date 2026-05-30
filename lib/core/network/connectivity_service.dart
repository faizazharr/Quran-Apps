/// Abstraction over the device network status.
///
/// Defined as an interface so the rest of the app depends on a contract
/// (Dependency Inversion Principle) and tests can supply a fake.
abstract class IConnectivityService {
  /// Returns `true` if the device currently has any network connection.
  Future<bool> isConnected();
}

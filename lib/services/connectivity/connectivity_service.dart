import 'package:connectivity_plus/connectivity_plus.dart';

/// Expose l'état de connexion réseau sous forme de flux booléen simple.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// `true` dès qu'au moins une interface réseau est disponible.
  Stream<bool> get onConnectedChanged =>
      _connectivity.onConnectivityChanged.map(_isConnected);

  Future<bool> get isConnected async =>
      _isConnected(await _connectivity.checkConnectivity());

  bool _isConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}

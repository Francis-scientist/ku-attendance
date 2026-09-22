import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over `connectivity_plus`.
///
/// IMPORTANT: connectivity only reports whether a network *interface* exists,
/// not whether the internet actually works. It is used for fast, friendly
/// pre-checks. The authoritative "are we online?" signal for attendance is that
/// the callable Cloud Function fails immediately when offline (callable
/// functions are live HTTPS round-trips and never queue), which is exactly what
/// we want — we never tell a student "marked" unless the server confirmed it.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  Future<bool> get isOnline async =>
      _hasConnection(await _connectivity.checkConnectivity());

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}

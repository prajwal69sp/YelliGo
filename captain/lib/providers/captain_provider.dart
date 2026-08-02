import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/captain_state.dart';
import '../services/mock_dispatch_service.dart';

final mockDispatchServiceProvider = Provider((ref) => MockDispatchService());

final captainControllerProvider =
    StateNotifierProvider<CaptainController, CaptainState>((ref) {
  return CaptainController(ref.read(mockDispatchServiceProvider));
});

/// Correct OTP for the mock trip-start flow (in production this comes from
/// `rides.otp_code` and is verified server-side, same as the SQL lifecycle
/// query: `WHERE status = 'ARRIVED' AND otp_code = $2`).
const _mockCorrectOtp = '1234';

class CaptainController extends StateNotifier<CaptainState> {
  final MockDispatchService _dispatch;
  StreamSubscription<IncomingRide>? _alertSub;
  Timer? _countdownTimer;

  CaptainController(this._dispatch)
      : super(const Offline(
          earnings: EarningsSummary(todayEarnings: 0, todayTrips: 0, rating: 4.9),
        ));

  void goOnline(LatLng currentLocation) {
    if (state is! Offline) return;
    state = OnlineSearching(earnings: state.earnings);

    _alertSub?.cancel();
    _alertSub = _dispatch.listenForRideAlerts(currentLocation).listen((ride) {
      if (state is OnlineSearching) {
        _showIncomingRequest(ride);
      }
    });
  }

  void goOffline() {
    _alertSub?.cancel();
    _countdownTimer?.cancel();
    state = Offline(earnings: state.earnings);
  }

  void _showIncomingRequest(IncomingRide ride) {
    const totalSeconds = 15;
    state = IncomingRequest(
      ride: ride,
      secondsRemaining: totalSeconds,
      earnings: state.earnings,
    );

    _countdownTimer?.cancel();
    var remaining = totalSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      final current = state;
      if (current is! IncomingRequest) {
        timer.cancel();
        return;
      }
      if (remaining <= 0) {
        timer.cancel();
        declineRide(); // auto-decline on timeout, matches backend 15s dispatch window
        return;
      }
      state = IncomingRequest(ride: current.ride, secondsRemaining: remaining, earnings: state.earnings);
    });
  }

  void acceptRide() {
    final current = state;
    if (current is! IncomingRequest) return;
    _countdownTimer?.cancel();
    // Backend equivalent: socket.emit('accept_ride', {ride_id, driver_id})
    // then wait for 'ride_confirmed' before transitioning - here we assume success.
    state = EnRouteToPickup(ride: current.ride, earnings: state.earnings);
  }

  void declineRide() {
    final current = state;
    if (current is! IncomingRequest) return;
    _countdownTimer?.cancel();
    state = OnlineSearching(earnings: state.earnings);
  }

  void markArrivedAtPickup() {
    final current = state;
    if (current is! EnRouteToPickup) return;
    // Backend equivalent: PATCH /trips/:id/arrive (ACCEPTED -> ARRIVED)
    state = ArrivedAtPickup(ride: current.ride, earnings: state.earnings);
  }

  /// Backend equivalent: PATCH /trips/:id/start with OTP check
  /// (ARRIVED -> STARTED only if otp_code matches).
  void verifyOtpAndStart(String enteredOtp) {
    final current = state;
    if (current is! ArrivedAtPickup) return;

    if (enteredOtp != _mockCorrectOtp) {
      state = ArrivedAtPickup(
        ride: current.ride,
        earnings: state.earnings,
        otpError: 'Incorrect OTP. Ask the rider to confirm.',
      );
      return;
    }
    state = OnTrip(ride: current.ride, earnings: state.earnings);
  }

  /// Backend equivalent: PATCH /trips/:id/complete (STARTED -> COMPLETED)
  void completeTrip() {
    final current = state;
    if (current is! OnTrip) return;
    state = TripCompleted(
      ride: current.ride,
      fareCollected: current.ride.fareEstimated,
      earnings: state.earnings,
    );
  }

  /// Rolls the completed trip into today's earnings and returns to searching -
  /// backend equivalent: UPDATE drivers SET status='ONLINE', total_rides += 1
  void confirmPaymentAndContinue() {
    final current = state;
    if (current is! TripCompleted) return;
    final updatedEarnings = state.earnings.addCompletedTrip(current.fareCollected);
    state = OnlineSearching(earnings: updatedEarnings);
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class GyroscopeService {
  final _gyroscopeController = StreamController<GyroscopeEvent>.broadcast();
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  Stream<GyroscopeEvent> get gyroscopeStream => _gyroscopeController.stream;

  void startListening() {
    if (_gyroscopeSubscription == null) {
      _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
        _gyroscopeController.add(event);
      });
    }
  }

  void stopListening() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
  }

  void dispose() {
    stopListening();
    _gyroscopeController.close();
  }
}
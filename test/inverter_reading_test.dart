import 'package:flutter_test/flutter_test.dart';
import 'package:solar_inverter_monitor/models/inverter_reading.dart';

void main() {
  test('parses a complete reading', () {
    final reading = InverterReading.fromRegisters({
      'Battery SOC': 100,
      'Grid Relay Status': 1,
    });
    expect(reading.batterySoc, 100);
    expect(reading.gridOn, isTrue);
  });

  test('parses verified live power values without affecting grid status', () {
    final reading = InverterReading.fromRegisters({
      'Battery SOC': 100,
      'Grid Relay Status': 0,
      'Battery Power': 403,
      'PV1 Power': 10,
      'PV2 Power': 21,
    });

    expect(reading.gridOn, isFalse);
    expect(reading.batteryPowerWatts, 403);
    expect(reading.pvTotalWatts, 31);
  });

  test('power values remain optional and battery power can be negative', () {
    final charging = InverterReading.fromRegisters({
      'Battery SOC': 89,
      'Grid Relay Status': 1,
      'Battery Power': -250,
    });

    expect(charging.batteryPowerWatts, -250);
    expect(charging.pvTotalWatts, isNull);
  });

  test('does not treat missing grid status as an outage', () {
    expect(
      () => InverterReading.fromRegisters({'Battery SOC': 87}),
      throwsFormatException,
    );
  });

  test('rejects invalid register values', () {
    expect(
      () => InverterReading.fromRegisters({
        'Battery SOC': 101,
        'Grid Relay Status': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => InverterReading.fromRegisters({
        'Battery SOC': 87,
        'Grid Relay Status': 2,
      }),
      throwsFormatException,
    );
  });
}

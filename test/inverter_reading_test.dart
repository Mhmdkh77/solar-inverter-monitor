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

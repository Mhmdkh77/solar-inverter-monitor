/// The two values Solar Inverter Monitor needs from a logger poll.
class InverterReading {
  final int batterySoc;
  final bool gridOn;

  const InverterReading({required this.batterySoc, required this.gridOn});

  factory InverterReading.fromRegisters(Map<String, int> registers) {
    final soc = registers['Battery SOC'];
    final grid = registers['Grid Relay Status'];

    if (soc == null || soc < 0 || soc > 100) {
      throw const FormatException('Missing or invalid battery SOC');
    }
    if (grid != 0 && grid != 1) {
      throw const FormatException('Missing or invalid grid relay status');
    }

    return InverterReading(batterySoc: soc, gridOn: grid == 1);
  }
}

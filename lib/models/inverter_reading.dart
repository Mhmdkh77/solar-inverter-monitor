/// Grid status and live power values from one logger poll.
class InverterReading {
  final int batterySoc;
  final bool gridOn;
  final int? batteryPowerWatts;
  final int? pv1PowerWatts;
  final int? pv2PowerWatts;

  const InverterReading({
    required this.batterySoc,
    required this.gridOn,
    this.batteryPowerWatts,
    this.pv1PowerWatts,
    this.pv2PowerWatts,
  });

  int? get pvTotalWatts => pv1PowerWatts == null || pv2PowerWatts == null
      ? null
      : pv1PowerWatts! + pv2PowerWatts!;

  factory InverterReading.fromRegisters(Map<String, int> registers) {
    final soc = registers['Battery SOC'];
    final grid = registers['Grid Relay Status'];

    if (soc == null || soc < 0 || soc > 100) {
      throw const FormatException('Missing or invalid battery SOC');
    }
    if (grid != 0 && grid != 1) {
      throw const FormatException('Missing or invalid grid relay status');
    }

    final pv1 = registers['PV1 Power'];
    final pv2 = registers['PV2 Power'];
    return InverterReading(
      batterySoc: soc,
      gridOn: grid == 1,
      batteryPowerWatts: registers['Battery Power'],
      pv1PowerWatts: pv1 != null && pv1 >= 0 ? pv1 : null,
      pv2PowerWatts: pv2 != null && pv2 >= 0 ? pv2 : null,
    );
  }
}

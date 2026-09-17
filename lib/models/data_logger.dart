class DataLogger {
  final String id;
  final String name;
  final String ipAddress;
  final int serial;
  final int port;
  final bool alarmEnabled;

  /// Cached last-known values for home screen badges (not persisted to prefs).
  final int? lastSoc;
  final bool? lastGridOn;
  final DateTime? lastSeen;

  const DataLogger({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.serial,
    this.port = 8899,
    this.alarmEnabled = false,
    this.lastSoc,
    this.lastGridOn,
    this.lastSeen,
  });

  DataLogger copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? serial,
    int? port,
    bool? alarmEnabled,
    int? lastSoc,
    bool? lastGridOn,
    DateTime? lastSeen,
  }) {
    return DataLogger(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      serial: serial ?? this.serial,
      port: port ?? this.port,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      lastSoc: lastSoc ?? this.lastSoc,
      lastGridOn: lastGridOn ?? this.lastGridOn,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Serialises only persistent fields (transient live values are excluded).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ipAddress': ipAddress,
        'serial': serial,
        'port': port,
        'alarmEnabled': alarmEnabled,
      };

  factory DataLogger.fromJson(Map<String, dynamic> map) => DataLogger(
        id: map['id']?.toString() ?? '',
        name: map['name'] ?? '',
        ipAddress: map['ipAddress'] ?? '',
        serial: (map['serial'] as num?)?.toInt() ?? 0,
        port: (map['port'] as num?)?.toInt() ?? 8899,
        alarmEnabled: map['alarmEnabled'] as bool? ?? false,
      );
}

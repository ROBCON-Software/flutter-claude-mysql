class MeterLastValue {
  final int? merId;
  final DateTime? datetime;
  final double? raw;
  final double? global;

  const MeterLastValue({this.merId, this.datetime, this.raw, this.global});

  factory MeterLastValue.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MeterLastValue();
    return MeterLastValue(
      merId: json['mer_id'] as int?,
      datetime: json['mer_datetime'] != null
          ? DateTime.tryParse(json['mer_datetime'] as String)
          : null,
      raw: (json['raw'] as num?)?.toDouble(),
      global: (json['global'] as num?)?.toDouble(),
    );
  }
}

class LastReadings {
  final MeterLastValue pln;
  final MeterLastValue ele;
  final MeterLastValue vod;

  const LastReadings({required this.pln, required this.ele, required this.vod});

  factory LastReadings.fromJson(Map<String, dynamic> json) {
    return LastReadings(
      pln: MeterLastValue.fromJson(json['pln'] as Map<String, dynamic>?),
      ele: MeterLastValue.fromJson(json['ele'] as Map<String, dynamic>?),
      vod: MeterLastValue.fromJson(json['vod'] as Map<String, dynamic>?),
    );
  }
}

class DataPoint {
  final double temperature;
  final double energy;
  final int year;

  DataPoint({
    required this.temperature,
    required this.energy,
    required this.year,
  });

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      temperature: json['temperature']?.toDouble() ?? 0.0,
      energy: json['energy']?.toDouble() ?? 0.0,
      year: json['year'] ?? 2024,
    );
  }
}

class TracingPoint {
  final double x;
  final double y;
  final int timestamp;

  const TracingPoint({
    required this.x,
    required this.y,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'timestamp': timestamp,
      };

  factory TracingPoint.fromJson(Map<String, dynamic> json) => TracingPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        timestamp: json['timestamp'] as int,
      );
}
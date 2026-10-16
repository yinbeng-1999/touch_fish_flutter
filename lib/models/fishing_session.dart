class FishingSession {
  const FishingSession({
    required this.start,
    required this.end,
    this.monthlySalary,
  });

  final DateTime start;
  final DateTime end;
  final double? monthlySalary;

  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'monthlySalary': monthlySalary,
  };

  factory FishingSession.fromJson(Map<String, dynamic> json) => FishingSession(
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    monthlySalary: (json['monthlySalary'] as num?)?.toDouble(),
  );
}

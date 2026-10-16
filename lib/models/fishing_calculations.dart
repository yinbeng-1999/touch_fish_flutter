const fishingWorkday = Duration(hours: 8);

double calculateFishingGold({
  required double monthlySalary,
  required Duration fishingDuration,
}) =>
    monthlySalary /
    30 *
    fishingDuration.inMicroseconds /
    fishingWorkday.inMicroseconds;

double monthlySalaryForRecordedGold({
  required double gold,
  required Duration fishingDuration,
}) {
  if (fishingDuration <= Duration.zero) return 0;
  return gold *
      30 *
      fishingWorkday.inMicroseconds /
      fishingDuration.inMicroseconds;
}

double calculateFishingEfficiency(Duration fishingDuration) =>
    (fishingDuration.inMicroseconds / fishingWorkday.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();

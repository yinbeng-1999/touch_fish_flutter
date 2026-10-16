import 'package:flutter_test/flutter_test.dart';
import 'package:touch_fish_flutter/models/fishing_calculations.dart';
import 'package:touch_fish_flutter/models/work_schedule.dart';
import 'package:touch_fish_flutter/utils/money_formatter.dart';

void main() {
  group('工作與休息時間邊界', () {
    const schedule = WorkSchedule.defaults;

    test('上班時間可開始，休息時間與下班時間不可開始', () {
      expect(schedule.allowsStartAt(DateTime(2026, 10, 14, 9)), isTrue);
      expect(schedule.allowsStartAt(DateTime(2026, 10, 14, 12)), isFalse);
      expect(schedule.allowsStartAt(DateTime(2026, 10, 14, 13)), isTrue);
      expect(schedule.allowsStartAt(DateTime(2026, 10, 14, 18)), isFalse);
    });

    test('跨過休息開始時，回傳精確切斷時間', () {
      expect(
        schedule.breakStartBetween(
          DateTime(2026, 10, 14, 11, 30),
          DateTime(2026, 10, 14, 12, 5),
        ),
        DateTime(2026, 10, 14, 12),
      );
    });

    test('休息結束後開始搜尋，不會回傳已過的休息時間', () {
      expect(
        schedule.breakStartBetween(
          DateTime(2026, 10, 14, 13),
          DateTime(2026, 10, 14, 17),
        ),
        isNull,
      );
    });
  });

  group('淘金金額與效率', () {
    test('金額依摸魚時數計算，匯入反推可還原月薪', () {
      const fourHours = Duration(hours: 4);
      final gold = calculateFishingGold(
        monthlySalary: 30000,
        fishingDuration: fourHours,
      );

      expect(gold, closeTo(500, 0.000001));
      expect(
        monthlySalaryForRecordedGold(gold: gold, fishingDuration: fourHours),
        closeTo(30000, 0.000001),
      );
    });

    test('八小時為 100%，超過八小時封頂', () {
      expect(calculateFishingEfficiency(const Duration(hours: 4)), 0.5);
      expect(calculateFishingEfficiency(const Duration(hours: 8)), 1.0);
      expect(calculateFishingEfficiency(const Duration(hours: 10)), 1.0);
    });
  });

  group('金額縮寫門檻', () {
    test('五位數起使用 K，七位數起使用 M', () {
      expect(formatMoney(9999), 'NT\$9,999');
      expect(formatMoney(10000), 'NT\$10K');
      expect(formatMoney(12345), 'NT\$12.3K');
      expect(formatMoney(999999), 'NT\$999.9K');
      expect(formatMoney(1000000), 'NT\$1M');
      expect(formatMoney(1234567), 'NT\$1.2M');
    });
  });
}

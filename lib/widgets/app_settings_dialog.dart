import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/work_schedule.dart';

class AppSettingsDialog extends StatefulWidget {
  const AppSettingsDialog({
    super.key,
    required this.monthlySalary,
    required this.workSchedule,
  });

  final double? monthlySalary;
  final WorkSchedule workSchedule;

  @override
  State<AppSettingsDialog> createState() => _AppSettingsDialogState();
}

class _AppSettingsDialogState extends State<AppSettingsDialog> {
  late final TextEditingController _salaryController;
  late TimeOfDay _workStart;
  late TimeOfDay _workEnd;
  late TimeOfDay _breakStart;
  late TimeOfDay _breakEnd;
  String? _salaryError;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    _salaryController = TextEditingController(
      text: widget.monthlySalary?.toStringAsFixed(0) ?? '',
    );
    _workStart = widget.workSchedule.workStart;
    _workEnd = widget.workSchedule.workEnd;
    _breakStart = widget.workSchedule.breakStart;
    _breakEnd = widget.workSchedule.breakEnd;
  }

  void _save() {
    final salary = double.tryParse(
      _salaryController.text.replaceAll(',', '').trim(),
    );
    setState(() {
      _salaryError = salary == null || !salary.isFinite || salary <= 0
          ? '請輸入大於 0 的有效月薪'
          : salary > 100000
          ? '麥擱騙'
          : null;
      _scheduleError = null;
    });
    if (_salaryError != null || _scheduleError != null) return;

    final schedule = WorkSchedule(
      workStart: _workStart,
      workEnd: _workEnd,
      breakStart: _breakStart,
      breakEnd: _breakEnd,
    );
    if (!schedule.isValid) {
      setState(() => _scheduleError = '休息時間需在上班時間內，且下班時間要晚於上班時間。');
      return;
    }
    Navigator.of(context)
        .pop(AppSettings(monthlySalary: salary!, workSchedule: schedule));
  }

  Widget _timeRow(
    String label,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        _numberDropdown(
          value: time.hour,
          maxValue: 23,
          onChanged: (hour) =>
              onChanged(TimeOfDay(hour: hour, minute: time.minute)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(':'),
        ),
        _numberDropdown(
          value: time.minute,
          maxValue: 59,
          onChanged: (minute) =>
              onChanged(TimeOfDay(hour: time.hour, minute: minute)),
        ),
      ],
    ),
  );

  Widget _numberDropdown({
    required int value,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) => PopupMenuButton<int>(
    tooltip: '',
    position: PopupMenuPosition.under,
    offset: const Offset(0, 4),
    constraints: const BoxConstraints(minWidth: 64, maxHeight: 220),
    itemBuilder: (context) => List.generate(
      maxValue + 1,
      (index) => PopupMenuItem<int>(
        value: index,
        height: 40,
        child: Center(child: Text(index.toString().padLeft(2, '0'))),
      ),
    ),
    onSelected: (next) => setState(() {
      onChanged(next);
      _scheduleError = null;
    }),
    child: Container(
      width: 52,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(value.toString().padLeft(2, '0')),
    ),
  );

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('設定'),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _salaryController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '月薪',
                prefixText: 'NT\$ ',
                errorText: _salaryError,
              ),
            ),
            const SizedBox(height: 20),
            Text('工作時間', style: Theme.of(context).textTheme.titleSmall),
            _timeRow('上班', _workStart, (value) => _workStart = value),
            _timeRow('下班', _workEnd, (value) => _workEnd = value),
            const SizedBox(height: 12),
            Text('休息時間', style: Theme.of(context).textTheme.titleSmall),
            _timeRow('開始', _breakStart, (value) => _breakStart = value),
            _timeRow('結束', _breakEnd, (value) => _breakEnd = value),
            if (_scheduleError != null) ...[
              const SizedBox(height: 8),
              Text(
                _scheduleError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _save, child: const Text('儲存')),
    ],
  );
}

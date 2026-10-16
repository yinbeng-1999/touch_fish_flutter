import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/fishing_session.dart';
import '../models/fishing_calculations.dart';
import '../utils/money_formatter.dart';

class _FishingRank {
  const _FishingRank(this.title, this.description, this.color);

  final String title;
  final String description;
  final Color color;

  static _FishingRank fromPercent(double percent) {
    if (percent <= 9) {
      return const _FishingRank('摸魚學徒', '尚有良心', Colors.green);
    }
    if (percent <= 19) {
      return const _FishingRank('混水摸魚', '拿起手機，肌肉記憶', Colors.blue);
    }
    if (percent <= 29) {
      return const _FishingRank('帶薪拉屎', '上班只是修仙的廢棄物', Colors.purple);
    }
    if (percent < 39) {
      return const _FishingRank('工位活佛', '心無掛礙，無掛礙故', Color(0xFFFFB300));
    }
    return const _FishingRank('公司供奉', '如來在世', Colors.red);
  }
}

class _DailySummary {
  Duration duration = Duration.zero;
  double gold = 0;
  bool hasGold = false;
}

class _ImportedDay {
  int seconds = 0;
  double gold = 0;
  bool hasGold = false;
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.sessions,
    required this.currentMonthlySalary,
    required this.onSessionsImported,
  });

  final List<FishingSession> sessions;
  final double? currentMonthlySalary;
  final Future<void> Function(List<FishingSession>) onSessionsImported;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late List<FishingSession> sessions;
  bool _isImporting = false;

  double? get currentMonthlySalary => widget.currentMonthlySalary;

  @override
  void initState() {
    super.initState();
    sessions = List.of(widget.sessions);
  }

  String _formatDate(DateTime date) {
    const weekdays = ['(一)', '(二)', '(三)', '(四)', '(五)', '(六)', '(日)'];
    return '${date.year}/${date.month}/${date.day}  ${weekdays[date.weekday - 1]}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<DateTime, _DailySummary> _buildDailySummaries() {
    final summaries = <DateTime, _DailySummary>{};
    for (final session in sessions) {
      var cursor = session.start;
      while (cursor.isBefore(session.end)) {
        final day = DateTime(cursor.year, cursor.month, cursor.day);
        final nextDay = DateTime(day.year, day.month, day.day + 1);
        final segmentEnd = session.end.isBefore(nextDay)
            ? session.end
            : nextDay;
        final duration = segmentEnd.difference(cursor);
        final summary = summaries.putIfAbsent(day, _DailySummary.new);
        summary.duration += duration;

        final salary = session.monthlySalary ?? currentMonthlySalary;
        if (salary != null) {
          summary.gold += calculateFishingGold(
            monthlySalary: salary,
            fishingDuration: duration,
          );
          summary.hasGold = true;
        }
        cursor = segmentEnd;
      }
    }
    return summaries;
  }

  Duration _durationInRange(
    Map<DateTime, _DailySummary> summaries,
    DateTime start,
    DateTime end,
  ) {
    var total = Duration.zero;
    for (final entry in summaries.entries) {
      if (!entry.key.isBefore(start) && entry.key.isBefore(end)) {
        total += entry.value.duration;
      }
    }
    return total;
  }

  double _goldInRange(
    Map<DateTime, _DailySummary> summaries,
    DateTime start,
    DateTime end,
  ) {
    var total = 0.0;
    for (final entry in summaries.entries) {
      if (!entry.key.isBefore(start) && entry.key.isBefore(end)) {
        total += entry.value.gold;
      }
    }
    return total;
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  Future<void> _exportCsv(Map<DateTime, _DailySummary> summaries) async {
    final days = summaries.keys.toList()..sort();
    final rows = <String>['日期,摸魚時間,摸魚時數,淘金金額(NT\$)'];
    for (final day in days) {
      final summary = summaries[day]!;
      rows.add(
        [
          _csvCell(
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
          ),
          _csvCell(_formatDuration(summary.duration)),
          summary.duration.inSeconds.toString(),
          summary.hasGold ? summary.gold.toStringAsFixed(2) : '',
        ].join(','),
      );
    }
    final csv = '\uFEFF${rows.join('\r\n')}';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(csv),
            mimeType: 'text/csv',
            name: 'touch_fish.csv',
          ),
        ],
        fileNameOverrides: ['touch_fish.csv'],
      ),
    );
  }

  List<List<String>> _parseCsv(String contents) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var insideQuotes = false;
    for (var index = 0; index < contents.length; index++) {
      final character = contents[index];
      if (character == '"') {
        if (insideQuotes &&
            index + 1 < contents.length &&
            contents[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (character == ',' && !insideQuotes) {
        row.add(field.toString());
        field.clear();
      } else if ((character == '\n' || character == '\r') && !insideQuotes) {
        row.add(field.toString());
        field.clear();
        if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
        if (character == '\r' &&
            index + 1 < contents.length &&
            contents[index + 1] == '\n') {
          index++;
        }
      } else {
        field.write(character);
      }
    }
    if (insideQuotes) throw const FormatException('CSV 引號格式不完整。');
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  int? _parseDurationSeconds(String value) {
    final normalized = value.trim();
    final seconds = int.tryParse(normalized);
    if (seconds != null) return seconds;
    final parts = normalized.split(':');
    if (parts.length != 3) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final remainingSeconds = int.tryParse(parts[2]);
    if (hours == null || minutes == null || remainingSeconds == null) {
      return null;
    }
    if (minutes < 0 ||
        minutes >= 60 ||
        remainingSeconds < 0 ||
        remainingSeconds >= 60) {
      return null;
    }
    return hours * 3600 + minutes * 60 + remainingSeconds;
  }

  Future<void> _importCsv() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final contents = utf8
          .decode(bytes, allowMalformed: true)
          .replaceFirst('\uFEFF', '');
      final rows = _parseCsv(contents);
      if (rows.length < 2) throw const FormatException('CSV 沒有可匯入的紀錄。');

      final headers = rows.first.map((header) => header.trim()).toList();
      final dateIndex = headers.indexOf('日期');
      final durationIndex = headers.indexOf('摸魚時間');
      final secondsIndex = headers.indexOf('摸魚時數');
      final goldIndex = headers.indexWhere(
        (header) => header.startsWith('淘金金額'),
      );
      if (dateIndex < 0 || (durationIndex < 0 && secondsIndex < 0)) {
        throw const FormatException('找不到日期或摸魚時間欄位。');
      }

      final importedByDay = <DateTime, _ImportedDay>{};
      for (var index = 1; index < rows.length; index++) {
        final cells = rows[index];
        String cellAt(int cellIndex) =>
            cellIndex >= 0 && cellIndex < cells.length
            ? cells[cellIndex].trim()
            : '';

        final dateText = cellAt(dateIndex).replaceAll('/', '-');
        final parsedDate = DateTime.tryParse(dateText);
        final seconds = secondsIndex >= 0
            ? _parseDurationSeconds(cellAt(secondsIndex))
            : _parseDurationSeconds(cellAt(durationIndex));
        if (parsedDate == null ||
            seconds == null ||
            seconds <= 0 ||
            seconds > 86400) {
          throw FormatException('第 ${index + 1} 列的日期或摸魚時間格式不正確。');
        }

        final day = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        final importedDay = importedByDay.putIfAbsent(day, _ImportedDay.new);
        importedDay.seconds += seconds;
        if (importedDay.seconds > 86400) {
          throw FormatException('第 ${index + 1} 列的同日摸魚時間超過 24 小時。');
        }
        final goldText = cellAt(goldIndex);
        if (goldText.isNotEmpty) {
          final normalizedGold = goldText.replaceAll(RegExp(r'[^0-9.\-]'), '');
          final gold = double.tryParse(normalizedGold);
          if (gold == null || !gold.isFinite || gold < 0) {
            throw FormatException('第 ${index + 1} 列的淘金金額格式不正確。');
          }
          importedDay.gold += gold;
          importedDay.hasGold = true;
        }
      }

      final existingDays = <DateTime>{};
      for (final session in sessions) {
        var cursor = session.start;
        while (cursor.isBefore(session.end)) {
          existingDays.add(DateTime(cursor.year, cursor.month, cursor.day));
          final day = DateTime(cursor.year, cursor.month, cursor.day);
          cursor = DateTime(day.year, day.month, day.day + 1);
        }
      }
      final newDays = importedByDay.entries
          .where((entry) => !existingDays.contains(entry.key))
          .toList();
      final importedSessions = <FishingSession>[];
      for (final entry in newDays) {
        final duration = Duration(seconds: entry.value.seconds);
        final importedSalary = entry.value.hasGold
            ? monthlySalaryForRecordedGold(
                gold: entry.value.gold,
                fishingDuration: duration,
              )
            : 0.0;
        importedSessions.add(
          FishingSession(
            start: entry.key,
            end: entry.key.add(duration),
            monthlySalary: importedSalary,
          ),
        );
      }
      if (importedSessions.isEmpty) {
        _showImportMessage('沒有新增紀錄；CSV 中的日期都已存在。');
        return;
      }
      await widget.onSessionsImported(importedSessions);
      if (!mounted) return;
      setState(() => sessions = [...sessions, ...importedSessions]);
      _showImportMessage('已匯入 ${importedSessions.length} 天的紀錄。');
    } on FormatException catch (error) {
      _showImportMessage('匯入失敗：${error.message}');
    } catch (_) {
      _showImportMessage('匯入失敗，請選擇有效的 CSV 檔案。');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showImportMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required Duration duration,
    required double gold,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Text(
                _formatDuration(duration),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(gold),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyTrend(
    BuildContext context,
    Map<DateTime, _DailySummary> summaries,
    DateTime weekStart,
  ) {
    final now = DateTime.now();
    final data = List.generate(7, (index) {
      final date = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + index,
      );
      return (date, summaries[date]?.duration ?? Duration.zero);
    });
    final maxSeconds = data.fold<int>(
      0,
      (maximum, item) =>
          item.$2.inSeconds > maximum ? item.$2.inSeconds : maximum,
    );
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('本週每日摸魚'),
            const SizedBox(height: 14),
            SizedBox(
              height: 104,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < data.length; index++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: maxSeconds == 0
                                  ? 4
                                  : (data[index].$2.inSeconds / maxSeconds * 62)
                                        .clamp(4, 62)
                                        .toDouble(),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weekdays[index],
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              data[index].$1.day.toString(),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color:
                                        data[index].$1.year == now.year &&
                                            data[index].$1.month == now.month &&
                                            data[index].$1.day == now.day
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaries = _buildDailySummaries();
    final days = summaries.keys.toList()..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );
    final monthStart = DateTime(today.year, today.month);
    final nextMonth = DateTime(today.year, today.month + 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('摸魚紀錄'),
        actions: [
          IconButton(
            tooltip: '匯入 CSV',
            onPressed: _isImporting ? null : _importCsv,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: '匯出 CSV',
            onPressed: days.isEmpty ? null : () => _exportCsv(summaries),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: days.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('還沒有摸魚紀錄', style: TextStyle(fontSize: 18)),
                    SizedBox(height: 4),
                    Text(
                      '暫停或結束一次摸魚後，紀錄會顯示在這裡。',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildSummaryCard(
                                context: context,
                                title: '本週',
                                duration: _durationInRange(
                                  summaries,
                                  weekStart,
                                  weekStart.add(const Duration(days: 7)),
                                ),
                                gold: _goldInRange(
                                  summaries,
                                  weekStart,
                                  weekStart.add(const Duration(days: 7)),
                                ),
                              ),
                              _buildSummaryCard(
                                context: context,
                                title: '本月',
                                duration: _durationInRange(
                                  summaries,
                                  monthStart,
                                  nextMonth,
                                ),
                                gold: _goldInRange(
                                  summaries,
                                  monthStart,
                                  nextMonth,
                                ),
                              ),
                            ],
                          ),
                          _buildWeeklyTrend(context, summaries, weekStart),
                          const SizedBox(height: 8),
                          for (final day in days) ...[
                            _buildHistoryCard(context, day, summaries[day]!),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    DateTime day,
    _DailySummary summary,
  ) {
    final percent = calculateFishingEfficiency(summary.duration) * 100;
    final rank = _FishingRank.fromPercent(percent);
    return Card(
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.center,
        leading: const CircleAvatar(child: Icon(Icons.calendar_today)),
        title: Text(_formatDate(day)),
        isThreeLine: true,
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Text(
                rank.title,
                style: TextStyle(
                  color: rank.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  rank.description,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _formatDuration(summary.duration),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (summary.hasGold) ...[
              const SizedBox(height: 6),
              Text(
                formatMoney(summary.gold),
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

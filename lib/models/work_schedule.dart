import 'package:flutter/material.dart';

class WorkSchedule {
  const WorkSchedule({
    required this.workStart,
    required this.workEnd,
    required this.breakStart,
    required this.breakEnd,
  });

  static const defaults = WorkSchedule(
    workStart: TimeOfDay(hour: 9, minute: 0),
    workEnd: TimeOfDay(hour: 18, minute: 0),
    breakStart: TimeOfDay(hour: 12, minute: 0),
    breakEnd: TimeOfDay(hour: 13, minute: 0),
  );

  final TimeOfDay workStart;
  final TimeOfDay workEnd;
  final TimeOfDay breakStart;
  final TimeOfDay breakEnd;

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  bool get isValid =>
      _minutes(workStart) < _minutes(workEnd) &&
      _minutes(workStart) <= _minutes(breakStart) &&
      _minutes(breakStart) < _minutes(breakEnd) &&
      _minutes(breakEnd) <= _minutes(workEnd);

  bool allowsStartAt(DateTime dateTime) {
    final minutes = dateTime.hour * 60 + dateTime.minute;
    return isValid &&
        minutes >= _minutes(workStart) &&
        minutes < _minutes(workEnd) &&
        (minutes < _minutes(breakStart) || minutes >= _minutes(breakEnd));
  }

  DateTime? breakStartBetween(DateTime start, DateTime end) {
    if (!isValid || end.isBefore(start)) return null;
    var day = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(lastDay)) {
      final breakStartAt = DateTime(
        day.year,
        day.month,
        day.day,
        breakStart.hour,
        breakStart.minute,
      );
      if (!breakStartAt.isBefore(start) && !breakStartAt.isAfter(end)) {
        return breakStartAt;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return null;
  }

  Duration remainingUntilWorkEnd(DateTime now) {
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      workEnd.hour,
      workEnd.minute,
    );
    return end.isAfter(now) ? end.difference(now) : Duration.zero;
  }

  Map<String, int> toJson() => {
    'workStart': _minutes(workStart),
    'workEnd': _minutes(workEnd),
    'breakStart': _minutes(breakStart),
    'breakEnd': _minutes(breakEnd),
  };

  factory WorkSchedule.fromJson(Map<String, dynamic> json) => WorkSchedule(
    workStart: _fromMinutes(json['workStart'] as int),
    workEnd: _fromMinutes(json['workEnd'] as int),
    breakStart: _fromMinutes(json['breakStart'] as int),
    breakEnd: _fromMinutes(json['breakEnd'] as int),
  );

  static TimeOfDay _fromMinutes(int value) =>
      TimeOfDay(hour: value ~/ 60, minute: value % 60);
}

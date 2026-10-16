String formatMoney(double amount) {
  final sign = amount < 0 ? '-' : '';
  final absoluteAmount = amount.abs();
  final compact = _compactNumber(absoluteAmount);
  return 'NT\$$sign$compact';
}

String formatCompactMoney(double amount) {
  final sign = amount < 0 ? '-' : '';
  return '$sign${_compactNumber(amount.abs())}';
}

String _compactNumber(double amount) {
  if (amount >= 1000000) {
    return '${_floorToOneDecimal(amount / 1000000)}M';
  }
  if (amount >= 10000) {
    return '${_floorToOneDecimal(amount / 1000)}K';
  }
  final grouped = amount.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return grouped;
}

String _floorToOneDecimal(double value) {
  final roundedDown = (value * 10).floorToDouble() / 10;
  return roundedDown.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
}

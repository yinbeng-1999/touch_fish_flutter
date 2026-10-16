import 'package:flutter/material.dart';

import '../utils/money_formatter.dart';

class GoldMiningDisplay extends StatefulWidget {
  const GoldMiningDisplay({
    super.key,
    required this.goldAmount,
    required this.amountLabel,
    required this.isFishing,
    required this.isLoading,
    required this.hasSalary,
  });

  final double goldAmount;
  final String amountLabel;
  final bool isFishing;
  final bool isLoading;
  final bool hasSalary;

  @override
  State<GoldMiningDisplay> createState() => _GoldMiningDisplayState();
}

class _GoldMiningDisplayState extends State<GoldMiningDisplay>
    with TickerProviderStateMixin {
  late final AnimationController _gainController;
  late final AnimationController _amountController;
  int _lastRoundedGold = 0;
  String? _gainLabel;

  @override
  void initState() {
    super.initState();
    _lastRoundedGold = widget.goldAmount.round();
    _gainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
      value: 1,
    );
    _amountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant GoldMiningDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final roundedGold = widget.goldAmount.round();
    final increase = roundedGold - _lastRoundedGold;
    _lastRoundedGold = roundedGold;
    if (widget.isFishing && !widget.isLoading && increase > 0) {
      _gainLabel = '+${formatCompactMoney(increase.toDouble())}';
      _gainController.forward(from: 0);
      _amountController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _gainController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = TextStyle(
      fontSize: widget.hasSalary ? 32 : 16,
      fontWeight: widget.hasSalary ? FontWeight.bold : FontWeight.normal,
      color: widget.hasSalary ? null : theme.colorScheme.onSurfaceVariant,
    );
    final amountPainter = TextPainter(
      text: TextSpan(text: widget.amountLabel, style: amountStyle),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final gainOffsetX = amountPainter.width / 2 + 8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('今日淘金', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        SizedBox(
          height: 46,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _amountController,
                builder: (context, child) => Transform.scale(
                  scale: 1.18 - 0.18 * _amountController.value,
                  child: child,
                ),
                child: Text(widget.amountLabel, style: amountStyle),
              ),
              if (widget.hasSalary && _gainLabel != null)
                Align(
                  alignment: Alignment.center,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _gainController,
                      builder: (context, child) => Opacity(
                        opacity: (1 - _gainController.value).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(
                            gainOffsetX,
                            8 - 60 * _gainController.value,
                          ),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _gainLabel!,
                        style: TextStyle(
                          color: theme.colorScheme.tertiary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: theme.colorScheme.surface,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

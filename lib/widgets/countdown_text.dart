import 'dart:async';

import 'package:flutter/material.dart';

import 'package:am_in/core/utils/formatters.dart';

/// A self-ticking `MM:SS` countdown to [expiresAt].
///
/// Rebuilds once per second and calls [onExpired] exactly once when the target
/// time passes. Purely presentational — the server clock remains authoritative
/// for whether a session is actually open.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.expiresAt,
    this.style,
    this.onExpired,
    this.expiredLabel = '00:00',
  });

  final DateTime expiresAt;
  final TextStyle? style;
  final VoidCallback? onExpired;
  final String expiredLabel;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  bool _firedExpired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final Duration remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative && !_firedExpired) {
      _firedExpired = true;
      _timer?.cancel();
      widget.onExpired?.call();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = widget.expiresAt.difference(DateTime.now());
    final String text = remaining.isNegative
        ? widget.expiredLabel
        : Formatters.countdown(remaining);
    return Text(text, style: widget.style);
  }
}

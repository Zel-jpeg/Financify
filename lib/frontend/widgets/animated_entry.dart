import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedEntry extends StatefulWidget {
  final Widget child;
  final int index;
  final double offsetY;
  final Duration duration;
  final Duration? delay;

  const AnimatedEntry({
    super.key,
    required this.child,
    this.index = 0,
    this.offsetY = 20,
    this.duration = const Duration(milliseconds: 320),
    this.delay,
  });

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _startAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset and restart animation when navigating back
    _controller.reset();
    _startAnimation();
  }

  void _startAnimation() {
    final d = widget.delay ?? Duration(milliseconds: 50 * widget.index);
    Future.delayed(d, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, widget.offsetY * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}


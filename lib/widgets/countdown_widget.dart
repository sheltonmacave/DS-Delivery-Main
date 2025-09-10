import 'dart:async';
import 'package:flutter/material.dart';

class OrderCountdownWidget extends StatefulWidget {
  final DateTime targetTime;
  final VoidCallback? onComplete;
  
  const OrderCountdownWidget({
    super.key,
    required this.targetTime,
    this.onComplete,
  });

  @override
  State<OrderCountdownWidget> createState() => _OrderCountdownWidgetState();
}

class _OrderCountdownWidgetState extends State<OrderCountdownWidget> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isComplete = false;
  
  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    _startTimer();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  void _calculateRemainingTime() {
    final now = DateTime.now();
    if (now.isBefore(widget.targetTime)) {
      _remainingTime = widget.targetTime.difference(now);
    } else {
      _remainingTime = Duration.zero;
      _isComplete = true;
      widget.onComplete?.call();
    }
  }
  
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _calculateRemainingTime();
        if (_isComplete) {
          timer.cancel();
        }
      });
    });
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isComplete 
            ? Colors.green.withOpacity(0.2) 
            : const Color(0xFFFF6A00).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isComplete ? Icons.check_circle : Icons.timer,
            size: 16,
            color: _isComplete ? Colors.green : const Color(0xFFFF6A00),
          ),
          const SizedBox(width: 6),
          _isComplete 
              ? const Text('Finalizado', 
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
              : Text(
                  'Auto-finaliza em: ${_formatDuration(_remainingTime)}',
                  style: const TextStyle(
                    color: Color(0xFFFF6A00),
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ],
      ),
    );
  }
}
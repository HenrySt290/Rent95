import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_routes.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  bool get _complete => _controllers.every((c) => c.text.isNotEmpty);

  Future<void> _verify() async {
    if (!_complete) return;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify your number',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'We sent a 6-digit code to your phone. Enter it below to continue.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _nodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) _nodes[i + 1].requestFocus();
                        if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _complete ? _verify : null,
                child: const Text('Verify'),
              ),
              const SizedBox(height: 20),
              Center(
                child: _secondsLeft > 0
                    ? Text('Resend code in ${_secondsLeft}s',
                        style: const TextStyle(color: AppColors.textSecondary))
                    : TextButton(
                        onPressed: _startTimer,
                        child: const Text('Resend code'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

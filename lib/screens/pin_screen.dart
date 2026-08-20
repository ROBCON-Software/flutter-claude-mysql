import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session.dart';
import 'home_screen.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.login(_pin);
      if (data['success'] == true) {
        Session.username = data['username'] as String?;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
        return;
      }
      setState(() {
        _error = 'Nespravny PIN';
        _pin = '';
      });
    } catch (_) {
      setState(() {
        _error = 'Chyba pripojenia k serveru';
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDigit(String digit) {
    if (_loading || _pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _buildDot(int index) {
    final filled = index < _pin.length;
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
    );
  }

  Widget _buildKey({String? label, Widget? child, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: child ?? Text(label ?? '', style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Zadaj PIN', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, _buildDot),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 24,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _error != null
                        ? Text(_error!, style: const TextStyle(color: Colors.red))
                        : null,
              ),
              const SizedBox(height: 24),
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.map((d) => _buildKey(label: d, onTap: () => _onDigit(d))).toList(),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 88),
                  _buildKey(label: '0', onTap: () => _onDigit('0')),
                  _buildKey(child: const Icon(Icons.backspace_outlined), onTap: _onBackspace),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

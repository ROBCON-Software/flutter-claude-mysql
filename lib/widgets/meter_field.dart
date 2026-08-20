import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numericky vstup (iba 0-9 a bodka) s volitelnou reload ikonkou vlavo
/// a clear ikonkou vpravo, ktora sa zobrazi len ked pole obsahuje text.
class MeterField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
  final VoidCallback? onReload;
  final bool alwaysFloatLabel;
  final bool invalid;

  const MeterField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
    this.onReload,
    this.alwaysFloatLabel = false,
    this.invalid = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            filled: invalid,
            fillColor: invalid ? Colors.red.shade50 : null,
            labelText: labelText,
            floatingLabelBehavior:
                alwaysFloatLabel ? FloatingLabelBehavior.always : FloatingLabelBehavior.auto,
            prefixIcon: onReload != null
                ? IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Nacitat poslednu hodnotu',
                    onPressed: onReload,
                  )
                : null,
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel),
                    tooltip: 'Vymazat',
                    onPressed: () => controller.clear(),
                  )
                : null,
          ),
        );
      },
    );
  }
}

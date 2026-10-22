/// Hex input field with validation.
///
/// Filters input to allow only valid hex characters (0-9, a-f, A-F)
/// and optionally enforces a fixed byte-length.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pm3gui/l10n/l10n.dart';

class HexInputField extends StatelessWidget {
  final String label;
  final String hint;
  final int? byteLength;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final IconData? prefixIcon;

  const HexInputField({
    super.key,
    required this.label,
    this.hint = '',
    this.byteLength,
    this.initialValue,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final maxChars = byteLength != null ? byteLength! * 2 : null;
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isNotEmpty
            ? hint
            : (byteLength != null
                ? context.l10n.hexDigits(byteLength! * 2)
                : 'hex'),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        counterText:
            maxChars != null ? context.l10n.maxCharacters(maxChars) : null,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
        if (maxChars != null) LengthLimitingTextInputFormatter(maxChars),
      ],
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      onChanged: onChanged,
    );
  }
}

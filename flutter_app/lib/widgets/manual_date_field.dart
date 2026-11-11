import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class Date8InputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digits[i]);
    }

    if ((digits.length == 2 || digits.length == 4) &&
        newValue.text.endsWith('/') &&
        !oldValue.text.endsWith('/')) {
      buffer.write('/');
    }

    final string = buffer.toString();

    int selectionIndex = newValue.selection.end;
    if (selectionIndex < 0) selectionIndex = 0;
    if (selectionIndex > newValue.text.length) {
      selectionIndex = newValue.text.length;
    }

    int digitsBeforeCursor = 0;
    for (int i = 0; i < selectionIndex; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    int newCursorPos = 0;
    int countedDigits = 0;
    while (newCursorPos < string.length && countedDigits < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(string[newCursorPos])) {
        countedDigits++;
      }
      newCursorPos++;
    }

    if (newCursorPos < string.length &&
        string[newCursorPos] == '/' &&
        (countedDigits == 2 || countedDigits == 4)) {
      newCursorPos++;
    }

    if (newCursorPos > string.length) {
      newCursorPos = string.length;
    }

    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}

String formatIsoDateToItalian(String? isoDate) {
  if (isoDate == null || isoDate.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(isoDate.trim());
  if (parsed == null) return '';
  return DateFormat('dd/MM/yyyy').format(parsed);
}

({bool isValid, String? isoDate}) parseItalianDateToIso(
  String rawText, {
  int minYear = 1900,
  int maxYear = 2100,
}) {
  final trimmed = rawText.trim();
  if (trimmed.isEmpty) {
    return (isValid: true, isoDate: null);
  }
  final parts = trimmed.split('/');
  if (parts.length == 3 &&
      parts[0].length == 2 &&
      parts[1].length == 2 &&
      parts[2].length == 4) {
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d != null &&
        m != null &&
        y != null &&
        m >= 1 &&
        m <= 12 &&
        d >= 1 &&
        d <= 31 &&
        y >= minYear &&
        y <= maxYear) {
      try {
        final dt = DateTime(y, m, d);
        if (dt.year == y && dt.month == m && dt.day == d) {
          return (isValid: true, isoDate: DateFormat('yyyy-MM-dd').format(dt));
        }
      } catch (_) {}
    }
  }
  return (isValid: false, isoDate: null);
}

class ManualDateField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String? helperText;
  final IconData prefixIcon;
  final String clearTooltip;

  const ManualDateField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = 'GG/MM/AAAA (8 cifre)',
    this.helperText,
    this.prefixIcon = Icons.calendar_today_outlined,
    this.clearTooltip = 'Rimuovi data',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            Date8InputFormatter(),
          ],
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            helperText: helperText,
            prefixIcon: Icon(prefixIcon),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                    tooltip: clearTooltip,
                    onPressed: controller.clear,
                  )
                : null,
          ),
        );
      },
    );
  }
}

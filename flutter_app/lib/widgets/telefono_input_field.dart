import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formatta la parte locale del numero di cellulare nel formato `xxx xxx xxxx`
/// preservando correttamente la posizione del cursore durante la digitazione.
class PhoneLocalInputFormatter extends TextInputFormatter {
  static String formatDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatDigits(digits);

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
    while (newCursorPos < formatted.length && countedDigits < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[newCursorPos])) {
        countedDigits++;
      }
      newCursorPos++;
    }

    if (newCursorPos < formatted.length &&
        formatted[newCursorPos] == ' ' &&
        (countedDigits == 3 || countedDigits == 6)) {
      newCursorPos++;
    }

    if (newCursorPos > formatted.length) {
      newCursorPos = formatted.length;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }
}

/// Formatta il prefisso internazionale nel formato `+<1-4 cifre>` (es. `+39`).
class PhonePrefixInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) {
      digits = digits.substring(0, 4);
    }
    final formatted = '+$digits';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Campo input per numero di cellulare con prefisso internazionale modificabile
/// (default `+39`) e formattazione automatica `xxx xxx xxxx`.
///
/// Sincronizza il valore combinato (es. `+39 333 123 4567`, oppure stringa vuota
/// se il numero non è stato inserito) sul [controller] passato.
class TelefonoInputField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final bool showPrefixIcon;
  final InputBorder? border;

  const TelefonoInputField({
    super.key,
    required this.controller,
    this.labelText = 'Telefono',
    this.hintText = '333 123 4567',
    this.showPrefixIcon = true,
    this.border,
  });

  @override
  State<TelefonoInputField> createState() => _TelefonoInputFieldState();
}

class _TelefonoInputFieldState extends State<TelefonoInputField> {
  late final TextEditingController _prefixController;
  late final TextEditingController _localController;
  late final FocusNode _prefixFocusNode;

  @override
  void initState() {
    super.initState();
    final parsed = _parseInitialPhone(widget.controller.text);
    _prefixController = TextEditingController(text: parsed.$1);
    _localController = TextEditingController(text: parsed.$2);
    _prefixFocusNode = FocusNode()..addListener(_onPrefixFocusChange);
  }

  @override
  void dispose() {
    _prefixFocusNode.removeListener(_onPrefixFocusChange);
    _prefixFocusNode.dispose();
    _prefixController.dispose();
    _localController.dispose();
    super.dispose();
  }

  void _onPrefixFocusChange() {
    if (!_prefixFocusNode.hasFocus) {
      final digits = _prefixController.text.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        _prefixController.text = '+39';
        _syncToParentController();
      }
    }
  }

  /// Restituisce `(prefisso, numeroLocaleFormattato)`.
  (String, String) _parseInitialPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toUpperCase() == 'TBD') {
      return ('+39', '');
    }

    if (trimmed.startsWith('+')) {
      final spaceIdx = trimmed.indexOf(RegExp(r'\s'));
      if (spaceIdx > 1) {
        final prefDigits = trimmed.substring(1, spaceIdx).replaceAll(RegExp(r'\D'), '');
        final restDigits = trimmed.substring(spaceIdx + 1).replaceAll(RegExp(r'\D'), '');
        final pref = prefDigits.isNotEmpty ? '+$prefDigits' : '+39';
        return (pref, PhoneLocalInputFormatter.formatDigits(restDigits));
      }

      final allDigits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      if (allDigits.startsWith('39') && allDigits.length > 2) {
        return ('+39', PhoneLocalInputFormatter.formatDigits(allDigits.substring(2)));
      }
      if ((allDigits.startsWith('1') || allDigits.startsWith('7')) && allDigits.length > 1) {
        return ('+${allDigits.substring(0, 1)}', PhoneLocalInputFormatter.formatDigits(allDigits.substring(1)));
      }
      if (allDigits.length > 2) {
        return ('+${allDigits.substring(0, 2)}', PhoneLocalInputFormatter.formatDigits(allDigits.substring(2)));
      }
      return (allDigits.isNotEmpty ? '+$allDigits' : '+39', '');
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0039') && digits.length > 4) {
      return ('+39', PhoneLocalInputFormatter.formatDigits(digits.substring(4)));
    }
    return ('+39', PhoneLocalInputFormatter.formatDigits(digits));
  }

  void _syncToParentController() {
    final localFormatted = _localController.text.trim();
    if (localFormatted.isEmpty) {
      widget.controller.text = '';
      return;
    }
    var prefixDigits = _prefixController.text.replaceAll(RegExp(r'\D'), '');
    if (prefixDigits.isEmpty) {
      prefixDigits = '39';
    }
    widget.controller.text = '+$prefixDigits $localFormatted';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: TextField(
            controller: _prefixController,
            focusNode: _prefixFocusNode,
            keyboardType: TextInputType.phone,
            textAlign: TextAlign.center,
            inputFormatters: [
              PhonePrefixInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Prefisso',
              border: widget.border,
            ),
            onChanged: (_) => _syncToParentController(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _localController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              PhoneLocalInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.showPrefixIcon ? const Icon(Icons.phone_outlined) : null,
              border: widget.border,
            ),
            onChanged: (_) => _syncToParentController(),
          ),
        ),
      ],
    );
  }
}

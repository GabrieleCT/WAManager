import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DataAmmissioneField extends StatelessWidget {
  final TextEditingController controller;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const DataAmmissioneField({
    super.key,
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          controller.text = DateFormat('dd/MM/yyyy').format(picked);
          onChanged(picked);
        }
      },
      decoration: InputDecoration(
        labelText: 'Data Ammissione',
        hintText: 'GG/MM/AAAA',
        prefixIcon: const Icon(Icons.event_available_outlined),
        helperText: 'Data di ammissione a socio ASD',
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Colors.red),
                tooltip: 'Rimuovi data ammissione',
                onPressed: () {
                  controller.clear();
                  onChanged(null);
                },
              )
            : const Icon(Icons.edit_calendar, size: 18),
      ),
    );
  }
}

// Path: lib/widgets/payment_btn.dart
import 'package:flutter/material.dart';

// MODIFIED PaymentBtn to be flexible
class PaymentBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PaymentBtn(this.icon, this.label,
      {super.key, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Define the base style for the outlined button
    final ButtonStyle defaultStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.black, // Default text/icon color
      side: const BorderSide(color: Colors.grey, width: 1), // Default border
      backgroundColor: Colors.white, // Default background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Allow padding to adjust
    );

    // Define the selected style, overriding parts of the default
    final ButtonStyle selectedStyle = OutlinedButton.styleFrom(
      foregroundColor: Colors.white, // White text/icon when selected
      backgroundColor: const Color(0xffFE691E), // Orange background
      side: const BorderSide(color: Color(0xffFE691E), width: 1), // Orange border
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    );

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label),
      ),
      style: isSelected ? selectedStyle : defaultStyle,
    );
  }
}
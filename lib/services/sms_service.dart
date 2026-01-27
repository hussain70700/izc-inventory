import 'package:intl/intl.dart';

class MessageService {
  // SMS API credentials are no longer needed
  // static const String _twilioAccountSid = 'AC45ad60b5482ba2e363f67f072f526cc6';
  // static const String _twilioAuthToken = '624573534bfdf9b3d6b0565abcafa996';
  // static const String _twilioPhoneNumber = '+12183944708';

  // Local SMS provider details also not needed
  // static const String _localSmsApiKey = 'YOUR_LOCAL_SMS_API_KEY';
  // static const String _localSmsApiUrl = 'https://api.example.com/sms/send';

  // Utility to normalize phone numbers to E.164 format for consistency
  static String _normalizePhoneNumber(String phoneNumber) {
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), ''); // Remove non-digits
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1); // Remove leading '0'
    }
    if (!cleaned.startsWith('92')) { // Assuming default country code is Pakistan (+92)
      cleaned = '92$cleaned';
    }
    return '+$cleaned'; // Add '+' for E.164 format
  }

  // Generates the confirmation message text for a sale
  static String generateSaleConfirmationMessage({
    required String customerName,
    required String saleId,
    required double totalAmount,
    required String paymentMethod,
    double? advancePayment,
    double? remainingAmount,
    String? promoCode,
    double? discount,
  }) {
    final dateFormat = DateFormat('dd MMM yyyy hh:mm a');
    final now = dateFormat.format(DateTime.now());

    String message = 'Dear $customerName,\n\n';
    message += 'Thank you for your purchase from IZZAHS COLLECTION!\n';
    message += 'Invoice No: ${saleId.substring(0, 14).toUpperCase()}\n';
    message += 'Date: $now\n';
    message += 'Total Amount: \$${totalAmount.toStringAsFixed(2)}\n';
    message += 'Payment Method: $paymentMethod\n';

    if (advancePayment != null && advancePayment > 0) {
      message += 'Advance Payment: \$${advancePayment.toStringAsFixed(2)}\n';
      message += 'Remaining (COD): \$${remainingAmount?.toStringAsFixed(2) ?? '0.00'}\n';
    }
    if (promoCode != null && discount != null && discount > 0) {
      message += 'Promo Code: $promoCode (Discount: \$${discount.toStringAsFixed(2)})\n';
    }
    message += '\nWe appreciate your business!';
    return message;
  }

  // NEW: Generates a WhatsApp direct message URL
  static String generateWhatsAppUrl({
    required String phoneNumber,
    required String message,
  }) {
    final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber).substring(1); // Remove '+' for wa.me
    final encodedMessage = Uri.encodeComponent(message);
    return 'https://wa.me/$normalizedPhoneNumber?text=$encodedMessage';
  }

// The SMS sending logic is completely removed
// static Future<bool> sendSms({
//   required String toPhoneNumber,
//   required String message,
// }) async {
//   // ... (Twilio and local provider logic removed)
//   return false; // Always return false as SMS sending is dropped
// }
}
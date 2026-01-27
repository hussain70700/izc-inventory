import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

Future<void> downloadFile(Uint8List bytes, String fileName) async {
  // Convert to base64
  final base64Data = base64Encode(bytes);

  // Create data URL with proper MIME type
  final dataUrl = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64Data';

  // Create and trigger download
  final anchor = html.AnchorElement(href: dataUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();

  // Clean up
  await Future.delayed(const Duration(milliseconds: 100));
  anchor.remove();
}
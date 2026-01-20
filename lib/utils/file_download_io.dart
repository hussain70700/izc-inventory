import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<void> downloadFile(List<int> bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';

  File file = File(filePath);
  await file.writeAsBytes(bytes);

  await OpenFile.open(filePath);
}
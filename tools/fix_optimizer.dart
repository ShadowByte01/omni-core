import 'dart:io';

void main() {
  final file = File('lib/screens/optimizer_screen.dart');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(
    'Widget _infoRow(String label, String value) {',
    'Widget _infoRow(BuildContext context, String label, String value) {',
  );
  
  // replace all occurrences of `_infoRow('` or `_infoRow(\n` with `context` added
  content = content.replaceAll(
    RegExp(r"_infoRow\(\s*'"),
    "_infoRow(context, '",
  );
  
  content = content.replaceAll(
    "_infoRow(\n",
    "_infoRow(context,\n",
  );
  
  file.writeAsStringSync(content);
  print('Fixed optimizer_screen.dart');
}

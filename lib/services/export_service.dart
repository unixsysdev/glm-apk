import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';

class ExportService {
  /// Export conversation as Markdown string
  static String toMarkdown(String title, List<MessageModel> messages) {
    final buffer = StringBuffer();
    buffer.writeln('# $title');
    buffer.writeln();
    buffer.writeln('Exported ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final msg in messages) {
      final role = msg.isUser ? '**You**' : '**Assistant** (${msg.model ?? "unknown"})';
      final time = DateFormat('HH:mm').format(msg.createdAt);
      buffer.writeln('### $role — $time');
      buffer.writeln();

      if (msg.hasReasoning) {
        buffer.writeln('<details><summary>Reasoning</summary>');
        buffer.writeln();
        buffer.writeln(msg.reasoningContent);
        buffer.writeln();
        buffer.writeln('</details>');
        buffer.writeln();
      }

      buffer.writeln(msg.content);
      buffer.writeln();

      if (msg.hasAttachments) {
        for (final a in msg.attachments) {
          buffer.writeln('📎 ${a.fileName} (${a.mimeType})');
        }
        buffer.writeln();
      }

      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Share conversation as Markdown file
  static Future<void> shareAsMarkdown(String title, List<MessageModel> messages) async {
    final markdown = toMarkdown(title, messages);
    final dir = await getTemporaryDirectory();
    final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final file = File('${dir.path}/${safeName}_export.md');
    await file.writeAsString(markdown);
    await Share.shareXFiles([XFile(file.path)], text: 'Conversation: $title');
  }
}

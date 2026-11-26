import 'package:PiliPlus/utils/page_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Lightweight Markdown renderer for GitHub release notes in dialogs.
class SimpleMarkdown extends StatefulWidget {
  const SimpleMarkdown(
    this.data, {
    super.key,
    this.onTapLink,
  });

  final String data;
  final ValueChanged<String>? onTapLink;

  @override
  State<SimpleMarkdown> createState() => _SimpleMarkdownState();
}

class _SimpleMarkdownState extends State<SimpleMarkdown> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _linkRecognizer(String url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (widget.onTapLink case final onTap?) {
          onTap(url);
        } else {
          PageUtils.launchURL(url);
        }
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  static final _headingRe = RegExp(r'^(#{1,4})\s+(.+)$');
  static final _bulletRe = RegExp(r'^(\s*)[-*+]\s+(.+)$');
  static final _orderedRe = RegExp(r'^(\s*)(\d+)\.\s+(.+)$');
  static final _hrRe = RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$');

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        );

    final lines = widget.data.replaceAll('\r\n', '\n').split('\n');
    final children = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join('\n');
      paragraph.clear();
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(_parseInline(text, baseStyle, colorScheme)),
        ),
      );
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      if (trimmed.startsWith('```')) {
        flushParagraph();
        i++;
        final codeLines = <String>[];
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++;
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                codeLines.join('\n'),
                style: baseStyle.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      if (_hrRe.hasMatch(trimmed)) {
        flushParagraph();
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: colorScheme.outlineVariant),
          ),
        );
        i++;
        continue;
      }

      if (_headingRe.firstMatch(trimmed) case final match?) {
        flushParagraph();
        final level = match.group(1)!.length;
        final text = match.group(2)!;
        final size = switch (level) {
          1 => 18.0,
          2 => 16.0,
          3 => 15.0,
          _ => 14.0,
        };
        final style = baseStyle.copyWith(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.35,
        );
        children.add(
          Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 6, bottom: 6),
            child: Text.rich(_parseInline(text, style, colorScheme)),
          ),
        );
        i++;
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        children.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 3),
              ),
            ),
            child: Text.rich(
              _parseInline(quoteLines.join('\n'), baseStyle, colorScheme),
            ),
          ),
        );
        continue;
      }

      if (_bulletRe.firstMatch(line) case final match?) {
        flushParagraph();
        final indent = match.group(1)!.length;
        final nested = indent >= 2;
        final text = match.group(2)!;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              left: nested ? 16 : 2,
              bottom: 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nested ? '◦  ' : '•  ',
                  style: baseStyle.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text.rich(_parseInline(text, baseStyle, colorScheme)),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      if (_orderedRe.firstMatch(line) case final match?) {
        flushParagraph();
        final indent = match.group(1)!.length;
        final number = match.group(2)!;
        final text = match.group(3)!;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              left: indent >= 2 ? 16 : 2,
              bottom: 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ',
                  style: baseStyle.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Text.rich(_parseInline(text, baseStyle, colorScheme)),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      paragraph.add(line);
      i++;
    }

    flushParagraph();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static final _inlineRe = RegExp(
    r'`([^`]+)`'
    r'|\[([^\]]+)\]\(([^)\s]+)\)'
    r'|\*\*(.+?)\*\*'
    r'|__(.+?)__'
    r'|~~(.+?)~~'
    r'|\*([^*\n]+)\*',
  );

  TextSpan _parseInline(
    String text,
    TextStyle baseStyle,
    ColorScheme colorScheme,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _inlineRe.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) case final code?) {
        spans.add(
          TextSpan(
            text: ' $code ',
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: (baseStyle.fontSize ?? 14) - 1,
              color: colorScheme.onSurface,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      } else if (match.group(2) case final label?) {
        final url = match.group(3)!;
        spans.add(
          TextSpan(
            text: label,
            style: baseStyle.copyWith(
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.primary,
            ),
            recognizer: _linkRecognizer(url),
          ),
        );
      } else if (match.group(4) ?? match.group(5) case final bold?) {
        spans.add(
          _parseInline(
            bold,
            baseStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            colorScheme,
          ),
        );
      } else if (match.group(6) case final strike?) {
        spans.add(
          _parseInline(
            strike,
            baseStyle.copyWith(decoration: TextDecoration.lineThrough),
            colorScheme,
          ),
        );
      } else if (match.group(7) case final italic?) {
        spans.add(
          _parseInline(
            italic,
            baseStyle.copyWith(fontStyle: FontStyle.italic),
            colorScheme,
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }
}

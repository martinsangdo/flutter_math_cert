import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Diagram for a question. `.svg` URLs are drawn as vectors, anything else as a
/// raster image. Both sit in a fixed-height box so the layout doesn't jump
/// while loading, and a broken URL just collapses.
class QuestionImage extends StatefulWidget {
  const QuestionImage(this.url, {super.key});

  final String url;

  static const height = 220.0;

  static bool isSvg(String url) =>
      (Uri.tryParse(url)?.path ?? url).toLowerCase().endsWith('.svg');

  @override
  State<QuestionImage> createState() => _QuestionImageState();
}

class _QuestionImageState extends State<QuestionImage> {
  var _failed = false;

  void _onError() {
    if (_failed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void didUpdateWidget(QuestionImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    const loading = SizedBox(
      height: QuestionImage.height,
      child: Center(child: CircularProgressIndicator()),
    );
    final Widget image;
    if (QuestionImage.isSvg(widget.url)) {
      image = SvgPicture.network(
        widget.url,
        height: QuestionImage.height,
        fit: BoxFit.contain,
        semanticsLabel: 'Diagram for the question',
        placeholderBuilder: (_) => loading,
        errorBuilder: (_, _, _) {
          _onError();
          return loading;
        },
      );
    } else {
      image = Image.network(
        widget.url,
        height: QuestionImage.height,
        cacheWidth: 720, // decode small: keeps RAM low on 2GB phones
        fit: BoxFit.contain,
        semanticLabel: 'Diagram for the question',
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : loading,
        errorBuilder: (_, _, _) {
          _onError();
          return loading;
        },
      );
    }
    // Diagrams are usually drawn on transparent backgrounds with dark lines.
    return ColoredBox(
      color: Colors.white,
      child: Center(child: image),
    );
  }
}

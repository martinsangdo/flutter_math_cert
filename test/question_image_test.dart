import 'package:flutter_test/flutter_test.dart';
import 'package:mathpathway_junior/views/widgets/question_image.dart';

void main() {
  test('detects svg urls by path, ignoring query and case', () {
    expect(QuestionImage.isSvg('https://x.co/a/fig1.svg'), isTrue);
    expect(QuestionImage.isSvg('https://x.co/a/FIG1.SVG?token=abc'), isTrue);
    expect(QuestionImage.isSvg('https://x.co/a/fig1.png'), isFalse);
    expect(QuestionImage.isSvg('https://x.co/svg/fig1.png'), isFalse);
  });
}

import 'package:material_ui/material_ui.dart';

import '../theme/app_text_styles.dart';

enum HeadingStyle { display, h1, h2, h3, h4, h5 }

/// Heading
/// - Uppercase, using TextStyle
/// - Tells screen readers that this text is a heading

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, this.style = HeadingStyle.h1, this.uppercase = true, this.color});

  final String text;
  final HeadingStyle style;

  /// Set false for titles that should keep their own case
  final bool uppercase;

  /// Optional: overrides the default text color from the theme.
  final Color? color;

  TextStyle get _textStyle {
    switch (style) {
      case HeadingStyle.display:
        return AppTextStyles.display;
      case HeadingStyle.h1:
        return AppTextStyles.h1;
      case HeadingStyle.h2:
        return AppTextStyles.h2;
      case HeadingStyle.h3:
        return AppTextStyles.h3;
      case HeadingStyle.h4:
        return AppTextStyles.h4;
      case HeadingStyle.h5:
        return AppTextStyles.h5;
    }
  }

  /// Heading level for screen readers: display and h1 = 1, h2 = 2, ...
  int get _level {
    switch (style) {
      case HeadingStyle.display:
      case HeadingStyle.h1:
        return 1;
      case HeadingStyle.h2:
        return 2;
      case HeadingStyle.h3:
        return 3;
      case HeadingStyle.h4:
        return 4;
      case HeadingStyle.h5:
        return 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Semantics marks the text as a heading, so screen readers
    // (TalkBack, VoiceOver) can jump from heading to heading.
    return Semantics(
      headingLevel: _level,
      child: Text(uppercase ? text.toUpperCase() : text, style: _textStyle.copyWith(color: color)),
    );
  }
}

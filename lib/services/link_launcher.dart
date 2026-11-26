import 'package:url_launcher/url_launcher.dart';

/// Opens web pages in the browser, outside the app.
class LinkLauncher {
  const LinkLauncher();

  /// False if [url] couldn't be opened.
  Future<bool> open(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
      // launchUrl returns false or throws, depending on the failure
    } on Exception {
      return false;
    }
  }
}

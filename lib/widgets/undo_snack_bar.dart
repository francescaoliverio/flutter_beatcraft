import 'package:material_ui/material_ui.dart';

import '../theme/app_spacing.dart';
import 'button.dart';

/// Shows [message] with an Undo button and a close icon, replacing the current snackbar instead of queueing behind it.
/// It closes by itself, except for screen reader users, who need time to reach Undo.
void showUndoSnackBar(BuildContext context, {required String message, required VoidCallback onUndo}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // Our Button instead of SnackBarAction, which is a Material text button with its own overlay
        content: Row(
          spacing: AppSpacing.paddingMd,
          children: [
            Expanded(child: Text(message)),
            Button(
              label: 'Undo',
              color: ButtonColor.tertiary,
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onUndo();
              },
            ),
          ],
        ),
        persist: MediaQuery.accessibleNavigationOf(context),
        showCloseIcon: true,
      ),
    );
}

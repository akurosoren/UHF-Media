import 'dart:async';

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

class ToastMessage {
  const ToastMessage(this.text, {this.actionLabel, this.onAction});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// One message at a time, bottom-left; a new message replaces the old one.
class ToastController extends ChangeNotifier {
  ToastMessage? _current;
  Timer? _timer;

  ToastMessage? get current => _current;

  void show(String text, {String? actionLabel, VoidCallback? onAction}) {
    _timer?.cancel();
    _current = ToastMessage(text, actionLabel: actionLabel, onAction: onAction);
    _timer = Timer(actionLabel == null ? UhfDurations.toast : UhfDurations.toastWithAction, dismiss);
    notifyListeners();
  }

  void dismiss() {
    _timer?.cancel();
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.controller, this.bottom = 96});

  final ToastController controller;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: bottom,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final message = controller.current;
          return AnimatedSwitcher(
            duration: UhfDurations.base,
            child: message == null
                ? const SizedBox.shrink(key: ValueKey('no-toast'))
                : Container(
                    key: ObjectKey(message),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: UhfColors.raised,
                      borderRadius: BorderRadius.circular(UhfRadii.md),
                      border: Border.all(color: UhfColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message.text, style: UhfText.body),
                        if (message.actionLabel != null) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              message.onAction?.call();
                              controller.dismiss();
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Text(
                                message.actionLabel!,
                                style: UhfText.sans(weight: 500, color: UhfColors.signal),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

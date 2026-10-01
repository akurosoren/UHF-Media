import 'dart:async';
import 'dart:ui';

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
  const ToastHost({super.key, required this.controller, this.top = 16});

  final ToastController controller;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: top,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final message = controller.current;
          return Center(
            child: AnimatedSwitcher(
              duration: UhfDurations.base,
              switchInCurve: UhfCurves.ease,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: message == null
                  ? const SizedBox.shrink(key: ValueKey('no-toast'))
                  : ClipRRect(
                      key: ObjectKey(message),
                      borderRadius: BorderRadius.circular(UhfRadii.pill),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            color: UhfColors.glass,
                            borderRadius: BorderRadius.circular(UhfRadii.pill),
                            border: Border.all(color: UhfColors.lineStrong),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: UhfColors.signal,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: UhfColors.signal, blurRadius: 8)],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(child: Text(message.text, style: UhfText.body)),
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
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

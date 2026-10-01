import 'dart:ui';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/icons.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_chip.dart';
import '../../ui/uhf_icon_button.dart';
import 'music_id_controller.dart';

/// Glass card that springs in with the identified song.
class MusicResultCard extends StatelessWidget {
  const MusicResultCard({super.key, required this.music, required this.onCopy});

  final MusicIdController music;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: music,
      builder: (context, _) {
        final card = music.card;
        return AnimatedSwitcher(
          duration: UhfDurations.slow,
          switchInCurve: UhfCurves.spring,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
              child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
            ),
          ),
          child: card == null ? const SizedBox.shrink(key: ValueKey('no-card')) : _body(context, card),
        );
      },
    );
  }

  Widget _body(BuildContext context, MusicCard card) {
    final l = AppLocalizations.of(context);
    final renamed = card.renamedFrom != null;
    return ClipRRect(
      key: ValueKey(card.text),
      borderRadius: BorderRadius.circular(UhfRadii.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          decoration: BoxDecoration(
            color: UhfColors.glass,
            border: Border.all(color: UhfColors.lineStrong),
            borderRadius: BorderRadius.circular(UhfRadii.lg),
            boxShadow: UhfShadows.floating,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(UhfRadii.md),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [UhfColors.signal, Color(0xFF3A1A14)],
                      ),
                    ),
                    child: const Icon(UhfIcons.music_note, size: 26, color: UhfColors.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.musicIdentified.toUpperCase(),
                          style: UhfText.sans(size: 10, weight: 500, color: UhfColors.signal),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: UhfText.sans(size: 14, weight: 500),
                        ),
                        Text(
                          card.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UhfText.sans(size: 12, color: UhfColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  UhfIconButton(
                    icon: UhfIcons.close,
                    tooltip: l.tooltipClose,
                    size: 28,
                    iconSize: 16,
                    onPressed: music.dismiss,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  UhfChip(
                    label: renamed ? l.actionUndo : l.actionRenameFile,
                    selected: !renamed,
                    onPressed: renamed ? music.undoRename : music.renameToResult,
                  ),
                  const SizedBox(width: 6),
                  UhfChip(label: l.actionCopy, onPressed: () => onCopy(card.text)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

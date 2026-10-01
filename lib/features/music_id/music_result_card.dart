import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/tokens.dart';
import '../../ui/typography.dart';
import '../../ui/uhf_chip.dart';
import '../../ui/uhf_icon_button.dart';
import 'music_id_controller.dart';

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
        if (card == null) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        final renamed = card.renamedFrom != null;
        return Container(
          width: 320,
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: UhfColors.raised,
            border: Border.all(color: UhfColors.line),
            borderRadius: BorderRadius.circular(UhfRadii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UhfText.sans(size: 11, color: UhfColors.textMuted),
                        ),
                        Text(
                          card.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: UhfText.sans(weight: 500),
                        ),
                      ],
                    ),
                  ),
                  UhfIconButton(
                    icon: Symbols.close_sharp,
                    tooltip: l.tooltipClose,
                    size: 24,
                    iconSize: 16,
                    onPressed: music.dismiss,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  UhfChip(
                    label: renamed ? l.actionUndo : l.actionRenameFile,
                    onPressed: renamed ? music.undoRename : music.renameToResult,
                  ),
                  const SizedBox(width: 6),
                  UhfChip(label: l.actionCopy, onPressed: () => onCopy(card.text)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

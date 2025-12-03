import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:solitaire/home_page.dart';
import 'package:solitaire/providers/save_state_notifier.dart';
import 'package:solitaire/services/audio_service.dart';
import 'package:solitaire/utils/build_context_extensions.dart';
import 'package:solitaire/widgets/themed_sheet.dart';

class SettingsDialog {
  static Future<void> show(BuildContext context) async {
    final rootContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, child) {
          final saveState = ref.watch(saveStateNotifierProvider).valueOrNull;
          if (saveState == null) {
            return SizedBox.shrink();
          }

          return HookBuilder(
            builder: (context) {
              final volumeState = useState(saveState.volume);
              Widget buildCard({
                required Widget child,
                Color? borderColor,
              }) {
                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sheetTileColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          borderColor ?? Colors.white.withValues(alpha: 0.08),
                      width: 1.4,
                    ),
                  ),
                  child: child,
                );
              }

              final navigator = Navigator.of(sheetContext);

              return ThemedSheet(
                title: 'Settings',
                subtitle: 'Dial in how the collection should feel.',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Volume',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.2),
                              thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: volumeState.value,
                              onChanged: (value) => volumeState.value = value,
                              onChangeEnd: (value) async {
                                await ref
                                    .read(saveStateNotifierProvider.notifier)
                                    .saveVolume(volume: value);
                                ref.read(audioServiceProvider).playPlace();
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Muted',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'Full',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    buildCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto Move',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Automatically send safe cards to their foundations.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: saveState.enableAutoMove,
                            onChanged: (newValue) => ref
                                .read(saveStateNotifierProvider.notifier)
                                .saveEnableAutoMove(
                                  enableAutoMove: newValue,
                                ),
                          ),
                        ],
                      ),
                    ),
                    buildCard(
                      borderColor: Colors.redAccent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Danger Zone',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Delete all local progress, achievements, and preferences.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text('Delete all data?'),
                                  content: Text(
                                    'This cannot be undone. Your save data, hints, and achievements will be permanently removed.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext)
                                              .pop(false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldDelete == true) {
                                await ref
                                    .read(saveStateNotifierProvider.notifier)
                                    .deleteAllData();
                                navigator.pop();
                                rootContext.pushReplacement(() => HomePage());
                              }
                            },
                            child: Text('Delete Data'),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => navigator.pop(),
                        child: Text('Close'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

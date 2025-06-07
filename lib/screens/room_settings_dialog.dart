import 'package:flutter/material.dart';
import '../socket_service.dart';

class RoomSettingsDialog extends StatefulWidget {
  final bool isHost;
  final Function(Map<String, dynamic>) onSave;

  const RoomSettingsDialog({
    super.key,
    required this.isHost,
    required this.onSave,
  });

  @override
  State<RoomSettingsDialog> createState() => _RoomSettingsDialogState();
}

class _RoomSettingsDialogState extends State<RoomSettingsDialog> {
  late Map<String, dynamic> editedSettings;
  late TextEditingController customWordsController;
  String? lastCustomWordsString;

  @override
  void initState() {
    super.initState();
    final customWordsString =
        (SocketService.latestSettings['customWords'] as List?)?.join(', ') ?? '';
    customWordsController = TextEditingController(text: customWordsString);
    lastCustomWordsString = customWordsString;

    editedSettings = Map<String, dynamic>.from(SocketService.latestSettings);

    customWordsController.addListener(() {
      if (widget.isHost) {
        editedSettings['customWords'] = customWordsController.text
            .split(',')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList();
        // LOG: This will print on every keystroke for the host
        print('[SETTINGS_DIALOG] Host changed customWords: ${editedSettings['customWords']}');
        widget.onSave({...editedSettings}); // Always send a new map!
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SocketService(),
      builder: (context, _) {
        final settings = SocketService.latestSettings;
        editedSettings = Map<String, dynamic>.from(settings);
        final customWordsString =
            (settings['customWords'] as List?)?.join(', ') ?? '';
        // Only update controller if the value from the server changed
        if (customWordsString != lastCustomWordsString) {
          customWordsController.text = customWordsString;
          lastCustomWordsString = customWordsString;
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 107, 149, 255),
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Room Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Match all dropdowns with create screen
                  _dropdownRow('Max Players', 'maxPlayers', [4, 6, 8, 10]),
                  _dropdownRow('Draw Time', 'drawTime', [30, 45, 60, 90, 120, 140, 160]),
                  _dropdownRow('Choose Time', 'chooseTime', [30, 45, 60, 90, 120, 140, 160]),
                  _dropdownRow('Word Choices', 'wordOptions', [2, 3, 4, 5]),
                  _dropdownRow('Difficulty', 'difficulty', ['Easy', 'Normal', 'Moderate', 'Hard', 'Mix']),
                  _dropdownRow('Rounds', 'rounds', [2, 3, 4, 5, 6, 7, 8]),
                  _hintsRow(),
                  const SizedBox(height: 16),
                  TextField(
                    enabled: widget.isHost,
                    controller: customWordsController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Words (comma separated)',
                      hintText: 'e.g. apple, banana, cherry',
                      fillColor: Colors.white24,
                      filled: true,
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.white),
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close', 
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dropdownRow(String label, String key, List options) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          DropdownButton(
            value: editedSettings[key],
            items: options
                .map((e) => DropdownMenuItem(value: e, child: Text(e.toString())))
                .toList(),
            onChanged: widget.isHost
                ? (v) {
                    setState(() => editedSettings[key] = v);
                    widget.onSave({...editedSettings});
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Switch(
            value: editedSettings[key] ?? false,
            onChanged: widget.isHost
                ? (v) {
                    setState(() => editedSettings[key] = v);
                    widget.onSave({...editedSettings});
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // Add new method for hints handling
  Widget _hintsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Hints'),
          Row(
            children: [
              Switch(
                value: editedSettings['hintsEnabled'] ?? true,
                onChanged: widget.isHost ? (value) {
                  setState(() {
                    editedSettings['hintsEnabled'] = value;
                    if (!value) editedSettings['hintCount'] = 2; // Reset to default
                    widget.onSave({...editedSettings});
                  });
                } : null,
              ),
              if (editedSettings['hintsEnabled'] ?? true)
                DropdownButton<int>(
                  value: editedSettings['hintCount'] ?? 2,
                  items: [1, 2, 3, 4, 5]
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toString()),
                          ))
                      .toList(),
                  onChanged: widget.isHost
                      ? (v) {
                          setState(() => editedSettings['hintCount'] = v);
                          widget.onSave({...editedSettings});
                        }
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
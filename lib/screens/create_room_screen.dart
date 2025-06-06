import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import '../socket_service.dart';

class CreateRoomScreen extends StatefulWidget {
  final String username;
  const CreateRoomScreen({super.key, required this.username});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  // Update default values to match
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _customWordsController = TextEditingController();
  int maxPlayers = 4;
  int drawTime = 60;
  int chooseTime = 60;
  int wordOptions = 3;
  String difficulty = 'Normal';
  bool hintsEnabled = true;
  int hintCount = 2;
  int rounds = 3;

  final socket = SocketService().socket;
  bool navigatedToLobby = false;

  void createRoom() {
    SocketService().socket.emit('create-room', {
      'settings': {
        'maxPlayers': maxPlayers,
        'drawTime': drawTime,
        'chooseTime': chooseTime,
        'wordOptions': wordOptions,
        'difficulty': difficulty,
        'hintsEnabled': hintsEnabled,
        'hintCount': hintCount,
        'rounds': rounds,
        'customWords': _customWordsController.text
            .split(',')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList(),
      },
      'username': widget.username,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SocketService(),
      builder: (context, _) {
        if (!navigatedToLobby &&
            SocketService.latestRoomId.isNotEmpty &&
            SocketService.latestPlayers.isNotEmpty) {
          navigatedToLobby = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LobbyScreen(
                  username: widget.username,
                  roomId: SocketService.latestRoomId,
                  isHost: true,
                ),
              ),
            );
          });
        }
        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 255, 0, 242),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Image.asset('assets/images/create_room.png', height: 120),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _roomNameController,
                  decoration: InputDecoration(
                    hintText: 'Room Name',
                    filled: true,
                    fillColor: const Color.fromARGB(255, 255, 167, 251),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: maxPlayers,
                  items: [4, 6, 8, 10]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text("Max Players: $e"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => maxPlayers = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: drawTime,
                  items: [30, 45, 60, 90, 120, 140, 160]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text("Draw Time: $e sec"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => drawTime = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: chooseTime,
                  items: [30, 45, 60, 90, 120, 140, 160]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text("Choose Time: $e sec"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => chooseTime = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: wordOptions,
                  items: [2, 3, 4, 5]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text("Word Choices: $e"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => wordOptions = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: difficulty,
                  items: ['Easy', 'Normal', 'Moderate', 'Hard']
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text("Difficulty: $e"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => difficulty = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: hintsEnabled ? 'Enabled ($hintCount)' : 'Disabled',
                  items: [
                    const DropdownMenuItem(
                      value: 'Disabled',
                      child: Text('Hints: Disabled'),
                    ),
                    ...[1, 2, 3, 4, 5].map(
                      (count) => DropdownMenuItem(
                        value: 'Enabled ($count)',
                        child: Text('Hints: $count'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == 'Disabled') {
                      setState(() {
                        hintsEnabled = false;
                        hintCount = 2;
                      });
                    } else {
                      final count =
                          int.tryParse(val!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
                      setState(() {
                        hintsEnabled = true;
                        hintCount = count;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  dropdownColor: const Color.fromARGB(255, 255, 167, 251),
                  value: rounds,
                  items: [2, 3, 4, 5, 6, 7, 8]
                      .map(
                        (e) =>
                            DropdownMenuItem(value: e, child: Text("Rounds: $e")),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => rounds = val!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _customWordsController,
                  decoration: InputDecoration(
                    hintText: 'Custom words (comma separated)',
                    filled: true,
                    fillColor: const Color.fromARGB(255, 255, 167, 251),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF316BFF),
                      elevation: 8,
                      shadowColor: const Color(0xFF002366),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    onPressed: createRoom,
                    child: const Text(
                      'Create Room',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _customWordsController.dispose();
    super.dispose();
  }
}

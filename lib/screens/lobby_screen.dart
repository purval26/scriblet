import 'package:flutter/material.dart';
import '../socket_service.dart';
import 'room_settings_dialog.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String username;
  final String roomId;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.username,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      SocketService().socket.emit('get-room', {'roomId': widget.roomId});
    });

    // Listen for game start and navigate
    SocketService().socket.on('game-state-update', (data) {
      if (data['isPlaying'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              username: widget.username,
              roomId: widget.roomId,
            ),
          ),
        );
      }
    });
  }

  void startGame() {
    final socket = SocketService().socket;
    socket.emit('start-game');
  }

  @override
  void dispose() {
    SocketService().socket.off('game-state-update');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SocketService(),
      builder: (context, _) {
        final players = SocketService.latestPlayers;
        final host = SocketService.latestHost;
        final roomSettings = SocketService.latestSettings;

        return Scaffold(
          backgroundColor: const Color(0xFF316BFF),
          body: Column(
            children: [
              const SizedBox(height: 48),
              Text('Players in Lobby:', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text('Room ID: ${widget.roomId}', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Image.asset(
                      'assets/images/${players[i]['avatar'] ?? 'mascot1.png'}',
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                    title: Text(players[i]['username'] ?? 'Player'),
                    trailing: (host == players[i]['username'])
                        ? const Icon(Icons.star, color: Colors.yellow)
                        : null,
                  ),
                ),
              ),
              if (widget.isHost)
                ElevatedButton(
                  onPressed: startGame,
                  child: const Text('Start Game'),
                ),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => RoomSettingsDialog(
                      isHost: widget.isHost,
                      onSave: (newSettings) {
                        if (widget.isHost) {
                          final socket = SocketService().socket;
                          socket.emit('update-room-settings', {
                            'roomId': widget.roomId,
                            'settings': newSettings,
                          });
                        }
                      },
                    ),
                  );
                },
                child: const Text('Room Settings'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
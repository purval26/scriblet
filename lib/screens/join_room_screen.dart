import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import '../socket_service.dart';
import 'game_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  final String username;
  const JoinRoomScreen({super.key, required this.username});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _roomIdController = TextEditingController();
  final socket = SocketService().socket;
  bool navigatedToLobby = false;

  @override
  void initState() {
    super.initState();
    if (!(SocketService().socket.connected ?? false)) {
      SocketService().socket.connect();
    }
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Clean up socket and room data when leaving
        socket.disconnect();
        SocketService.setRejoining(false);
        SocketService.setGameState(null);
        // Clear latest room data
        SocketService().clearRoomData();
        return true;
      },
      child: AnimatedBuilder(
        animation: SocketService(),
        builder: (context, _) {
          if (!navigatedToLobby &&
              SocketService.latestRoomId.isNotEmpty &&
              SocketService.latestPlayers.isNotEmpty) {
            navigatedToLobby = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Use the single instance of getters
              if (SocketService.isRejoining && SocketService.gameState != null) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      username: widget.username,
                      roomId: SocketService.latestRoomId,
                    ),
                  ),
                );
              } else {
                // Normal lobby navigation
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LobbyScreen(
                      username: widget.username,
                      roomId: SocketService.latestRoomId,
                      isHost: false,
                    ),
                  ),
                );
              }
            });
          }
          return Scaffold(
            resizeToAvoidBottomInset: true, // Allow resize for keyboard
            backgroundColor: const Color.fromARGB(255, 255, 0, 242),
            body: SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top section with logo and title
                        Column(
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Image.asset(
                                'assets/images/join_room.png',
                                height: 120,
                              ),
                            ),
                            const Text(
                              'Join Room',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),

                        // Middle section with welcome text and input
                        Column(
                          children: [
                            Text(
                              'Hello, ${widget.username}!',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 40),
                            TextField(
                              controller: _roomIdController,
                              decoration: InputDecoration(
                                hintText: 'Enter Room ID',
                                filled: true,
                                fillColor:
                                    const Color.fromARGB(255, 255, 167, 251),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Bottom section with join button
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: ElevatedButton(
                            onPressed: () {
                              final roomId = _roomIdController.text.trim();
                              if (roomId.isEmpty) return;
                              socket.emit('join-room', {
                                'roomId': roomId,
                                'username': widget.username,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF316BFF),
                              elevation: 8,
                              shadowColor: const Color(0xFF002366),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Join Room',
                              style: TextStyle(fontSize: 20, color: Colors.white),
                            ),
                          ),
                        ),
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

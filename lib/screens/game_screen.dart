import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../socket_service.dart';

class GameScreen extends StatefulWidget {
  final String username;
  final String roomId;

  const GameScreen({super.key, required this.username, required this.roomId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final TextEditingController messageController = TextEditingController();

  double strokeWidth = 4.0;
  Color selectedColor = Colors.black;
  ToolType selectedTool = ToolType.pencil;
  bool isToolPanelExpanded = false;
  final GlobalKey _toolsKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _wordChoiceOverlay;

  late List<List<DrawPoint>> points = [];
  late List<List<DrawPoint>> strokes = [];
  late List<List<List<DrawPoint>>> undoStack = [];
  late List<List<List<DrawPoint>>> redoStack = [];

  List<String> chatMessages = [];

  int timeLeft = 0;
  String timerType = 'choose';

  int get drawTime => (SocketService.latestSettings['drawTime']) as int;
  bool get roundEnded => SocketService.latestRoundEnd;
  String get word => SocketService.latestWord;
  List<String> get wordChoices => SocketService.latestWordChoices;
  String get latestHiddenWord => SocketService.latestHiddenWord;
  String get hiddenWord {
    if (word.isEmpty) return '';
    
    return word.split('').asMap().entries.map((entry) {
      final index = entry.key;
      final letter = entry.value;
      
      if (letter == ' ') return ' ';
      if (revealedIndices.contains(index)) return letter;
      return '_';
    }).join(' ');
  }
  bool get isDrawer =>
      SocketService.latestDrawerId == SocketService().socket.id;
  String get drawer => SocketService.latestDrawer;
  bool get isChoosing => SocketService.latestIsChoosing;
  bool get isPlaying => SocketService.latestIsPlaying;

  // Add scores getter
  Map<String, dynamic> get scores => SocketService.latestScores;

  late final socket = SocketService().socket;

  // Add new state variables
  Set<int> revealedIndices = {};

  void toggleToolPanel() {
    if (isToolPanelExpanded) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
    setState(() => isToolPanelExpanded = !isToolPanelExpanded);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    isToolPanelExpanded = false;
  }

  void _showOverlay() {
    // Remove existing overlay first
    _removeOverlay();
    
    if (!mounted) return;

    final RenderBox? renderBox = _toolsKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _removeOverlay,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              Positioned(
                top: offset.dy + renderBox.size.height + 8,
                right: MediaQuery.of(context).size.width - offset.dx - renderBox.size.width,
                child: buildExpandedTools(),
              ),
            ],
          ),
        );
      },
    );

    try {
      Overlay.of(context).insert(_overlayEntry!);
    } catch (e) {
      print("Error showing overlay: $e");
    }
  }

  String _getSelectedToolIcon() {
    switch (selectedTool) {
      case ToolType.eraser:
        return 'assets/images/eraser.png';
      case ToolType.pencil:
        return 'assets/images/pencil.png';
      default:
        return 'assets/images/pencil.png';
    }
  }

  @override
  void initState() {
    super.initState();

    // Handle rejoining
    if (SocketService.isRejoining && SocketService.gameState != null) {
      final gameState = SocketService.gameState!;
      setState(() {
        timeLeft = gameState['timeLeft'] ?? timeLeft;
        if (gameState['drawingData'] != null) {
          strokes = _parseDrawingData(gameState['drawingData']);
        }
      });
      // Reset rejoining flag using public methods
      SocketService.setRejoining(false);
      SocketService.setGameState(null);
    }

    final settings = SocketService.latestSettings;
    timeLeft = settings['drawTime'];    socket.on('drawing-data', (raw) {
      try {
        if (raw == null) {
          print("Received null drawing data");
          return;
        }

        setState(() {
          strokes = _parseDrawingData(raw);
        });
      } catch (e) {
        print("Error parsing drawing data: $e");
      }
    });

    // Add canvas-clear handler
    socket.on('canvas-clear', (_) {
      // if (!mounted) return;
      print("Canvas cleared by server");
      setState(() {
        strokes = [];
        undoStack = [];
        redoStack = [];
      });
    });

    socket.on('chat-message', (data) {
      setState(() {
        chatMessages.add('${data['username']}: ${data['message']}');
      });
    });

    socket.on('correct-guess', (data) {
      setState(() {
        chatMessages.add(
          '${data['username']} guessed correctly! (+${data['points']})',
        );
      });
    });

    socket.on('game-end', (data) {
      showLeaderboard(data['scores'] ?? {});
    });

    socket.on('error', (data) {
      print('[CLIENT] Socket error: $data');
    });

    // socket.on('drawing-data', (data) {
    //   if (data is List) {
    //     List<DrawPoint?> receivedPoints = data.map<DrawPoint?>((p) {
    //       if (p == null) return null;
    //       return DrawPoint(Offset(p[0], p[1]), Color(p[2]), p[3].toDouble());
    //     }).toList();

    //     setState(() {
    //       pointsList = receivedPoints;
    //     });
    //   }
    // });

    // Add timer update listener
    socket.on('timer-update', (data) {
      if (!mounted) return;
      setState(() {
        timeLeft = data['timeLeft'];
        timerType = data['timerType'];
      });
    });

    // Update game state handler
    socket.on('game-state-update', (data) {
      if (!mounted) return;
      
      print("Game state update received: $data"); // Debug log

      // Always clear canvas when isChoosing is true
      if (data['isChoosing'] == true) {
        print("Clearing canvas - drawer change or choosing phase"); // Debug
        handleClear();
      }

      setState(() {
        if (data['timeLeft'] != null) {
          timeLeft = data['timeLeft'];
        }
        if (data['timerType'] != null) {
          timerType = data['timerType'];
        }
      });

      // Handle word choices outside setState
      // if (data['isChoosing'] == true) {
      //   WidgetsBinding.instance.addPostFrameCallback((_) {
      //     if (isDrawer && data['wordChoices'] != null) {
      //       List<String> choices = List<String>.from(data['wordChoices']);
      //       print("Showing word choices to drawer: $choices"); // Debug
      //       _showWordChoiceOverlay(choices);
      //     } else if (!isDrawer) {
      //       print("Showing waiting overlay for: ${data['drawer']}"); // Debug
      //       _showWaitingOverlay(data['drawer'] ?? 'Someone');
      //     }
      //   });
      // }
    });

    socket.on('drawer-points', (data) {
      if (!mounted) return;
      setState(() {
        chatMessages.add(
          '${data['username']} got +${data['points']} points for ${data['allGuessed'] ? 'everyone guessing!' : 'a correct guess!'}',
        );
      });
    });



    // Add hint update listener
socket.on('hint-update', (data) {
  if (!mounted || isDrawer) return;
  setState(() {
    if (data['indices'] != null) {
      revealedIndices.addAll(List<int>.from(data['indices']));
    }
    if (data['hiddenWord'] != null) {
      SocketService.latestHiddenWord = data['hiddenWord'] as String;
    }
  });
});

    // Clear hints when word changes
    socket.on('game-state-update', (data) {
      if (!mounted) return;
      
      if (data['isChoosing'] == true) {
        setState(() {
          revealedIndices.clear();
        });
      }
    });
  }

  List<List<DrawPoint>> _parseDrawingData(dynamic data) {
    if (data == null) return [];
    
    try {
      List<dynamic> decoded = data is String ? jsonDecode(data) : data;
      List<List<DrawPoint>> result = [];
      
      for (var stroke in decoded) {
        if (stroke == null) {
          result.add([]);
          continue;
        }
        List<DrawPoint> strokePoints = [];
        for (var p in stroke) {
          strokePoints.add(DrawPoint(
            Offset(p[0].toDouble(), p[1].toDouble()),
            Color(p[2]),
            p[3].toDouble(),
          ));
        }
        result.add(strokePoints);
      }
      return result;
    } catch (e) {
      print("Error parsing drawing data: $e");
      return [];
    }
  }
  void sendDrawingData() {
    if (!mounted || !isDrawer || isChoosing) return;

    try {
      final data = strokes.map((stroke) {
        return stroke.map((p) => [
          p.offset.dx,
          p.offset.dy,
          p.color.value,
          p.strokeWidth
        ]).toList();
      }).toList();

      final jsonData = jsonEncode(data);
      socket.emit('drawing-data', jsonData);
    } catch (e) {
      print("Error sending drawing data: $e");
    }
  }
  void handleUndo() {
    if (strokes.isEmpty) return;
    setState(() {
      // Save current state to redo stack
      redoStack.add(strokes.map((stroke) => 
        stroke.map((point) => DrawPoint.from(point)).toList()
      ).toList());
      
      // Pop the last action from undoStack
      if (undoStack.isNotEmpty) {
        strokes = undoStack.removeLast().map((stroke) =>
          stroke.map((point) => DrawPoint.from(point)).toList()
        ).toList();
      } else {
        // If no previous state in undoStack, just remove the last stroke
        strokes.removeLast();
      }
    });
    sendDrawingData();
  }
  void handleRedo() {
    if (redoStack.isEmpty) return;
    setState(() {
      // Save current state to undo stack
      undoStack.add(strokes.map((stroke) => 
        stroke.map((point) => DrawPoint.from(point)).toList()
      ).toList());
      
      // Apply the redo state
      strokes = redoStack.removeLast().map((stroke) =>
        stroke.map((point) => DrawPoint.from(point)).toList()
      ).toList();
    });
    sendDrawingData();
  }
  void handlePanStart(DragStartDetails details) {
    if (!isDrawingAllowed()) return;
    
    // Save current state before starting new stroke
    undoStack.add(strokes.map((stroke) => 
      stroke.map((point) => DrawPoint.from(point)).toList()
    ).toList());
    // Clear redo stack when new action starts
    redoStack.clear();
    
    setState(() {
      strokes.add([]); // Start a new stroke
    });
  }

  void handlePanUpdate(DragUpdateDetails details) {
    final isDrawer = SocketService.latestDrawerId == socket.id;
    final isChoosing = SocketService.latestIsChoosing;
    if (!isDrawer || isChoosing || strokes.isEmpty) return;

    setState(() {
      strokes.last.add(
        DrawPoint(
          details.localPosition,
          selectedTool == ToolType.eraser ? Colors.white : selectedColor,
          selectedTool == ToolType.eraser ? strokeWidth + 8 : strokeWidth,
        ),
      );
    });
    sendDrawingData();
  }

  void handlePanEnd(DragEndDetails details) {
    if (!isDrawingAllowed()) return;
    
    setState(() {
      if (strokes.last.isEmpty) {
        strokes.removeLast(); // Remove empty strokes
      } else {
        undoStack.add(
          strokes.map((s) => s.toList()).toList(),
        );
        redoStack.clear();
      }
    });
    sendDrawingData();
  }

  void handleClear() {
    final isDrawer = SocketService.latestDrawerId == socket.id;
    final isChoosing = SocketService.latestIsChoosing;
    if (!isDrawer || isChoosing) return;

    setState(() {
      if (strokes.isNotEmpty) {
        undoStack.add(
          strokes.map((s) => s.toList()).toList(),
        ); // Fixed conversion
        redoStack.clear();
      }
      strokes.clear();
    });
    sendDrawingData();
  }
  void handleBucket() {
    final isDrawer = SocketService.latestDrawerId == socket.id;
    final isChoosing = SocketService.latestIsChoosing;
    if (!isDrawer || isChoosing) return;

    final bgStroke = [
      DrawPoint(Offset.zero, selectedColor, MediaQuery.of(context).size.width),
    ];

    setState(() {
      undoStack.add(strokes.map((stroke) => 
        stroke.map((point) => DrawPoint.from(point)).toList()
      ).toList());
      redoStack.clear();
      strokes.insert(0, bgStroke);
    });
    sendDrawingData();
  }

  void handleGuess(String guess) {
    if (guess.trim().isEmpty) return;
    
    // Don't process as guess if:
    // 1. Player is drawer
    // 2. Game is in choosing phase
    // 3. Round has ended
    if (isDrawer || isChoosing || roundEnded) {
      socket.emit('chat-message', {'message': guess});
      messageController.clear();
      return;
    }

    // Send as potential guess
    socket.emit('chat-message', {'message': guess});
    messageController.clear();
  }

  void selectWord(String word) {
    socket.emit('select-word', {'word': word});
  }

  void showLeaderboard(Map<String, dynamic> scores) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Convert scores to proper format and handle type safety
        final processedScores = scores.entries.map((entry) {
          if (entry.value is Map) {
            return MapEntry(entry.key, entry.value as Map<String, dynamic>);
          } else {
            // Handle case where score is direct integer
            return MapEntry(entry.key, {
              'score': entry.value is int ? entry.value : 0,
              'mascot': 'default'
            });
          }
        }).toList();

        // Sort by score
        processedScores.sort((a, b) {
          final scoreA = a.value['score'] is int ? a.value['score'] as int : 0;
          final scoreB = b.value['score'] is int ? b.value['score'] as int : 0;
          return scoreB.compareTo(scoreA);
        });

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/leaderboard.png',
                    height: 32,
                    errorBuilder: (_, __, ___) => const Icon(Icons.leaderboard),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: processedScores.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = processedScores[index];
                    final score = entry.value['score'] ?? 0;
                    final mascot = entry.value['mascot'] ?? 'default';
                    final isCurrentPlayer = entry.key == widget.username;
                    
                    return Container(
                      color: isCurrentPlayer ? Colors.blue.withOpacity(0.1) : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRankColor(index + 1),
                          child: Text(
                            '#${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: isCurrentPlayer ? 
                              FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text(
                          score.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getRankColor(index + 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey[400]!; // Silver
      case 3:
        return Colors.brown[300]!; // Bronze
      default:
        return Colors.grey[700]!;
    }
  }

  void showRoundResultsModal(Map<String, dynamic> roundScores) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The word was: $word',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ...roundScores.entries.map((e) => ListTile(
                  leading: Image.asset(
                    'assets/mascots/${e.value['mascot']}.png',
                    width: 40,
                    height: 40,
                  ),
                  title: Text(e.key),
                  trailing: Text(
                    '+${e.value['points']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                if (isDrawer) ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (wordChoices.isNotEmpty) {
                      _showWordChoiceOverlay(wordChoices);
                    }
                  },
                  child: const Text('Next Word'),
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
    // Clean up overlays
    _wordChoiceOverlay?.remove();
    _overlayEntry?.remove();
    
    // Clean up socket listeners
    socket.off('drawing-data');
    socket.off('timer-update'); 
    socket.off('game-state-update');
    socket.off('canvas-clear');
    socket.off('chat-message');
    socket.off('correct-guess');
    socket.off('game-end');
    socket.off('drawer-points');
    socket.off('error');
    socket.off('hint-update');
    
    // Clean up controllers
    messageController.dispose();
    super.dispose();
  }

  Widget buildWordBar() {
  if (isChoosing && isDrawer && wordChoices.isNotEmpty) {
    // Drawer: show word choices in horizontal wrap
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose a word to draw: ($timeLeft)',
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, // gap between buttons horizontally
            runSpacing: 8, // gap between rows
            alignment: WrapAlignment.center,
            children: wordChoices.map((w) => SizedBox(
              width: 120, // fixed width for each button
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => selectWord(w),
                child: Text(
                  w,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  } else if (isChoosing) {
    // Guessers: show "Player X is choosing a word..."
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        '$drawer is choosing a word... $timeLeft',
        style: const TextStyle(fontSize: 20, color: Colors.white),
      ),
    );
  } else {
    // After word is chosen: show word or underlines
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              isDrawer ? word : '${latestHiddenWord}  (${latestHiddenWord.replaceAll(' ', '').length})',
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              buildCanvasTools(isDrawer: isDrawer, isChoosing: isChoosing),
              const SizedBox(width: 8),
              const Icon(Icons.timer, color: Colors.red),
              const SizedBox(width: 4),
              const SizedBox(height: 50),
              Text(
                '$timeLeft',
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

  Widget buildCanvasTools({required bool isDrawer, required bool isChoosing}) {
    if (!isDrawer || isChoosing) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(0),
      child: GestureDetector(
        onTap: toggleToolPanel,
        child: Container(
          key: _toolsKey,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black),
          ),
          child: Image.asset(_getSelectedToolIcon(), height: 32),
        ),
      ),
    );
  }

  Widget buildExpandedTools() {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 320),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.start,
              runSpacing: 8,
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                toolButton(
                  icon: 'assets/images/undo.png',
                  tooltip: 'Undo',
                  onPressed: handleUndo, // ✅ don't call _removeOverlay
                ),
                toolButton(
                  icon: 'assets/images/redo.png',
                  tooltip: 'Redo',
                  onPressed: handleRedo, // ✅ don't call _removeOverlay
                ),
                toolButton(
                  icon: 'assets/images/eraser.png',
                  tooltip: 'Eraser',
                  selected: selectedTool == ToolType.eraser,
                  onPressed: () {
                    setState(() => selectedTool = ToolType.eraser);
                    _removeOverlay(); // ✅ close overlay
                  },
                ),
                toolButton(
                  icon: 'assets/images/delete.png',
                  tooltip: 'Delete',
                  selected: selectedTool == ToolType.delete,
                  onPressed: () {
                    handleClear(); // ✅ clear canvas
                    _removeOverlay(); // ✅ close overlay
                  },
                ),
                toolButton(
                  icon: 'assets/images/pencil.png',
                  tooltip: 'Pencil',
                  selected: selectedTool == ToolType.pencil,
                  onPressed: () {
                    setState(() => selectedTool = ToolType.pencil);
                    _removeOverlay(); // ✅ close overlay
                  },
                ),
                toolButton(
                  icon: 'assets/images/bucket.png',
                  tooltip: 'Fill',
                  onPressed: () {
                    handleBucket();
                    _removeOverlay(); // ✅ close overlay
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    _removeOverlay(); // ✅ close overlay before opening dialog
                    Color? picked = await showDialog(
                      context: context,
                      builder: (context) =>
                          ColorPickerDialog(selectedColor: selectedColor),
                    );
                    if (picked != null) {
                      setState(() => selectedColor = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Slider(
                    value: strokeWidth,
                    min: 2,
                    max: 24,
                    divisions: 11,
                    label: strokeWidth.round().toString(),
                    onChanged: (v) => setState(() => strokeWidth = v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget toolButton({
    required String icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? Colors.blue.shade100 : Colors.white,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Image.asset(icon, height: 28),
        tooltip: tooltip,
      ),
    );
  }

  Widget buildChatBox() {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final reversedIndex = chatMessages.length - 1 - index;
                final message = chatMessages[reversedIndex];
                
                // Style based on message type
                TextStyle messageStyle;
                Color? backgroundColor;
                
                if (message.contains("guessed correctly")) {
                  messageStyle = const TextStyle(
                    color: Color.fromARGB(255, 4, 219, 11),
                    fontWeight: FontWeight.bold,
                  );
                } else if (message.startsWith("$drawer:")) {
                  messageStyle = const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  );
                  backgroundColor = const Color.fromARGB(255, 255, 196, 0);
                } else {
                  messageStyle = const TextStyle(
                    color: Colors.white,
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Container(
                    padding: backgroundColor != null ? 
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
                    decoration: backgroundColor != null ? BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ) : null,
                    child: Text(message, style: messageStyle),
                  ),
                );
              },
            ),
          ),
        ),        Padding(          
          padding: const EdgeInsets.only(
            left: 4,
            right: 4,
            top: 4,
            bottom: 0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: messageController,
                    onSubmitted: handleGuess,
                    cursorColor: Colors.white,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isDrawer 
                        ? "Chat with players..." 
                        : isChoosing
                          ? "Waiting for word..."
                          : "Enter your guess...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => handleGuess(messageController.text),
                  icon: const Icon(Icons.send, color: Color(0xFF2F31C5)),
                  tooltip: 'Send',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add new method for word choice overlay
  void _showWordChoiceOverlay(List<String> choices) {
    // Remove any existing overlay
    _wordChoiceOverlay?.remove();
    _wordChoiceOverlay = null;

    final overlay = OverlayEntry(
      maintainState: true, // Keep overlay alive
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose a word to draw ($timeLeft)',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ...choices.map((word) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          selectWord(word);
                          _wordChoiceOverlay?.remove();
                          _wordChoiceOverlay = null;
                        },
                        child: Text(
                          word,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _wordChoiceOverlay = overlay;
    
    // Use addPostFrameCallback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Overlay.of(context).insert(overlay);
      }
    });
  }

  // Add new method for waiting overlay
  void _showWaitingOverlay(String drawerName) {
    // Remove any existing overlay
    _wordChoiceOverlay?.remove();
    _wordChoiceOverlay = null;

    final overlay = OverlayEntry(
      maintainState: true,
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black54,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    '$drawerName is choosing a word...',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$timeLeft seconds',
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    _wordChoiceOverlay = overlay;
    
    // Use addPostFrameCallback to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Overlay.of(context).insert(overlay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SocketService(),
      builder: (context, _) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            resizeToAvoidBottomInset: true, // Enable resize for keyboard
            backgroundColor: const Color(0xFF2F31C5),
            appBar: AppBar(
              backgroundColor: const Color(0xFF2F31C5),
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              ),              title: const Text(
                "Scriblet",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset(
                        'assets/images/leaderboard.png',
                        height: 28,
                      ),
                    ),
                  ),
                  onPressed: () => showLeaderboard(scores),
                  tooltip: 'Leaderboard',
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  buildWordBar(),
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              onPanStart: isDrawer && !isChoosing
                                  ? (details) {
                                      setState(() {
                                        strokes.add([]); // Start a new stroke
                                      });
                                    }
                                  : null,                              onPanUpdate: isDrawer && !isChoosing
                                  ? (details) {
                                      setState(() {
                                        strokes.last.add(DrawPoint(
                                          details.localPosition,
                                          selectedTool == ToolType.eraser
                                              ? Colors.white
                                              : selectedColor,
                                          selectedTool == ToolType.eraser
                                              ? strokeWidth + 8
                                              : strokeWidth,
                                        ));
                                      });
                                      sendDrawingData();
                                    }
                                  : null,
                              onPanEnd: isDrawer && !isChoosing
                                  ? (details) {
                                      setState(() {
                                        if (strokes.last.isEmpty) {
                                          strokes
                                              .removeLast(); // Remove empty strokes
                                        } else {
                                          undoStack.add(
                                            List.from(
                                              strokes.map((s) => List.from(s)),
                                            ),
                                          );
                                          redoStack.clear();
                                        }
                                      });
                                      sendDrawingData();
                                    }
                                  : null,
                              child: CustomPaint(
                                painter: DrawingPainter(strokes: strokes),
                                child: const SizedBox.expand(),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      margin: const EdgeInsets.only(bottom: 0),
                      child: buildChatBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool isDrawingAllowed() {
    return isDrawer && !isChoosing;
  }

}

class DrawPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawPoint(this.offset, this.color, this.strokeWidth);

  // Add copy constructor
  DrawPoint.from(DrawPoint other)
      : offset = Offset(other.offset.dx, other.offset.dy),
        color = Color(other.color.value),
        strokeWidth = other.strokeWidth;
}

class DrawingPainter extends CustomPainter {
  final List<List<DrawPoint>> strokes;

  DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        final p1 = stroke[i];
        final p2 = stroke[i + 1];

        final paint = Paint()
          ..color = p1.color
          ..strokeWidth = p1.strokeWidth
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

        canvas.drawLine(p1.offset, p2.offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ColorPickerDialog extends StatefulWidget {
  final Color selectedColor;
  const ColorPickerDialog({super.key, required this.selectedColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color pickerColor;

  @override
  void initState() {
    super.initState();
    pickerColor = widget.selectedColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: pickerColor,
          onColorChanged: (color) => setState(() => pickerColor = color),
          pickerAreaHeightPercent: 0.8,
          enableAlpha: false,
          displayThumbColor: true,
          showLabel: false,
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Select'),
          onPressed: () => Navigator.of(context).pop(pickerColor),
        ),
      ],
    );
  }
}

enum ToolType { pencil, eraser, delete }

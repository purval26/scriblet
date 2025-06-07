// This file is a compatibility shim for socket_io_client import style.
// Use this in your Flutter screens to import the socket_io_client package.

export 'package:socket_io_client/socket_io_client.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService extends ChangeNotifier {
  static final SocketService _instance = SocketService._internal();
  static Map<String, dynamic> latestSettings = {};
  static List<dynamic> latestPlayers = [];
  static List<dynamic> latestDrawing = [];
  static String latestHost = '';
  static String latestRoomId = '';
  static String latestDrawer = '';
  static String latestDrawerId = '';
  static String latestHiddenWord = '';
  static List<String> latestWordChoices = [];
  static String latestWord = '';
  static bool latestIsChoosing = false;
  static bool latestIsPlaying = false;
  static bool latestRoundEnd = false;
  static bool DebugMode = false; // Set to false in production
  static Map<String, int> latestScores = {};

  // Add new static properties
  static bool _rejoining = false;
  static Map<String, dynamic>? _gameState;

  static bool get isRejoining => _rejoining;
  static Map<String, dynamic>? get gameState => _gameState;

  // Add these public methods
  static void setRejoining(bool value) {
    _rejoining = value;
  }

  static void setGameState(Map<String, dynamic>? state) {
    _gameState = state;
  }

  late IO.Socket socket;

  factory SocketService() {
    return _instance;
  }
  SocketService._internal() {    
    // Use localhost for debug, production URL for release
    final serverUrl = DebugMode 
        ? 'http://localhost:3001' // Use your local server URL
        : 'https://scriblet-server.onrender.com';
    
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    // Listen to all relevant events
    socket.on('connect', (_) {
      debugPrint('[SOCKET_SERVICE] Connected: ${socket.id}');
    });

    socket.on('room-update', (data) {
      debugPrint('[SOCKET_SERVICE] room-update: $data');
      latestRoomId = data['roomId'] ?? latestRoomId;
      latestPlayers = data['players'] ?? [];
      latestHost = data['host'] ?? '';
      if (data['settings'] != null) {
        latestSettings = Map<String, dynamic>.from(data['settings']);
      }
      notifyListeners();
    });

    socket.on('room-created', (data) {
      debugPrint('[SOCKET_SERVICE] room-created: $data');
      latestRoomId = data['roomId'] ?? latestRoomId;
      latestPlayers = data['players'] ?? [];
      latestHost = data['host'] ?? '';
      if (data['settings'] != null) {
        latestSettings = Map<String, dynamic>.from(data['settings']);
      }
      notifyListeners();
    });

    void initializeSocket() {
      // Update room-joined handler
      socket.on('room-joined', (data) {
        debugPrint('[SOCKET_SERVICE] room-joined: $data');
        latestRoomId = data['roomId'] ?? latestRoomId;
        latestPlayers = data['players'] ?? [];
        latestHost = data['host'] ?? '';
        if (data['settings'] != null) {
          latestSettings = Map<String, dynamic>.from(data['settings']);
        }
        if (data['gameState'] != null) {
          _gameState = Map<String, dynamic>.from(data['gameState']);
          _rejoining = true;
        }
        notifyListeners();
      });
    }

    socket.on('disconnect', (_) {
      debugPrint('[SOCKET_SERVICE] Disconnected');
    });

    socket.on('error', (data) {
      debugPrint('[SOCKET_SERVICE] Error: $data');
    });

    socket.onAny((event, data) {
      if(data != null && data is Map<String, dynamic>) {
      debugPrint('[SOCKET_SERVICE] $event received Any: $data');


      // Log each property individually

      if (data['drawer'] != null) {
        debugPrint('[SOCKET_SERVICE] Setting drawer: ${data['drawer']}');
        latestDrawer = data['drawer'];
      }

      if (data['drawerId'] != null) {
        debugPrint('[SOCKET_SERVICE] Setting drawerId: ${data['drawerId']}');
        latestDrawerId = data['drawerId'];
      }

      if (data['wordChoices'] != null) {
        debugPrint(
          '[SOCKET_SERVICE] Setting wordChoices: ${data['wordChoices']}',
        );
        latestWordChoices = List<String>.from(data['wordChoices']);
      }
            if (data['hiddenWord'] != null) {
        latestHiddenWord = data['hiddenWord'];
      }
    

      if (data['word'] != null) {
        debugPrint('[SOCKET_SERVICE] Setting word: ${data['word']}');
        latestWord = data['word'];
      }
      if(data['chooseTime'] != null) {
      debugPrint('[SOCKET_SERVICE] Setting chooseTime: ${data['chooseTime']}');
      latestSettings['chooseTime'] = data['chooseTime'];
      }

      if(data['drawTime'] != null) {
      debugPrint('[SOCKET_SERVICE] Setting drawTime: ${data['drawTime']}');
      latestSettings['drawTime'] = data['drawTime'];
      }

      if (data['isChoosing'] != null) {
      debugPrint('[SOCKET_SERVICE] Setting isChoosing: ${data['isChoosing']}');
        latestIsChoosing = data['isChoosing'];
      }

      if (data['isPlaying'] != null) {
      debugPrint('[SOCKET_SERVICE] Setting isPlaying: ${data['isPlaying']}');
      latestIsPlaying = data['isPlaying'];
      }

      if (data['scores'] != null) {
        debugPrint('[SOCKET_SERVICE] Setting scores: ${data['scores']}');
        latestScores = Map<String, int>.from(data['scores']);
      }

      if (data['roundEnd'] != null) {
        debugPrint('[SOCKET_SERVICE] Setting roundEnd: ${data['roundEnd']}');
        latestRoundEnd = data['roundEnd'];
      }

      debugPrint('[SOCKET_SERVICE] Current state after update:');
      debugPrint('  - drawer: $latestDrawer');
      debugPrint('  - drawerId: $latestDrawerId');
      debugPrint('  - wordChoices: $latestWordChoices');
      debugPrint('  - word: $latestWord');
      debugPrint('  - isChoosing: $latestIsChoosing');
      debugPrint('  - isPlaying: $latestIsPlaying');

      notifyListeners();
      }
    });

    socket.on('game-end', (data) {
      debugPrint('[SOCKET_SERVICE] game-end: $data');
      if (data['scores'] != null){
        latestScores = Map<String, int>.from(data['scores']);
        }
      latestIsPlaying = false;
      latestIsChoosing = false;
      notifyListeners();
    });

    initializeSocket();

    socket.connect();
  }


}

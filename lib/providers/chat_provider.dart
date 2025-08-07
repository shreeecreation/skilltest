import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

// Chat Provider
class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State variables
  String? _currentUserName;
  bool _isRegistered = false;
  bool _isLoading = true;
  List<Message> _messages = [];
  List<String> _typingUsers = [];
  List<String> _activeUsers = [];
  Timer? _typingTimer;
  Timer? _presenceTimer;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _typingSubscription;
  StreamSubscription<QuerySnapshot>? _presenceSubscription;

  // Getters
  String? get currentUserName => _currentUserName;
  bool get isRegistered => _isRegistered;
  bool get isLoading => _isLoading;
  List<Message> get messages => _messages;
  List<String> get typingUsers => _typingUsers;
  List<String> get activeUsers => _activeUsers;

  // Initialize chat
  Future<void> initialize() async {
    await _loadUserName();
    _startListening();
  }

  // Load username from SharedPreferences
  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name');

      if (savedName != null && savedName.isNotEmpty) {
        _currentUserName = savedName;
        _isRegistered = true;
        await _updateUserPresence();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save username and join chat
  Future<void> joinChat(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);

      final isNewUser = _currentUserName == null;
      _currentUserName = name;
      _isRegistered = true;

      // Update user presence
      await _updateUserPresence();

      // Send join message for new users
      if (isNewUser) {
        await _sendJoinMessage(name);
      }

      // Start presence updates
      _startPresenceUpdates();

      notifyListeners();
    } catch (e) {
      print('Error joining chat: $e');
    }
  }

  // Change username
  Future<void> changeUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');

      // Remove old presence
      if (_currentUserName != null) {
        await _removeUserPresence();
      }

      _currentUserName = null;
      _isRegistered = false;
      _stopPresenceUpdates();

      notifyListeners();
    } catch (e) {
      print('Error changing username: $e');
    }
  }

  // Logout from chat
  Future<void> logout() async {
    try {
      // Send leave message
      if (_currentUserName != null) {
        await _sendLeaveMessage(_currentUserName!);
      }

      // Clean up
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');

      // Remove presence and typing indicators
      if (_currentUserName != null) {
        await _removeUserPresence();
        await _removeTypingIndicator();
      }

      // Reset state
      _currentUserName = null;
      _isRegistered = false;
      _messages.clear();
      _typingUsers.clear();
      _activeUsers.clear();

      // Stop all timers and streams
      _stopPresenceUpdates();
      _stopListening();

      notifyListeners();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Send message
  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty || _currentUserName == null) return false;

    try {
      final message = Message(
        id: '',
        text: text.trim(),
        senderName: _currentUserName!,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('messages').add(message.toFirestore());
      await _removeTypingIndicator();
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  // Send system join message
  Future<void> _sendJoinMessage(String userName) async {
    try {
      final joinMessage = Message.systemMessage(
        text: '$userName joined the chat',
        timestamp: DateTime.now(),
      );

      await _firestore.collection('messages').add(joinMessage.toFirestore());
    } catch (e) {
      print('Error sending join message: $e');
    }
  }

  // Send system leave message
  Future<void> _sendLeaveMessage(String userName) async {
    try {
      final leaveMessage = Message.systemMessage(
        text: '$userName left the chat',
        timestamp: DateTime.now(),
      );

      await _firestore.collection('messages').add(leaveMessage.toFirestore());
    } catch (e) {
      print('Error sending leave message: $e');
    }
  }

  // Update typing indicator
  void updateTypingIndicator() {
    if (_currentUserName == null) return;

    _typingTimer?.cancel();

    // Update typing indicator
    _firestore
        .collection('typing_indicators')
        .doc(_currentUserName)
        .set(
          TypingIndicator(
            userName: _currentUserName!,
            lastTyped: DateTime.now(),
          ).toFirestore(),
          SetOptions(merge: true),
        );

    // Remove after 3 seconds
    _typingTimer = Timer(Duration(seconds: 3), () {
      _removeTypingIndicator();
    });
  }

  // Remove typing indicator
  Future<void> _removeTypingIndicator() async {
    if (_currentUserName != null) {
      await _firestore
          .collection('typing_indicators')
          .doc(_currentUserName)
          .delete();
    }
  }

  // Update user presence
  Future<void> _updateUserPresence() async {
    if (_currentUserName == null) return;

    try {
      final now = DateTime.now();
      final presenceDoc = _firestore
          .collection('user_presence')
          .doc(_currentUserName);

      // Check if user exists
      final docSnapshot = await presenceDoc.get();

      if (docSnapshot.exists) {
        // Update existing presence
        await presenceDoc.update({
          'lastSeen': Timestamp.fromDate(now),
          'isActive': true,
        });
      } else {
        // Create new presence (new user)
        final presence = UserPresence(
          userName: _currentUserName!,
          joinedAt: now,
          lastSeen: now,
        );
        await presenceDoc.set(presence.toFirestore());
      }
    } catch (e) {
      print('Error updating presence: $e');
    }
  }

  // Remove user presence
  Future<void> _removeUserPresence() async {
    if (_currentUserName != null) {
      try {
        await _firestore
            .collection('user_presence')
            .doc(_currentUserName)
            .update({
              'isActive': false,
              'lastSeen': Timestamp.fromDate(DateTime.now()),
            });
      } catch (e) {
        print('Error removing presence: $e');
      }
    }
  }

  // Start presence updates (heartbeat)
  void _startPresenceUpdates() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateUserPresence();
    });
  }

  // Stop presence updates
  void _stopPresenceUpdates() {
    _presenceTimer?.cancel();
  }

  // Start listening to Firestore streams
  void _startListening() {
    // Listen to messages
    _messagesSubscription = _firestore
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
          _messages = snapshot.docs
              .map((doc) => Message.fromFirestore(doc))
              .toList();
          notifyListeners();
        });

    // Listen to typing indicators
    _typingSubscription = _firestore
        .collection('typing_indicators')
        .snapshots()
        .listen((snapshot) {
          final now = DateTime.now();
          final activeTypers = <String>[];

          for (var doc in snapshot.docs) {
            final typing = TypingIndicator.fromFirestore(doc.data());
            if (typing.userName != _currentUserName &&
                now.difference(typing.lastTyped).inSeconds < 3) {
              activeTypers.add(typing.userName);
            }
          }

          _typingUsers = activeTypers;
          notifyListeners();
        });

    // Listen to user presence
    _presenceSubscription = _firestore
        .collection('user_presence')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          final now = DateTime.now();
          final active = <String>[];

          for (var doc in snapshot.docs) {
            final presence = UserPresence.fromFirestore(doc.data());
            // Consider user active if seen within last 2 minutes
            if (now.difference(presence.lastSeen).inMinutes < 2) {
              active.add(presence.userName);
            }
          }

          _activeUsers = active;
          notifyListeners();
        });
  }

  // Stop listening to streams
  void _stopListening() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _presenceTimer?.cancel();
    _stopListening();
    _removeTypingIndicator();
    _removeUserPresence();
    super.dispose();
  }
}

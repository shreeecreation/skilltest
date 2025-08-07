// Models
import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderName;
  final DateTime timestamp;
  final MessageType type;

  Message({
    required this.id,
    required this.text,
    required this.senderName,
    required this.timestamp,
    this.type = MessageType.text,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderName: data['senderName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: MessageType.values.firstWhere(
        (type) => type.name == data['type'],
        orElse: () => MessageType.text,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderName': senderName,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
    };
  }

  // Factory for system messages (like user joined)
  factory Message.systemMessage({
    required String text,
    required DateTime timestamp,
  }) {
    return Message(
      id: '',
      text: text,
      senderName: 'System',
      timestamp: timestamp,
      type: MessageType.system,
    );
  }
}

enum MessageType { text, system }

class TypingIndicator {
  final String userName;
  final DateTime lastTyped;

  TypingIndicator({required this.userName, required this.lastTyped});

  factory TypingIndicator.fromFirestore(Map<String, dynamic> data) {
    return TypingIndicator(
      userName: data['userName'] ?? '',
      lastTyped: (data['lastTyped'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'userName': userName, 'lastTyped': Timestamp.fromDate(lastTyped)};
  }
}

class UserPresence {
  final String userName;
  final DateTime joinedAt;
  final DateTime lastSeen;
  final bool isActive;

  UserPresence({
    required this.userName,
    required this.joinedAt,
    required this.lastSeen,
    this.isActive = true,
  });

  factory UserPresence.fromFirestore(Map<String, dynamic> data) {
    return UserPresence(
      userName: data['userName'] ?? '',
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isActive': isActive,
    };
  }
}

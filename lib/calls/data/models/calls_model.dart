enum CallStatus { idle, calling, incoming, connected, ended }

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String receiverId;
  final CallStatus status;
  final DateTime createdAt;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'callId': callId,
    'callerId': callerId,
    'callerName': callerName,
    'callerAvatar': callerAvatar,
    'receiverId': receiverId,
    'status': status.name,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory CallModel.fromMap(Map<String, dynamic> map) => CallModel(
    callId: map['callId'],
    callerId: map['callerId'],
    callerName: map['callerName'] ?? 'Unknown',
    callerAvatar: map['callerAvatar'] ?? '',
    receiverId: map['receiverId'],
    status: CallStatus.values.byName(map['status'] ?? 'idle'),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
  );
}
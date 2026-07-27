import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/env.dart';
import '../storage/token_storage.dart';
import 'auth_event_bus.dart';
import 'socket_events.dart';

/// Payload of a `message_received` event.
@immutable
class IncomingMessage {
  const IncomingMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.createdAt,
    this.content,
    this.mediaUrl,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String type;
  final String? content;
  final String? mediaUrl;
  final DateTime createdAt;

  factory IncomingMessage.fromJson(Map<String, dynamic> json) => IncomingMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        receiverId: json['receiverId'] as String,
        type: (json['messageType'] as String?) ?? (json['type'] as String?) ?? 'text',
        content: json['content'] as String?,
        mediaUrl: json['mediaUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// A "user is typing" indicator.
@immutable
class TypingEvent {
  const TypingEvent({
    required this.conversationId,
    required this.userId,
    required this.typing,
  });
  final String conversationId;
  final String userId;
  final bool typing;
}

/// Realtime order status change payload.
@immutable
class OrderUpdate {
  const OrderUpdate({required this.orderId, required this.status, this.raw});
  final String orderId;
  final String status;
  final Map<String, dynamic>? raw;

  factory OrderUpdate.fromJson(Map<String, dynamic> json) => OrderUpdate(
        orderId: json['id'] as String,
        status: (json['status'] as String?) ?? 'unknown',
        raw: json,
      );
}

/// Server-pushed notification (transient — persisted copies come via REST).
@immutable
class RealtimeNotification {
  const RealtimeNotification({required this.type, this.entityId, this.raw});
  final String type;
  final String? entityId;
  final Map<String, dynamic>? raw;

  factory RealtimeNotification.fromJson(Map<String, dynamic> json) => RealtimeNotification(
        type: (json['type'] as String?) ?? 'system',
        entityId:
            (json['conversationId'] as String?) ?? (json['orderId'] as String?) ?? (json['entityId'] as String?),
        raw: json,
      );
}

// -----------------------------------------------------------------------------
// SocketClient
// -----------------------------------------------------------------------------

/// A thin, well-tested wrapper over `socket_io_client` that:
///
/// - Authenticates the connection with the JWT access token from [TokenStorage].
///   The token is read *at connect time* so it always reflects the latest
///   refresh — see `TokenRefreshInterceptor`.
///
/// - Emits every incoming payload as a Dart [Stream] so features can `.listen`
///   without knowing anything about socket.io internals.
///
/// - Reconnects with exponential backoff, but only up to a cap so a dead
///   backend doesn't spin the phone's battery.
///
/// - Listens for [AuthEvent.forceLogout] on the [AuthEventBus] and disconnects
///   immediately — no point holding a socket open with a dead session.
///
/// - Exposes a [SocketStatus] stream so the UI can render "Reconnecting..."
///   banners without polling.
class SocketClient {
  SocketClient({
    required TokenStorage storage,
    required AuthEventBus events,
    String? url,
  })  : _storage = storage,
        _events = events,
        _url = url ?? Env.socketUrl {
    _forceLogoutSub = _events.stream.listen((e) {
      if (e == AuthEvent.forceLogout) disconnect();
    });
  }

  final TokenStorage _storage;
  final AuthEventBus _events;
  final String _url;

  io.Socket? _socket;
  StreamSubscription<AuthEvent>? _forceLogoutSub;

  // Broadcast streams — anyone can listen, and the socket is unaware of them.
  final _status = StreamController<SocketStatus>.broadcast();
  final _messages = StreamController<IncomingMessage>.broadcast();
  final _messageReads = StreamController<MessageReadEvent>.broadcast();
  final _typing = StreamController<TypingEvent>.broadcast();
  final _orderUpdates = StreamController<OrderUpdate>.broadcast();
  final _notifications = StreamController<RealtimeNotification>.broadcast();

  Stream<SocketStatus> get status$ => _status.stream;
  Stream<IncomingMessage> get messages$ => _messages.stream;
  Stream<MessageReadEvent> get messageReads$ => _messageReads.stream;
  Stream<TypingEvent> get typing$ => _typing.stream;
  Stream<OrderUpdate> get orderUpdates$ => _orderUpdates.stream;
  Stream<RealtimeNotification> get notifications$ => _notifications.stream;

  SocketStatus _currentStatus = SocketStatus.disconnected;
  SocketStatus get currentStatus => _currentStatus;
  bool get isConnected => _currentStatus == SocketStatus.connected;

  // -------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------

  /// Idempotent: repeated calls with a live socket are no-ops.
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) {
      // Silent no-op when there's no session; caller can retry after login.
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] Socket connect skipped: no auth token');
      }
      return;
    }

    _updateStatus(SocketStatus.connecting);

    // Dispose any previous socket instance so we don't leak listeners.
    _socket?.dispose();

    final socket = io.io(
      _url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setReconnectionAttempts(10)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(10 * 1000)
          .setTimeout(15 * 1000)
          .build(),
    );

    _wireCoreEvents(socket);
    _wireDomainEvents(socket);

    _socket = socket;
    socket.connect();
  }

  Future<void> disconnect() async {
    final s = _socket;
    if (s == null) {
      _updateStatus(SocketStatus.disconnected);
      return;
    }
    s.disconnect();
    s.dispose();
    _socket = null;
    _updateStatus(SocketStatus.disconnected);
  }

  /// Force a full reconnect. Handy after a manual token refresh where you
  /// know the current token is stale.
  Future<void> reconnectWithFreshToken() async {
    await disconnect();
    await connect();
  }

  // -------------------------------------------------------------------
  // Emitters
  // -------------------------------------------------------------------

  void joinConversation(String conversationId) {
    _socket?.emit(SocketEvents.joinConversation, {'conversationId': conversationId});
  }

  void leaveConversation(String conversationId) {
    _socket?.emit(SocketEvents.leaveConversation, {'conversationId': conversationId});
  }

  void startTyping(String conversationId) {
    _socket?.emit(SocketEvents.typingStart, {'conversationId': conversationId});
  }

  void stopTyping(String conversationId) {
    _socket?.emit(SocketEvents.typingStop, {'conversationId': conversationId});
  }

  void markRead({required String conversationId, required List<String> messageIds}) {
    if (messageIds.isEmpty) return;
    _socket?.emit(SocketEvents.markRead, {
      'conversationId': conversationId,
      'messageIds': messageIds,
    });
  }

  void joinOrderRoom(String orderId) {
    _socket?.emit(SocketEvents.joinOrderRoom, {'orderId': orderId});
  }

  // -------------------------------------------------------------------
  // Wiring
  // -------------------------------------------------------------------

  void _wireCoreEvents(io.Socket s) {
    s.onConnect((_) {
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] Socket connected: ${s.id}');
      }
      _updateStatus(SocketStatus.connected);
    });
    s.onDisconnect((_) => _updateStatus(SocketStatus.disconnected));
    s.onReconnectAttempt((_) => _updateStatus(SocketStatus.reconnecting));
    s.onConnectError((err) {
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] Socket connect_error: $err');
      }
      // If the server rejects our token, no amount of reconnecting will help.
      // The REST layer will do the refresh dance on its next call; when it
      // succeeds and saves a new token, connect() can be called again.
      _updateStatus(SocketStatus.reconnecting);
    });
    s.onError((err) {
      if (Env.isDev) {
        // ignore: avoid_print
        print('[Rent95] Socket error: $err');
      }
    });
  }

  void _wireDomainEvents(io.Socket s) {
    s.on(SocketEvents.messageReceived, (data) {
      final map = _asMap(data);
      if (map == null) return;
      try {
        _messages.add(IncomingMessage.fromJson(map));
      } catch (e) {
        if (Env.isDev) {
          // ignore: avoid_print
          print('[Rent95] Bad message payload: $e ($map)');
        }
      }
    });

    s.on(SocketEvents.messageRead, (data) {
      final map = _asMap(data);
      if (map == null) return;
      final ids = (map['messageIds'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      _messageReads.add(MessageReadEvent(
        conversationId: map['conversationId']?.toString() ?? '',
        messageIds: ids,
      ));
    });

    s.on(SocketEvents.typingStarted, (data) {
      final map = _asMap(data);
      if (map == null) return;
      _typing.add(TypingEvent(
        conversationId: map['conversationId']?.toString() ?? '',
        userId: map['userId']?.toString() ?? '',
        typing: true,
      ));
    });

    s.on(SocketEvents.typingStopped, (data) {
      final map = _asMap(data);
      if (map == null) return;
      _typing.add(TypingEvent(
        conversationId: map['conversationId']?.toString() ?? '',
        userId: map['userId']?.toString() ?? '',
        typing: false,
      ));
    });

    void handleOrder(dynamic data) {
      final map = _asMap(data);
      if (map == null) return;
      try {
        _orderUpdates.add(OrderUpdate.fromJson(map));
      } catch (_) {}
    }

    s.on(SocketEvents.orderUpdated, handleOrder);
    s.on(SocketEvents.bookingRequestReceived, handleOrder);
    s.on(SocketEvents.paymentUpdated, handleOrder);

    s.on(SocketEvents.notificationReceived, (data) {
      final map = _asMap(data);
      if (map == null) return;
      try {
        _notifications.add(RealtimeNotification.fromJson(map));
      } catch (_) {}
    });
  }

  void _updateStatus(SocketStatus next) {
    if (_currentStatus == next) return;
    _currentStatus = next;
    if (!_status.isClosed) _status.add(next);
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }

  Future<void> dispose() async {
    await _forceLogoutSub?.cancel();
    await disconnect();
    await _status.close();
    await _messages.close();
    await _messageReads.close();
    await _typing.close();
    await _orderUpdates.close();
    await _notifications.close();
  }
}

@immutable
class MessageReadEvent {
  const MessageReadEvent({required this.conversationId, required this.messageIds});
  final String conversationId;
  final List<String> messageIds;
}

// -----------------------------------------------------------------------------
// Riverpod
// -----------------------------------------------------------------------------

/// Global socket client. Kept alive for the whole app so we don't churn the
/// TCP connection every time a screen mounts.
final socketClientProvider = Provider<SocketClient>((ref) {
  final client = SocketClient(
    storage: ref.watch(tokenStorageProvider),
    events: ref.watch(authEventBusProvider),
  );
  ref.onDispose(() {
    // Fire-and-forget async dispose — Riverpod's onDispose is sync.
    unawaited(client.dispose());
  });
  return client;
});

/// Live connection status. Screens can `ref.watch` this to show a small
/// "Reconnecting..." banner when the socket drops.
final socketStatusProvider = StreamProvider<SocketStatus>((ref) async* {
  final client = ref.watch(socketClientProvider);
  yield client.currentStatus;
  yield* client.status$;
});

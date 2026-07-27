/// Typed event names shared with the backend.
///
/// The strings here MUST match `rent95-api/src/sockets/index.ts`. Keeping
/// them in a single class instead of scattered string literals means the
/// compiler catches typos and refactors are one file long.
class SocketEvents {
  const SocketEvents._();

  // -------- Client → Server --------
  static const String joinConversation = 'join_conversation';
  static const String leaveConversation = 'leave_conversation';
  static const String typingStart = 'typing_start';
  static const String typingStop = 'typing_stop';
  static const String markRead = 'mark_read';
  static const String joinOrderRoom = 'join_order_room';

  // -------- Server → Client --------
  static const String messageReceived = 'message_received';
  static const String messageRead = 'message_read';
  static const String typingStarted = 'typing_started';
  static const String typingStopped = 'typing_stopped';
  static const String orderUpdated = 'order_updated';
  static const String bookingRequestReceived = 'booking_request_received';
  static const String paymentUpdated = 'payment_updated';
  static const String notificationReceived = 'notification_received';
}

/// Discrete states the socket can be in from the app's perspective.
///
/// Note this is *not* a 1:1 mapping to `socket.io_client`'s internal state —
/// we collapse a few states so the UI can render a simple banner if we want.
enum SocketStatus {
  /// Not connected, and no attempt in progress. Either logged out, or never connected.
  disconnected,

  /// Trying to open the socket (initial or reconnect).
  connecting,

  /// Connected and authenticated. Realtime events flowing.
  connected,

  /// Was connected but the transport dropped; a reconnect will fire automatically.
  reconnecting,
}

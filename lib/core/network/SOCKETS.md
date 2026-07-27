# Rent95 realtime layer

Socket.io client wired to the same session as REST — the JWT access token
stored in `TokenStorage` is used to authenticate the WebSocket handshake.

## What's wired

- **`SocketClient`** — thin wrapper around `socket_io_client` that:
  - Reads the access token from `TokenStorage` at connect time
  - Reconnects with exponential backoff (up to 10 attempts, 500 ms → 10 s)
  - Exposes typed broadcast streams: `messages$`, `messageReads$`, `typing$`,
    `orderUpdates$`, `notifications$`, `status$`
  - Auto-disconnects when `AuthEventBus` fires `forceLogout`

- **`SocketLifecycleController`** — Riverpod side-effect controller that
  watches `authControllerProvider` and:
  - Connects when the user logs in
  - Disconnects when the user logs out
  - Reconnects with the fresh token when the account changes

- **Instantiated once in `main.dart`** via a tiny `_AppBootstrap` widget so it
  starts observing auth state before any screen mounts.

## Event contract

Constants live in `lib/core/network/socket_events.dart` and mirror
`rent95-api/src/sockets/index.ts` exactly. A test asserts every wire string
matches, so accidental renames on either side surface as a failed test rather
than silent no-ops in production.

## Consuming events

### Listen to new messages in a conversation

`MessagesController` (in `features/chat/presentation/chat_screens.dart`) does
this already. Pattern:

```dart
final client = ref.read(socketClientProvider);
client.joinConversation(conversationId);
final sub = client.messages$
    .where((m) => m.conversationId == conversationId)
    .listen(_append);
```

Optimistic sends: append a temp message with `id: 'temp_…'`, POST via REST,
then let either the REST response **or** the socket echo reconcile it (whoever
returns first wins — the other side is a no-op thanks to id de-dup).

### Show a live connection banner

```dart
final status = ref.watch(socketStatusProvider).valueOrNull;
// SocketStatus.connected / connecting / reconnecting / disconnected
```

Used inside the chat detail app-bar to show "Online / Reconnecting… / Offline"
under the seller's name.

### Auto-refresh a list when something changes

The notifications inbox uses this pattern:

```dart
final _bridge = Provider.autoDispose<void>((ref) {
  final client = ref.watch(socketClientProvider);
  final sub = client.notifications$.listen((_) {
    ref.invalidate(_notificationsProvider);
  });
  ref.onDispose(sub.cancel);
});

// In the screen:
ref.watch(_bridge);
```

The chat list uses the same pattern with `client.messages$`.

## Order rooms

For a live order-detail screen, join the room in `initState`:

```dart
ref.read(socketClientProvider).joinOrderRoom(order.id);
// then listen to client.orderUpdates$.where((u) => u.orderId == order.id)
```

## Testing

- `test/socket_payloads_test.dart` covers the JSON parsers and asserts the
  event-name contract byte-for-byte with the backend.
- End-to-end socket testing needs a live server; do that in `rent95-api`'s
  integration tests, not here.

## Notes

- The client requests `websocket` transport only — no long-polling fallback.
  If a corporate network blocks that we can add `['websocket', 'polling']`.
- Reconnects use socket.io's built-in reconnection logic; our
  `SocketStatus.reconnecting` reflects that state to the UI.
- The socket is *not* opened until the user is authenticated **and** the
  bootstrap check has finished, so we never try to connect with a stale token
  fished out of secure storage on cold start.

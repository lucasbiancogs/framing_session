# Broadcast

## Overview

Broadcast sends fire-and-forget messages to all subscribers on a channel. It's designed for **high-frequency, loss-tolerant updates** like cursor positions.

## Key Characteristics

| Characteristic | Description |
|----------------|-------------|
| **No persistence** | Messages are not stored anywhere |
| **No delivery guarantee** | Offline clients miss messages |
| **No acknowledgment** | Fire and forget |
| **High frequency safe** | No database load (unlike CDC) |

## When to Use Broadcast

| Use Case | Why Broadcast |
|----------|---------------|
| Cursor positions | 30-60 updates/sec, missing one is fine |
| Drawing in progress | Transient visual feedback |
| Typing indicators | Ephemeral, no persistence needed |
| Live annotations | Temporary overlays |

## When NOT to Use Broadcast

| Use Case | Why Not | Use Instead |
|----------|---------|-------------|
| Shape data | Must persist after refresh | Database CDC |
| User list | Need sync on join | Presence |
| Chat messages | Must persist | Database |
| Critical updates | Need delivery guarantee | Database CDC |

## Implementation Pattern

### Service Layer

Broadcast is implemented in `CanvasServices`:

```dart
// lib/domain/services/canvas_services.dart

abstract class CanvasServices {
  /// Send a cursor position broadcast.
  Future<Either<BaseException, void>> sendCursorPosition(
    String sessionId,
    CursorPosition cursor,
  );

  /// Subscribe to cursor position broadcasts.
  Future<Either<BaseException, Stream<CursorPosition>>> subscribeToCursors(
    String sessionId,
  );

  /// Unsubscribe from cursor broadcasts.
  Future<Either<BaseException, void>> unsubscribeFromCursors(
    String sessionId,
  );
}
```

### Sending a Broadcast

```dart
final canvasServices = ref.read(canvasServicesProvider);

final cursor = CursorPosition(
  userId: myUserId,
  x: cursorX,
  y: cursorY,
  timestamp: DateTime.now().millisecondsSinceEpoch,
);

final result = await canvasServices.sendCursorPosition(sessionId, cursor);

result.fold(
  (error) => print('Failed to send: ${error.message}'),
  (_) => print('Sent successfully'),
);
```

### Receiving Broadcasts

```dart
final result = await canvasServices.subscribeToCursors(sessionId);

result.fold(
  (error) => print('Failed to subscribe: ${error.message}'),
  (stream) {
    stream.listen((cursor) {
      // Update cursor position for this user
      updateUserCursor(cursor.userId, cursor.x, cursor.y);
    });
  },
);
```

### Payload Design

Keep payloads **small** — they're sent frequently:

```dart
// CursorPosition entity
class CursorPosition {
  final String userId;      // 'user_id' in JSON
  final double x;           // 'x' in JSON
  final double y;           // 'y' in JSON
  final int timestamp;       // 't' in JSON (milliseconds)
}

// JSON payload (minimal)
{
  "user_id": "abc-123",
  "x": 450.5,
  "y": 320.0,
  "t": 1705312200000
}
```

### Handling Dropped Messages

Broadcast messages can be lost. Handle stale messages:

```dart
// In CanvasServices implementation
channel.onBroadcast(
  event: 'cursor',
  callback: (payload) {
    final cursor = CursorPosition.fromJson(payload);
    
    // Check for stale messages (older than 5 seconds)
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - cursor.timestamp > 5000) {
      // Message is too old, ignore it
      return;
    }
    
    // Process valid cursor position
    controller.add(cursor);
  },
);
```

### Throttling Sends

Don't send on every mouse move. Throttle to ~60fps (16ms):

```dart
Timer? _throttleTimer;

void onCursorMove(double x, double y) {
  _throttleTimer?.cancel();
  
  _throttleTimer = Timer(const Duration(milliseconds: 16), () {
    final cursor = CursorPosition(
      userId: myUserId,
      x: x,
      y: y,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    canvasServices.sendCursorPosition(sessionId, cursor);
  });
}
```

## Channel Management

### Channel Naming

Use consistent channel naming:

```dart
// Pattern: 'session:{sessionId}'
static String _broadcastChannel(String sessionId) => 'session:$sessionId';
```

### Subscription Lifecycle

1. **Subscribe** when joining a session
2. **Unsubscribe** when leaving a session
3. **Clean up** stream controllers on dispose

```dart
// Subscribe
final result = await canvasServices.subscribeToCursors(sessionId);

// Later, when leaving
await canvasServices.unsubscribeFromCursors(sessionId);
```

## Reconnection Behavior

When a client reconnects:

1. **No sync** — missed messages are gone
2. **Resubscribe** — channel reconnects automatically
3. **New messages** — only receive messages after reconnection

This is why Broadcast is **loss-tolerant** — late joiners don't get historical data.

## Example: Cursor Broadcasting

### Complete Flow

```dart
// 1. Subscribe to receive cursor updates
final subscribeResult = await canvasServices.subscribeToCursors(sessionId);

subscribeResult.fold(
  (error) => handleError(error),
  (stream) {
    stream.listen((cursor) {
      // Render cursor for other users
      if (cursor.userId != myUserId) {
        renderRemoteCursor(cursor);
      }
    });
  },
);

// 2. Send cursor position on mouse move (throttled)
void onPointerMove(PointerMoveEvent event) {
  _throttleTimer?.cancel();
  
  _throttleTimer = Timer(const Duration(milliseconds: 16), () {
    final cursor = CursorPosition(
      userId: myUserId,
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    
    canvasServices.sendCursorPosition(sessionId, cursor);
  });
}

// 3. Clean up on dispose
@override
void dispose() {
  canvasServices.unsubscribeFromCursors(sessionId);
  _throttleTimer?.cancel();
  super.dispose();
}
```

## Best Practices

1. **Keep payloads small** — use short keys (`'t'` not `'timestamp'`)
2. **Throttle sends** — 60fps max (16ms intervals)
3. **Handle stale messages** — ignore messages older than 5 seconds
4. **Filter own messages** — don't render your own cursor from broadcast
5. **Clean up subscriptions** — unsubscribe when leaving session
6. **Use timestamps** — include timestamp for stale detection

## Architecture Notes

- **Service Layer**: `CanvasServices` handles all Broadcast operations
- **Entity**: `CursorPosition` is a simple data class (not a DTO, no persistence)
- **Channel**: Shared channel with Presence (`session:{sessionId}`)
- **Error Handling**: Uses `Either<BaseException, T>` pattern

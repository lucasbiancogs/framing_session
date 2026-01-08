# Presence

## Overview

Presence tracks which users are currently connected to a channel. It's designed for answering **"Who's here right now?"** — not for persistent data.

## Key Characteristics

| Characteristic | Description |
|----------------|-------------|
| **Ephemeral** | State exists only while users are connected |
| **Automatic cleanup** | User presence removed on disconnect (or crash) |
| **Sync on join** | New subscribers immediately receive full current state |
| **Small payloads** | Keep < 1KB per user (syncs to everyone) |

## When to Use Presence

| Use Case | Why Presence |
|----------|--------------|
| Show online users | Auto-cleanup, sync on join |
| Display user colors | Tied to connection lifetime |
| Show "X is typing..." | Ephemeral indicator |
| User avatars/names | Don't need persistence |

## When NOT to Use Presence

| Use Case | Why Not | Use Instead |
|----------|---------|-------------|
| Cursor position | Too frequent (30-60 updates/sec) | Broadcast |
| Shape data | Must survive refresh | Database CDC |
| Chat history | Must persist | Database |
| Large payloads | Syncs to all users | Database |

## Presence Events

### onPresenceSync

Fires when you first connect. Contains the **full current state** of all connected users.

```dart
channel.onPresenceSync((payload) {
  // Get full state
  final presences = channel.presenceState();
  
  // presences is Map<String, List<Presence>>
  // Each key is a presence reference
  // Each value is a list of Presence objects
});
```

### onPresenceJoin

Fires when a **new user** connects to the channel.

```dart
channel.onPresenceJoin((payload) {
  final newPresences = payload.newPresences;
  
  for (final presence in newPresences) {
    final userData = presence.payload;
    print('User joined: ${userData['name']}');
  }
});
```

### onPresenceLeave

Fires when a user **disconnects** from the channel.

```dart
channel.onPresenceLeave((payload) {
  final leftPresences = payload.leftPresences;
  
  for (final presence in leftPresences) {
    final userData = presence.payload;
    print('User left: ${userData['name']}');
  }
});
```

## Tracking Your Presence

After subscribing to a channel, call `track()` to announce your presence:

```dart
final channel = supabase.channel('session:$sessionId');

await channel.subscribe((status, error) async {
  if (status == RealtimeSubscribeStatus.subscribed) {
    // Now tracking
    await channel.track({
      'user_id': myUserId,
      'name': 'Alice',
      'color': '#FF5733',
      'online_at': DateTime.now().toIso8601String(),
    });
  }
});
```

## Untracking

Remove your presence when leaving:

```dart
// Remove presence
await channel.untrack();

// Unsubscribe from channel
await channel.unsubscribe();
```

## Payload Structure

### Recommended Payload

```dart
{
  'user_id': 'abc-123',           // Required: unique identifier
  'name': 'Alice',                 // Required: display name
  'color': '#FF5733',              // Required: user color (cursor, avatar)
  'online_at': '2024-01-15...',    // Optional: connection timestamp
}
```

### Presence State Shape

`channel.presenceState()` returns:

```dart
{
  'presence_ref_1': [
    Presence(
      presenceRef: 'presence_ref_1',
      payload: {
        'user_id': 'abc',
        'name': 'Alice',
        'color': '#FF5733',
        'online_at': '2024-01-15T10:30:00Z'
      }
    )
  ],
  'presence_ref_2': [
    Presence(
      presenceRef: 'presence_ref_2', 
      payload: {
        'user_id': 'xyz',
        'name': 'Bob',
        'color': '#33FF57',
        'online_at': '2024-01-15T10:31:00Z'
      }
    )
  ]
}
```

## Reconnection Behavior

When a client reconnects:

1. **Sync event fires** with current state (no missed data)
2. Client can call `track()` again to re-announce presence
3. Other clients see **leave then join** events

This is why presence is safe for "who's online" — late joiners always get current state.

## Common Patterns

### Parse Presence State

```dart
List<OnlineUser> parsePresenceState(Map<String, List<Presence>> state) {
  final users = <OnlineUser>[];
  
  for (final presences in state.values) {
    for (final presence in presences) {
      final payload = presence.payload;
      users.add(OnlineUser(
        id: payload['user_id'] as String,
        name: payload['name'] as String,
        color: payload['color'] as String,
      ));
    }
  }
  
  return users;
}
```

### Generate Anonymous Identity

```dart
import 'dart:math';
import 'package:uuid/uuid.dart';

class AnonymousUser {
  static String generateId() => const Uuid().v4();
  
  static String generateName() {
    const adjectives = ['Happy', 'Swift', 'Clever', 'Brave', 'Calm'];
    const nouns = ['Panda', 'Eagle', 'Tiger', 'Wolf', 'Fox'];
    final random = Random();
    return '${adjectives[random.nextInt(adjectives.length)]} '
           '${nouns[random.nextInt(nouns.length)]}';
  }
  
  static String generateColor() {
    const colors = ['#FF5733', '#33FF57', '#5733FF', '#FF33F5', '#33FFF5', 
                    '#F5FF33', '#33B5FF', '#FF3366', '#66FF33', '#9933FF'];
    return colors[Random().nextInt(colors.length)];
  }
}
```

## Whiteboard Use Cases

| Feature | How Presence Helps |
|---------|-------------------|
| Online users list | Show avatars with names/colors |
| "X is editing shape Y" | Track `editing_shape_id` in payload |
| Reconnection | User reappears automatically |
| User left | Remove their cursor, clear their lock |

## Anti-patterns

### ❌ Don't Track Cursor Position

```dart
// BAD - too frequent, use Broadcast instead
await channel.track({
  'user_id': myId,
  'cursor_x': 150.5,  // NO!
  'cursor_y': 200.3,  // NO!
});
```

### ❌ Don't Track Large Data

```dart
// BAD - syncs to everyone on join
await channel.track({
  'user_id': myId,
  'selected_shapes': [...100 shapes...],  // NO!
});
```

### ❌ Don't Rely on Presence Order

```dart
// BAD - presence order is not guaranteed
final firstUser = presenceState.values.first;  // Don't assume order
```

## Related Documentation

- [Broadcast](./broadcast.md) — For cursor movement, drawing in progress
- [Database CDC](../notes/concepts.md) — For persistent shape data

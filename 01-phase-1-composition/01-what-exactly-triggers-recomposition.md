# What exactly triggers recomposition?

## Understanding recomposition

Before we dive into the technical machinery behind Compose, we must align on
what recomposition really is.

> Recomposition is not a redraw.  
> Recomposition is not a rerun of your whole UI.  
> Recomposition is a selective, intelligent reinvocation of `@Composable`
functions, driven by observable state.

Imagine your UI as a live formula: `UI = f(state)`. This is the fundamental
shift Compose brings to UI development. You don't update the UI manually.
Instead, you describe what the UI *should look like* based on the current
state, and Compose takes care of the rest. This means every time your state
changes, Compose revisits the functions that rely on that state and
recomposes them.

But here's what makes it magical and efficient: **Compose doesn't recompose
everything**. It reuses, skips, preserves, and orchestrates updates through
internal structures and compiler support.

Think of recomposition as a play. Your UI is the performance, and each
composable is an actor. If one actor forgets their lines (state changes),
the director (Compose) doesn't reshoot the whole scene, only that actor
rehearses again.

In this chapter, we're not just going to define what triggers recomposition.
We'll also set the foundation to reason about recomposition as an internal
process that relies on memory tracking, observability, and the identity of
your functions in time and space.

## Observable state

Recomposition doesn't happen in a vacuum, it's a precise response to a change
in something Compose is **watching**. That "something" is the *observable state*.

Compose is built on a reactive data flow system. Instead of you telling the
UI what to do when something changes, Compose tracks the data you read inside
composables, and updates the UI *for you* when that data changes.

So how does Compose know what to watch?

The answer: whenever you **read from a state object inside a composable**,
Compose records that read. That read becomes a tracked dependency. Later,
when the state value changes, Compose knows *exactly* which composable
function depends on it and schedules that function for recomposition.

This is the cornerstone of Compose's reactivity model.

For example:

```kotlin
@Composable
fun CounterDisplay() {
    val counter = remember { mutableStateOf(0) }
    Text("Counter is ${counter.value}")
}
```

Here, `counter.value` is read inside a composable. Compose tracks this read,
and any change to `counter.value` later will recompose `CounterDisplay()`.

### Key APIs that enable observability

While Compose appears to support reactive updates from a variety of sources,
under the hood, it only tracks a specific class of observable state: types
that implement the `State<T>` interface. This includes all constructs backed
by the Snapshot system, such as `mutableStateOf`, `derivedStateOf`, and the
specialized observable collections like `SnapshotStateList` and
`SnapshotStateMap`.

These types are explicitly designed for Compose. They work by integrating
with the runtime's snapshot mechanism, which tracks state reads during
composition and records them as dependencies. When the corresponding
state changes, Compose knows exactly which parts of the composition
tree were reading that state, and schedules them for recomposition.

> ⚠️ It's important to note that Compose does not track arbitrary
> properties, flows, or LiveData. Only `State<T>` values integrated into
> the snapshot system are automatically observed.

For other reactive types, you must convert them into `State<T>` using
APIs like `collectAsState()` or `rememberUpdatedState()` in order
to trigger recomposition.

Here's an example with a Flow:

```kotlin
@Composable
fun MessageCount(messages: Flow<Int>) {
    val count by messages.collectAsState(initial = 0)
    Text("Messages: $count")
}
```

In this case, Compose doesn't observe the flow directly. The
`collectAsState()` function bridges the flow into Compose's
runtime by exposing it as `State<Int>`.

This distinction is key for avoiding surprising bugs. If you read
from a property that isn't observable via `State<T>`, Compose
won't recompose when it changes.

So, whenever you want your UI to react to data changes:

- Use `State<T>` or snapshot-backed types.
- Convert other reactive types into `State<T>`.
- Ensure reads happen during the composition phase.

The combination of the snapshot system and `State<T>` is what makes
Compose's reactivity both efficient and predictable.

### A crucial rule

**Only reads from observable state during the composition phase are
tracked for recomposition.**

This rule is fundamental to understanding how Compose knows which parts
of your UI to update. It's not enough to simply use `State<T>` or
snapshot-backed types. You also have to read them in the correct phase.

Let's clarify the distinction:

When you read a state value inside the body of a `@Composable` function
or inside a `remember {}` block, Compose intercepts that read and marks
it as a dependency of the current group. If the state changes later,
Compose uses that dependency to schedule the group for recomposition.

However, if you read the same state inside side-effect handlers like
`LaunchedEffect`, `SideEffect`, or inside modifier lambdas
(`Modifier.layout`, `Modifier.drawBehind`, etc.), those reads are not
tracked for recomposition. They happen outside the composition phase,
and Compose won't recompose the function when the value changes.

These trigger recomposition:

```kotlin
@Composable
fun Example() {
    val count = remember { mutableStateOf(0) }
    Text("Count: ${count.value}") // ✅ Read tracked
}
```

These do not trigger recomposition:

```kotlin
@Composable
fun Example() {
    val count = remember { mutableStateOf(0) }

    LaunchedEffect(Unit) {
        println("Counter = ${count.value}") // 🚫 Not tracked
    }
}
```

This model is what allows Compose to build a dependency graph during
composition and only recompose when the right things change—no more,
no less.

## Snapshots: Compose's secret weapon

Behind all this observability lies the Snapshot system, the mechanism that
makes Compose's fine-grained reactivity possible. When you use
`mutableStateOf`, `derivedStateOf`, or any observable collection
like `SnapshotStateList`, you’re relying on this system.

A snapshot is an isolated, thread-safe environment where state reads and
writes are tracked. During composition, Compose activates a read-tracking
snapshot. Every time you read from a state object (such as `counter.value`),
that read is registered as a dependency of the current group. When you write
to a state, Compose doesn't immediately apply the change. Instead, it creates
a change set. Once the snapshot is committed, Compose knows which reads were
affected and schedules the appropriate recompositions.

This system gives Compose its three defining characteristics:

- **Automatic** — You don’t manually subscribe or unsubscribe from state.
- **Efficient** — Only composables that read the changed state are recomposed.
- **Thread-safe** — Multiple snapshots can exist independently on different
threads.

The snapshot system is Compose's alternative to listeners, observers, and
lifecycle-coupled reactivity. Instead of wiring up callbacks, you just declare
what depends on what and Compose figures out when and how to recompose it.

For those interested in digging deeper, the snapshot system is more than just
an implementation detail, it's a rich, standalone framework that powers
Compose's reactive model.

If you want a thorough technical deep dive,
[Zach Klippenstein](https://blog.zachklipp.com/)
one of the engineers who contributed directly
to this system has written an excellent, detailed article:
[Introduction to the Compose Snapshot System](
https://blog.zachklipp.com/introduction-to-the-compose-snapshot-system/).
This article explains the principles, the runtime behavior, and the safety
guarantees that snapshots provide.

## Parameter changes and equality checks

Not all recomposition is caused by state. Sometimes, you cause recomposition
just by changing the arguments to a composable.

Compose compares new parameter values to previous ones using `==`
(structural equality) or `===` (reference equality). If a parameter
is different, the function is recomposed.

Stable parameters (e.g. primitives, `@Immutable` data classes) don't trigger
recomposition unless they truly change. But unstable ones like lambdas or
inline modifiers can cause frequent, unnecessary recompositions.

```kotlin
@Composable
fun UserProfile(user: User) {
    UserCard(user = user, onClick = { println("Clicked") })
}
```

This creates a new `onClick` lambda every time, causing `UserCard` to
recompose even if `user` didn't change.

This is a fix:

```kotlin
val onClick = remember { { println("Clicked") } }
UserCard(user = user, onClick = onClick)
```

## Manual recomposition with RecomposeScope

Sometimes you need to force recomposition even without state change.
Compose exposes `currentRecomposeScope()` to let you trigger recomposition
manually.

```kotlin
val scope = currentRecomposeScope()
Button(onClick = { scope.invalidate() }) {
    Text("Force Recomposition")
}
```

This is rarely needed, but useful for custom layouts, dev tools, or advanced
debugging.

## Keying: Identity changes trigger recomposition

Compose relies heavily on structural position to associate each composable
invocation with a corresponding entry in the slot table. This means that by
default, Compose assumes the identity of a composable is determined by where
it appears in the composition tree, not what it is or what parameters it
receives.

This model works beautifully for static UIs where nothing changes position.
But as soon as your UI becomes dynamic—driven by conditionals, reordering,
or list updates position alone is not enough. The same logical component
may appear at a different position during the next recomposition, and if
Compose can't match it with the previous group, it assumes it's a different
entity. The result? Recomposition happens from scratch, remembered state
is lost, and animations may reset.

To handle this, Compose provides the key() function.

```kotlin
if (isAdmin) {
    key("admin") {
        Greeting("Admin")
    }
}
key("user") {
    Greeting("User")
}
```

In this example, without `key("admin")`, the position of `Greeting("User")`
could shift depending on the `isAdmin` flag. That shift would cause Compose
to treat it as a different group entirely. By wrapping each composable with
a stable key, you tell Compose, "Even if this changes position, it's
still the same thing."

#### Keying in lazy lists

The most common and critical place to use keys is inside `LazyColumn`,
`LazyRow`, or `LazyVerticalGrid`. These layouts recycle their slot table
entries as you scroll, and incorrect identity here can lead to jarring
UI resets.

Compare this:

```kotlin
LazyColumn {
    items(users) { user ->
        UserCard(user)
    }
}
```

To this:

```kotlin
LazyColumn {
    items(users, key = { it.id }) { user ->
        UserCard(user)
    }
}
```

In the first version, Compose uses the index as the default key. If the user
removes the first item, all items shift, and their identities no longer match.
Compose will discard the slot table entries and recreate them.

In the second version, `user.id` acts as a stable identity. Even if the list
order changes, Compose can locate the correct group in the slot table and reuse
its remembered state, animations, and composition data.

#### What happens without keys?

If you omit keys in dynamic structures:

- `remember` values may reset
- Input state (text fields, selection) can be lost
- Animations may restart unexpectedly
- Performance can degrade due to unnecessary recomposition

#### What compose does with keys

Internally, when you provide a key, Compose associates that group with your
supplied value in addition to its position. During recomposition, if the same
key is found even in a different position, it restores the correct slot table
entry. This results in consistent state, lower recomposition cost, and better
user experience.

#### Best practices

- Always use stable keys in lists (e.g., unique IDs from your model).
- Use `key()` in conditional blocks that add or remove composables.
- Avoid using non-deterministic values as keys (e.g., random IDs, hashcodes).

Correct keying is not just a performance concern, it’s essential for
correctness. If identity is not preserved, Compose can't do its job
efficiently.

Think of keys as the glue that holds your state and structure together
when the UI moves and adapts.

## Summary: What exactly triggers recomposition?

Recomposition happens when:

- You read observable state (tracked by snapshots)
- A parameter value changes
- You call `invalidate()` manually
- A composable's identity shifts (and isn't keyed)

Understanding these core triggers allows you to:

- Predict recomposition behavior
- Avoid wasteful work
- Preserve user state
- Build smoother, faster UIs

## What's Next?

Next, we'll explore **what happens during recomposition**, including how the
Slot Table stores your UI, how Compose determines what to reuse or skip, and
how group lifecycle impacts performance.

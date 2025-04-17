# What Exactly Triggers Recomposition?

## Understanding Recomposition

Before we dive into the technical machinery behind Compose, we must align on
what recomposition really is—not just mechanically, but conceptually.

> Recomposition is not a redraw.  
> Recomposition is not a rerun of your whole UI.  
> Recomposition is a selective, intelligent reinvocation of `@Composable`
functions, driven by observable state.

Imagine your UI as a live formula: `UI = f(state)`. This is the fundamental
shift Compose brings to UI development. You don’t update the UI manually.
Instead, you describe what the UI *should look like* based on the current
state, and Compose takes care of the rest. This means every time your state
changes, Compose revisits the functions that rely on that state and recomposes them.

But here’s what makes it magical—and efficient: **Compose doesn’t recompose
everything**. It reuses, skips, preserves, and orchestrates updates through
internal structures and compiler support.

Think of recomposition as a play. Your UI is the performance, and each
composable is an actor. If one actor forgets their lines (state changes),
the director (Compose) doesn't reshoot the whole scene—only that actor
rehearses again.

In this chapter, we’re not just going to define what triggers recomposition.
We’ll also set the foundation to reason about recomposition as an internal
process that relies on memory tracking, observability, and the identity of
your functions in time and space.

## Observable State: The Core Trigger

Recomposition doesn’t happen in a vacuum—it’s a precise response to a change
in something Compose is **watching**. That “something” is *observable state*.

Compose is built on a reactive data flow system. Instead of you telling the
UI what to do when something changes, Compose tracks the data you read inside
composables, and updates the UI *for you* when that data changes.

So how does Compose know what to watch?

The answer: whenever you **read from a state object inside a composable**,
Compose records that read. That read becomes a tracked dependency. Later,
when the state value changes, Compose knows *exactly* which composable
function depends on it and schedules that function for recomposition.

This is the cornerstone of Compose's reactivity model.

### Example

```kotlin
@Composable
fun CounterDisplay() {
    val counter = remember { mutableStateOf(0) }
    Text("Counter is ${counter.value}")
}
```

Here, `counter.value` is read inside a composable. Compose tracks this read,
and any change to `counter.value` later will recompose `CounterDisplay()`.

### Key APIs That Enable Observability

Compose observes these state types by default:

- `mutableStateOf()`
- `derivedStateOf()`
- `SnapshotStateList`, `SnapshotStateMap`

They’re all backed by Compose’s internal **snapshot system**.

### A Crucial Rule

**Only reads during composition are tracked.**

Tracked:

- Inside a `@Composable` body
- Inside `remember {}`

Not tracked:

- Inside `LaunchedEffect`, `SideEffect`
- Inside layout or draw modifiers

## Snapshots: Compose’s Secret Weapon

Behind all this observability lies the **Snapshot system**. Snapshots are
Compose’s way of tracking state changes and read dependencies safely and
efficiently.

Every time you read observable state, Compose registers the read in a
snapshot. When you write to state, it creates a change set. Once changes
are committed, Compose uses the recorded dependencies to trigger recompositions.

This system is:

- **Automatic** (you don’t manage observers)
- **Efficient** (only affected composables are recomposed)
- **Thread-safe** (mutable state changes happen in isolated snapshots)

It’s one of the quiet strengths of Compose, allowing reactivity without manual
wiring.

## Parameter Changes and Equality Checks

Not all recomposition is caused by state. Sometimes, you cause recomposition
just by changing the arguments to a composable.

Compose compares new parameter values to previous ones using `==`
(structural equality) or `===` (reference equality). If a parameter
is different, the function is recomposed.

Stable parameters (e.g. primitives, `@Immutable` data classes) don’t trigger
recomposition unless they truly change. But unstable ones—like lambdas or
inline modifiers—can cause frequent, unnecessary recompositions.

### Example

```kotlin
@Composable
fun UserProfile(user: User) {
    UserCard(user = user, onClick = { println("Clicked") })
}
```

This creates a new `onClick` lambda every time, causing `UserCard` to
recompose even if `user` didn’t change.

This is a fix:

```kotlin
val onClick = remember { { println("Clicked") } }
UserCard(user = user, onClick = onClick)
```

## Manual Recomposition with RecomposeScope

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

## Keying: Identity Changes Trigger Recomposition

Compose tracks composables by their **position** in the composition tree—not
by function name.

This works well until structure changes dynamically, like in conditionals or
lists.

To avoid losing state or triggering recomposition due to shifts in position,
use `key()` to provide stable identity:

```kotlin
if (isAdmin) {
    key("admin") { Greeting("Admin") }
}
key("user") { Greeting("User") }
```

In `LazyColumn`, always provide a `key`:

```kotlin
items(users, key = { it.id }) { user ->
    UserRow(user)
}
```

Keys ensure identity is preserved even when the UI structure shifts.

## Summary: What Exactly Triggers Recomposition?

Recomposition happens when:

- You read observable state (tracked by snapshots)
- A parameter value changes
- You call `invalidate()` manually
- A composable’s identity shifts (and isn’t keyed)

<!-- ✅ Force space here -->

Understanding these core triggers allows you to:

- Predict recomposition behavior
- Avoid wasteful work
- Preserve user state
- Build smoother, faster UIs

## What’s Next?

Next, we’ll explore **what happens during recomposition**, including how the
Slot Table stores your UI, how Compose determines what to reuse or skip, and
how group lifecycle impacts performance.

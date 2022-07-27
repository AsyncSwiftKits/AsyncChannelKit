# AsyncChannelKit

A simple implementation of an async channel for use with [AsyncSequence] and [AsyncIterator].

When the `next()` function is called it is expected to return a value asynchronusly for an async for loop.
If the values are not created in response to calling this function these values will have to be provided
somehow. This channel supports sending values which the `next()` can return.

In the unit tests, a channel is created and given to the sequence. When the iterator is created it is
given the same channel. Calling `send` on the channel will make new values available. When the `next`
function is called it creates a `continuation` which will be matched to a value so it can be returned.
Calling `terminate` will use a `continuation` to send `nil` which tells the for loop it is done.

All of the work done by the channel is done as an actor type so that it is thread-safe.

[AsyncSequence]: https://developer.apple.com/documentation/swift/asyncsequence
[AsyncIterator]: https://developer.apple.com/documentation/swift/asyncsequence/asynciterator
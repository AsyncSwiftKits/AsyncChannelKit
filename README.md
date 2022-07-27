# AsyncChannelKit

A simple implementation of an async channel for use with [AsyncSequence] and [AsyncIterator].

When the `next()` function is called it is expected to return a value asynchronusly for an async for loop.
If the values are not created in response to calling this function these values will have to be provided
somehow. This channel supports sending values which the `next()` can return.

[AsyncSequence]: https://developer.apple.com/documentation/swift/asyncsequence
[AsyncIterator]: https://developer.apple.com/documentation/swift/asyncsequence/asynciterator
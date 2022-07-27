import Foundation

public struct AsyncChannelSequence<Element: Sendable>: AsyncSequence {
    public typealias AsyncIterator = AsyncChannelIterator<Element>

    private let channel: AsyncChannel<Element>

    public init(channel: AsyncChannel<Element>) {
        self.channel = channel
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncChannelIterator(channel: channel)
    }
}

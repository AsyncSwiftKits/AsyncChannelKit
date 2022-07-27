import Foundation

public struct AsyncChannelIterator<Element: Sendable>: AsyncIteratorProtocol {
    private let channel: AsyncChannel<Element>

    public init(channel: AsyncChannel<Element>) {
        self.channel = channel
    }

    public mutating func next() async throws -> Element? {
        await channel.next()
    }
}

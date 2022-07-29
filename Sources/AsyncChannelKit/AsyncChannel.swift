import Foundation

public actor AsyncChannel<Element: Sendable>: AsyncSequence {
    public struct Iterator: AsyncIteratorProtocol, Sendable {
        private let channel: AsyncChannel<Element>

        public init(_ channel: AsyncChannel<Element>) {
            self.channel = channel
        }

        public mutating func next() async -> Element? {
            await channel.next()
        }
    }

    public enum InternalFailure: Error {
        case cannotSendAfterTerminated
    }
    public typealias ChannelContinuation = CheckedContinuation<Element?, Never>

    private var continuations: [ChannelContinuation] = []
    private var elements: [Element] = []
    private var terminated: Bool = false

    private var hasNext: Bool {
        !continuations.isEmpty && !elements.isEmpty
    }

    private var canTerminate: Bool {
        terminated && elements.isEmpty && !continuations.isEmpty
    }

    public init() {
    }

    public nonisolated func makeAsyncIterator() -> Iterator {
        Iterator(self)
    }

    public func next() async -> Element? {
        await withCheckedContinuation { (continuation: ChannelContinuation) in
            continuations.append(continuation)
            processNext()
        }
    }

    public func send(_ element: Element) throws {
        guard !terminated else {
            throw InternalFailure.cannotSendAfterTerminated
        }
        elements.append(element)
        processNext()
    }

    public func finish() {
        terminated = true
        processNext()
    }

    private func processNext() {
        if canTerminate {
            let contination = continuations.removeFirst()
            assert(continuations.isEmpty)
            assert(elements.isEmpty)
            contination.resume(returning: nil)
            return
        }

        guard hasNext else {
            return
        }

        assert(!continuations.isEmpty)
        assert(!elements.isEmpty)

        let contination = continuations.removeFirst()
        let element = elements.removeFirst()

        contination.resume(returning: element)
    }
}

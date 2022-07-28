import Foundation

public actor AsyncChannel<Element: Sendable> {
    public enum Failure: Error {
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

    public func next() async -> Element? {
        await withCheckedContinuation { (continuation: ChannelContinuation) in
            continuations.append(continuation)
            processNext()
        }
    }

    public func send(element: Element) throws {
        guard !terminated else {
            throw Failure.cannotSendAfterTerminated
        }
        elements.append(element)
        processNext()
    }

    public func terminate() {
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

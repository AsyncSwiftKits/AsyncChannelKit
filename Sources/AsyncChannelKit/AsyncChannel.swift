import Foundation

public actor AsyncChannel<Element: Sendable> {
    public enum Failure: Error {
        case cannotSendAfterTerminated
    }
    public typealias ChannelContinuation = CheckedContinuation<Element?, Error>

    private var continuations: [ChannelContinuation] = []
    private var elements: [Element] = []
    private var terminated: Bool = false
    private var error: Error? = nil

    private var hasNext: Bool {
        !continuations.isEmpty && !elements.isEmpty
    }

    private var canFail: Bool {
        error != nil && !continuations.isEmpty
    }

    private var canTerminate: Bool {
        terminated && elements.isEmpty && !continuations.isEmpty
    }

    public init() {
    }

    public func next() async throws -> Element? {
        try await withCheckedThrowingContinuation { (continuation: ChannelContinuation) in
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

    public func send(error: Error) throws {
        guard !terminated else {
            throw Failure.cannotSendAfterTerminated
        }
        self.error = error
        processNext()
    }

    public func terminate() {
        terminated = true
        processNext()
    }

    private func processNext() {
        if canFail {
            let contination = continuations.removeFirst()
            assert(continuations.isEmpty)
            assert(elements.isEmpty)
            assert(error != nil)
            if let error = error {
                contination.resume(throwing: error)
                return
            }
        }

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

import XCTest
import AsyncTesting
@testable import AsyncChannelKit

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * Double(NSEC_PER_SEC))
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

enum Sender {

    static func send<Element>(elements: [Element], channel: AsyncChannel<Element>, delay: Double = 0.1) async throws {
        var index = 0
        while index < elements.count {
            try await Task.sleep(seconds: delay)
            let element = elements[index]
            await channel.send(element)

            index += 1
        }
        await channel.finish()
    }

    static func send<Element>(elements: [Element], channel: AsyncThrowingChannel<Element, Error>, delay: Double = 0.1, processor: ((Element) throws -> Element)? = nil) async throws {
        var index = 0
        while index < elements.count {
            try await Task.sleep(seconds: delay)
            let element = elements[index]
            if let processor = processor {
                do {
                    let processed = try processor(element)
                    await channel.send(processed)
                } catch {
                    await channel.fail(error)
                }
            } else {
                await channel.send(element)
            }

            index += 1
        }
        await channel.finish()
    }

}

final class AsyncChannelKitTests: XCTestCase {
    enum Failure: Error {
        case unluckyNumber
    }

    actor Output<Element> {
        var elements: [Element] = []
        func append(_ element: Element) {
            elements.append(element)
        }
    }

    func testNumberSequence() async throws {
        let delay = 0.01
        let input = [1, 2, 3, 4, 5]
        let channel = AsyncChannel<Int>()
        let sent = asyncExpectation(description: "sent")
        let received = asyncExpectation(description: "received")

        // load all numbers into the channel with delays
        Task {
            try await Sender.send(elements: input, channel: channel, delay: delay)
            await sent.fulfill()
        }

        Task {
            var output: [Int] = []
            for try await element in channel {
                output.append(element)
            }
            XCTAssertEqual(input, output)
            await received.fulfill()
        }

        try await waitForExpectations([sent, received])
    }

    func testNumberSequenceUsingForEach() async throws {
        let delay = 0.01
        let input = [1, 2, 3, 4, 5]
        let channel = AsyncChannel<Int>()
        let sent = asyncExpectation(description: "sent")
        let received = asyncExpectation(description: "received")

        // load all numbers into the channel with delays
        Task {
            try await Sender.send(elements: input, channel: channel, delay: delay)
            await sent.fulfill()
        }

        Task {
            let output = Output<Int>()
            await channel.forEach { element in
                await output.append(element)
            }
            let outputElements = await output.elements
            XCTAssertEqual(input, outputElements)
            await received.fulfill()
        }

        try await waitForExpectations([sent, received])
    }

    func testStringSequence() async throws {
        let delay = 0.01
        let input = ["one", "two", "three", "four", "five"]
        let channel = AsyncChannel<String>()
        let sent = asyncExpectation(description: "sent")
        let received = asyncExpectation(description: "received")

        // load all strings into the channel with delays
        Task {
            try await Sender.send(elements: input, channel: channel, delay: delay)
            await sent.fulfill()
        }

        Task {
            var output: [String] = []
            for try await element in channel {
                output.append(element)
            }
            XCTAssertEqual(input, output)
            await received.fulfill()
        }

        try await waitForExpectations([sent, received])
    }

    func testSucceedingSequence() async throws {
        let delay = 0.01
        let input = [3, 7, 14, 21]
        let channel = AsyncThrowingChannel<Int, Error>()
        let sent = asyncExpectation(description: "sent")
        let received = asyncExpectation(description: "received")

        // load all numbers into the channel with delays
        Task {
            try await Sender.send(elements: input, channel: channel, delay: delay) { element in
                if element == 13 {
                    throw Failure.unluckyNumber
                } else {
                    return element
                }
            }
            await sent.fulfill()
        }

        Task {
            var output: [Int] = []
            var thrown: Error? = nil
            do {
                for try await element in channel {
                    output.append(element)
                }
            } catch {
                thrown = error
            }
            XCTAssertNil(thrown)
            XCTAssertEqual(input, output)
            await received.fulfill()
        }

        try await waitForExpectations([sent, received])
    }

    func testFailingSequence() async throws {
        let delay = 0.01
        let input = [3, 7, 13, 21]
        let channel = AsyncThrowingChannel<Int, Error>()
        let sent = asyncExpectation(description: "sent", isInverted: true)
        let failed = asyncExpectation(description: "failed")
        let received = asyncExpectation(description: "received")

        // load all numbers into the channel with delays
        Task {
            try await Sender.send(elements: input, channel: channel, delay: delay) { element in
                if element == 13 {
                    Task {
                        await failed.fulfill()
                    }
                    throw Failure.unluckyNumber
                } else {
                    return element
                }
            }
            await sent.fulfill()
        }

        Task {
            var output: [Int] = []
            var thrown: Error? = nil

            do {
                for try await element in channel {
                    output.append(element)
                }
            } catch {
                thrown = error
            }

            XCTAssertNotNil(thrown)
            let expected = Array(input[0..<2])
            XCTAssertEqual(expected, output)
            await received.fulfill()
        }

        try await waitForExpectations([sent], timeout: delay * Double(input.count))
        try await waitForExpectations([failed, received])
    }

    func testChannelCancelled() async throws {
        let channel = AsyncChannel<String>()
        let ready = asyncExpectation(description: "ready")
        let done = asyncExpectation(description: "done")

        let task: Task<String?, Never> = Task {
            var iterator = channel.makeAsyncIterator()
            await ready.fulfill()
            return await iterator.next()
        }

        try await waitForExpectations([ready])
        task.cancel()

        Task {
            let value = await task.value
            XCTAssertNil(value)
            await done.fulfill()
        }

        try await waitForExpectations([done])
    }

    func testThrowingChannelCancelled() async throws {
        let channel = AsyncThrowingChannel<String, Error>()
        let ready = asyncExpectation(description: "ready")
        let done = asyncExpectation(description: "done")

        let task: Task<String?, Error> = Task {
            var iterator = channel.makeAsyncIterator()
            await ready.fulfill()
            return try await iterator.next()
        }

        try await waitForExpectations([ready])
        task.cancel()

        Task {
            let value = try await task.value
            XCTAssertNil(value)
            await done.fulfill()
        }

        try await waitForExpectations([done])
    }

    func testChannelCancelledOnSend() async throws {
        let delay = 0.01
        let channel = AsyncChannel<Int>()
        let notYetDone = asyncExpectation(description: "not yet done", isInverted: true)
        let done = asyncExpectation(description: "done")

        let task = Task {
            await channel.send(1)
            await notYetDone.fulfill()
            await done.fulfill()
        }

        try await waitForExpectations([notYetDone], timeout: delay)
        task.cancel()
        try await waitForExpectations([done], timeout: 1.0)
    }

    func testThrowingChannelCancelledOnSend() async throws {
        let delay = 0.01
        let channel = AsyncThrowingChannel<Int, Error>()
        let notYetDone = asyncExpectation(description: "not yet done", isInverted: true)
        let done = asyncExpectation(description: "done")
        let task = Task {
            await Task.yield()
            await channel.send(1)
            await notYetDone.fulfill()
            await done.fulfill()
        }

        try await waitForExpectations([notYetDone], timeout: delay)
        task.cancel()
        try await waitForExpectations([done])
    }

}

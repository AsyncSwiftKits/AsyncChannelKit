import XCTest
@testable import AsyncChannelKit

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * Double(NSEC_PER_SEC))
        try await Task.sleep(nanoseconds: nanoseconds)
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

    let delay = 0.1

    func testNumberSequence() async throws {
        let input = [1, 2, 3, 4, 5]
        let channel = AsyncChannel<Int>()

        // load all numbers into the channel with delays
        Task {
            try await send(elements: input, channel: channel, delay: delay)
        }

        var output: [Int] = []

        print("-- before --")
        for try await element in channel {
            print(element)
            output.append(element)
        }
        print("-- after --")

        XCTAssertEqual(input, output)
    }

    func testNumberSequenceUsingForEach() async throws {
        let input = [1, 2, 3, 4, 5]
        let channel = AsyncChannel<Int>()

        // load all numbers into the channel with delays
        Task {
            try await send(elements: input, channel: channel, delay: delay)
        }

        let output = Output<Int>()

        print("-- before --")
        await channel.forEach { element in
            print(element)
            await output.append(element)
        }
        print("-- after --")

        let outputElements = await output.elements
        XCTAssertEqual(input, outputElements)
    }

    func testStringSequence() async throws {
        let input = ["one", "two", "three", "four", "five"]
        let channel = AsyncChannel<String>()

        // load all strings into the channel with delays
        Task {
            try await send(elements: input, channel: channel, delay: delay)
        }

        var output: [String] = []

        print("-- before --")
        for try await element in channel {
            print(element)
            output.append(element)
        }
        print("-- after --")

        XCTAssertEqual(input, output)
    }

    func testSucceedingSequence() async throws {
        let input = [3, 7, 14, 21]
        let channel = AsyncThrowingChannel<Int, Error>()

        // load all numbers into the channel with delays
        Task {
            try await send(elements: input, channel: channel, delay: delay) { element in
                if element == 13 {
                    throw Failure.unluckyNumber
                } else {
                    return element
                }
            }
        }

        var output: [Int] = []
        var thrown: Error? = nil

        print("-- before --")
        do {
            for try await element in channel {
                print(element)
                output.append(element)
            }
        } catch {
            thrown = error
        }
        print("-- after --")

        XCTAssertNil(thrown)
        XCTAssertEqual(input, output)
    }

    func testFailingSequence() async throws {
        let input = [3, 7, 13, 21]
        let channel = AsyncThrowingChannel<Int, Error>()

        // load all numbers into the channel with delays
        Task {
            try await send(elements: input, channel: channel, delay: delay) { element in
                if element == 13 {
                    throw Failure.unluckyNumber
                } else {
                    return element
                }
            }
        }

        var output: [Int] = []
        var thrown: Error? = nil

        print("-- before --")
        do {
            for try await element in channel {
                print(element)
                output.append(element)
            }
        } catch {
            thrown = error
        }
        print("-- after --")

        XCTAssertNotNil(thrown)
        let expected = Array(input[0..<2])
        XCTAssertEqual(expected, output)
    }

    func testChannelCancelled() async throws {
        let channel = AsyncChannel<String>()
        let ready = expectation(description: "ready")
        let task: Task<String?, Never> = Task {
          var iterator = channel.makeAsyncIterator()
          ready.fulfill()
          return await iterator.next()
        }
        wait(for: [ready], timeout: 1.0)
        task.cancel()
        let value = await task.value
        XCTAssertNil(value)
    }

    func testThrowingChannelCancelled() async throws {
        let channel = AsyncThrowingChannel<String, Error>()
        let ready = expectation(description: "ready")
        let task: Task<String?, Error> = Task {
          var iterator = channel.makeAsyncIterator()
          ready.fulfill()
          return try await iterator.next()
        }
        wait(for: [ready], timeout: 1.0)
        task.cancel()
        let value = try await task.value
        XCTAssertNil(value)
    }

    func testChannelCancelledOnSend() async {
      let channel = AsyncChannel<Int>()
      let notYetDone = expectation(description: "not yet done")
      notYetDone.isInverted = true
      let done = expectation(description: "done")
      let task = Task {
        await channel.send(1)
        notYetDone.fulfill()
        done.fulfill()
      }
      wait(for: [notYetDone], timeout: 0.1)
      task.cancel()
      wait(for: [done], timeout: 1.0)
    }

    func testThrowingChannelCancelledOnSend() async {
      let channel = AsyncThrowingChannel<Int, Error>()
      let notYetDone = expectation(description: "not yet done")
      notYetDone.isInverted = true
      let done = expectation(description: "done")
      let task = Task {
        await channel.send(1)
        notYetDone.fulfill()
        done.fulfill()
      }
      wait(for: [notYetDone], timeout: 0.1)
      task.cancel()
      wait(for: [done], timeout: 1.0)
    }

    private func send<Element>(elements: [Element], channel: AsyncChannel<Element>, delay: Double = 0.1) async throws {
        var index = 0
        while index < elements.count {
            try await Task.sleep(seconds: delay)
            let element = elements[index]
            await channel.send(element)

            index += 1
        }
        await channel.finish()
    }

    private func send<Element>(elements: [Element], channel: AsyncThrowingChannel<Element, Error>, delay: Double = 0.1, processor: ((Element) throws -> Element)? = nil) async throws {
        var index = 0
        while index < elements.count {
            try await Task.sleep(seconds: delay)
            let element = elements[index]
            if let processor = processor {
                do {
                    let processed = try processor(element)
                    await channel.send(processed)
                } catch {
                    print("throwing \(error)")
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

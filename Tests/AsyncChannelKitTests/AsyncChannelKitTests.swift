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
    let sleepSeconds = 0.1

    func testNumberSequence() async throws {
        let input = [1, 2, 3, 4, 5]
        let channel = AsyncChannel<Int>()
        let sequence = AsyncChannelSequence(channel: channel)

        // load all numbers into the channel with delays
        Task {
            try await send(elements: input, channel: channel, sleepSeconds: sleepSeconds)
        }

        var output: [Int] = []

        print("-- before --")
        for try await element in sequence {
            print(element)
            output.append(element)
        }
        print("-- after --")

        XCTAssertEqual(input, output)
    }

    func testStringSequence() async throws {
        let input = ["one", "two", "three", "four", "five"]
        let channel = AsyncChannel<String>()
        let sequence = AsyncChannelSequence(channel: channel)

        // load all strings into the channel with delays
        Task {
            try await send(elements: input, channel: channel, sleepSeconds: sleepSeconds)
        }

        var output: [String] = []

        print("-- before --")
        for try await element in sequence {
            print(element)
            output.append(element)
        }
        print("-- after --")

        XCTAssertEqual(input, output)
    }


    func testFailingSequence() async throws {
        let input = [3, 7, 13, 21]
        let channel = AsyncChannel<Int>()
        let sequence = AsyncChannelSequence(channel: channel)

        // load all numbers into the channel with delays
        Task {
            try await send(elements: input, channel: channel, sleepSeconds: sleepSeconds) { element in
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
            for try await element in sequence {
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

    private func send<Element>(elements: [Element], channel: AsyncChannel<Element>, sleepSeconds: Double = 0.1, processor: ((Element) throws -> Element)? = nil) async throws {
        var index = 0
        while index < elements.count {
            try await Task.sleep(seconds: sleepSeconds)
            let element = elements[index]
            if let processor = processor {
                do {
                    let processed = try processor(element)
                    try await channel.send(element: processed)
                } catch {
                    print("throwing \(error)")
                    try await channel.send(error: error)
                }
            } else {
                try await channel.send(element: element)
            }

            index += 1
        }
        await channel.terminate()
    }
}

import XCTest
@testable import AsyncChannelKit

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let nanoseconds = UInt64(seconds * Double(NSEC_PER_SEC))
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

final class AsyncChannelKitTests: XCTestCase {
    let sleepSeconds = 0.25

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
            output.append(element)
        }
        print("-- after --")

        XCTAssertEqual(input, output)
    }

    private func send<Element>(elements: [Element], channel: AsyncChannel<Element>, sleepSeconds: Double = 0.1) async throws {
        var index = 0
        while index < elements.count {
            try await Task.sleep(seconds: sleepSeconds)
            await channel.send(element: elements[index])
            index += 1
        }
        await channel.terminate()
    }
}

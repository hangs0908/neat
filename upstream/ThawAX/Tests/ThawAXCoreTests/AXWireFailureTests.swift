import Foundation
import Testing
@testable import ThawAXCore

@Suite("AX 프레임 실패 처리")
struct AXWireFailureTests {
    @Test("비정상 헤더나 누락된 본문은 지정된 프레임 오류를 반환한다", arguments: [
        (Data([0]), AXWire.WireError.truncated),
        (Data([0, 0]), .truncated),
        (Data([0, 0, 0]), .truncated),
        (Data([0, 0, 0, 0]), .empty),
        (Data([1, 0, 0, 1]), .tooLarge(16_777_217)),
        (Data([255, 255, 255, 255]), .tooLarge(4_294_967_295)),
        (Data([0, 0, 0, 1]), .truncated),
    ])
    func rejectsInvalidFrame(frame: Data, expected: AXWire.WireError) throws {
        try withClosedWriter(frame) { reader in
            #expect(throws: expected) {
                _ = try AXWire.read(Int.self, from: reader, timeoutSeconds: 1)
            }
        }
    }

    @Test("잘못된 JSON과 요청한 타입에 맞지 않는 본문은 디코딩 오류다", arguments: [
        Data([0, 0, 0, 1, 123]),
        Data([0, 0, 0, 2, 34, 34]),
    ])
    func rejectsUndecodablePayload(frame: Data) throws {
        try withClosedWriter(frame) { reader in
            #expect(performing: {
                _ = try AXWire.read(Int.self, from: reader, timeoutSeconds: 1)
            }, throws: { error in
                switch error {
                case AXWire.WireError.decode: true
                default: false
                }
            })
        }
    }

    @Test("인코딩할 수 없는 값은 프레임을 일부라도 쓰지 않는다", arguments: [Double.infinity, Double.nan])
    func encodingFailureWritesNothing(value: Double) throws {
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForWriting.close()
            try? pipe.fileHandleForReading.close()
        }
        #expect(performing: {
            try AXWire.write(value, to: pipe.fileHandleForWriting)
        }, throws: { error in
            switch error {
            case AXWire.WireError.encode: true
            default: false
            }
        })
        try pipe.fileHandleForWriting.close()
        #expect(try AXWire.read(Int.self, from: pipe.fileHandleForReading, timeoutSeconds: 1) == nil)
    }

    private func withClosedWriter(_ frame: Data, _ body: (FileHandle) throws -> Void) throws {
        let pipe = Pipe()
        defer {
            try? pipe.fileHandleForWriting.close()
            try? pipe.fileHandleForReading.close()
        }
        try pipe.fileHandleForWriting.write(contentsOf: frame)
        try pipe.fileHandleForWriting.close()
        try body(pipe.fileHandleForReading)
    }
}

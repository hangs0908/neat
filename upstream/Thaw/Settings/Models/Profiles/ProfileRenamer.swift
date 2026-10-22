//
//  ProfileRenamer.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

enum ProfileRenamer {
    static func rename(id: UUID, to name: String, in directory: URL, profiles: [ProfileMetadata]) throws -> [ProfileMetadata] {
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        let originalData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let original = try decoder.decode(Profile.self, from: originalData)
        let renamed = Profile(
            id: original.id,
            name: name,
            createdAt: original.createdAt,
            modifiedAt: Date(),
            content: original.content
        )
        var updated = profiles
        if let index = updated.firstIndex(where: { $0.id == id }) {
            updated[index].name = name
            updated[index].modifiedAt = renamed.modifiedAt
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let profileData = try encoder.encode(renamed)
        let manifestData = try encoder.encode(updated)
        try profileData.write(to: url, options: .atomic)
        do {
            try manifestData.write(to: directory.appendingPathComponent("profiles.json"), options: .atomic)
        } catch let manifestError {
            do {
                try originalData.write(to: url, options: .atomic)
            } catch {
                throw CocoaError(.fileWriteUnknown, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Couldn't restore the profile after its list failed to save."),
                    NSMultipleUnderlyingErrorsKey: [manifestError, error],
                ])
            }
            throw manifestError
        }
        // 저장 성공 전에는 메모리의 목록이나 단축키 관찰자를 갱신하지 않는다.
        return updated
    }
}

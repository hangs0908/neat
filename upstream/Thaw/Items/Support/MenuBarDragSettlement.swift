//
//  MenuBarDragSettlement.swift
//  Project: Thaw
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Foundation

/// 메뉴바 관찰의 정착 대기와 사용자 드래그 직후의 자동 이동 보호를 소유한다.
@MainActor
final class MenuBarDragSettlement {
    private var adoptionTask: Task<Void, Never>?
    private var lastDragEnd: ContinuousClock.Instant?
    private let sleep: @MainActor (Duration) async throws -> Void

    init(sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    isolated deinit {
        adoptionTask?.cancel()
    }

    func isArranging(isDragging: Bool, now: ContinuousClock.Instant = .now) -> Bool {
        isDragging || lastDragEnd.map { $0.duration(to: now) < .seconds(4) } == true
    }

    func schedule(
        afterUserDrag: Bool,
        now: ContinuousClock.Instant = .now,
        refresh: @escaping @MainActor (_ skipSavedLayoutApply: Bool) async -> Void,
        adopt: @escaping @MainActor () async -> Void,
        record: @escaping @MainActor () async -> Void
    ) {
        let sleep = self.sleep
        if afterUserDrag {
            lastDragEnd = now
        }
        adoptionTask?.cancel()
        adoptionTask = Task {
            try? await sleep(.milliseconds(1500))
            guard !Task.isCancelled else { return }
            await refresh(true)
            guard !Task.isCancelled else { return }
            await adopt()
            if afterUserDrag {
                await record()
            }
        }
        if afterUserDrag {
            // 각 종료의 빠른 갱신은 정착 작업 교체와 별도로 유지한다.
            Task {
                try? await sleep(.milliseconds(500))
                await refresh(false)
            }
        }
    }
}

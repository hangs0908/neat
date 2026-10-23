import CoreGraphics
import MenuBarModel
import Testing
import ThawLayout

@Suite("노치 너비에 따른 배치와 섹션 분할")
struct NotchOverflowTests {
    private let controls = ControlUIDs(visible: "chevron", hidden: "divider", alwaysHidden: "alwaysDivider")
    private let flat = ["a", "chevron", "b", "new", "divider", "hidden", "alwaysDivider", "secret"]
    private var sectionMap: [String: String] {
        ["a": "visible", "chevron": "visible", "b": "visible", "new": "visible",
         "hidden": "hidden", "secret": "alwaysHidden"]
    }

    private var widths: [String: CGFloat] {
        ["a": 20, "chevron": 10, "b": 20, "new": 20]
    }

    @Test("측정할 수 없는 너비에서는 원래 배치를 보존한다", arguments: [
        CGFloat.zero, -1, .nan, .infinity, -.infinity,
    ])
    func invalidBudgetPreservesLayout(budget: CGFloat) {
        let result = LayoutSolver.planNotchOverflow(
            desiredFiltered: flat, unmanagedUIDs: ["new"], controlUIDs: controls,
            sectionMap: sectionMap, uidWidths: widths, availableWidth: budget
        )
        #expect(result == .init(
            overflowUIDs: [], updatedDesiredFiltered: flat, updatedSectionMap: sectionMap
        ))
    }

    @Test("경계 너비에서 신규 항목을 먼저 숨기고 기존 순서를 보존한다", arguments: [
        (CGFloat(70), [String]()), (CGFloat(69), ["new"]), (CGFloat(49), ["a", "new"]),
    ])
    func overflowPriority(budget: CGFloat, expectedOverflow: [String]) {
        let result = LayoutSolver.planNotchOverflow(
            desiredFiltered: flat, unmanagedUIDs: ["new"], controlUIDs: controls,
            sectionMap: sectionMap, uidWidths: widths, availableWidth: budget
        )
        let expectedVisible = flat.prefix(4).filter { !expectedOverflow.contains($0) }
        var expectedMap = sectionMap
        for uid in expectedOverflow {
            expectedMap[uid] = "hidden"
        }
        #expect(result == .init(
            overflowUIDs: expectedOverflow,
            updatedDesiredFiltered: expectedVisible + ["divider", "hidden"] + expectedOverflow + ["alwaysDivider", "secret"],
            updatedSectionMap: expectedMap
        ))

        let split = LayoutSolver.splitDesiredFiltered(result.updatedDesiredFiltered, controlUIDs: controls)
        #expect(split == .init(
            visible: expectedVisible, hidden: ["hidden"] + expectedOverflow, alwaysHidden: ["secret"]
        ))
        #expect(LayoutSolver.flattenCurrentSections(
            visible: split.visible, hidden: split.hidden, alwaysHidden: split.alwaysHidden,
            hiddenCtrlUID: controls.hidden, ahCtrlUID: controls.alwaysHidden
        ) == result.updatedDesiredFiltered)

        // 숨김 결과를 다시 계산해도 추가 이동이나 항목 소실이 없어야 한다.
        let second = LayoutSolver.planNotchOverflow(
            desiredFiltered: result.updatedDesiredFiltered, unmanagedUIDs: ["new"], controlUIDs: controls,
            sectionMap: result.updatedSectionMap, uidWidths: widths, availableWidth: budget
        )
        #expect(second == .init(
            overflowUIDs: [], updatedDesiredFiltered: result.updatedDesiredFiltered,
            updatedSectionMap: expectedMap
        ))
    }

    @Test("흩어진 그룹은 신규 구성원이 하나라도 있으면 함께 숨긴다")
    func mixedGroupOverflowsWhole() {
        let result = LayoutSolver.planNotchOverflow(
            desiredFiltered: flat, unmanagedUIDs: ["new"], controlUIDs: controls,
            sectionMap: sectionMap, uidWidths: widths, availableWidth: 50,
            groups: .init(groups: [["a", "new"]])
        )
        var expectedMap = sectionMap
        expectedMap["a"] = "hidden"
        expectedMap["new"] = "hidden"
        #expect(result == .init(
            overflowUIDs: ["a", "new"],
            updatedDesiredFiltered: ["chevron", "b", "divider", "hidden", "a", "new", "alwaysDivider", "secret"],
            updatedSectionMap: expectedMap, groupsOverflowedWhole: [["a", "new"]],
            oversizedGroups: [["a", "new"]]
        ))
    }

    @Test("바 전체보다 큰 그룹은 왼쪽의 들어갈 수 있는 항목까지 숨기지 않는다")
    func oversizedGroupDoesNotCascade() {
        let input = ["left", "g1", "g2", "right", "divider"]
        let result = LayoutSolver.planNotchOverflow(
            desiredFiltered: input, unmanagedUIDs: [],
            controlUIDs: .init(visible: nil, hidden: "divider", alwaysHidden: nil),
            sectionMap: ["left": "visible", "g1": "visible", "g2": "visible", "right": "visible"],
            uidWidths: ["left": 10, "g1": 30, "g2": 30, "right": 10], availableWidth: 50,
            groups: .init(groups: [["g1", "g2"]])
        )
        #expect(result == .init(
            overflowUIDs: ["g1", "g2"],
            updatedDesiredFiltered: ["left", "right", "divider", "g1", "g2"],
            updatedSectionMap: ["left": "visible", "g1": "hidden", "g2": "hidden", "right": "visible"],
            groupsOverflowedWhole: [["g1", "g2"]], oversizedGroups: [["g1", "g2"]]
        ))
    }

    @Test("들어가지 않는 일반 항목을 건너뛰어 왼쪽에 구멍을 만들지 않는다")
    func trailingRunStopsAtFirstNonFittingItem() {
        let result = LayoutSolver.planNotchOverflow(
            desiredFiltered: ["small", "large", "right", "divider"], unmanagedUIDs: [],
            controlUIDs: .init(visible: nil, hidden: "divider", alwaysHidden: nil),
            sectionMap: ["small": "visible", "large": "visible", "right": "visible"],
            uidWidths: ["small": 5, "large": 40, "right": 20], availableWidth: 50
        )
        #expect(result == .init(
            overflowUIDs: ["small", "large"],
            updatedDesiredFiltered: ["right", "divider", "small", "large"],
            updatedSectionMap: ["small": "hidden", "large": "hidden", "right": "visible"]
        ))
    }

    @Test("너비 누락은 진단에 포함하고 숨김 여부와 무관하게 순서를 보존한다", arguments: [CGFloat(50), 49])
    func missingWidthIsReported(budget: CGFloat) {
        var measured = widths
        measured.removeValue(forKey: "a")
        let overflow = budget == 50 ? [] : ["new"]
        let result = LayoutSolver.planNotchOverflow(
            desiredFiltered: flat, unmanagedUIDs: ["new"], controlUIDs: controls,
            sectionMap: sectionMap, uidWidths: measured, availableWidth: budget
        )
        #expect(result.missingWidthUIDs == ["a"])
        #expect(result.overflowUIDs == overflow)
        var expectedMap = sectionMap
        for uid in overflow {
            expectedMap[uid] = "hidden"
        }
        #expect(result == .init(
            overflowUIDs: overflow,
            updatedDesiredFiltered: budget == 50 ? flat : ["a", "chevron", "b", "divider", "hidden", "new", "alwaysDivider", "secret"],
            updatedSectionMap: expectedMap, missingWidthUIDs: ["a"]
        ))
    }
}

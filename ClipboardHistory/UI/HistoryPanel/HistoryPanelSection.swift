//
//  HistoryPanelSection.swift
//  ClipboardHistory
//

enum HistoryPanelSection: String, CaseIterable, Identifiable, Equatable {
    case history
    case favorites

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .history:
            "历史"
        case .favorites:
            "收藏"
        }
    }

    var systemImage: String {
        switch self {
        case .history:
            "clock.arrow.circlepath"
        case .favorites:
            "star.fill"
        }
    }
}

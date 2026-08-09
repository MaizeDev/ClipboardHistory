//
//  HistorySelection.swift
//  ClipboardHistory
//

import Foundation

enum HistorySelection {

    static func reconciled(
        _ selectedID: UUID?,
        in itemIDs: [UUID]
    ) -> UUID? {
        guard let selectedID,
              itemIDs.contains(selectedID) else {
            return itemIDs.first
        }

        return selectedID
    }

    static func moving(
        from selectedID: UUID?,
        offset: Int,
        in itemIDs: [UUID]
    ) -> UUID? {
        guard !itemIDs.isEmpty else {
            return nil
        }

        guard let selectedID,
              let currentIndex = itemIDs.firstIndex(of: selectedID) else {
            return itemIDs.first
        }

        let targetIndex = min(
            max(currentIndex + offset, itemIDs.startIndex),
            itemIDs.index(before: itemIDs.endIndex)
        )

        return itemIDs[targetIndex]
    }

    static func item(
        at index: Int,
        in itemIDs: [UUID]
    ) -> UUID? {
        guard itemIDs.indices.contains(index) else {
            return nil
        }

        return itemIDs[index]
    }

    static func afterRemoving(
        _ removedID: UUID,
        from itemIDs: [UUID]
    ) -> UUID? {
        guard let removedIndex = itemIDs.firstIndex(of: removedID) else {
            return reconciled(nil, in: itemIDs)
        }

        let remainingIDs = itemIDs.filter { $0 != removedID }

        guard !remainingIDs.isEmpty else {
            return nil
        }

        let lastRemainingIndex = remainingIDs.index(before: remainingIDs.endIndex)
        let nextIndex = min(removedIndex, lastRemainingIndex)
        return remainingIDs[nextIndex]
    }
}

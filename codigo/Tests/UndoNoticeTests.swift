import Foundation

@main
struct UndoNoticeTests {
    @MainActor static func main() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FocoUndo-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FocusStore(directory: dir)
        let first = FocusRecord(id: "test-first", startedAt: 100, seconds: 25, completed: false)
        let second = FocusRecord(id: "test-second", startedAt: 200, seconds: 40, completed: false)
        try store.transaction { $0.records = [second, first] }
        let model = FocoModel(store: store)
        model.deleteRecord(first)
        precondition(model.deletedRecord?.id == first.id)
        model.dismissUndo()
        precondition(model.deletedRecord == nil)
        var records = try store.read().records
        precondition(records.map(\.id) == [second.id], "Closing notice must keep deletion")
        model.deleteRecord(second)
        model.dismissExpiredUndo(at: Date().addingTimeInterval(7))
        precondition(model.deletedRecord != nil, "Undo stays available before deadline")
        model.dismissExpiredUndo(at: Date().addingTimeInterval(9))
        precondition(model.deletedRecord == nil, "Notice expires without requiring interaction")
        records = try store.read().records
        precondition(records.isEmpty, "Expiry must not restore deleted records")
        try store.restoreRecord(first)
        model.deleteRecord(first)
        model.undoDelete()
        precondition(model.deletedRecord == nil)
        records = try store.read().records
        precondition(records.map(\.id) == [first.id], "Undo still restores record")
        model.dismissExpiredUndo(at: Date().addingTimeInterval(20))
        records = try store.read().records
        precondition(records.count == 1, "Expired notice cannot delete restored record")
        let task = try store.addTask(title: "Temporary task", day: Date())
        model.selectedTaskID = task.id
        model.deleteTask(task)
        precondition(model.deletedTask?.task.id == task.id && model.selectedTaskID == nil)
        model.dismissExpiredTaskUndo(at: Date().addingTimeInterval(7))
        precondition(model.deletedTask != nil)
        model.undoTaskDelete()
        let restoredTasks = try store.read().tasks!
        precondition(restoredTasks.contains { $0.id == task.id })
        model.deleteTask(task)
        model.dismissExpiredTaskUndo(at: Date().addingTimeInterval(9))
        precondition(model.deletedTask == nil)
        let deletedTasks = try store.read().tasks!
        precondition(!deletedTasks.contains { $0.id == task.id })
        print("PASS task notice: selection cleared, undo available, expiry preserves deletion")
        print("PASS undo notice: close, eight-second expiry, deletion preserved and undo restoration")
    }
}

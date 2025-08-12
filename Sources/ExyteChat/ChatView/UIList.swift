//
//  UIList.swift
//  
//
//  Created by Alisa Mylnikova on 24.02.2023.
//

import SwiftUI

public extension Notification.Name {
    static let onScrollToBottom = Notification.Name("onScrollToBottom")
    static let audioPlaybackStarted = Notification.Name("audioPlaybackStarted")
    static let recordingStarted = Notification.Name("recordingStarted")
    static let recordingStopped = Notification.Name("recordingStopped")
    static let uploadStarted = Notification.Name("uploadStarted")
    static let uploadFinished = Notification.Name("uploadFinished")
    static let startSharing = Notification.Name("startSharing")
    static let stopSharing = Notification.Name("stopSharing")
}

struct UIList<MessageContent: View, InputView: View>: UIViewRepresentable {

    typealias MessageBuilderClosure = ChatView<MessageContent, InputView, DefaultMessageMenuAction>.MessageBuilderClosure

    @Environment(\.chatTheme) var theme

    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var inputViewModel: InputViewModel

    @Binding var isScrolledToBottom: Bool
    @Binding var shouldScrollToTop: () -> ()
    @Binding var tableContentHeight: CGFloat

    var messageBuilder: MessageBuilderClosure?
    var mainHeaderBuilder: (()->AnyView)?
    var headerBuilder: ((Date)->AnyView)?
    var inputView: InputView

    let type: ChatType
    let showDateHeaders: Bool
    let isScrollEnabled: Bool
    let avatarSize: CGFloat
    let showMessageMenuOnLongPress: Bool
    let tapAvatarClosure: ChatView.TapAvatarClosure?
    let tapDocumentClosure: ChatView.TapDocumentClosure?
    let paginationHandler: PaginationHandler?
    let messageStyler: (String) -> AttributedString
//    let shouldShowLinkPreview: (URL) -> Bool
    let showMessageTimeView: Bool
//    let messageLinkPreviewLimit: Int
    let messageFont: UIFont
    let sections: [MessagesSection]
    let ids: [String]
//    let listSwipeActions: ListSwipeActions
 
    let messageUseMarkdown: Bool
    let showAvatars: Bool
    let groupUsers: [User]
    @State var isScrolledToTop = false
    @State var updateQueue = UpdateQueue()

    func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.transform = CGAffineTransform(rotationAngle: (type == .conversation ? .pi : 0))

        tableView.showsVerticalScrollIndicator = false
        tableView.estimatedSectionHeaderHeight = 1
        tableView.estimatedSectionFooterHeight = UITableView.automaticDimension
        tableView.backgroundColor = UIColor(theme.colors.mainBackground)
        tableView.scrollsToTop = false
        tableView.isScrollEnabled = isScrollEnabled

        NotificationCenter.default.addObserver(forName: .onScrollToBottom, object: nil, queue: nil) { _ in
            DispatchQueue.main.async {
                if !context.coordinator.sections.isEmpty {
                    tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: true)
                }
            }
        }

        DispatchQueue.main.async {
            shouldScrollToTop = {
                tableView.contentOffset = CGPoint(x: 0, y: tableView.contentSize.height - tableView.frame.height)
            }
        }

        return tableView
    }
    
    @MainActor
    private func updatePaginationTargetIfNeeded(_ coordinator: Coordinator) {
        if coordinator.sections.isEmpty { return }

        if let lastSection = coordinator.sections.last, !lastSection.rows.isEmpty {
            coordinator.paginationTargetIndexPath = IndexPath(
                row: lastSection.rows.count - 1,
                section: coordinator.sections.count - 1
            )
        }
    }

    func updateUIView(_ tableView: UITableView, context: Context) {
        if !isScrollEnabled {
            DispatchQueue.main.async {
                tableContentHeight = tableView.contentSize.height
            }
        }

        updatePaginationTargetIfNeeded(context.coordinator)
        guard context.coordinator.sections != sections else { return }
        Task {
            await updateQueue.enqueue {
                await updateIfNeeded(coordinator: context.coordinator, tableView: tableView)
            }
        }
    }

    @MainActor
    private func updateIfNeeded(coordinator: Coordinator, tableView: UITableView) async {
        if coordinator.sections == sections {
            return
        }

        if coordinator.sections.isEmpty {
            coordinator.sections = sections
            tableView.reloadData()
            if !isScrollEnabled {
                DispatchQueue.main.async {
                    tableContentHeight = tableView.contentSize.height
                }
            }
            return
        }

        if let lastSection = sections.last {
            coordinator.paginationTargetIndexPath = IndexPath(row: lastSection.rows.count - 1, section: sections.count - 1)
        }

        let prevSections = coordinator.sections
        //print("0 whole sections:", runID, "\n")
        //print("whole previous:\n", formatSections(prevSections), "\n")
        let splitInfo = await performSplitInBackground(prevSections, sections)
        await applyUpdatesToTable(tableView, splitInfo: splitInfo) {
            coordinator.sections = $0
        }
    }

    nonisolated private func performSplitInBackground(_  prevSections:  [MessagesSection], _ sections: [MessagesSection]) async -> SplitInfo {
        await withCheckedContinuation { continuation in
            Task.detached {
                let result = operationsSplit(oldSections: prevSections, newSections: sections)
                continuation.resume(returning: result)
            }
        }
    }

    @MainActor
    private func applyUpdatesToTable(_ tableView: UITableView, splitInfo: SplitInfo, updateContextClosure: ([MessagesSection])->()) async {
        // step 0: preparation
        // prepare intermediate sections and operations
        //print("whole appliedDeletes:\n", formatSections(splitInfo.appliedDeletes), "\n")
        //print("whole appliedDeletesSwapsAndEdits:\n", formatSections(splitInfo.appliedDeletesSwapsAndEdits), "\n")
        //print("whole final sections:\n", formatSections(sections), "\n")

        //print("operations delete:\n", splitInfo.deleteOperations.map { $0.description })
        //print("operations swap:\n", splitInfo.swapOperations.map { $0.description })
        //print("operations edit:\n", splitInfo.editOperations.map { $0.description })
        //print("operations insert:\n", splitInfo.insertOperations.map { $0.description })

        await performBatchTableUpdates(tableView) {
            // step 1: deletes
            // delete sections and rows if necessary
            //print("1 apply deletes", runID)
            updateContextClosure(splitInfo.appliedDeletes)
            //context.coordinator.sections = appliedDeletes
            for operation in splitInfo.deleteOperations {
                applyOperation(operation, tableView: tableView)
            }
        }
        //print("1 finished deletes", runID)

        await performBatchTableUpdates(tableView) {
            // step 2: swaps
            // swap places for rows that moved inside the table
            // (example of how this happens. send two messages: first m1, then m2. if m2 is delivered to server faster, then it should jump above m1 even though it was sent later)
            //print("2 apply swaps", runID)
            updateContextClosure(splitInfo.appliedDeletesSwapsAndEdits) // NOTE: this array already contains necessary edits, but won't be a problem for appplying swaps
            for operation in splitInfo.swapOperations {
                applyOperation(operation, tableView: tableView)
            }
        }
        //print("2 finished swaps", runID)

        UIView.setAnimationsEnabled(false)
        await performBatchTableUpdates(tableView) {
            // step 3: edits
            // check only sections that are already in the table for existing rows that changed and apply only them to table's dataSource without animation
            //print("3 apply edits", runID)
            updateContextClosure(splitInfo.appliedDeletesSwapsAndEdits)

            for operation in splitInfo.editOperations {
                applyOperation(operation, tableView: tableView)
            }
        }
        UIView.setAnimationsEnabled(true)
        //print("3 finished edits", runID)

        if isScrolledToBottom || isScrolledToTop {
            // step 4: inserts
            // apply the rest of the changes to table's dataSource, i.e. inserts
            //print("4 apply inserts", runID)
            updateContextClosure(sections)

            tableView.beginUpdates()
            for operation in splitInfo.insertOperations {
                applyOperation(operation, tableView: tableView)
            }
            tableView.endUpdates()
            //print("4 finished inserts", runID)

            if !isScrollEnabled {
                tableContentHeight = tableView.contentSize.height
            }
        }
    }

    // MARK: - Operations

    enum Operation {
        case deleteSection(Int)
        case insertSection(Int)

        case delete(Int, Int) // delete with animation
        case insert(Int, Int) // insert with animation
        case swap(Int, Int, Int) // delete first with animation, then insert it into new position with animation. do not do anything with the second for now
        case edit(Int, Int, Bool) // reload the element without animation and if content edit - with animation

        var description: String {
            switch self {
            case .deleteSection(let int):
                return "deleteSection \(int)"
            case .insertSection(let int):
                return "insertSection \(int)"
            case .delete(let int, let int2):
                return "delete section \(int) row \(int2)"
            case .insert(let int, let int2):
                return "insert section \(int) row \(int2)"
            case .swap(let int, let int2, let int3):
                return "swap section \(int) rowFrom \(int2) rowTo \(int3)"
            case .edit(let int, let int2, let bool):
                return "edit section \(int) row \(int2) isContentEdit \(bool)"
            }
        }
    }

    func applyOperation(_ operation: Operation, tableView: UITableView) {
        let animation: UITableView.RowAnimation = .top
        switch operation {
        case .deleteSection(let section):
            tableView.deleteSections([section], with: animation)
        case .insertSection(let section):
            tableView.insertSections([section], with: animation)

        case .delete(let section, let row):
            tableView.deleteRows(at: [IndexPath(row: row, section: section)], with: animation)
        case .insert(let section, let row):
            tableView.insertRows(at: [IndexPath(row: row, section: section)], with: animation)
        case .edit(let section, let row, let isContentEdit):
            let indexPath = IndexPath(row: row, section: section)
            if isContentEdit {
                tableView.reloadRows(at: [indexPath], with: .none)
            } else {
                tableView.reconfigureRows(at: [indexPath])
            }
        case .swap(let section, let rowFrom, let rowTo):
            tableView.deleteRows(at: [IndexPath(row: rowFrom, section: section)], with: animation)
            tableView.insertRows(at: [IndexPath(row: rowTo, section: section)], with: animation)
        }
    }

    private nonisolated func operationsSplit(oldSections: [MessagesSection], newSections: [MessagesSection]) -> SplitInfo {
        var appliedDeletes = oldSections
        var appliedDeletesSwapsAndEdits = newSections

        var deleteOperations = [Operation]()
        var swapOperations = [Operation]()
        var editOperations = [Operation]()
        var insertOperations = [Operation]()

        // Build union of section keys but keep deterministic order (desc by date)
        let oldDates = oldSections.map(\.date)
        let newDates = newSections.map(\.date)
        let commonDates = Array(Set(oldDates).union(newDates)).sorted(by: >)

        for date in commonDates {
            let oldIdxMut = appliedDeletes.firstIndex(where: { $0.date == date })
            let newIdxMut = appliedDeletesSwapsAndEdits.firstIndex(where: { $0.date == date })

            // Capture stable "operation indices" against original arrays for UITableView
            let oldOpIdx = oldSections.firstIndex(where: { $0.date == date })
            let newOpIdx = newSections.firstIndex(where: { $0.date == date })

            if oldIdxMut == nil, let newIdxMut, let newOpIdx {
                // Section insert
                appliedDeletesSwapsAndEdits.remove(at: newIdxMut)
                insertOperations.append(.insertSection(newOpIdx))
                continue
            }
            if newIdxMut == nil, let oldIdxMut, let oldOpIdx {
                // Section delete
                appliedDeletes.remove(at: oldIdxMut)
                deleteOperations.append(.deleteSection(oldOpIdx))
                continue
            }
            guard let oldIdxMut, let newIdxMut, let oldOpIdx, let newOpIdx else { continue }

            // Rows diff within a section
            var oldRows = appliedDeletes[oldIdxMut].rows
            var newRows = appliedDeletesSwapsAndEdits[newIdxMut].rows

            // Fast path sets/maps
            let oldIDs = oldRows.map(\.id)
            let newIDs = newRows.map(\.id)
            let oldSet = Set(oldIDs)
            let newSet = Set(newIDs)

            let idsToDelete = oldIDs.filter { !newSet.contains($0) }
            let idsToInsert = newIDs.filter { !oldSet.contains($0) }

            // DELETE rows (descending by original index in oldRows)
            if !idsToDelete.isEmpty {
                // Map id -> index in oldRows
                var indexMapOld: [String:Int] = [:]
                for (i, r) in oldRows.enumerated() { indexMapOld[r.id] = i }
                let deleteIdxsDesc = idsToDelete.compactMap { indexMapOld[$0] }.sorted(by: >)
                for idx in deleteIdxsDesc {
                    oldRows.remove(at: idx)
                    deleteOperations.append(.delete(oldOpIdx, idx)) // use stable section index
                }
            }

            // INSERT rows (ascending by index in newRows)
            if !idsToInsert.isEmpty {
                // Map id -> index in newRows
                var indexMapNew: [String:Int] = [:]
                for (i, r) in newRows.enumerated() { indexMapNew[r.id] = i }
                let insertIdxsAsc = idsToInsert.compactMap { indexMapNew[$0] }.sorted()
                for idx in insertIdxsAsc {
                    insertOperations.append(.insert(newOpIdx, idx)) // use stable section index
                }
                // Remove inserted rows from `newRows` to leave only duplicates
                let insertSet = Set(idsToInsert)
                newRows = newRows.filter { !insertSet.contains($0.id) }
            }

            // Now only duplicates remain; lengths might still differ. Protect indexing.
            let count = min(oldRows.count, newRows.count)
            if count > 0 {
                // Build quick map id -> index in newRows for swap detection
                var newPos: [String:Int] = [:]
                for (i, r) in newRows.enumerated() { newPos[r.id] = i }

                for i in 0..<count {
                    let o = oldRows[i]
                    let n = newRows[i]

                    if o.id != n.id {
                        if let target = newPos[o.id], target != i {
                            // Avoid duplicate swaps: ensure both ends not already scheduled
                            if !swapsContain(swaps: swapOperations, section: oldOpIdx, index: i)
                                && !swapsContain(swaps: swapOperations, section: oldOpIdx, index: target) {
                                swapOperations.append(.swap(oldOpIdx, i, target))
                            }
                        }
                    } else if o != n {
                        // Visual content vs. meta changes
                        let oldMsg = o.message
                        let newMsg = n.message

                        let contentChanged =
                            oldMsg.text != newMsg.text ||
                            oldMsg.attachments != newMsg.attachments ||
                            oldMsg.recording != newMsg.recording ||
                            oldMsg.replyMessage?.id != newMsg.replyMessage?.id ||
                            oldMsg.type != newMsg.type ||
                            oldMsg.isDeleted != newMsg.isDeleted

                        let metaChanged =
                            oldMsg.status != newMsg.status ||
                            oldMsg.reactions != newMsg.reactions ||
                            oldMsg.createdAt != newMsg.createdAt

                        if contentChanged || metaChanged {
                            editOperations.append(.edit(oldOpIdx, i, contentChanged))
                        }
                    }
                }
            }

            // Persist filtered rows back to the working copies
            appliedDeletes[oldIdxMut].rows = oldRows
            appliedDeletesSwapsAndEdits[newIdxMut].rows = newRows
        }

        // Normalize operation order: deletes desc, inserts asc
        // Try without this
        deleteOperations.sort { lhs, rhs in
            switch (lhs, rhs) {
            case let (.deleteSection(a), .deleteSection(b)): return a > b
            case let (.delete(sa, ra), .delete(sb, rb)): return sa == sb ? ra > rb : sa > sb
            default: return false
            }
        }
        insertOperations.sort { lhs, rhs in
            switch (lhs, rhs) {
            case let (.insertSection(a), .insertSection(b)): return a < b
            case let (.insert(sa, ra), .insert(sb, rb)): return sa == sb ? ra < rb : sa < sb
            default: return false
            }
        }

        return SplitInfo(
            appliedDeletes: appliedDeletes,
            appliedDeletesSwapsAndEdits: appliedDeletesSwapsAndEdits,
            deleteOperations: deleteOperations,
            swapOperations: swapOperations,
            editOperations: editOperations,
            insertOperations: insertOperations
        )
    }

    private nonisolated func swapsContain(swaps: [Operation], section: Int, index: Int) -> Bool {
        swaps.filter {
            if case let .swap(section, rowFrom, rowTo) = $0 {
                return section == section && (rowFrom == index || rowTo == index)
            }
            return false
        }.count > 0
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(
            viewModel: viewModel, inputViewModel: inputViewModel,
            isScrolledToBottom: $isScrolledToBottom, isScrolledToTop: $isScrolledToTop,
            messageBuilder: messageBuilder, mainHeaderBuilder: mainHeaderBuilder,
            headerBuilder: headerBuilder, type: type, showDateHeaders: showDateHeaders,
            avatarSize: avatarSize, showMessageMenuOnLongPress: showMessageMenuOnLongPress,
            tapAvatarClosure: tapAvatarClosure, tapDocumentClosure: tapDocumentClosure, paginationHandler: paginationHandler, messageStyler: messageStyler,
            
            showMessageTimeView: showMessageTimeView,
             messageFont: messageFont,
            sections: sections, ids: ids, showAvatars: showAvatars, groupUsers: groupUsers, messageUseMarkdown: messageUseMarkdown, mainBackgroundColor: theme.colors.mainBackground)
    }

    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {

        @ObservedObject var viewModel: ChatViewModel
        @ObservedObject var inputViewModel: InputViewModel

        @Binding var isScrolledToBottom: Bool
        @Binding var isScrolledToTop: Bool

        let messageBuilder: MessageBuilderClosure?
        let mainHeaderBuilder: (()->AnyView)?
        let headerBuilder: ((Date)->AnyView)?

        let type: ChatType
        let showDateHeaders: Bool
        let avatarSize: CGFloat
        let showMessageMenuOnLongPress: Bool
        let tapAvatarClosure: ChatView.TapAvatarClosure?
        let paginationHandler: PaginationHandler?
        let messageStyler: (String) -> AttributedString
//        let shouldShowLinkPreview: (URL) -> Bool
        let showMessageTimeView: Bool
//        let messageLinkPreviewLimit: Int
        let messageFont: UIFont
        let tapDocumentClosure: ChatView.TapDocumentClosure?
        let showAvatars: Bool
        let groupUsers: [User]
        let messageUseMarkdown: Bool
        
        var sections: [MessagesSection] {
            didSet {
                if let lastSection = sections.last {
                    paginationTargetIndexPath = IndexPath(row: lastSection.rows.count - 1, section: sections.count - 1)
                }
            }
        }
        let ids: [String]
        let mainBackgroundColor: Color
//        let listSwipeActions: ListSwipeActions

        init(
            viewModel: ChatViewModel, inputViewModel: InputViewModel,
            isScrolledToBottom: Binding<Bool>, isScrolledToTop: Binding<Bool>,
            messageBuilder: MessageBuilderClosure?, mainHeaderBuilder: (() -> AnyView)?,
            headerBuilder: ((Date) -> AnyView)?, type: ChatType, showDateHeaders: Bool,
            avatarSize: CGFloat, showMessageMenuOnLongPress: Bool,
            tapAvatarClosure: ChatView.TapAvatarClosure?, tapDocumentClosure: ChatView.TapDocumentClosure?, paginationHandler: PaginationHandler?,
            messageStyler: @escaping (String) -> AttributedString,
             showMessageTimeView: Bool,
             messageFont: UIFont, sections: [MessagesSection],
            ids: [String], showAvatars: Bool, groupUsers: [User], messageUseMarkdown: Bool, mainBackgroundColor: Color, paginationTargetIndexPath: IndexPath? = nil,
        ) {
            self.viewModel = viewModel
            self.inputViewModel = inputViewModel
            self._isScrolledToBottom = isScrolledToBottom
            self._isScrolledToTop = isScrolledToTop
            self.messageBuilder = messageBuilder
            self.mainHeaderBuilder = mainHeaderBuilder
            self.headerBuilder = headerBuilder
            self.type = type
            self.showDateHeaders = showDateHeaders
            self.avatarSize = avatarSize
            self.showMessageMenuOnLongPress = showMessageMenuOnLongPress
            self.tapAvatarClosure = tapAvatarClosure
            self.tapDocumentClosure = tapDocumentClosure
            self.paginationHandler = paginationHandler
            self.messageStyler = messageStyler
//            self.shouldShowLinkPreview = shouldShowLinkPreview
            self.showMessageTimeView = showMessageTimeView
//            self.messageLinkPreviewLimit = messageLinkPreviewLimit
            self.messageFont = messageFont
            self.sections = sections
            self.ids = ids
            self.showAvatars = showAvatars
            self.groupUsers = groupUsers
            self.messageUseMarkdown = messageUseMarkdown
            self.mainBackgroundColor = mainBackgroundColor
            self.paginationTargetIndexPath = paginationTargetIndexPath
//            self.listSwipeActions = listSwipeActions
        }

        /// call pagination handler when this row is reached
        /// without this there is a bug: during new cells insertion willDisplay is called one extra time for the cell which used to be the last one while it is being updated (its position in group is changed from first to middle)
        var paginationTargetIndexPath: IndexPath?

        func numberOfSections(in tableView: UITableView) -> Int {
            sections.count
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            sections[section].rows.count
        }

        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
            if type == .comments {
                return sectionHeaderView(section)
            }
            return nil
        }

        func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
            if type == .conversation {
                return sectionHeaderView(section)
            }
            return nil
        }

        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                return 0.1
            }
            return type == .conversation ? 0.1 : UITableView.automaticDimension
        }

        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                return 0.1
            }
            return type == .conversation ? UITableView.automaticDimension : 0.1
        }

        func sectionHeaderView(_ section: Int) -> UIView? {
            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
                return nil
            }

            let header = UIHostingController(rootView:
                sectionHeaderViewBuilder(section)
                    .rotationEffect(Angle(degrees: (type == .conversation ? 180 : 0)))
            ).view
            header?.backgroundColor = UIColor(mainBackgroundColor)
            return header
        }
        
//        func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//            guard let items = type == .conversation ? listSwipeActions.trailing : listSwipeActions.leading else { return nil }
//            guard !items.actions.isEmpty else { return nil }
//            let message = sections[indexPath.section].rows[indexPath.row].message
//            let conf = UISwipeActionsConfiguration(actions: items.actions.filter({ $0.activeFor(message) }).map { toContextualAction($0, message: message) })
//            conf.performsFirstActionWithFullSwipe = items.performsFirstActionWithFullSwipe
//            return conf
//        }
//        
//        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//            guard let items = type == .conversation ? listSwipeActions.leading : listSwipeActions.trailing else { return nil }
//            guard !items.actions.isEmpty else { return nil }
//            let message = sections[indexPath.section].rows[indexPath.row].message
//            let conf = UISwipeActionsConfiguration(actions: items.actions.filter({ $0.activeFor(message) }).map { toContextualAction($0, message: message) })
//            conf.performsFirstActionWithFullSwipe = items.performsFirstActionWithFullSwipe
//            return conf
//        }
        
//        private func toContextualAction(_ item: SwipeActionable, message:Message) -> UIContextualAction {
//            let ca = UIContextualAction(style: .normal, title: nil) { (action, sourceView, completionHandler) in
//                item.action(message, self.viewModel.messageMenuAction())
//                completionHandler(true)
//            }
//            ca.image = item.render(type: type)
//            
//            let bgColor = item.background ?? mainBackgroundColor
//            ca.backgroundColor = UIColor(bgColor)
//            
//            return ca
//        }
        
        @ViewBuilder
        func sectionHeaderViewBuilder(_ section: Int) -> some View {
            if let mainHeaderBuilder, section == 0 {
                VStack(spacing: 0) {
                    mainHeaderBuilder()
                    dateViewBuilder(section)
                }
            } else {
                dateViewBuilder(section)
            }
        }

        @ViewBuilder
        func dateViewBuilder(_ section: Int) -> some View {
            if showDateHeaders {
                if let headerBuilder {
                    headerBuilder(sections[section].date)
                } else {
                    Text(sections[section].formattedDate)
                        .font(.system(size: 11))
                        .padding(.top, 30)
                        .padding(.bottom, 8)
                        .foregroundColor(.gray)
                }
            }
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

            let tableViewCell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            tableViewCell.selectionStyle = .none
            tableViewCell.backgroundColor = UIColor(mainBackgroundColor)

            let row = sections[indexPath.section].rows[indexPath.row]
            tableViewCell.contentConfiguration = UIHostingConfiguration {
                ChatMessageView(
                    viewModel: viewModel,
                    messageBuilder: messageBuilder,
                    row: row, chatType: type,
                    avatarSize: avatarSize,
                    tapAvatarClosure: tapAvatarClosure,
                    messageUseMarkdown: messageUseMarkdown,
                    isDisplayingMessageMenu: false,
                    showMessageTimeView: showMessageTimeView,
                    showAvatar: showAvatars,
                    messageFont: messageFont,
                    tapDocumentClosure: tapDocumentClosure,
                    groupUsers: groupUsers)
                .id(row.id)
                .transition(.scale)
                .background(MessageMenuPreferenceViewSetter(id: row.id))
                .rotationEffect(Angle(degrees: (type == .conversation ? 180 : 0)))
                .applyIf(showMessageMenuOnLongPress && !row.message.isDeleted && row.message.type != .status && row.message.type != .call) {
                    $0.simultaneousGesture(
                        TapGesture().onEnded { } // add empty tap to prevent iOS17 scroll breaking bug (drag on cells stops working)
                    )
                    .onLongPressGesture {
                        // Launch the message menu
                        self.viewModel.messageMenuRow = row
                    }
                }
            }
            .minSize(width: 0, height: 0)
            .margins(.all, 0)

            return tableViewCell
        }

        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            guard let paginationHandler = self.paginationHandler, let paginationTargetIndexPath, indexPath == paginationTargetIndexPath else {
                return
            }

            let row = self.sections[indexPath.section].rows[indexPath.row]
            Task.detached {
                await paginationHandler.handleClosure(row.message)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            isScrolledToBottom = scrollView.contentOffset.y <= 0
            isScrolledToTop = scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.frame.height - 1
        }
    }

    func formatRow(_ row: MessageRow) -> String {
        String(
            "id: \(row.id) text: \(row.message.text) status: \(row.message.status ?? .none) date: \(row.message.createdAt) position in user group: \(row.positionInUserGroup) position in messages section: \(row.positionInMessagesSection) trigger: \(row.message.triggerRedraw)"
        )
    }

    func formatSections(_ sections: [MessagesSection]) -> String {
        var res = "{\n"
        for section in sections.reversed() {
            res += String("\t{\n")
            for row in section.rows {
                res += String("\t\t\(formatRow(row))\n")
            }
            res += String("\t}\n")
        }
        res += String("}")
        return res
    }
}

extension UIList {
    struct SplitInfo: @unchecked Sendable {
        let appliedDeletes: [MessagesSection]
        let appliedDeletesSwapsAndEdits: [MessagesSection]
        let deleteOperations: [Operation]
        let swapOperations: [Operation]
        let editOperations: [Operation]
        let insertOperations: [Operation]
    }
}

actor UpdateQueue {
    // MARK: - Tuning
    private let debounce: Duration = .milliseconds(20)    // 20ms debounce
    private let maxWait:  Duration = .milliseconds(120)   // flush at least every 120ms

    // MARK: - State
    private var isProcessing = false
    private var scheduledTask: Task<Void, Never>?
    private var queue: [@Sendable () async -> Void] = []

    private let clock = ContinuousClock()
    private var lastFlush: ContinuousClock.Instant

    init() {
        self.lastFlush = clock.now
    }

    /// Enqueue work; it will be coalesced and executed later.
    /// `urgent: true` triggers immediate flush, preserving batching semantics.
    func enqueue(_ work: @escaping @Sendable () async -> Void, urgent: Bool = false) {
        queue.append(work)

        if urgent {
            scheduledTask?.cancel()
            scheduledTask = Task { await self.processQueue() }
            return
        }

        scheduleNextFlush()
    }

    /// Force immediate processing of everything queued.
    func flush() async {
        scheduledTask?.cancel()
        await processQueue()
    }

    // MARK: - Private

    /// Decide when to run next: debounce but never exceed maxWait.
    private func scheduleNextFlush() {
        scheduledTask?.cancel()

        let sinceLast = clock.now - lastFlush
        let remainingToMax = max(.zero, maxWait - sinceLast)
        let delay = min(debounce, remainingToMax)

        scheduledTask = Task { [clock] in
            if delay > .zero {
                // cooperative cancellation: if task is cancelled, sleep throws — ignoring issue
                try? await clock.sleep(for: delay)
            }
            await self.processQueue()
        }
    }

    /// Drain the queue in batches; re-check if new work arrived while processing.
    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        // we're flushing now; any pending timer — no need
        scheduledTask?.cancel()
        scheduledTask = nil

        defer {
            lastFlush = clock.now
            isProcessing = false
        }

        while !queue.isEmpty {
            let batch = queue
            queue.removeAll()

            for job in batch {
                await job()
            }
        }
    }
}

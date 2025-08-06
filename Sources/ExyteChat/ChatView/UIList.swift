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

//struct UIList<MessageContent: View, InputView: View>: UIViewRepresentable {
//
//    typealias MessageBuilderClosure = ChatView<MessageContent, InputView, DefaultMessageMenuAction>.MessageBuilderClosure
//
//    @Environment(\.chatTheme) private var theme
//
//    @ObservedObject var viewModel: ChatViewModel
//    @ObservedObject var inputViewModel: InputViewModel
//
//    @Binding var isScrolledToBottom: Bool
//    @Binding var shouldScrollToTop: () -> ()
//    @Binding var tableContentHeight: CGFloat
//
//    var messageBuilder: MessageBuilderClosure?
//    var mainHeaderBuilder: (()->AnyView)?
//    var headerBuilder: ((Date)->AnyView)?
//    var inputView: InputView
//
//    let type: ChatType
//    let showDateHeaders: Bool
//    let isScrollEnabled: Bool
//    let avatarSize: CGFloat
//    let showAvatars: Bool
//    let groupUsers: [User]
//    let showMessageMenuOnLongPress: Bool
//    let tapAvatarClosure: ChatView.TapAvatarClosure?
//    let tapDocumentClosure: ChatView.TapDocumentClosure?
//    let paginationHandler: PaginationHandler?
//    let messageUseMarkdown: Bool
//    let showMessageTimeView: Bool
//    let messageFont: UIFont
//    let sections: [MessagesSection]
//    let ids: [String]
//
//    @State private var isScrolledToTop = false
//    
//    @GestureState private var isDetectingLongPress = false
//    
//    var longPress: some Gesture {
//        LongPressGesture(minimumDuration: 0.15)
//            .onEnded { finished in
//                
//            }
//    }
//
//    private let updatesQueue = DispatchQueue(label: "updatesQueue", qos: .utility)
//    @State private var updateSemaphore = DispatchSemaphore(value: 1)
//    @State private var tableSemaphore = DispatchSemaphore(value: 0)
//
//    func makeUIView(context: Context) -> UITableView {
//        let tableView = UITableView(frame: .zero, style: .grouped)
//        tableView.translatesAutoresizingMaskIntoConstraints = false
//        tableView.separatorStyle = .none
//        tableView.dataSource = context.coordinator
//        tableView.delegate = context.coordinator
//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
//        tableView.transform = CGAffineTransform(rotationAngle: (type == .conversation ? .pi : 0))
//
//        tableView.showsVerticalScrollIndicator = false
//        tableView.estimatedSectionHeaderHeight = 1
//        tableView.estimatedSectionFooterHeight = UITableView.automaticDimension
//        tableView.backgroundColor = UIColor(theme.colors.mainBackground)
//        tableView.scrollsToTop = false
//        tableView.isScrollEnabled = isScrollEnabled
//
//        NotificationCenter.default.addObserver(forName: .onScrollToBottom, object: nil, queue: nil) { _ in
//            DispatchQueue.main.async {
//                if !context.coordinator.sections.isEmpty {
//                    tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: true)
//                }
//            }
//        }
//
//        DispatchQueue.main.async {
//            shouldScrollToTop = {
//                tableView.contentOffset = CGPoint(x: 0, y: tableView.contentSize.height - tableView.frame.height)
//            }
//        }
//
//        return tableView
//    }
//
//    func updateUIView(_ tableView: UITableView, context: Context) {
//        if !isScrollEnabled {
//            DispatchQueue.main.async {
//                tableContentHeight = tableView.contentSize.height
//            }
//        }
//
//        if context.coordinator.sections == sections {
//            return
//        }
//        updatesQueue.async {
//            updateSemaphore.wait()
//
//            if context.coordinator.sections == sections {
//                updateSemaphore.signal()
//                return
//            }
//
//            if context.coordinator.sections.isEmpty {
//                DispatchQueue.main.async {
//                    context.coordinator.sections = sections
//                    tableView.reloadData()
//                    if !isScrollEnabled {
//                        DispatchQueue.main.async {
//                            tableContentHeight = tableView.contentSize.height
//                        }
//                    }
//                    updateSemaphore.signal()
//                }
//                return
//            }
//
//            if let lastSection = sections.last {
//                context.coordinator.paginationTargetIndexPath = IndexPath(row: lastSection.rows.count - 1, section: sections.count - 1)
//            }
//
//            let prevSections = context.coordinator.sections
//            let (appliedDeletes, appliedDeletesSwapsAndEdits, deleteOperations, swapOperations, editOperations, insertOperations) = operationsSplit(oldSections: prevSections, newSections: sections)
//
//            // step 1
//            // preapare intermediate sections and operations
//            //print("1 updateUIView sections:", "\n")
//            //print("whole previous:\n", formatSections(prevSections), "\n")
//            //print("whole appliedDeletes:\n", formatSections(appliedDeletes), "\n")
//            //print("whole appliedDeletesSwapsAndEdits:\n", formatSections(appliedDeletesSwapsAndEdits), "\n")
//            //print("whole final sections:\n", formatSections(sections), "\n")
//
//            //print("operations delete:\n", deleteOperations.map { $0.description })
//            //print("operations swap:\n", swapOperations.map { $0.description })
//            //print("operations edit:\n", editOperations.map { $0.description })
//            //print("operations insert:\n", insertOperations.map { $0.description })
//
//            DispatchQueue.main.async {
//                tableView.performBatchUpdates {
//                    // step 2
//                    // delete sections and rows if necessary
//                    //print("2 apply delete")
//                    context.coordinator.sections = appliedDeletes
//                    for operation in deleteOperations {
//                        applyOperation(operation, tableView: tableView)
//                    }
//                } completion: { _ in
//                    tableSemaphore.signal()
//                    //print("2 finished delete")
//                }
//            }
//            tableSemaphore.wait()
//
//            DispatchQueue.main.async {
//                tableView.performBatchUpdates {
//                    // step 3
//                    // swap places for rows that moved inside the table
//                    // (example of how this happens. send two messages: first m1, then m2. if m2 is delivered to server faster, then it should jump above m1 even though it was sent later)
//                    //print("3 apply swaps")
//                    context.coordinator.sections = appliedDeletesSwapsAndEdits // NOTE: this array already contains necessary edits, but won't be a problem for appplying swaps
//                    for operation in swapOperations {
//                        applyOperation(operation, tableView: tableView)
//                    }
//                } completion: { _ in
//                    tableSemaphore.signal()
//                    //print("3 finished swaps")
//                }
//            }
//            tableSemaphore.wait()
//
//            DispatchQueue.main.async {
//                UIView.setAnimationsEnabled(false)
//                tableView.performBatchUpdates {
//                    // step 4
//                    // check only sections that are already in the table for existing rows that changed and apply only them to table's dataSource without animation
//                    //print("4 apply edits")
//                    context.coordinator.sections = appliedDeletesSwapsAndEdits
//
//                    for operation in editOperations {
//                        applyOperation(operation, tableView: tableView)
//                    }
//
//                } completion: { _ in
//                    tableSemaphore.signal()
//                    UIView.setAnimationsEnabled(true)
//                    //print("4 finished edits")
//                }
//            }
//            tableSemaphore.wait()
//
//            if isScrolledToBottom || isScrolledToTop {
//                DispatchQueue.main.sync {
//                    // step 5
//                    // apply the rest of the changes to table's dataSource, i.e. inserts
//                    //print("5 apply inserts")
//                    context.coordinator.sections = sections
//
//                    tableView.beginUpdates()
//                    for operation in insertOperations {
//                        applyOperation(operation, tableView: tableView)
//                    }
//                    tableView.endUpdates()
//
//                    if !isScrollEnabled {
//                        tableContentHeight = tableView.contentSize.height
//                    }
//
//                    updateSemaphore.signal()
//                }
//            } else {
//                updateSemaphore.signal()
//            }
//        }
//    }
//
//    // MARK: - Operations
//
//    enum Operation {
//        case deleteSection(Int)
//        case insertSection(Int)
//
//        case delete(Int, Int) // delete with animation
//        case insert(Int, Int) // insert with animation
//        case swap(Int, Int, Int) // delete first with animation, then insert it into new position with animation. do not do anything with the second for now
//        case edit(Int, Int) // reload the element without animation
//
//        var description: String {
//            switch self {
//            case .deleteSection(let int):
//                return "deleteSection \(int)"
//            case .insertSection(let int):
//                return "insertSection \(int)"
//            case .delete(let int, let int2):
//                return "delete section \(int) row \(int2)"
//            case .insert(let int, let int2):
//                return "insert section \(int) row \(int2)"
//            case .swap(let int, let int2, let int3):
//                return "swap section \(int) rowFrom \(int2) rowTo \(int3)"
//            case .edit(let int, let int2):
//                return "edit section \(int) row \(int2)"
//            }
//        }
//    }
//
//    func applyOperation(_ operation: Operation, tableView: UITableView) {
//        let animation: UITableView.RowAnimation = .top
//        switch operation {
//        case .deleteSection(let section):
//            tableView.deleteSections([section], with: animation)
//        case .insertSection(let section):
//            tableView.insertSections([section], with: animation)
//
//        case .delete(let section, let row):
//            tableView.deleteRows(at: [IndexPath(row: row, section: section)], with: animation)
//        case .insert(let section, let row):
//            tableView.insertRows(at: [IndexPath(row: row, section: section)], with: animation)
//        case .edit(let section, let row):
//            tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
//        case .swap(let section, let rowFrom, let rowTo):
//            tableView.deleteRows(at: [IndexPath(row: rowFrom, section: section)], with: animation)
//            tableView.insertRows(at: [IndexPath(row: rowTo, section: section)], with: animation)
//        }
//    }
//
//    func operationsSplit(oldSections: [MessagesSection], newSections: [MessagesSection]) -> ([MessagesSection], [MessagesSection], [Operation], [Operation], [Operation], [Operation]) {
//        var appliedDeletes = oldSections // start with old sections, remove rows that need to be deleted
//        var appliedDeletesSwapsAndEdits = newSections // take new sections and remove rows that need to be inserted for now, then we'll get array with all the changes except for inserts
//        // appliedDeletesSwapsEditsAndInserts == newSection
//
//        var deleteOperations = [Operation]()
//        var swapOperations = [Operation]()
//        var editOperations = [Operation]()
//        var insertOperations = [Operation]()
//
//        // 1 compare sections
//
//        let oldDates = oldSections.map { $0.date }
//        let newDates = newSections.map { $0.date }
//        let commonDates = Array(Set(oldDates + newDates)).sorted(by: >)
//        for date in commonDates {
//            let oldIndex = appliedDeletes.firstIndex(where: { $0.date == date } )
//            let newIndex = appliedDeletesSwapsAndEdits.firstIndex(where: { $0.date == date } )
//            if oldIndex == nil, let newIndex {
//                // operationIndex is not the same as newIndex because appliedDeletesSwapsAndEdits is being changed as we go, but to apply changes to UITableView we should have initial index
//                if let operationIndex = newSections.firstIndex(where: { $0.date == date } ) {
//                    appliedDeletesSwapsAndEdits.remove(at: newIndex)
//                    insertOperations.append(.insertSection(operationIndex))
//                }
//                continue
//            }
//            if newIndex == nil, let oldIndex {
//                if let operationIndex = oldSections.firstIndex(where: { $0.date == date } ) {
//                    appliedDeletes.remove(at: oldIndex)
//                    deleteOperations.append(.deleteSection(operationIndex))
//                }
//                continue
//            }
//            guard let newIndex, let oldIndex else { continue }
//
//            // 2 compare section rows
//            // isolate deletes and inserts, and remove them from row arrays, leaving only rows that are in both arrays: 'duplicates'
//            // this will allow to compare relative position changes of rows - swaps
//
//            var oldRows = appliedDeletes[oldIndex].rows
//            var newRows = appliedDeletesSwapsAndEdits[newIndex].rows
//            let oldRowIDs = oldRows.map { $0.id }
//            let newRowIDs = newRows.map { $0.id }
//            let rowIDsToDelete = oldRowIDs.filter { !newRowIDs.contains($0) }.reversed()
//            let rowIDsToInsert = newRowIDs.filter { !oldRowIDs.contains($0) }
//            for rowId in rowIDsToDelete {
//                if let index = oldRows.firstIndex(where: { $0.id == rowId }) {
//                    oldRows.remove(at: index)
//                    deleteOperations.append(.delete(oldIndex, index)) // this row was in old section, should not be in final result
//                }
//            }
//            for rowId in rowIDsToInsert {
//                if let index = newRows.firstIndex(where: { $0.id == rowId }) {
//                    // this row was not in old section, should add it to final result
//                    insertOperations.append(.insert(newIndex, index))
//                }
//            }
//
//            for rowId in rowIDsToInsert {
//                if let index = newRows.firstIndex(where: { $0.id == rowId }) {
//                    // remove for now, leaving only 'duplicates'
//                    newRows.remove(at: index)
//                }
//            }
//
//            // 3 isolate swaps and edits
//
//            for i in 0..<oldRows.count {
//                let oldRow = oldRows[i]
//                let newRow = newRows[i]
//                if oldRow.id != newRow.id { // a swap: rows in same position are not actually the same rows
//                    if let index = newRows.firstIndex(where: { $0.id == oldRow.id }) {
//                        if !swapsContain(swaps: swapOperations, section: oldIndex, index: i) ||
//                            !swapsContain(swaps: swapOperations, section: oldIndex, index: index) {
//                            swapOperations.append(.swap(oldIndex, i, index))
//                        }
//                    }
//                } else if oldRow != newRow { // same ids om same positions but something changed - reload rows without animation
//                    editOperations.append(.edit(oldIndex, i))
//                }
//            }
//
//            // 4 store row changes in sections
//
//            appliedDeletes[oldIndex].rows = oldRows
//            appliedDeletesSwapsAndEdits[newIndex].rows = newRows
//        }
//
//        return (appliedDeletes, appliedDeletesSwapsAndEdits, deleteOperations, swapOperations, editOperations, insertOperations)
//    }
//
//    func swapsContain(swaps: [Operation], section: Int, index: Int) -> Bool {
//        swaps.filter {
//            if case let .swap(section, rowFrom, rowTo) = $0 {
//                return section == section && (rowFrom == index || rowTo == index)
//            }
//            return false
//        }.count > 0
//    }
//
//    // MARK: - Coordinator
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(viewModel: viewModel, inputViewModel: inputViewModel, isScrolledToBottom: $isScrolledToBottom, isScrolledToTop: $isScrolledToTop, messageBuilder: messageBuilder, mainHeaderBuilder: mainHeaderBuilder, headerBuilder: headerBuilder, chatTheme: theme, type: type, showDateHeaders: showDateHeaders, avatarSize: avatarSize, showAvatars: showAvatars, groupUsers: groupUsers, showMessageMenuOnLongPress: showMessageMenuOnLongPress, tapAvatarClosure: tapAvatarClosure, tapDocumentClosure: tapDocumentClosure, paginationHandler: paginationHandler, messageUseMarkdown: messageUseMarkdown, showMessageTimeView: showMessageTimeView, messageFont: messageFont, sections: sections, ids: ids, mainBackgroundColor: theme.colors.mainBackground)
//    }
//
//    class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
//
//        @ObservedObject var viewModel: ChatViewModel
//        @ObservedObject var inputViewModel: InputViewModel
//
//        @Binding var isScrolledToBottom: Bool
//        @Binding var isScrolledToTop: Bool
//
//        let messageBuilder: MessageBuilderClosure?
//        let mainHeaderBuilder: (()->AnyView)?
//        let headerBuilder: ((Date)->AnyView)?
//
//        let chatTheme: ChatTheme
//        let type: ChatType
//        let showDateHeaders: Bool
//        let avatarSize: CGFloat
//        let showAvatars: Bool
//        let groupUsers: [User]
//        let showMessageMenuOnLongPress: Bool
//        let tapAvatarClosure: ChatView.TapAvatarClosure?
//        let tapDocumentClosure: ChatView.TapDocumentClosure?
//        let paginationHandler: PaginationHandler?
//        let messageUseMarkdown: Bool
//let showAvatars: Bool
//let groupUsers: [User]
//        let showMessageTimeView: Bool
//        let messageFont: UIFont
//        var sections: [MessagesSection] {
//            didSet {
//                if let lastSection = sections.last {
//                    paginationTargetIndexPath = IndexPath(row: lastSection.rows.count - 1, section: sections.count - 1)
//                }
//            }
//        }
//        let ids: [String]
//        let mainBackgroundColor: Color
//
//        init(
//            viewModel: ChatViewModel,
//            inputViewModel: InputViewModel,
//            isScrolledToBottom: Binding<Bool>,
//            isScrolledToTop: Binding<Bool>,
//            messageBuilder: MessageBuilderClosure?,
//            mainHeaderBuilder: (()->AnyView)?,
//            headerBuilder: ((Date)->AnyView)?,
//            chatTheme: ChatTheme,
//            type: ChatType,
//            showDateHeaders: Bool,
//            avatarSize: CGFloat,
//            showAvatars: Bool,
//            groupUsers: [User],
//            showMessageMenuOnLongPress: Bool,
//            tapAvatarClosure: ChatView.TapAvatarClosure?,
//            tapDocumentClosure: ChatView.TapDocumentClosure?,
//            paginationHandler: PaginationHandler?,
//            messageUseMarkdown: Bool,
//            showMessageTimeView: Bool,
//            messageFont: UIFont,
//            sections: [MessagesSection],
//            ids: [String],
//            mainBackgroundColor:
//            Color,
//            paginationTargetIndexPath: IndexPath? = nil
//        ) {
//            self.viewModel = viewModel
//            self.inputViewModel = inputViewModel
//            self._isScrolledToBottom = isScrolledToBottom
//            self._isScrolledToTop = isScrolledToTop
//            self.messageBuilder = messageBuilder
//            self.mainHeaderBuilder = mainHeaderBuilder
//            self.headerBuilder = headerBuilder
//            self.chatTheme = chatTheme
//            self.type = type
//            self.showDateHeaders = showDateHeaders
//            self.avatarSize = avatarSize
//            self.showAvatars = showAvatars
//            self.groupUsers = groupUsers
//            self.showMessageMenuOnLongPress = showMessageMenuOnLongPress
//            self.tapAvatarClosure = tapAvatarClosure
//            self.tapDocumentClosure = tapDocumentClosure
//            self.paginationHandler = paginationHandler
//            self.messageUseMarkdown = messageUseMarkdown
//            self.showMessageTimeView = showMessageTimeView
//            self.messageFont = messageFont
//            self.sections = sections
//            self.ids = ids
//            self.mainBackgroundColor = mainBackgroundColor
//            self.paginationTargetIndexPath = paginationTargetIndexPath
//             
//            if self.paginationTargetIndexPath == nil, let lastSection = sections.last {
//                self.paginationTargetIndexPath = IndexPath(
//                    row: lastSection.rows.count - 1,
//                    section: sections.count - 1
//                )
//            }
//        }
//
//        /// call pagination handler when this row is reached
//        /// without this there is a bug: during new cells insertion willDisplay is called one extra time for the cell which used to be the last one while it is being updated (its position in group is changed from first to middle)
//        var paginationTargetIndexPath: IndexPath?
//
//        func numberOfSections(in tableView: UITableView) -> Int {
//            sections.count
//        }
//
//        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//            sections[section].rows.count
//        }
//
//        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//            if type == .comments {
//                return sectionHeaderView(section)
//            }
//            return nil
//        }
//
//        func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
//            if type == .conversation {
//                return sectionHeaderView(section)
//            }
//            return nil
//        }
//
//        func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
//                return 0.1
//            }
//            return type == .conversation ? 0.1 : UITableView.automaticDimension
//        }
//
//        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
//            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
//                return 0.1
//            }
//            return type == .conversation ? UITableView.automaticDimension : 0.1
//        }
//
//        func sectionHeaderView(_ section: Int) -> UIView? {
//            if !showDateHeaders && (section != 0 || mainHeaderBuilder == nil) {
//                return nil
//            }
//
//            let header = UIHostingController(rootView:
//                sectionHeaderViewBuilder(section)
//                    .rotationEffect(Angle(degrees: (type == .conversation ? 180 : 0)))
//            ).view
//            header?.backgroundColor = UIColor(chatTheme.colors.mainBackground)
//            return header
//        }
//
//        @ViewBuilder
//        func sectionHeaderViewBuilder(_ section: Int) -> some View {
//            if let mainHeaderBuilder, section == 0 {
//                VStack(spacing: 0) {
//                    mainHeaderBuilder()
//                    dateViewBuilder(section)
//                }
//            } else {
//                dateViewBuilder(section)
//            }
//        }
//
//        @ViewBuilder
//        func dateViewBuilder(_ section: Int) -> some View {
//            if showDateHeaders {
//                if let headerBuilder {
//                    headerBuilder(sections[section].date)
//                } else {
//                    Text(sections[section].formattedDate)
//                        .font(.system(size: 11))
//                        .padding(10)
//                        .padding(.bottom, 8)
//                        .foregroundColor(.gray)
//                }
//            }
//        }
//
//        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//
//            let tableViewCell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
//            tableViewCell.selectionStyle = .none
//            tableViewCell.backgroundColor = UIColor(mainBackgroundColor)
//
//            let row = sections[indexPath.section].rows[indexPath.row]
//            tableViewCell.contentConfiguration = UIHostingConfiguration {
//                ChatMessageView(
//                    viewModel: viewModel,
//                    messageBuilder: messageBuilder,
//                    row: row, chatType: type,
//                    avatarSize: avatarSize,
//                    tapAvatarClosure: tapAvatarClosure,
//                    messageUseMarkdown: messageUseMarkdown,
//                    isDisplayingMessageMenu: false,
//                    showMessageTimeView: showMessageTimeView, 
//                    showAvatar: showAvatars,
//                    messageFont: messageFont,
//                    tapDocumentClosure: tapDocumentClosure,
//                    groupUsers: groupUsers)
//                    .transition(.scale)
//                    .background(MessageMenuPreferenceViewSetter(id: row.id))
//                    .rotationEffect(Angle(degrees: (type == .conversation ? 180 : 0)))
//                    .applyIf(showMessageMenuOnLongPress && !row.message.isDeleted && row.message.type != .status && row.message.type != .call) {
//                        $0.highPriorityGesture(LongPressGesture(minimumDuration: 0.15)
//                            .onEnded({ _ in
//                                let generator = UIImpactFeedbackGenerator(style: .medium)
//                                generator.prepare()
//                                generator.impactOccurred()
//                                self.viewModel.messageMenuRow = row
//                        }))
//                    }
//            }
//            .minSize(width: 0, height: 0)
//            .margins(.all, 0)
//
//            return tableViewCell
//        }
//
//        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//            guard let paginationHandler = self.paginationHandler, let paginationTargetIndexPath, indexPath == paginationTargetIndexPath else {
//                return
//            }
//
//            let row = self.sections[indexPath.section].rows[indexPath.row]
//            Task.detached {
//                await paginationHandler.handleClosure(row.message)
//            }
//        }
//
//        func scrollViewDidScroll(_ scrollView: UIScrollView) {
//            let contentOffsetY = scrollView.contentOffset.y.rounded(.down)
//            let contentSizeHeight = scrollView.contentSize.height.rounded(.down)
//            let scrollViewHeight = scrollView.frame.height.rounded(.down)
//            isScrolledToBottom = contentOffsetY <= 0
//            isScrolledToTop = contentOffsetY >= contentSizeHeight - scrollViewHeight - 100
//        }
//    }
//
//    func formatRow(_ row: MessageRow) -> String {
//        if let status = row.message.status {
//            return String("id: \(row.id) text: \(row.message.text) status: \(status) date: \(row.message.createdAt) position: \(row.positionInUserGroup) trigger: \(row.message.triggerRedraw)")
//        }
//        return ""
//    }
//
//    func formatSections(_ sections: [MessagesSection]) -> String {
//        var res = "{\n"
//        for section in sections.reversed() {
//            res += String("\t{\n")
//            for row in section.rows {
//                res += String("\t\t\(formatRow(row))\n")
//            }
//            res += String("\t}\n")
//        }
//        res += String("}")
//        return res
//    }
//}
//
//  UIList.swift
//
//
//  Created by Alisa Mylnikova on 24.02.2023.
//

import SwiftUI

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
//        tableView.backgroundColor = UIColor(theme.colors.mainBG)
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
        
        if context.coordinator.sections == sections {
            return
        }

        Task {
            await updateQueue.enqueue() {
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
        case edit(Int, Int) // reload the element without animation

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
            case .edit(let int, let int2):
                return "edit section \(int) row \(int2)"
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
        case .edit(let section, let row):
            // tableView.reconfigureRows(at: [IndexPath(row: row, section: section)])
            // ⚠️ This only works if the cell uses `contentConfiguration` (e.g., UIListContentConfiguration or a custom UIContentConfiguration).
            // It does NOT trigger `cellForRow(at:)`, nor will it update views added manually via subviews or custom layout code.
            // Use `reloadRows(at:with:)` instead if the cell is configured manually or does not rely on contentConfiguration.
            tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .automatic)
        case .swap(let section, let rowFrom, let rowTo):
            tableView.deleteRows(at: [IndexPath(row: rowFrom, section: section)], with: animation)
            tableView.insertRows(at: [IndexPath(row: rowTo, section: section)], with: animation)
        }
    }

    private nonisolated func operationsSplit(oldSections: [MessagesSection], newSections: [MessagesSection]) -> SplitInfo {
        var appliedDeletes = oldSections // start with old sections, remove rows that need to be deleted
        var appliedDeletesSwapsAndEdits = newSections // take new sections and remove rows that need to be inserted for now, then we'll get array with all the changes except for inserts
        // appliedDeletesSwapsEditsAndInserts == newSection

        var deleteOperations = [Operation]()
        var swapOperations = [Operation]()
        var editOperations = [Operation]()
        var insertOperations = [Operation]()

        // 1 compare sections

        let oldDates = oldSections.map { $0.date }
        let newDates = newSections.map { $0.date }
        let commonDates = Array(Set(oldDates + newDates)).sorted(by: >)
        for date in commonDates {
            let oldIndex = appliedDeletes.firstIndex(where: { $0.date == date } )
            let newIndex = appliedDeletesSwapsAndEdits.firstIndex(where: { $0.date == date } )
            if oldIndex == nil, let newIndex {
                // operationIndex is not the same as newIndex because appliedDeletesSwapsAndEdits is being changed as we go, but to apply changes to UITableView we should have initial index
                if let operationIndex = newSections.firstIndex(where: { $0.date == date } ) {
                    appliedDeletesSwapsAndEdits.remove(at: newIndex)
                    insertOperations.append(.insertSection(operationIndex))
                }
                continue
            }
            if newIndex == nil, let oldIndex {
                if let operationIndex = oldSections.firstIndex(where: { $0.date == date } ) {
                    appliedDeletes.remove(at: oldIndex)
                    deleteOperations.append(.deleteSection(operationIndex))
                }
                continue
            }
            guard let newIndex, let oldIndex else { continue }

            // 2 compare section rows
            // isolate deletes and inserts, and remove them from row arrays, leaving only rows that are in both arrays: 'duplicates'
            // this will allow to compare relative position changes of rows - swaps

            var oldRows = appliedDeletes[oldIndex].rows
            var newRows = appliedDeletesSwapsAndEdits[newIndex].rows
            let oldRowIDs = oldRows.map { $0.id }
            let newRowIDs = newRows.map { $0.id }
            let rowIDsToDelete = oldRowIDs.filter { !newRowIDs.contains($0) }.reversed()
            let rowIDsToInsert = newRowIDs.filter { !oldRowIDs.contains($0) }
            for rowId in rowIDsToDelete {
                if let index = oldRows.firstIndex(where: { $0.id == rowId }) {
                    oldRows.remove(at: index)
                    deleteOperations.append(.delete(oldIndex, index)) // this row was in old section, should not be in final result
                }
            }
            for rowId in rowIDsToInsert {
                if let index = newRows.firstIndex(where: { $0.id == rowId }) {
                    // this row was not in old section, should add it to final result
                    insertOperations.append(.insert(newIndex, index))
                }
            }

            for rowId in rowIDsToInsert {
                if let index = newRows.firstIndex(where: { $0.id == rowId }) {
                    // remove for now, leaving only 'duplicates'
                    newRows.remove(at: index)
                }
            }

            // 3 isolate swaps and edits

            for i in 0..<oldRows.count {
                let oldRow = oldRows[i]
                let newRow = newRows[i]
                if oldRow.id != newRow.id { // a swap: rows in same position are not actually the same rows
                    if let index = newRows.firstIndex(where: { $0.id == oldRow.id }) {
                        if !swapsContain(swaps: swapOperations, section: oldIndex, index: i) ||
                            !swapsContain(swaps: swapOperations, section: oldIndex, index: index) {
                            swapOperations.append(.swap(oldIndex, i, index))
                        }
                    }
                } else if oldRow != newRow { // same ids om same positions but something changed - reload rows without animation
                    editOperations.append(.edit(oldIndex, i))
                }
            }

            // 4 store row changes in sections

            appliedDeletes[oldIndex].rows = oldRows
            appliedDeletesSwapsAndEdits[newIndex].rows = newRows
        }

        return SplitInfo(appliedDeletes: appliedDeletes, appliedDeletesSwapsAndEdits: appliedDeletesSwapsAndEdits, deleteOperations: deleteOperations, swapOperations: swapOperations, editOperations: editOperations, insertOperations: insertOperations)
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
//        Coordinator(
//            viewModel: viewModel, inputViewModel: inputViewModel,
//            isScrolledToBottom: $isScrolledToBottom, isScrolledToTop: $isScrolledToTop,
//            messageBuilder: messageBuilder, mainHeaderBuilder: mainHeaderBuilder,
//            headerBuilder: headerBuilder, type: type, showDateHeaders: showDateHeaders,
//            avatarSize: avatarSize, showMessageMenuOnLongPress: showMessageMenuOnLongPress,
//            tapAvatarClosure: tapAvatarClosure, tapDocumentClosure: tapDocumentClosure, paginationHandler: paginationHandler,
//            messageStyler: messageStyler, shouldShowLinkPreview: shouldShowLinkPreview,
//            showMessageTimeView: showMessageTimeView,
//            messageLinkPreviewLimit: messageLinkPreviewLimit, messageFont: messageFont,
//            sections: sections, ids: ids, showAvatars: showAvatars, groupUsers: groupUsers, messageUseMarkdown: messageUseMarkdown)
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
//        let mainBackgroundColor: Color
        
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

        private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)

        init(
//            viewModel: ChatViewModel, inputViewModel: InputViewModel,
//            isScrolledToBottom: Binding<Bool>, isScrolledToTop: Binding<Bool>,
//            messageBuilder: MessageBuilderClosure?, mainHeaderBuilder: (() -> AnyView)?,
//            headerBuilder: ((Date) -> AnyView)?, type: ChatType, showDateHeaders: Bool,
//            avatarSize: CGFloat, showMessageMenuOnLongPress: Bool,
//            tapAvatarClosure: ChatView.TapAvatarClosure?, tapDocumentClosure: ChatView.TapDocumentClosure?, paginationHandler: PaginationHandler?,
//            messageStyler: @escaping (String) -> AttributedString,
//            shouldShowLinkPreview: @escaping (URL) -> Bool, showMessageTimeView: Bool,
//            messageLinkPreviewLimit: Int, messageFont: UIFont, sections: [MessagesSection],
//            ids: [String], showAvatars: Bool, groupUsers: [User], messageUseMarkdown: Bool, paginationTargetIndexPath: IndexPath? = nil,
//            listSwipeActions: ListSwipeActions
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
//                ChatMessageView(
//                    viewModel: viewModel, messageBuilder: messageBuilder, row: row, chatType: type,
//                    avatarSize: avatarSize, tapAvatarClosure: tapAvatarClosure,
//                    messageStyler: messageStyler, shouldShowLinkPreview: shouldShowLinkPreview,
//                    isDisplayingMessageMenu: false, showMessageTimeView: showMessageTimeView,
//                    messageLinkPreviewLimit: messageLinkPreviewLimit, messageFont: messageFont
//                )
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
                .transition(.scale)
                .background(MessageMenuPreferenceViewSetter(id: row.id))
                .rotationEffect(Angle(degrees: (type == .conversation ? 180 : 0)))
                .applyIf(showMessageMenuOnLongPress) {
                    $0.simultaneousGesture(
                        TapGesture().onEnded { } // add empty tap to prevent iOS17 scroll breaking bug (drag on cells stops working)
                    )
                    .onLongPressGesture {
                        // Trigger haptic feedback
                        self.impactGenerator.impactOccurred()
                        // Launch the message menu
                        self.viewModel.messageMenuRow = row
                    }
                }
            }
            .minSize(width: 0, height: 0)
            .margins(.all, 0)

            return tableViewCell
        }

//        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//            guard let paginationHandler = self.paginationHandler, let paginationTargetIndexPath, indexPath == paginationTargetIndexPath else {
//                return
//            }
//
//            let row = self.sections[indexPath.section].rows[indexPath.row]
//            Task.detached {
//                await paginationHandler.handleClosure(row.message)
//            }
//        }
        func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
            print("➡️ willDisplay called for indexPath: \(indexPath)")
            print("🎯 paginationTargetIndexPath: \(paginationTargetIndexPath?.description ?? "nil")")

            guard let paginationHandler = self.paginationHandler,
                  let paginationTargetIndexPath,
                  indexPath == paginationTargetIndexPath else {
                return
            }

            print("🟢 pagination triggered at indexPath: \(indexPath)")
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
    private var isProcessing = false

    func enqueue(_ work: @escaping @Sendable () async -> Void) async {
        while isProcessing {
            await Task.yield() // Wait for previous task to finish
        }

        isProcessing = true
        await work()
        isProcessing = false
    }
}

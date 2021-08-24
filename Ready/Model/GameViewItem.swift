/*
 GameViewItem.swift -- Common Interface to Game, Inbox, and Tools
 Copyright (C) 2019 Dieter Baron
 
 This file is part of Ready, a home computer emulator for iPad.
 The authors can be contacted at <ready@tpau.group>.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 2. The names of the authors may not be used to endorse or promote
 products derived from this software without specific prior
 written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import C64UIComponents
import Emulator

enum GameViewItemType {
    case game
    case inbox
    case tools
}

struct GameViewItemMedia {
    class Changes {
        class PendingItems {
            var rows = Set<Int>()
            
            func add(_ row: Int) -> Int {
                let adjustedRow = row + rows.count
                rows.insert(adjustedRow)
                return adjustedRow
            }
            
            func remove(_ row: Int) -> Int {
                let adjustedRow = row - rows.filter({ $0 < row }).count
                rows.remove(row)
                return adjustedRow
            }
        }
        
        enum Item {
            case move(row: Int)
            case drag(UIDragItem)
            case dragGmod2(flash: UIDragItem, eeprom: UIDragItem)
            case file(url: URL, filetype: C64FileType)
            case fileGmod2(flash: URL, eeprom: URL)
        }
        
        var destinationIndexPath: IndexPath?
        var gameViewItem: GameViewItem
        var media: GameViewItemMedia
        weak var tableView: UITableView?
        weak var gameViewController: GameViewController?

        var sections: [[Item]]
        var destinationSectionIndex: Int? = nil
        
        struct Gmod2Part {
            var indexPath: IndexPath
            var isFlash: Bool
        }
        var gmod2parts = [String: Gmod2Part]()
        
        var tableViewUpdates = TableViewUpdates()

        init?(gameViewController: GameViewController, destinationIndexPath: IndexPath?) {
            guard let gameViewItem = gameViewController.gameViewItem else { return nil }
            self.gameViewController = gameViewController
            self.gameViewItem = gameViewItem
            media = gameViewController.media
            self.tableView = gameViewController.mediaTableView
            self.destinationIndexPath = destinationIndexPath
            
            if let destinationIndexPath = destinationIndexPath {
                destinationSectionIndex = media.sectionIndexFor(activeIndex: destinationIndexPath.section)
            }
            sections = [[Item]](repeating: [Item](), count: media.sections.count)
        }
        
        func move(from sourceIndexPath: IndexPath) {
            // can't move if no explicit destination is provided
            guard let destinationSectionIndex = destinationSectionIndex else { return }
            // can't move between sections
            guard sourceIndexPath.section == destinationIndexPath?.section else { return }

            sections[destinationSectionIndex].append(.move(row: sourceIndexPath.row))
        }

        func add(dragItem: UIDragItem) {
            guard let sectionIndex = media.sectionIndexFor(typeIdentifiers: Set<String>(dragItem.itemProvider.registeredTypeIdentifiers)) else { return }
            
            add(item: .drag(dragItem), sectionIndex: sectionIndex)
        }
        
        func add(url: URL) {
            guard let fileType = C64FileType.init(pathExtension: url.pathExtension) else { return }
            guard let sectionIndex = media.sectionIndexFor(typeIdentifiers: [fileType.typeIdentifier]) else { return }
            
            add(item: .file(url: url, filetype: fileType), sectionIndex: sectionIndex)
        }
        
        private func add(item: Item, sectionIndex: Int) {
            if !handleGmod2(item: item, sectionIndex: sectionIndex) {
                sections[sectionIndex].append(item)
            }
        }
        
        private func handleGmod2(item: Item, sectionIndex: Int) -> Bool {
            let name: String?
            
            switch item {
            case .drag(let dragItem):
                name = dragItem.itemProvider.suggestedName
                
            case .file(let url, _):
                name = url.lastPathComponent
                
            default:
                return false
            }
            
            guard let gmod2Info = Gmod2(suggestedName: name) else { return false }
            
            if let part = gmod2parts[gmod2Info.name] {
                guard part.isFlash != gmod2Info.isFlash else { return false }
                let otherItem = sections[part.indexPath.section][part.indexPath.row]
                let newItem: Item
                switch (item, otherItem) {
                case (.drag(let dragItem), .drag(let otherDragItem)):
                    if part.isFlash {
                        newItem = .dragGmod2(flash: otherDragItem, eeprom: dragItem)
                    }
                    else {
                        newItem = .dragGmod2(flash: dragItem, eeprom: otherDragItem)
                    }
                    
                case (.file(let url, _), .file(let otherUrl, _)):
                    if part.isFlash {
                        newItem = .fileGmod2(flash: otherUrl, eeprom: url)
                    }
                    else {
                        newItem = .fileGmod2(flash: url, eeprom: otherUrl)
                    }
                    
                default:
                    return false
                }
                sections[part.indexPath.section][part.indexPath.row] = newItem
                gmod2parts[gmod2Info.name] = nil
                return true
            }
            else {
                gmod2parts[gmod2Info.name] = Gmod2Part(indexPath: IndexPath(row: sections[sectionIndex].count, section: sectionIndex), isFlash: gmod2Info.isFlash)
                return false
            }
        }
        
        var activeSection = 0
        var newActiveSection = 0

        func execute() {
            tableViewUpdates.clear()
            
            for index in media.sections.indices {
                execute(sectionIndex: index)

                let wasActive = media.sections[index].isActive
                let isActive = gameViewItem.media.sections[index].isActive
                
                if wasActive && !isActive {
                    tableViewUpdates.delete(section: activeSection)
                }
                
                if !wasActive && isActive {
                    tableViewUpdates.insert(section: newActiveSection)
                }
                
                if wasActive {
                    activeSection += 1
                }
                if isActive {
                    newActiveSection += 1
                }
            }
            
            if gameViewItem.type != .inbox, let gameViewController = gameViewController {
                gameViewController.media = gameViewItem.media
                print("applying gameviewitemchanges updates: \(tableViewUpdates.insertedRows.count)")
                tableViewUpdates.apply(to: gameViewController.mediaTableView, animation: .automatic)
            }
            
            tableViewUpdates.clear()
        }
        
        private func execute(sectionIndex: Int) {
            let items = sections[sectionIndex]
            guard !items.isEmpty else { return }
            
            let sectionType = media.sections[sectionIndex].type

            if media.sections[sectionIndex].supportsMultiple {
                let pendingItems = PendingItems()
                var destinationRow = destinationRowFor(sectionIndex: sectionIndex)
                let movedRows = Set<Int>()
                
                var offset = 0
                
                for item in items {
                    switch item {
                    case .move(let row):
                        if row < destinationRow {
                            offset -= 1
                        }
                        
                    default:
                        break
                    }
                }
                
                for item in items {
                    switch item {
                    case .drag(let dragItem):
                        let adjustedRow = pendingItems.add(destinationRow)
                        load(from: dragItem.itemProvider, sectionIndex: sectionIndex, pendingItems: pendingItems, destinationRow: adjustedRow)
                        
                    case .dragGmod2(let flashItem, let eepromItem):
                        let adjustedRow = pendingItems.add(destinationRow)
                        loadGmod2(flashItem: flashItem.itemProvider, eepromItem: eepromItem.itemProvider, sectionIndex: sectionIndex, pendingItems: pendingItems, destinationRow: adjustedRow)

                    case .file(let url, let fileType):
                        if load(from: url, fileType: fileType, sectionIndex: sectionIndex, destinationRow: destinationRow) {
                            destinationRow += 1
                        }

                    case .fileGmod2(let flashURL, let eepromURL):
                        if loadGmod2(flashURL: flashURL, eepromURL: eepromURL, sectionIndex: sectionIndex, destinationRow: destinationRow) {
                            destinationRow += 1
                        }

                    case .move(var row):
                        row -= movedRows.filter({ $0 < row }).count
                        if row < destinationRow {
                            destinationRow -= 1
                        }
                        gameViewItem.moveMedia(from: row, to: destinationRow, sectionType: sectionType)
                        tableViewUpdates.move(row: IndexPath(row: row, section: activeSection), to: IndexPath(row: destinationRow, section: newActiveSection))
                        destinationRow += 1
                    }
                }
            }
            else {
                switch items[0] {
                case .drag(let dragItem):
                    load(from: dragItem.itemProvider, sectionIndex: sectionIndex, pendingItems: nil, destinationRow: 0)
                    
                case .dragGmod2(let flashItem, let eepromItem):
                    loadGmod2(flashItem: flashItem.itemProvider, eepromItem: eepromItem.itemProvider, sectionIndex: sectionIndex, pendingItems: nil, destinationRow: 0)
                    
                case .file(let url, let fileType):
                    _ = load(from: url, fileType: fileType, sectionIndex: sectionIndex, destinationRow: nil)
                    
                case .fileGmod2(let flashURL, let eepromURL):
                    _ = loadGmod2(flashURL: flashURL, eepromURL: eepromURL, sectionIndex: sectionIndex, destinationRow: nil)
                    
                case .move(_):
                    break
                }
            }
        }
        
        private func destinationRowFor(sectionIndex: Int) -> Int {
            if let destinationIndexPath = destinationIndexPath, sectionIndex == destinationSectionIndex {
                return destinationIndexPath.row
            }
            if media.sections[sectionIndex].addInFront {
                return 0
            }
            return media.sections[sectionIndex].items.count
        }
        
        private func load(from itemProvider: NSItemProvider, sectionIndex: Int,  pendingItems: PendingItems?, destinationRow: Int) {
            gameViewItem.loadMediaItem(from: itemProvider) { mediaItem in
                guard let mediaItem = mediaItem else { return }
                DispatchQueue.main.async {
                    self.addPending(mediaItem: mediaItem, sectionIndex: sectionIndex, pendingItems: pendingItems, destinationRow: destinationRow)
                }
            }
        }
        
        private func loadGmod2(flashItem: NSItemProvider, eepromItem: NSItemProvider, sectionIndex: Int, pendingItems: PendingItems?, destinationRow: Int) {
            gameViewItem.loadGmod2(flashItem: flashItem, eepromItem: eepromItem) { mediaItem in
                guard let mediaItem = mediaItem else { return }
                DispatchQueue.main.async {
                    self.addPending(mediaItem: mediaItem, sectionIndex: sectionIndex, pendingItems: pendingItems, destinationRow: destinationRow)
                }
            }
        }
        
        private func addPending(mediaItem: MediaItem, sectionIndex: Int, pendingItems: PendingItems?, destinationRow: Int) {
            let sectionType = media.sections[sectionIndex].type
            var row: Int
            if let pendingItems = pendingItems {
                row = pendingItems.remove(destinationRow)
                self.gameViewItem.addMedia(mediaItem: mediaItem, at: row, sectionType: sectionType)
                
            }
            else {
                row = 0
                self.gameViewItem.replaceMedia(mediaItem: mediaItem, sectionType: sectionType)
            }
            
            guard gameViewItem.type != .inbox else { return } // Inbox propagates changes itself
            guard let gameViewController = self.gameViewController else { return }
            let wasActive = gameViewController.media.sections[sectionIndex].isActive
            gameViewController.media = self.gameViewItem.media
            guard let activeSectionIndex = gameViewController.media.activeSectionIndex(for: sectionType) else { return }
            
            let indexPath = IndexPath(row: row, section: activeSectionIndex)
            if !wasActive {
                self.tableView?.insertSections([activeSectionIndex], with: .automatic)
            }
            else if pendingItems != nil {
                self.tableView?.insertRows(at: [indexPath], with: .automatic)
            }
            else {
                self.tableView?.reloadRows(at: [indexPath], with: .automatic)
            }
        }
        
        private func load(from url: URL, fileType: C64FileType, sectionIndex: Int, destinationRow: Int?) -> Bool {
            guard let mediaItem = gameViewItem.addMediaItem(name: url.lastPathComponent, fileType: fileType, url: url, copy: true) else { return false }
                
            add(mediaItem: mediaItem, at: destinationRow, sectionIndex: sectionIndex)
            return true
        }
        
        private func loadGmod2(flashURL: URL, eepromURL: URL, sectionIndex: Int, destinationRow: Int?) -> Bool {
            do {
                let flashData = try Data(contentsOf: flashURL)
                let eepromData = try Data(contentsOf: eepromURL)
                
                guard let mediaItem = gameViewItem.addGmod2(name: flashURL.lastPathComponent, flashData: flashData, eepromData: eepromData) else { return false }
                
                add(mediaItem: mediaItem, at: destinationRow, sectionIndex: sectionIndex)
                return true
            }
            catch {
                return false
            }
        }
        
        func add(mediaItem: MediaItem, at destinationRow: Int?, sectionIndex: Int) {
            let sectionType = media.sections[sectionIndex].type
            
            if let destinationRow = destinationRow {
                gameViewItem.addMedia(mediaItem: mediaItem, at: destinationRow, sectionType: sectionType)

                if media.sections[sectionIndex].isActive {
                    tableViewUpdates.insert(row: IndexPath(row: destinationRow, section: newActiveSection))
                }
            }
            else {
                gameViewItem.replaceMedia(mediaItem: mediaItem, sectionType: sectionType)
                
                if media.sections[sectionIndex].isActive {
                    tableViewUpdates.reload(row: IndexPath(row: 0, section: newActiveSection))
                }
            }
        }
    }

    enum SectionType {
        case cartridge
        case disks
        case ideDisks
        case programFile
        case ramExpansionUnit
        case tapes
        case mixed
        
        var supportedTypeIdentifiers: Set<String> {
            switch self {
            case .cartridge:
                return C64FileType.MediaType.cartridge.typeIdentifiers
            case .disks:
                return C64FileType.MediaType.disk.typeIdentifiers
            case .ideDisks:
                return C64FileType.MediaType.ideDisk.typeIdentifiers
            case .programFile:
                return C64FileType.MediaType.programFile.typeIdentifiers
            case .ramExpansionUnit:
                return C64FileType.MediaType.ramExpansionUnit.typeIdentifiers
            case .tapes:
                return C64FileType.MediaType.tape.typeIdentifiers
            case .mixed:
                return C64FileType.typeIdentifiers
            }
        }
        
        func title(plural: Bool) -> String? {
            switch self {
            case .cartridge:
                return plural ? "Cartridges" : "Cartridge"
                
            case .disks:
                return plural ? "Disks" : "Disk"
                
            case .ideDisks:
                return plural ? "IDE Disks" : "IDE Disk"
                
            case .mixed:
                return nil
                
            case .programFile:
                return plural ? "Progarm Files" : "Program File"
                
            case .ramExpansionUnit:
                return plural ? "RAM Expansion Images" : "RAM Expansion Image"
                
            case .tapes:
                return plural ? "Tapes" : "Tape"
            }
        }
    }
    
    struct Section {
        var type: SectionType
        var supportsMultiple: Bool
        var supportsReorder: Bool
        var addInFront: Bool
        var items: [MediaItem]
     
        var isActive: Bool {
            return true
        }
        var title: String? {
            return type.title(plural: supportsMultiple)
        }
    }
    
    init(sections: [Section]) {
        self.sections = sections
    }
    
    var sections: [Section]
    
    var isEmpty: Bool {
        return sections.count == 0 || sections[0].items.isEmpty
    }
    
    var supportedTypeIdentifiers: Set<String> {
        var typeIdentifiers = Set<String>()
        
        for section in sections {
            typeIdentifiers = typeIdentifiers.union(section.type.supportedTypeIdentifiers)
        }
        
        return typeIdentifiers
    }
    
    func item(for indexPath: IndexPath) -> MediaItem {
        return sections[indexPath.section].items[indexPath.row]
    }
    
    func sectionIndexFor(activeIndex: Int) -> Int {
        var count = activeIndex
        for (index, section) in sections.enumerated() {
            if section.isActive {
                if count == 0 {
                    return index
                }
                count -= 1
            }
        }
        fatalError("activeIndex out of bounds")
    }
    
    func sectionIndexFor(typeIdentifiers: Set<String>) -> Int? {
        for (index, section) in sections.enumerated() {
            if !section.type.supportedTypeIdentifiers.isDisjoint(with: typeIdentifiers) {
                return index
            }
        }
        return nil
    }
    
    func activeSectionIndex(for sectionType: SectionType) -> Int? {
        return sections.firstIndex(where: { $0.type == sectionType })
    }
}


extension GameViewItemMedia: Equatable {
    static func == (lhs: GameViewItemMedia, rhs: GameViewItemMedia) -> Bool {
        guard lhs.sections.count == rhs.sections.count else { return false }
        for index in lhs.sections.indices {
            guard lhs.sections[index].type == rhs.sections[index].type else { return false }
            guard lhs.sections[index].items.count == rhs.sections[index].items.count else { return false }
            for itemIndex in lhs.sections[index].items.indices {
                guard lhs.sections[index].items[itemIndex].url == rhs.sections[index].items[itemIndex].url else { return false }
            }
        }
        return true
    }
    
    
}


protocol GameViewItem {
    var type: GameViewItemType { get }
    
    var title: String { get }
    var directoryURL: URL { get }
    
    var media: GameViewItemMedia { get }
        
    func addScreenshot(url: URL)
    func loadScreenshots(completion: @escaping (_: [UIImage]) -> Void)

    var machine: MachineOld { get }

    func addMedia(mediaItem: MediaItem, at: Int, sectionType: GameViewItemMedia.SectionType)
    func moveMedia(from sourceRow: Int, to destinationRow: Int, sectionType: GameViewItemMedia.SectionType)
    func removeMedia(at: Int, sectionType: GameViewItemMedia.SectionType)
    func renameMedia(name: String, at: Int, sectionType: GameViewItemMedia.SectionType)
    func replaceMedia(mediaItem: MediaItem, sectionType: GameViewItemMedia.SectionType)

    func save() throws
}

extension GameViewItem {
    func addScreenshot(url: URL) {
        _ = addFile(name: "screenshot", pathExtension: "png", url: url)
    }

    func loadScreenshots(completion: @escaping (_: [UIImage]) -> Void) {
        let directoryURL = self.directoryURL
        DispatchQueue.global(qos: .userInteractive).async {
            let fileManager = FileManager.default
            
            do {
                let screenshots = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.creationDateKey], options: []).filter({ $0.lastPathComponent.hasPrefix("screenshot") && $0.pathExtension == "png" }).sorted(by: {
                    let a = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let b = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    switch (a, b) {
                    case (nil, nil):
                        return false
                    case (nil, _):
                        return false
                    case (_, nil):
                        return true
                    case (_, _):
                        return a! < b!
                    }
                }).compactMap({ UIImage(contentsOfFile: $0.path )})
                DispatchQueue.main.async {
                    completion(screenshots)
                }
            }
            catch {
                
            }
        }
    }
    
    func addMediaItem(name: String?, fileType: C64FileType, url: URL, copy: Bool = true) -> MediaItem? {
        guard let url = self.addFile(name: name, pathExtension: fileType.pathExtension, url: url, copy: copy) else { return nil }
        
        let mediaItem = CartridgeImage.loadMediaItem(from: url)
        
        if mediaItem == nil {
            do {
                try FileManager.default.removeItem(at: url)
            }
            catch { }
        }
        
        return mediaItem
    }
    
    func addGmod2(name: String?, flashData: Data, eepromData: Data) -> MediaItem? {
        let crtName = (name ?? "unnamed").replacingOccurrences(of: "(-flash)?.bin", with: "", options: [.regularExpression], range: nil)

        let crt = Gmod2Crt(flash: flashData, eeprom: eepromData)
        guard let crtURL = self.addFile(name: crtName, pathExtension: "crt", data: crt.crt) else { return nil }

        guard let cartridge = CartridgeImage(directory: directoryURL, file: crtURL.lastPathComponent) else {
            try? FileManager.default.removeItem(at: crtURL)
            return nil
        }
        
        return cartridge
    }
    
    func loadMediaItem(from itemProvider: NSItemProvider, completionHandler: @escaping ((MediaItem?) -> Void)) {
        guard let fileType = C64FileType.type(for: itemProvider.registeredTypeIdentifiers) else {
            completionHandler(nil)
            return
        }
        
        itemProvider.loadFileRepresentation(forTypeIdentifier: fileType.typeIdentifier) { url, error in
            guard let url = url, error == nil else {
                completionHandler(nil)
                return
            }
            
            let mediaItem = self.addMediaItem(name: itemProvider.suggestedName, fileType: fileType, url: url, copy: false)
            
            completionHandler(mediaItem)
        }
    }
    
    func loadGmod2(flashItem: NSItemProvider, eepromItem: NSItemProvider, completionHandler: @escaping ((MediaItem?) -> Void)) {
        guard let fileType = C64FileType(pathExtension: "bin") else {
            completionHandler(nil)
            return
        }
        
        flashItem.loadDataRepresentation(forTypeIdentifier: fileType.typeIdentifier) { data, error in
            guard let flashData = data, error == nil else {
                completionHandler(nil)
                return
            }
            
            eepromItem.loadDataRepresentation(forTypeIdentifier: fileType.typeIdentifier) { data, error in
                guard let eepromData = data, error == nil else {
                    completionHandler(nil)
                    return
                }
                
                let mediaItem = self.addGmod2(name: flashItem.suggestedName, flashData: flashData, eepromData: eepromData)
                
                completionHandler(mediaItem)
            }
        }
    }
    
    func addFile(name: String?, pathExtension: String, url: URL, copy: Bool = true) -> URL? {
        var fileName: String
        if let name = name, let index = name.lastIndex(of: ".") {
            fileName = String(name[name.startIndex..<index])
        }
        else {
            fileName = name ?? "unknown"
        }
        
        let fileURL: URL
        
        do {
            fileURL = try uniqueName(directory: directoryURL, name: fileName, pathExtension: pathExtension)
            if copy {
                try FileManager.default.copyItem(at: url, to: fileURL)
            }
            else {
                try FileManager.default.moveItem(at: url, to: fileURL)
            }
        }
        catch {
            return nil
        }
        return fileURL
    }
    
    func addFile(name: String?, pathExtension: String, data: Data) -> URL? {
        var fileName: String
        if let name = name, let index = name.lastIndex(of: ".") {
            fileName = String(name[name.startIndex..<index])
        }
        else {
            fileName = name ?? "unknown"
        }
        
        let fileURL: URL
        
        do {
            fileURL = try uniqueName(directory: directoryURL, name: fileName, pathExtension: pathExtension)
            try data.write(to: fileURL)
        }
        catch {
            return nil
        }
        return fileURL
    }
    
    func removeFile(_ name: String?) {
        guard let name = name else { return }
        do {
            try FileManager.default.removeItem(at: directoryURL.appendingPathComponent(name))
        }
        catch { }
    }
}

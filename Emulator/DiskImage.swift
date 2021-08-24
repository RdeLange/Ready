/*
 DiskImage.swift -- Access disk images
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

public protocol DiskImage {
    static func image(from url: URL) -> DiskImage?
    static func image(from bytes: Data) -> DiskImage?

    var directoryTrack: UInt8 { get }
    var directorySector: UInt8 { get }
    var tracks: Int { get }
    var url: URL? { get set }
    var connector: ConnectorType { get }

    var diskId: [UInt8]? { get }
    
    func save() throws

    func getBlock(track: UInt8, sector: UInt8) -> Data?
    
    func readDirectory() -> Directory?
    func readFreeBlocks() -> Int?
    func readFile(track: UInt8, sector: UInt8) -> Data?
    
    mutating func writeBLock(track: UInt8, sector: UInt8, data: Data)
}

extension DiskImage {
    public static func image(from url: URL) -> DiskImage? {
        guard let bytes = FileManager.default.contents(atPath: url.path) else { return nil }
        guard var image = image(from: bytes) else { return StubImage(url: url) }
        image.url = url
        return image
    }

    public static func image(from bytes: Data) -> DiskImage? {
        if let image = GxxImage(bytes: bytes) {
            return image
        }
        if let image = DxxImage(bytes: bytes) {
            return image
        }
        return nil
    }
    
    public static func blankImage(url: URL, connector: ConnectorType, namePETSCII: [UInt8], idPETSCII: [UInt8]) -> DiskImage? {
        var optinalImage: DiskImage?
        
        optinalImage = DxxImage(blank: connector, namePETSCII: namePETSCII, idPETSCII: idPETSCII)
        
        guard var image = optinalImage else { return nil }
        image.url = url
        do {
            try image.save()
        }
        catch {
            return nil
        }
        return image
    }

    public func readDirectory() -> Directory? {
        var seenSectors = Set<(UInt16)>()
        var entries = [Directory.Entry]()
        
        var track = directoryTrack
        var sector = directorySector
        
        while (track != 0) {
            let id = UInt16(track) << 8 | UInt16(sector)
            if (seenSectors.contains(id)) {
                // loop detected
                break
            }
            seenSectors.insert(id)

            guard let bytes = getBlock(track: track, sector: sector) else { break }
            
            var offset = 0;
            while (offset < 0x100) {
                if bytes[offset+2] == 0 {
                    offset += 0x20
                    continue
                }
                entries.append(Directory.Entry(bytes: bytes.subdata(in: offset..<offset+0x20)))
                offset += 0x20
            }
            
            track = bytes[0]
            sector = bytes[1]
        }
        
        guard let bytes = getBlock(track: directoryTrack, sector: 0) else { return nil }
        
        guard let freeBlocks = readFreeBlocks() else { return nil }

        let name: [UInt8]
        let diskId: [UInt8]
        
        switch connector {
        case .floppy3_5DoubleDensityDoubleSidedCommodore:
            name = [UInt8](bytes[0x04 ..< 0x14])
            diskId = [UInt8](bytes[0x16 ..< 0x1b])
            
        case .floppy5_25SingleDensitySingleSidedCommodore:
            name = [UInt8](bytes[0x90..<0xa0])
            diskId = [UInt8](bytes[0xa2..<0xa7])

        default:
            return nil
        }

        let signature = String(bytes: bytes[0xad...0xbc], encoding: .ascii)
        let isGEOS = signature?.hasPrefix("GEOS format ") ?? false

        return Directory(diskNamePETASCII: name, diskIdPETASCII: diskId, freeBlocks: freeBlocks, entries: entries, isGEOS: isGEOS)
    }
    
    public func readFile(track startTrack: UInt8, sector startSector: UInt8) -> Data? {
        var seenSectors = Set<(UInt16)>()
        
        var data = [UInt8]()
        
        var track = startTrack
        var sector = startSector
        
        while (track != 0) {
            let id = UInt16(track) << 8 | UInt16(sector)
            if (seenSectors.contains(id)) {
                // loop detected
                return nil
            }
            seenSectors.insert(id)
            
            guard let block = getBlock(track: track, sector: sector) else { return nil }
            
            track = block[0]
            sector = block[1]
            
            let length = Int(track == 0 ? sector : 255)
            
            data.append(contentsOf: block[2...length])
        }

        return Data(data)
    }
    
    public func readFreeBlocks() -> Int? {
        switch connector {
        case .floppy5_25SingleDensitySingleSidedCommodore:
            var freeBlocks = 0
        
            guard let bytes = getBlock(track: directoryTrack, sector: 0) else { return nil }

            for track in (1 ... 35) {
                if track == directoryTrack {
                    continue
                }
                freeBlocks += Int(bytes[track * 4])
            }
            
            // TODO: 40 tracks BAM (two variants)
            
            return freeBlocks
            
        case .floppy3_5DoubleDensityDoubleSidedCommodore:
            var freeBlocks = 0
            
            for sector in (UInt8(1) ... UInt8(2)) {
                guard let bytes = getBlock(track: directoryTrack, sector: sector) else { return nil }
                for track in (1 ... 40) {
                    if track == directoryTrack && sector == 1 {
                        continue
                    }
                    
                    freeBlocks += Int(bytes[0x0a + track * 6])
                }
            }
            
            return freeBlocks
            
        default:
            return nil
        }
    }
    
    public var diskId: [UInt8]? {
        guard let bytes = getBlock(track: directoryTrack, sector: 0) else { return nil }
        switch connector {
        case .floppy5_25SingleDensitySingleSidedCommodore:
            return Array(bytes[0xa2 ... 0xa3])
            
        case .floppy3_5DoubleDensityDoubleSidedCommodore:
            return Array(bytes[0x16 ... 0x17])
            
        default:
            return nil
        }
    }
}

public struct Directory {
    public struct Entry {
        public var fileType: UInt8
        // SAVE-@ replacement
        public var locked: Bool
        public var closed: Bool
        public var track: UInt8
        public var sector: UInt8
        public var namePETASCII: [UInt8]
        public var postNamePETASCII: [UInt8]
        public var blocks: UInt16
        // REL files
        public var recordLength: UInt8
        public var sideBlockTrack: UInt8
        public var sideBlockSector: UInt8
        // GEOS stuff
        
        public init(bytes: Data) {
            fileType = bytes[2] & 0xf
            // SAVE-@ replacment: bytes[0] & 0x20
            locked = (bytes[2] & 0x40) != 0
            closed = (bytes[2] & 0x80) != 0
            track = bytes[3]
            sector = bytes[4]
            let components = [UInt8](bytes[0x05 ... 0x14]).split(separator: 0xa0, maxSplits: 1, omittingEmptySubsequences: false)
            namePETASCII = [UInt8](components[0])
            if components.count > 1 {
                postNamePETASCII = [UInt8](components[1])
                postNamePETASCII.append(0xa0)
            }
            else {
                postNamePETASCII = [UInt8]()
            }
            sideBlockTrack = bytes[0x15]
            sideBlockSector = bytes[0x16]
            recordLength = bytes[0x17]
            // GEOS: 0x18-0x1d
            blocks = UInt16(bytes[0x1e]) | UInt16(bytes[0x1f]) << 8
        }
        
        public var name: String { return String(bytes: namePETASCII, encoding: .ascii) ?? "XXX" } // TODO: filter non-ASCII characters
    }
    public var diskNamePETASCII: [UInt8]
    public var diskIdPETASCII: [UInt8]
    public var freeBlocks: Int
    public var entries: [Entry]
    public var isGEOS: Bool
}

public struct DxxImage : DiskImage {
    private struct DiskLayout {
        var trackOffsets: [Int]
        var totalSectors: Int
        var directoryTrack: UInt8
        var directorySector: UInt8
        var hasErrorMap: Bool
        var connector: ConnectorType
        
        var fileSize: Int {
            return totalSectors * (hasErrorMap ? 257 : 256)
        }
        
        init(template: DiskLayoutTemplate, tracks: Int, hasErrorMap: Bool) {
            trackOffsets = [ 0 ] // track 0 doesn't exist

            var zoneIterator = template.zones.makeIterator()
            var offset = 0
            var size = 0
            
            var nextZone = zoneIterator.next()
            for track in (1 ... tracks) {
                trackOffsets.append(offset)
                if let zone = nextZone, track >= zone.firstTrack {
                    size = Int(zone.sectors)
                    nextZone = zoneIterator.next()
                }
                offset += size
            }
            totalSectors = offset
            
            self.directoryTrack = template.directoryTrack
            self.directorySector = template.directorySector
            self.connector = template.connector
            self.hasErrorMap = hasErrorMap
        }
        
        func getOffset(track: UInt8) -> Int {
            return trackOffsets[Int(track)]
        }
        
        func getSectors(track: UInt8) -> UInt8 {
            let track = Int(track)
            if track < trackOffsets.count - 1 {
                return UInt8(trackOffsets[track + 1] - trackOffsets[track])
            }
            else {
                return UInt8(totalSectors - trackOffsets[track])
            }
        }
    }

    public var bytes: Data
    public var url: URL?
    
    private var layout: DiskLayout
    
    private static var bam1541 = Data([
        0x12, 0x01, 0x41, 0x00, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f,
        0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f,
        0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f,
        0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f,
        0x15, 0xff, 0xff, 0x1f, 0x15, 0xff, 0xff, 0x1f, 0x11, 0xfc, 0xff, 0x07, 0x13, 0xff, 0xff, 0x07,
        0x13, 0xff, 0xff, 0x07, 0x13, 0xff, 0xff, 0x07, 0x13, 0xff, 0xff, 0x07, 0x13, 0xff, 0xff, 0x07,
        0x13, 0xff, 0xff, 0x07, 0x12, 0xff, 0xff, 0x03, 0x12, 0xff, 0xff, 0x03, 0x12, 0xff, 0xff, 0x03,
        0x12, 0xff, 0xff, 0x03, 0x12, 0xff, 0xff, 0x03, 0x12, 0xff, 0xff, 0x03, 0x11, 0xff, 0xff, 0x01,
        0x11, 0xff, 0xff, 0x01, 0x11, 0xff, 0xff, 0x01, 0x11, 0xff, 0xff, 0x01, 0x11, 0xff, 0xff, 0x01,
        0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0,
        0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0x32, 0x41, 0xa0, 0xa0, 0xa0, 0xa0, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])
    
    private static var bam1581 = Data([
        0x28, 0x03, 0x44, 0x00, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0,
        0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0xa0, 0x20, 0xa0, 0x33, 0x44, 0xa0, 0xa0, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x28, 0x02, 0x44, 0xbb, 0x42, 0x20, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x24, 0xf0, 0xff, 0xff, 0xff, 0xff,
        0x00, 0xff, 0x44, 0xbb, 0x42, 0x20, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff,
        0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff,
        0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff, 0x28, 0xff, 0xff, 0xff, 0xff, 0xff,
    ])
    
    public init?(blank connector: ConnectorType, namePETSCII: [UInt8], idPETSCII: [UInt8]) {
        DxxImage.initLayouts()
        
        guard let layout = DxxImage.layoutByConnector[connector] else { return nil }
        self.layout = layout
        bytes = Data(count: layout.fileSize)

        var bam: Data
        let nameOffset: Int

        switch connector {
        case .floppy5_25SingleDensitySingleSidedCommodore:
            bam = DxxImage.bam1541
            nameOffset = 0x90
            
        case .floppy3_5DoubleDensityDoubleSidedCommodore:
            bam = DxxImage.bam1581
            nameOffset = 0x04
            
        default:
            return nil
        }
        let name = namePETSCII.count <= 16 ? ArraySlice<UInt8>(namePETSCII) : namePETSCII[0..<16]
        var id: [UInt8]
        switch idPETSCII.count {
        case 0, 1, 2, 5:
            id = idPETSCII
        case 3:
            id = idPETSCII
            id.append(0xa0)
            id.append(0xa0)
        case 4:
            id = idPETSCII
            id.append(0xa0)
        default:
            id = Array(idPETSCII[0..<5])
        }
        bam.replaceSubrange(nameOffset ..< nameOffset + name.count, with: name)
        bam.replaceSubrange(nameOffset + 0x12 ..< nameOffset + 0x12 + id.count, with: id)
        guard let offset = getBlockOffset(track: directoryTrack, sector: 0) else { return nil }
        bytes.replaceSubrange(offset ..< offset + bam.count, with: bam)

        var block = Data(count: 256)
        block[1] = 0xff
        writeBLock(track: directoryTrack, sector: directorySector, data: block)
        block[0] = directoryTrack
        block[1] = directorySector
        
    }
    
    public init?(bytes: Data) {
        DxxImage.initLayouts()
        
        guard let layout = DxxImage.layoutBySize[bytes.count] else { return nil }
        self.layout = layout
        self.bytes = bytes
    }
    
    public func save() throws {
        guard let url = url else { return }
        try bytes.write(to: url)
    }
    
    public var directoryTrack: UInt8 { return layout.directoryTrack }
    public var directorySector: UInt8 { return layout.directorySector }
    public var connector: ConnectorType { return layout.connector }
    public var tracks: Int { return layout.trackOffsets.count - 1 }
    
    public func getBlock(track: UInt8, sector: UInt8) -> Data? {
        guard let offset = getBlockOffset(track: track, sector: sector) else { return nil }
        
        return bytes.subdata(in: offset*0x100..<(offset+1)*0x100)
    }
    
    mutating public func writeBLock(track: UInt8, sector: UInt8, data: Data) {
        guard data.count == 256 else { return }
        guard let offset = getBlockOffset(track: track, sector: sector) else { return }

        bytes.replaceSubrange(offset*0x100..<(offset+1)*0x100, with: data)
    }
    
    func getBlockOffset(track: UInt8, sector: UInt8) -> Int? {
        guard track > 0 && track < layout.trackOffsets.count else { return nil }
        guard sector < layout.getSectors(track: track) else { return nil }
        
        return layout.getOffset(track: track) + Int(sector)
    }
    
    private struct TrackSizeZone {
        var firstTrack: UInt8
        var sectors: UInt8
    }

    private struct DiskLayoutTemplate {
        var zones: [TrackSizeZone]
        var tracks: [Int]
        var directoryTrack: UInt8
        var directorySector: UInt8
        var connector: ConnectorType
    }
    private static var layoutBySize = [Int : DiskLayout]()
    private static var layoutByConnector = [ConnectorType: DiskLayout]()
    private static var layoutTemplates: [DiskLayoutTemplate] = [
        // 1541
        DiskLayoutTemplate(zones: [
            TrackSizeZone(firstTrack: 1, sectors: 21),
            TrackSizeZone(firstTrack: 18, sectors: 19),
            TrackSizeZone(firstTrack: 25, sectors: 18),
            TrackSizeZone(firstTrack: 31, sectors: 17),
            ], tracks: [35, 40, 42], directoryTrack: 18, directorySector: 1, connector: .floppy5_25SingleDensitySingleSidedCommodore),
        
        // 1571
        DiskLayoutTemplate(zones: [
            TrackSizeZone(firstTrack: 1, sectors: 21),
            TrackSizeZone(firstTrack: 18, sectors: 19),
            TrackSizeZone(firstTrack: 25, sectors: 18),
            TrackSizeZone(firstTrack: 31, sectors: 17),
            TrackSizeZone(firstTrack: 36, sectors: 21),
            TrackSizeZone(firstTrack: 53, sectors: 19),
            TrackSizeZone(firstTrack: 60, sectors: 18),
            TrackSizeZone(firstTrack: 66, sectors: 17)
        ], tracks: [70], directoryTrack: 18, directorySector: 1, connector: .floppy5_25SingleDensitySingleSidedCommodore),
        
        // 1581
        DiskLayoutTemplate(zones: [
            TrackSizeZone(firstTrack: 1, sectors: 40)
            ], tracks: [80, 81, 82, 83], directoryTrack: 40, directorySector: 3, connector: .floppy3_5DoubleDensityDoubleSidedCommodore),
        
        // 8050
        DiskLayoutTemplate(zones: [
            TrackSizeZone(firstTrack: 1, sectors: 29),
            TrackSizeZone(firstTrack: 40, sectors: 27),
            TrackSizeZone(firstTrack: 54, sectors: 25),
            TrackSizeZone(firstTrack: 65, sectors: 23)
            ], tracks: [77], directoryTrack: 39, directorySector: 1, connector: .floppy5_25SingleDensitySingleSidedCommodore), // TODO: correct connector?
        
        // 8250
        DiskLayoutTemplate(zones: [
            TrackSizeZone(firstTrack: 1, sectors: 29),
            TrackSizeZone(firstTrack: 40, sectors: 27),
            TrackSizeZone(firstTrack: 54, sectors: 25),
            TrackSizeZone(firstTrack: 65, sectors: 23),
            TrackSizeZone(firstTrack: 78, sectors: 29),
            TrackSizeZone(firstTrack: 117, sectors: 27),
            TrackSizeZone(firstTrack: 131, sectors: 25),
            TrackSizeZone(firstTrack: 142, sectors: 23)
            ], tracks: [134], directoryTrack: 39, directorySector: 1, connector: .floppy5_25SingleDensityDoubleSidedCommodore) // TODO: correct connector?
    ]
    
    private static func initLayouts() {
        guard layoutBySize.isEmpty else { return }
        
        for template in layoutTemplates {
            for tracks in template.tracks {
                let layout = DiskLayout(template: template, tracks: tracks, hasErrorMap: false)
                let layoutWithErrorMap = DiskLayout(template: template, tracks: tracks, hasErrorMap: true)
                layoutBySize[layout.fileSize] = layout
                layoutBySize[layoutWithErrorMap.fileSize] = layoutWithErrorMap
                layoutByConnector[layout.connector] = layout
            }
        }
    }
}

class BitStream {
    private static var masks = [ 0xff, 0x7f, 0x3f, 0x1f, 0xf, 0x7, 0x3, 0x1 ]
    var bytes: Data
    var byteOffset = 0
    var bitOffset = 0
    
    init(bytes: Data) {
        self.bytes = bytes
        reset()
    }
    
    func reset() {
        byteOffset = 0
        bitOffset = 0
    }
    
    func end() -> Bool {
        return byteOffset == bytes.count
    }
    
    func peek(_ length: Int) -> Int? {
        var bitOffset = self.bitOffset
        var byteOffset = self.byteOffset

        guard byteOffset * 8 + bitOffset + length <= bytes.count * 8 else { return nil }
        
        var value = 0
        var n = length
        
        while (n > 0) {
            let bitsRemaining = min(n, 8-bitOffset)
            let currentBits = (Int(bytes[byteOffset]) & BitStream.masks[bitOffset]) >> (8 - (bitOffset + bitsRemaining))
            
            value = value << bitsRemaining | currentBits
            
            n -= bitsRemaining
            bitOffset += bitsRemaining
            if (bitOffset == 8) {
                bitOffset = 0
                byteOffset += 1
            }
        }
        
        return value
    }
    
    func get(_ length: Int) -> Int? {
        guard let value = peek(length) else { return nil }
        
        let newOffset = bitOffset + length
        
        bitOffset = newOffset % 8
        byteOffset += newOffset / 8
        
        return value
    }
    
    func rewind(_ length: Int) {
        let newOffset = max(byteOffset * 8 + bitOffset - length, 0)
        
        bitOffset = newOffset % 8
        byteOffset = newOffset / 8
    }
}

public class GxxImage: DiskImage {
    public var tracks: Int { return trackOffsets.count / 2 }
    
    public var url: URL?
    
    public var directoryTrack = UInt8(18)
    public var directorySector = UInt8(1)
    public var connector: ConnectorType
    
    
    enum TrackData : Equatable {
        case NoData
        case NotRead
        case Sectors([Int: Data])
        case Error
        static func == (lhs: TrackData, rhs: TrackData) -> Bool {
            switch (lhs, rhs) {
            case (.NoData, .NoData), (.NotRead, .NotRead), (.Sectors(_), .Sectors(_)), (.Error, .Error):
                return true
            default:
                return false
            }
        }
    }

    public var bytes: Data
    
    var trackData = [TrackData]()
    var trackOffsets = [Int]()
    
    public init?(bytes: Data) {
        guard bytes.count >= 0x0c else { return nil } // too short for header

        let signature = String(bytes: bytes[0...7], encoding: .ascii)
        
        switch signature {
        case "GCR-1541":
            connector = .floppy5_25SingleDensitySingleSidedCommodore
            
        case "GCR-1571":
            connector = .floppy5_25SingleDensityDoubleSidedCommodore
            
        default:
            return nil
        }
        
        let numberOfHalftracks = Int(bytes[9])
        
        for track in 0..<numberOfHalftracks {
            let i = 0xc + track * 4
            let offset = Int(bytes[i]) | Int(bytes[i+1]) << 8 | Int(bytes[i+2]) << 16 | Int(bytes[i+3]) << 32
            trackOffsets.append(offset)
            trackData.append(offset == 0 ? .NoData : .NotRead)
        }
        
        self.bytes = bytes
    }
    
    public func save() throws {
        guard let url = url else { return }
        try bytes.write(to: url)
    }

    public func getBlock(track: UInt8, sector: UInt8) -> Data? {
        let halftrack = (Int(track)-1) * 2
        
        guard halftrack < trackData.count else { return nil }
        
        if trackData[halftrack] == TrackData.NotRead {
            trackData[halftrack] = readTrack(halftrack)
        }
        
        switch trackData[halftrack] {
        case .Error, .NoData, .NotRead:
            return nil
        case .Sectors(let sectors):
            if let data = sectors[Int(sector)] {
                return data
            }
            else {
                return nil
            }
        }
    }
    
    public func writeBLock(track: UInt8, sector: UInt8, data: Data) {
        return
    }
    
    func readTrack(_ halftrack: Int) -> TrackData {
        let offset = trackOffsets[halftrack]
        guard offset > 0 && offset + 2 < bytes.count else { return .Error }
        let size = Int(bytes[offset]) | Int(bytes[offset+1]) << 8
        guard offset + size < bytes.count else { return .Error }
        
/*
        for i in (offset..<offset+size) {
            let byte = bytes[i]
            var mask = UInt8(0x80)
            while mask > 0 {
                print((byte & mask) == 0 ? "0" : "1", terminator: "")
                mask >>= 1
            }
        }
 */
        let bits = BitStream(bytes: bytes.subdata(in: offset..<offset+size))
        
        var sectors = [Int: Data]()
        
        while (findSync(bits)) {
//            print("header sync")
            guard let header = decodeGCR(bits, 6) else { break }
//            print(String(format: "header: %02x %02x %02x %02x %02x %02x %02x %02x", header[0], header[1], header[2], header[3], header[4], header[5]))
            
            guard header[0] == 0x08 && header[1] == header[2] ^ header[3] ^ header[4] ^ header[5] else { break }
            
            guard findSync(bits) else { break }
//            print("data sync")
            guard let data = decodeGCR(bits, 0x102) else { break }
//            print(String(format: "data %02x ...", data[0]))
            
            let sector = Int(header[2])
            
            guard data[0] == 0x07 else { continue }
            
            var eor: UInt8 = 0
            
            for i in 1...0x100 {
                eor ^= data[i]
            }
            
            // guard eor == data[0x101] else { continue }
            
            sectors[sector] = data.subdata(in: 1..<0x101)
        }
        
        return .Sectors(sectors)
    }
    
    func findSync(_ bits: BitStream) -> Bool {
        var n = 0
        
        while (true) {
            guard let bit = bits.get(1) else { return false }
            
            if (bit == 0) {
                if (n >= 10) {
                    bits.rewind(1)
                    return true
                }
                n = 0
            }
            else {
                n += 1
            }
        }
    }
    
    // See https://en.wikipedia.org/wiki/Group_coded_recording#Commodore
    
    static var GCR: [UInt8] = [
        /* 0x00 */
        0xff, 0xff, 0xff, 0xff,
        /* 0x04 */
        0xff, 0xff, 0xff, 0xff,
        /* 0x08 */
        0xff, 0x08, 0x00, 0x01,
        /* 0x0c */
        0xff, 0x0c, 0x04, 0x05,
        /* 0x10 */
        0xff, 0xff, 0x02, 0x03,
        /* 0x14 */
        0xff, 0x0f, 0x06, 0x07,
        /* 0x18 */
        0xff, 0x09, 0x0a, 0x0b,
        /* 0x1c */
        0xff, 0x0d, 0x0e, 0xff,
    ]
    func decodeGCR(_ bits: BitStream, _ n: Int) -> Data? {
        var data = Data(repeating: 0, count: n)
        
        for i in 0..<n {
            guard let highGCR = bits.get(5) else { return nil }
            guard let lowGCR = bits.get(5) else { return nil }
            
/*
            if GxxImage.GCR[highGCR] & 0xf0 != 0 {
                print(String(format: "invalid GCR at \(i).0: %02x", highGCR))
            }
            if GxxImage.GCR[lowGCR] & 0xf0 != 0 {
                print(String(format: "invalid GCR at \(i).1: %02x", lowGCR))
            }
 */

            guard GxxImage.GCR[lowGCR] & 0xf0 == 0 && GxxImage.GCR[highGCR] & 0xf0 == 0 else { return nil }
            data[i] = GxxImage.GCR[lowGCR] | GxxImage.GCR[highGCR] << 4
        }
        
        return data
    }
}

public struct StubImage: DiskImage {
    public var directoryTrack = UInt8(18)
    public var directorySector = UInt8(1)
    public var connector: ConnectorType
    public var tracks: Int
    public var url: URL?
    
    private struct Layout {
        var connector: ConnectorType
        var tracks: Int
    }
    
    private static let layouts = [
        "d1m": Layout(connector: .floppy3_5DoubleDensityDoubleSidedCmd, tracks: 81),
        "d2m": Layout(connector: .floppy3_5HighDensityDoubleSidedCmd, tracks: 81),
        "d4m": Layout(connector: .floppy3_5ExtendedDensityDoubleSidedCmd, tracks: 81),
        "d64": Layout(connector: .floppy5_25SingleDensitySingleSidedCommodore, tracks: 35),
        // "d67": Layout(connector: .floppy5_25SingleDensitySingleSidedCommodore, tracks: 35), // not used on C64
        "d71": Layout(connector: .floppy5_25SingleDensityDoubleSidedCommodore, tracks: 70), // not used on C64
        // "d80": Layout(connector: .doubleDensitySingleSided5_25, tracks: 77), // not used on C64
        "d81": Layout(connector: .floppy3_5DoubleDensityDoubleSidedCommodore, tracks: 80),
        // "d82": Layout(connector: .doubleDensityDoubleSided5_25, tracks: 134), // not used on C64
        "g64": Layout(connector: .floppy5_25SingleDensitySingleSidedCommodore, tracks: 35),
        // "g71": Layout(connector: .floppy5_25SingleDensityDoubleSidedCommodore, tracks: 70), // not used on C64
        "p64": Layout(connector: .floppy5_25SingleDensitySingleSidedCommodore, tracks: 35)
    ]
    
    public init?(url: URL) {
        guard let layout = StubImage.layouts[url.pathExtension.lowercased()] else { return nil }
        self.connector = layout.connector
        self.tracks = layout.tracks
        self.url = url
    }
    
    public func save() throws {
        return
    }

    public func getBlock(track: UInt8, sector: UInt8) -> Data? {
        return nil
    }
    
    public func writeBLock(track: UInt8, sector: UInt8, data: Data) {
        return
    }
    
    public func readFreeBlocks() -> Int? {
        return nil
    }
}

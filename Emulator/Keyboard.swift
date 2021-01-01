/*
 Keyboard.swift -- Layout of Virtual Keyboards
 Copyright (C) 2019-2020 Dieter Baron
 
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

import UIKit

public struct Keyboard {
    public enum Region {
        case polygon(_ pologon: Polygon)
        case rect(_ rect: CGRect)
        case rects(_ rects: [CGRect])
    }
        
    public struct Polygon {
        var key: Key
        
        var vertices: [CGPoint]
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var bottom: CGFloat
        
        init(vertices: [CGPoint], key: Key) {
            self.vertices = vertices
            self.key = key

            if let first = vertices.first {
                left = first.x
                right = first.x
                top = first.y
                bottom = first.y
                
                for point in vertices.dropFirst() {
                    if point.x < left {
                        left = point.x
                    }
                    if point.x > right {
                        right = point.x
                    }
                    if point.y < top {
                        top = point.y
                    }
                    if point.y > bottom {
                        bottom = point.y
                    }
                }
            }
            else {
                // empty bounding box for empty polygon
                left = 1
                right = -1
                top = 1
                bottom = -1
            }
        }

        func hit(_ point: CGPoint) -> Key? {
            guard point.x >= left && point.x <= right && point.y >= top && point.y <= bottom else { return nil }
            guard var j = vertices.last else { return nil }

            var inside = false
            for i in vertices {
                if (i.y > point.y) != (j.y > point.y) && (point.x < (j.x - i.x) * (point.y - i.y) / (j.y - i.y) + i.x) {
                    inside = !inside
                }
                j = i
            }
            
            if inside {
                return key
            }
            else {
                return nil
            }
        }
    }
    private struct Span {
        var left: Int
        var right: Int
        var keys: [Key]
        var width: CGFloat

        init(left: Int, right: Int, keys: [Key]) {
            self.left = left
            self.right = right
            self.keys = keys
            self.width = CGFloat(right - left) / CGFloat(keys.count)
        }
        
        func hit(_ point: CGPoint) -> Key? {
            guard (Int(point.x) >= left && Int(point.x) < Int(right)) else { return nil }
            let idx = (Int(point.x) - left) * keys.count / (right - left)
            return keys[idx]
        }
    }
    
    private struct Row {
        var top: Int
        var bottom: Int
        var spans: [Span]
        
        func hit(_ point: CGPoint) -> Key? {
            guard (Int(point.y) >= top && Int(point.y) < bottom) else { return nil }
            for span in spans {
                if let key = span.hit(point) {
                    return key
                }
            }
            
            return nil
        }
    }
    
    private struct Layout {
        var rows: [Row]
        var polygons: [Polygon]
        
        init(rows: [Row], polygons: [Polygon] = []) {
            self.rows = rows
            self.polygons = polygons
        }
        
        func hit(_ point: CGPoint) -> Key? {
            for row in rows {
                if let key = row.hit(point) {
                    return key
                }
            }
            for polygon in polygons {
                if let key = polygon.hit(point) {
                    return key
                }
            }
            
            return nil
        }
        
        public func getKeyRegions() -> [Key : Region] {
            var regions = [Key: Region]()
            
            for row in rows {
                for span in row.spans {
                    for (index, key) in span.keys.enumerated() {
                        let region = Region.rect(CGRect(x: CGFloat(span.left) + CGFloat(index) * span.width, y: CGFloat(row.top), width: span.width, height: CGFloat(row.bottom - row.top)))
                        
                        if let _ = regions[key] {
                            // TODO: merge
                        }
                        else {
                            regions[key] = region
                        }
                    }
                }
            }
            
            // TODO: polygons

            return regions
        }
    }

    public var imageName: String
    public var hasPressedImage: Bool
    public var toggleKeys = Set<Key>()
    public var toggleImages = [Key: String]()
    public var keyboardSymbols: KeyboardSymbols
    
    public func hit(_ point: CGPoint) -> Key? {
        return layout.hit(point)
    }
    
    public func getKeyRegions() -> [Key: Region] {
        return layout.getKeyRegions()
    }
    
    private var layout: Layout
    
    private init(amigaWithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], left: Int, right: Int, tildeRight: Int, tabRight: Int, returnUpperLeft: Int, controlRight: Int, returnLowerLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, leftAltLeft: Int, spaceLeft: Int, spaceRight: Int, rightAltRight: Int, cursorLeft: Int, cursorRight: Int, keypadLeft: Int, keypadRight: Int, keypad0Right: Int, functionRowTop: Int, functionRowBottom: Int, escapeRight: Int, functionBlock1Left: Int, functionBlock1Right: Int, functionBlock2Left: Int, functionBlock2Right: Int) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.toggleKeys = [.CapsLock]
        if !hasPressedImage {
            self.toggleImages = [
                .CapsLock: imageName + " CapsLock",
            ]
        }
        let cursorThirdWidth = (cursorRight - cursorLeft) / 3
        self.layout = Layout(rows: [
            Row(top: functionRowTop, bottom: functionRowBottom, spans: [
                Span(left: left, right: escapeRight, keys: [.Escape]),
                Span(left: functionBlock1Left, right: functionBlock1Right, keys: [.F1, .F2, .F3, .F4, .F5]),
                Span(left: functionBlock2Left, right: functionBlock2Right, keys: [.F6, .F7, .F8, .F9, .F10]),
            ]),
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: left, right: tildeRight, keys: [.Char("`")]),
                Span(left: tildeRight, right: right, keys: [.Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .Char("ß"), .Char("'"), .Char("\\"), .Backspace]),
                Span(left: cursorLeft, right: cursorRight, keys: [.Delete, .Help]),
                Span(left: keypadLeft, right: keypadRight, keys: [.KeypadBracketOpen, .KeypadBracketClose, .KeypadSlash, .KeypadAsterisk])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left, right: tabRight, keys: [.Tab]),
                Span(left: tabRight, right: right, keys: [.Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("ü"), .Char("+")]),
                Span(left: returnUpperLeft, right: right, keys: [.Return]),
                Span(left: keypadLeft, right: keypadRight, keys: [.Keypad7, .Keypad8, .Keypad9, .KeypadMinus])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left, right: controlRight, keys: [.Control]),
                Span(left: controlRight, right: returnLowerLeft, keys: [.CapsLock, .Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char("ö"), .Char("ä"), .Char("#")]),
                Span(left: returnLowerLeft, right: right, keys: [.Return]),
                Span(left: cursorLeft + cursorThirdWidth, right: cursorRight - cursorThirdWidth, keys: [.CursorUp]),
                Span(left: keypadLeft, right: keypadRight, keys: [.Keypad4, .Keypad5, .Keypad6, .KeypadPlus])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left, right: leftShiftRight, keys: [.ShiftLeft]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [.Char("<"), .Char("y"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("-")]),
                Span(left: rightShiftLeft, right: right, keys: [.ShiftRight]),
                Span(left: cursorLeft, right: cursorRight, keys: [.CursorLeft, .CursorDown, .CursorRight]),
                Span(left: keypadLeft, right: keypadRight, keys: [.Keypad1, .Keypad2, .Keypad3, .KeypadEnter])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: leftAltLeft, right: spaceLeft, keys: [.AltLeft, .AmigaLeft]),
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")]),
                Span(left: spaceRight, right: rightAltRight, keys: [.AmigaRight, .AltRight]),
                Span(left: keypadLeft, right: keypad0Right, keys: [.Keypad0]),
                Span(left: keypad0Right, right: keypadRight, keys: [.KeypadPeriod, .KeypadEnter])
            ])
        ])
        self.keyboardSymbols = KeyboardSymbols.c128 // KeyboardSymbols.amiga
    }

    private init(atariXlWithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], left: Int, right: Int, escapeRight: Int, tabRight: Int, returnLeft: Int, controlRight: Int, capsLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, rightShiftRight: Int, spaceLeft: Int, spaceRight: Int, functionTop: Int, functionBottom: Int, functionLeft: Int, functionRight: Int) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        let functionHeight = (functionBottom - functionTop) / 5
        self.layout = Layout(rows: [
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: left, right: escapeRight, keys: [.Escape]),
                Span(left: escapeRight, right: right, keys: [.Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .Char("<"), .Char(">"), .Delete, .Break])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left, right: tabRight, keys: [.Tab]),
                Span(left: tabRight, right: returnLeft, keys: [.Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("-"), .Char("=")]),
                Span(left: returnLeft, right: right, keys: [.Return])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left, right: controlRight, keys: [.Control]),
                Span(left: controlRight, right: capsLeft, keys: [.Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char(";"), .Char("+"), .Char("*")]),
                Span(left: capsLeft, right: right, keys: [.Caps])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left, right: leftShiftRight, keys: [.ShiftLeft]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [.Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("/")]),
                Span(left: rightShiftLeft, right: rightShiftRight, keys: [.ShiftRight]),
                Span(left: rightShiftRight, right: right, keys: [.InverseVideo])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")])
            ]),
            Row(top: functionTop, bottom: functionTop + functionHeight, spans: [
                Span(left: functionLeft, right: functionRight, keys: [.Reset])
            ]),
            Row(top: functionTop + functionHeight, bottom: functionTop + functionHeight * 2, spans: [
                Span(left: functionLeft, right: functionRight, keys: [.Option])
            ]),
            Row(top: functionTop + functionHeight * 2, bottom: functionTop + functionHeight * 3, spans: [
                Span(left: functionLeft, right: functionRight, keys: [.Select])
            ]),
            Row(top: functionTop + functionHeight * 3, bottom: functionTop + functionHeight * 4, spans: [
                Span(left: functionLeft, right: functionRight, keys: [.Start])
            ]),
            Row(top: functionTop + functionHeight * 4, bottom: functionBottom, spans: [
                Span(left: functionLeft, right: functionRight, keys: [.Help])
            ])
        ])
        self.keyboardSymbols = KeyboardSymbols.atariXl
    }
    
    private init(c16WithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], topHalfLeft: Int, topHalfRight: Int, bottomHalfLeft: Int, bottomHalfRight: Int, functionKeysLeft: Int, functionKeysRight: Int, spaceLeft: Int, spaceRight: Int, ctrlRight: Int, clearLeft: Int, returnLeft: Int, leftShiftLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, rightShiftRight: Int) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.toggleKeys = [.ShiftLock]
        if !hasPressedImage {
            self.toggleImages = [.ShiftLock: imageName + " ShiftLock"]
        }
        self.layout = Layout(rows: [
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: topHalfLeft, right: topHalfRight, keys: [
                    .Escape, .Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .CursorLeft, .CursorRight, .CursorUp, .CursorDown, .InsertDelete
                ]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F1])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: topHalfLeft, right: ctrlRight, keys: [.Control]),
                Span(left: ctrlRight, right: clearLeft, keys: [
                    .Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("@"), .Char("+"), .Char("-")
                ]),
                Span(left: clearLeft, right: topHalfRight, keys: [.ClearHome]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F2])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: bottomHalfLeft, right: returnLeft, keys: [
                    .RunStop, .ShiftLock, .Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char(":"), .Char(";"), .Char("*")
                ]),
                Span(left: returnLeft, right: bottomHalfRight, keys: [.Return]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F3])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: bottomHalfLeft, right: leftShiftLeft, keys: [.Commodore]),
                Span(left: leftShiftLeft, right: leftShiftRight, keys: [.ShiftLeft]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [
                    .Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("/"),
                ]),
                Span(left: rightShiftLeft, right: rightShiftRight, keys: [.ShiftRight]),
                Span(left: rightShiftRight, right: bottomHalfRight, keys: [.Char("£"), .Char("=")]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.Help])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")])
            ])
        ])
        self.keyboardSymbols = KeyboardSymbols.plus4
    }
       
    private init(c64WithRenderedImage imageName: String, lockIsShift: Bool = true, pundIsYen: Bool = false, keyWidth: Int, keyHeight: Int, top: Int, topHalfLeft: Int, bottomHalfLeft: Int, functionKeysLeft: Int, spaceLeft: Int, spaceRight: Int) {
        let threeHalfsWidth = Int(Double(keyWidth) * 1.5)
        self.init(c64WithImageName: imageName,
                  hasPressedImage: true,
                  rows: [top, top + keyHeight, top + keyHeight * 2, top + keyHeight * 3, top + keyHeight * 4, top + keyHeight * 5],
                  topHalfLeft: topHalfLeft,
                  topHalfRight: topHalfLeft + keyWidth * 16,
                  bottomHalfLeft: bottomHalfLeft,
                  bottomHalfRight: bottomHalfLeft + keyWidth * 16,
                  functionKeysLeft: functionKeysLeft,
                  functionKeysRight: functionKeysLeft + threeHalfsWidth,
                  spaceLeft: spaceLeft,
                  spaceRight: spaceRight,
                  ctrlRight: topHalfLeft + threeHalfsWidth,
                  restoreLeft: topHalfLeft + threeHalfsWidth + keyWidth * 13,
                  returnLeft: bottomHalfLeft + keyWidth * 14,
                  leftShiftLeft: bottomHalfLeft + keyWidth,
                  leftShiftRight: bottomHalfLeft + keyWidth + threeHalfsWidth,
                  rightShiftLeft: bottomHalfLeft + keyWidth * 11 + threeHalfsWidth,
                  rightShiftRight: bottomHalfLeft + keyWidth * 14)
    }
    
    private init(c64WithImageName imageName: String, hasPressedImage: Bool = false, lockIsShift: Bool = true, poundIsYen: Bool = false, rows: [Int], topHalfLeft: Int, topHalfRight: Int, bottomHalfLeft: Int, bottomHalfRight: Int, functionKeysLeft: Int, functionKeysRight: Int, spaceLeft: Int, spaceRight: Int, ctrlRight: Int, restoreLeft: Int, returnLeft: Int, leftShiftLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, rightShiftRight: Int) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        if lockIsShift {
            self.toggleKeys = [.ShiftLock]
        }
        else {
            self.toggleKeys = [.CommodoreLock]
        }
        if !hasPressedImage {
            if lockIsShift {
                self.toggleImages = [.ShiftLock: imageName + " ShiftLock"]
            }
            else {
                self.toggleImages = [.CommodoreLock: imageName + " ShiftLock"]
            }
        }
        self.layout = Layout(rows: [
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: topHalfLeft, right: topHalfRight, keys: [
                    .ArrowLeft, .Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .Char("+"), .Char("-"), .Char("£"), .ClearHome, .InsertDelete
                ]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F1])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: topHalfLeft, right: ctrlRight, keys: [.Control]),
                Span(left: ctrlRight, right: restoreLeft, keys: [
                    .Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("@"), .Char("*"), .ArrowUp
                ]),
                Span(left: restoreLeft, right: topHalfRight, keys: [.Restore]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F3])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: bottomHalfLeft, right: returnLeft, keys: [
                    .RunStop, lockIsShift ? .ShiftLock : .CommodoreLock, .Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char(":"), .Char(";"), .Char("=")
                ]),
                Span(left: returnLeft, right: bottomHalfRight, keys: [.Return]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F5])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: bottomHalfLeft, right: leftShiftLeft, keys: [.Commodore]),
                Span(left: leftShiftLeft, right: leftShiftRight, keys: [.ShiftLeft]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [
                    .Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("/"),
                ]),
                Span(left: rightShiftLeft, right: rightShiftRight, keys: [.ShiftRight]),
                Span(left: rightShiftRight, right: bottomHalfRight, keys: [.CursorUpDown, .CursorLeftRight]),
                Span(left: functionKeysLeft, right: functionKeysRight, keys: [.F7])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")])
            ])
        ])
        self.keyboardSymbols = KeyboardSymbols.c64
        if poundIsYen {
            keyboardSymbols.keyMap[.Char("£")] = KeyboardSymbols.KeySymbols(normal: .char("¥"))
        }
    }
    
    private init(c128WithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], left: Int, right: Int, controlRight: Int, restoreLeft: Int, returnLeft: Int, leftShiftLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, rightShiftRight: Int, spaceLeft: Int, spaceRight: Int, keypadLeft: Int, keypadRight: Int, keypad0Right: Int, functionRowTop: Int, functionRowBottom: Int, functionBlock1Right: Int, functionBlock2Left: Int, functionBlock2Right: Int, functionBlock3Left: Int) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.toggleKeys = [.CapsLock, .Display4080, .ShiftLock]
        if !hasPressedImage {
            self.toggleImages = [
                .CapsLock: imageName + " CapsLock",
                .Display4080: imageName + " 40-80 Display",
                .ShiftLock: imageName + " ShiftLock"
            ]
        }
        self.layout = Layout(rows: [
            Row(top: functionRowTop, bottom: functionRowBottom, spans: [
                Span(left: left, right: functionBlock1Right, keys: [.Escape, .Tab, .Alt, .CapsLock]),
                Span(left: functionBlock2Left, right: functionBlock2Right, keys: [.Help, .LineFeed, .Display4080, .ScrollLock]),
                Span(left: functionBlock3Left, right: right, keys: [.CursorUp, .CursorDown, .CursorLeft, .CursorRight]),
                Span(left: keypadLeft, right: keypadRight, keys: [.F1, .F3, .F5, .F7])
            ]),
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: left, right: right, keys: [.ArrowLeft, .Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .Char("+"), .Char("-"), .Char("£"), .ClearHome, .InsertDelete]),
                Span(left: keypadLeft, right: keypadRight, keys: [.Keypad7, .Keypad8, .Keypad9, .KeypadPlus])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left, right: controlRight, keys: [.Control]),
                Span(left: controlRight, right: restoreLeft, keys: [.Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("@"), .Char("*"), .ArrowUp]),
                Span(left: restoreLeft, right: right, keys: [.Restore]),
                Span(left: keypadLeft, right: keypadRight, keys: [.Keypad4, .Keypad5, .Keypad6, .KeypadMinus])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left, right: returnLeft, keys: [.RunStop, .ShiftLock, .Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char(":"), .Char(";"), .Char("=")]),
                Span(left: returnLeft, right: right, keys: [.Return]),
                Span(left: keypadLeft, right: keypadRight, keys: [.Keypad1, .Keypad2, .Keypad3, .KeypadEnter])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left, right: leftShiftLeft, keys: [.Commodore]),
                Span(left: leftShiftLeft, right: leftShiftRight, keys: [.ShiftLeft]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [.Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("/")]),
                Span(left: rightShiftLeft, right: rightShiftRight, keys: [.ShiftRight]),
                Span(left: rightShiftRight, right: right, keys: [.CursorUpDown, .CursorLeftRight]),
                Span(left: keypadLeft, right: keypad0Right, keys: [.Keypad0]),
                Span(left: keypad0Right, right: keypadRight, keys: [.KeypadPeriod, .KeypadEnter])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")])
            ])
        ])
        self.keyboardSymbols = KeyboardSymbols.c128
    }
        
    private init(plus4WithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], functionLeft: Int, functionRight: Int, left: Int, right: Int, leftControlRight: Int, rightControlLeft: Int,returnLeft: Int, returnRight: Int, leftShiftLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, rightShiftRight: Int, spaceLeft: Int, spaceRight: Int, cursorTop: CGFloat, cursorLeft: CGFloat, cursorRight: CGFloat, cursorBottom: CGFloat) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.toggleKeys = [.ShiftLock]
        if !hasPressedImage {
            self.toggleImages = [.ShiftLock: imageName + " ShiftLock"]
        }
        
        let cursorWidth = cursorRight - cursorLeft
        let cursorHeight = cursorBottom - cursorTop

        let cursorPoints = [
            CGPoint(x: cursorLeft + cursorWidth * 0.5, y: cursorTop),
            CGPoint(x: cursorLeft + cursorWidth * 0.25, y: cursorTop + cursorHeight * 0.25),
            CGPoint(x: cursorLeft + cursorWidth * 0.75, y: cursorTop + cursorHeight * 0.25),
            CGPoint(x: cursorLeft, y: cursorTop + cursorHeight * 0.5),
            CGPoint(x: cursorLeft + cursorWidth * 0.5, y: cursorTop + cursorHeight * 0.5),
            CGPoint(x: cursorRight, y: cursorTop + cursorHeight * 0.5),
            CGPoint(x: cursorLeft + cursorWidth * 0.25, y: cursorTop + cursorHeight * 0.75),
            CGPoint(x: cursorLeft + cursorWidth * 0.75, y: cursorTop + cursorHeight * 0.75),
            CGPoint(x: cursorLeft + cursorWidth * 0.5, y: cursorBottom)
        ]
        
        self.layout = Layout(rows: [
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: functionLeft, right: functionRight, keys: [.F1, .F2, .F3, .Help])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left, right: right, keys: [.Escape, .Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .Char("+"), .Char("-"), .Char("="), .ClearHome, .InsertDelete])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left, right: leftControlRight, keys: [.Control]),
                Span(left: leftControlRight, right: rightControlLeft, keys: [.Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("@"), .Char("£"), .Char("*")]),
                Span(left: rightControlLeft, right: right, keys: [.Control])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left, right: returnLeft, keys: [.RunStop, .ShiftLock, .Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char(":"), .Char(";")]),
                Span(left: returnLeft, right: returnRight, keys: [.Return])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: left, right: leftShiftLeft, keys: [.Commodore]),
                Span(left: leftShiftLeft, right: leftShiftRight, keys: [.Shift]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [.Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("/")]),
                Span(left: rightShiftLeft, right: rightShiftRight, keys: [.Shift])
            ]),
            Row(top: rows[5], bottom: rows[6], spans: [
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")])
            ])
        ], polygons: [
            Polygon(vertices: [cursorPoints[0], cursorPoints[2], cursorPoints[4], cursorPoints[1]], key: .CursorUp),
            Polygon(vertices: [cursorPoints[1], cursorPoints[4], cursorPoints[6], cursorPoints[3]], key: .CursorLeft),
            Polygon(vertices: [cursorPoints[2], cursorPoints[5], cursorPoints[7], cursorPoints[4]], key: .CursorRight),
            Polygon(vertices: [cursorPoints[4], cursorPoints[7], cursorPoints[8], cursorPoints[6]], key: .CursorDown)
        ])
        self.keyboardSymbols = KeyboardSymbols.plus4
    }
    
    init(x16WithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], left: Int, right: Int, backspaceLeft: Int, tabRight: Int, poundLeft: Int, shiftLockRight: Int, returnLeft: Int, leftShiftRight: Int, rightShiftLeft: Int, spaceLeft: Int, spaceRight: Int, extraLeft: Int, extraRight: Int, functionRowTop: Int, functionRowBottom: Int, escapeRight: Int, functionBlock1Left: Int, functionBlock1Right: Int, functionBlock2Left: Int, functionBlock2Right: Int, functionBlock3Left: Int) {
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.toggleKeys = [.Display4080, .ShiftLock]
        if !hasPressedImage {
            self.toggleImages = [
                .Display4080: imageName + " 40-80 Display",
                .ShiftLock: imageName + " ShiftLock"
            ]
        }
        let extraWidth = extraRight - extraLeft
        self.layout = Layout(rows: [
            Row(top: functionRowTop, bottom: functionRowBottom, spans: [
                Span(left: left, right: escapeRight, keys: [.Escape]),
                Span(left: functionBlock1Left, right: functionBlock1Right, keys: [.F1, .F2, .F3, .F4]),
                Span(left: functionBlock2Left, right: functionBlock2Right, keys: [.F5, .F6, .F7, .F8]),
                Span(left: functionBlock3Left, right: right, keys: [.F9, .F10, .F11, .F12]),
                Span(left: extraLeft, right: extraRight, keys: [.Restore, .Display4080, .RunStop])
            ]),
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: left, right: backspaceLeft, keys: [.ArrowLeft, .Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0"), .Char("-"), .Char("=")]),
                Span(left: backspaceLeft, right: right, keys: [.Backspace]),
                Span(left: extraLeft, right: extraRight, keys: [.Insert, .ClearHome, .PageUp])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left, right: tabRight, keys: [.Tab]),
                Span(left: tabRight, right: poundLeft, keys: [.Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Char("["), .Char("]")]),
                Span(left: poundLeft, right: right, keys: [.Char("£")]),
                Span(left: extraLeft, right: extraRight, keys: [.Delete, .End, .PageDown])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left, right: shiftLockRight, keys: [.ShiftLock]),
                Span(left: shiftLockRight, right: returnLeft, keys: [.Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Char(";"), .Char("'")]),
                Span(left: returnLeft, right: right, keys: [.Return])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left, right: leftShiftRight, keys: [.ShiftLeft]),
                Span(left: leftShiftRight, right: rightShiftLeft, keys: [.Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(","), .Char("."), .Char("/")]),
                Span(left: rightShiftLeft, right: right, keys: [.ShiftRight]),
                Span(left: extraLeft + extraWidth / 3, right: extraRight - extraWidth / 3, keys: [.CursorUp])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: left, right: spaceLeft, keys: [.ControlLeft, .CommanderLeft, .AltLeft]),
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")]),
                Span(left: spaceRight, right: right, keys: [.AltRight, .CommanderRight, .Menu, .ControlRight]),
                Span(left: extraLeft, right: extraRight, keys: [.CursorLeft, .CursorDown, .CursorRight])
            ])
        ])
        self.keyboardSymbols = KeyboardSymbols.x16
    }
    
    init(zxSpectrumWithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], left: [Int], right: [Int], capsRight: Int, spaceLeft: Int) {
        self.layout = Layout(rows: [
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: left[0], right: right[0], keys: [.Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0")])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left[1], right: right[1], keys: [.Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p")])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left[2], right: right[2], keys: [.Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l"), .Return])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left[0], right: capsRight, keys: [.Shift]),
                Span(left: capsRight, right: spaceLeft, keys: [.Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .SymbolShift]),
                Span(left: spaceLeft, right: right[2], keys: [.Char(" ")])
            ])
        ])
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.keyboardSymbols = KeyboardSymbols.zxSpectrum
    }
    
    init(zxSpectrumPlusWithImageName imageName: String, hasPressedImage: Bool = false, rows: [Int], left: Int, right: Int, breakLeft: Int, deleteRight: Int, extendedRight: Int, editRight: Int, returnLeft: Int, leftCapsShiftRight: Int, rightCapsShiftLeft: Int, spaceLeft: Int, spaceRight: Int) {
        self.layout = Layout(rows: [
            Row(top: rows[0], bottom: rows[1], spans: [
                Span(left: left, right: breakLeft, keys: [.TrueVideo, .InverseVideo, .Char("1"), .Char("2"), .Char("3"), .Char("4"), .Char("5"), .Char("6"), .Char("7"), .Char("8"), .Char("9"), .Char("0")]),
                Span(left: breakLeft, right: right, keys: [.Break])
            ]),
            Row(top: rows[1], bottom: rows[2], spans: [
                Span(left: left, right: deleteRight, keys: [.Delete]),
                Span(left: deleteRight, right: right, keys: [.Graphics, .Char("q"), .Char("w"), .Char("e"), .Char("r"), .Char("t"), .Char("y"), .Char("u"), .Char("i"), .Char("o"), .Char("p"), .Return])
            ]),
            Row(top: rows[2], bottom: rows[3], spans: [
                Span(left: left, right: deleteRight, keys: [.ExtendedMode]),
                Span(left: extendedRight, right: editRight, keys: [.Edit]),
                Span(left: editRight, right: returnLeft, keys: [.Char("a"), .Char("s"), .Char("d"), .Char("f"), .Char("g"), .Char("h"), .Char("j"), .Char("k"), .Char("l")]),
                Span(left: returnLeft, right: right, keys: [.Return])
            ]),
            Row(top: rows[3], bottom: rows[4], spans: [
                Span(left: left, right: leftCapsShiftRight, keys: [.Shift]),
                Span(left: leftCapsShiftRight, right: rightCapsShiftLeft, keys: [.ShiftLock, .Char("z"), .Char("x"), .Char("c"), .Char("v"), .Char("b"), .Char("n"), .Char("m"), .Char(".")]),
                Span(left: rightCapsShiftLeft, right: right, keys: [.Shift])
            ]),
            Row(top: rows[4], bottom: rows[5], spans: [
                Span(left: left, right: spaceLeft, keys: [.SymbolShift, .Char(";"), .Char("\""), .CursorLeft, .CursorRight]),
                Span(left: spaceLeft, right: spaceRight, keys: [.Char(" ")]),
                Span(left: spaceRight, right: right, keys: [.CursorUp, .CursorDown, .Char(","), .SymbolShift])
            ])
        ])
        self.imageName = imageName
        self.hasPressedImage = hasPressedImage
        self.keyboardSymbols = KeyboardSymbols.zxSpectrum
    }

    private static var keyboards: [String: Keyboard] = [
        "Atari XL": Keyboard(atariXlWithImageName: "Atari XL Keyboard",
                             rows: [65, 278, 469, 668, 870, 1085],
                             left: 88,
                             right: 3097,
                             escapeRight: 315,
                             tabRight: 418,
                             returnLeft: 2810,
                             controlRight: 472,
                             capsLeft: 2860,
                             leftShiftRight: 568,
                             rightShiftLeft: 2584,
                             rightShiftRight: 2910,
                             spaceLeft: 667,
                             spaceRight: 2473,
                             functionTop: 83,
                             functionBottom: 1073,
                             functionLeft: 3207,
                             functionRight: 3421),
        
        "C16": Keyboard(c16WithImageName: "C16 Keyboard",
                        rows: [72, 262, 442, 618, 817, 981],
                        topHalfLeft: 86,
                        topHalfRight: 2965,
                        bottomHalfLeft: 56,
                        bottomHalfRight: 2919,
                        functionKeysLeft: 3066,
                        functionKeysRight: 3366,
                        spaceLeft: 540,
                        spaceRight: 2149,
                        ctrlRight: 341,
                        clearLeft: 2073,
                        returnLeft: 2564,
                        leftShiftLeft: 205,
                        leftShiftRight: 480,
                        rightShiftLeft: 2287,
                        rightShiftRight: 2566),
        
        "C64": Keyboard(c64WithRenderedImage: "C64 Keyboard",
                        keyWidth: 210,
                        keyHeight: 210,
                        top: 90,
                        topHalfLeft: 150,
                        bottomHalfLeft: 93,
                        functionKeysLeft: 3615,
                        spaceLeft: 670,
                        spaceRight: 2550),
        
        "C64 Japanese": Keyboard(c64WithImageName: "C64 Keyboard Japanese",
                                 lockIsShift: false,
                                 poundIsYen: true,
                                 rows: [ 70, 263, 457, 650, 843, 1027 ],
                                 topHalfLeft: 97,
                                 topHalfRight: 3148,
                                 bottomHalfLeft: 56,
                                 bottomHalfRight: 3098,
                                 functionKeysLeft: 3219,
                                 functionKeysRight: 3532,
                                 spaceLeft: 573,
                                 spaceRight: 2288,
                                 ctrlRight: 370,
                                 restoreLeft: 2869,
                                 returnLeft: 2723,
                                 leftShiftLeft: 231,
                                 leftShiftRight: 524,
                                 rightShiftLeft: 2436,
                                 rightShiftRight: 2723),
        
        "C64C": Keyboard(c64WithRenderedImage: "C64C Keyboard",
                        keyWidth: 210,
                        keyHeight: 210,
                        top: 90,
                        topHalfLeft: 150,
                        bottomHalfLeft: 93,
                        functionKeysLeft: 3615,
                        spaceLeft: 670,
                        spaceRight: 2550),
       
        "C64C New": Keyboard(c64WithImageName: "C64C New Keyboard",
                             rows: [ 50, 233, 402, 571, 746, 917 ],
                             topHalfLeft: 97,
                             topHalfRight: 2853,
                             bottomHalfLeft: 63,
                             bottomHalfRight: 2805,
                             functionKeysLeft: 2952,
                             functionKeysRight: 3222,
                             spaceLeft: 540,
                             spaceRight: 2076,
                             ctrlRight: 348,
                             restoreLeft: 2603,
                             returnLeft: 2469,
                             leftShiftLeft: 215,
                             leftShiftRight: 477,
                             rightShiftLeft: 2215,
                             rightShiftRight: 2476),

        "C128": Keyboard(c128WithImageName: "C128 Keyboard",
                            rows: [327, 511, 680, 848, 1019, 1187],
                            left: 59,
                            right: 2762,
                            controlRight: 298,
                            restoreLeft: 2500,
                            returnLeft: 2420,
                            leftShiftLeft: 238,
                            leftShiftRight: 477,
                            rightShiftLeft: 2178,
                            rightShiftRight: 2404,
                            spaceLeft: 659,
                            spaceRight: 2159,
                            keypadLeft: 2837,
                            keypadRight: 3514,
                            keypad0Right: 3168,
                            functionRowTop: 93,
                            functionRowBottom: 278,
                            functionBlock1Right: 735,
                            functionBlock2Left: 1055,
                            functionBlock2Right: 1744,
                            functionBlock3Left: 2080),
        

        "C128 DE": Keyboard(c128WithImageName: "C128 DE Keyboard",
                            rows: [327, 511, 680, 848, 1019, 1187],
                            left: 59,
                            right: 2762,
                            controlRight: 298,
                            restoreLeft: 2500,
                            returnLeft: 2420,
                            leftShiftLeft: 238,
                            leftShiftRight: 477,
                            rightShiftLeft: 2178,
                            rightShiftRight: 2404,
                            spaceLeft: 659,
                            spaceRight: 2159,
                            keypadLeft: 2837,
                            keypadRight: 3514,
                            keypad0Right: 3168,
                            functionRowTop: 93,
                            functionRowBottom: 278,
                            functionBlock1Right: 735,
                            functionBlock2Left: 1055,
                            functionBlock2Right: 1744,
                            functionBlock3Left: 2080),
        
        "Max": Keyboard(c64WithImageName: "Max Keyboard",
                        rows: [ 32, 217, 400, 588, 780, 972 ],
                        topHalfLeft: 39,
                        topHalfRight: 3058,
                        bottomHalfLeft: 39,
                        bottomHalfRight: 3058,
                        functionKeysLeft: 3116,
                        functionKeysRight: 3408,
                        spaceLeft: 506,
                        spaceRight: 2393,
                        ctrlRight: 323,
                        restoreLeft: 2762,
                        returnLeft: 2671,
                        leftShiftLeft: 230,
                        leftShiftRight: 517,
                        rightShiftLeft: 2390,
                        rightShiftRight: 2671),
        
        "PET Style": Keyboard(c64WithRenderedImage: "PET Style Keyboard",
                        keyWidth: 210,
                        keyHeight: 210,
                        top: 90,
                        topHalfLeft: 150,
                        bottomHalfLeft: 93,
                        functionKeysLeft: 3615,
                        spaceLeft: 670,
                        spaceRight: 2550),
        
        "Plus/4": Keyboard(plus4WithImageName: "Plus 4 Keyboard",
                           rows: [50, 231, 444, 656, 871, 1074, 1284],
                           functionLeft: 283,
                           functionRight: 1915,
                           left: 79,
                           right: 3430,
                           leftControlRight: 385,
                           rightControlLeft: 3130,
                           returnLeft: 2800,
                           returnRight: 3218,
                           leftShiftLeft: 264,
                           leftShiftRight: 578,
                           rightShiftLeft: 2696,
                           rightShiftRight: 3007,
                           spaceLeft: 795,
                           spaceRight: 2689,
                           cursorTop: 900,
                           cursorLeft:3032,
                           cursorRight: 3429,
                           cursorBottom: 1292),
        
        "SX64": Keyboard(c64WithImageName: "SX64 Keyboard",
                         rows: [ 69, 269, 469, 669, 869, 1060 ],
                         topHalfLeft: 90,
                         topHalfRight: 3229,
                         bottomHalfLeft: 90,
                         bottomHalfRight: 3229,
                         functionKeysLeft: 3313,
                         functionKeysRight: 3625,
                         spaceLeft: 763,
                         spaceRight: 2538,
                         ctrlRight: 395,
                         restoreLeft: 2917,
                         returnLeft: 2837,
                         leftShiftLeft: 286,
                         leftShiftRight: 580,
                         rightShiftLeft: 2543,
                         rightShiftRight: 2837),
        
        "VIC-20": Keyboard(c64WithRenderedImage: "VIC-20 Keyboard",
                        keyWidth: 210,
                        keyHeight: 210,
                        top: 90,
                        topHalfLeft: 150,
                        bottomHalfLeft: 93,
                        functionKeysLeft: 3615,
                        spaceLeft: 670,
                        spaceRight: 2550),

        "VIC-1001": Keyboard(c64WithImageName: "PET Style Keyboard Japanese",
                             poundIsYen: true,
                             rows: [ 73, 224, 370, 514, 668, 811 ],
                             topHalfLeft: 84,
                             topHalfRight: 2463,
                             bottomHalfLeft: 55,
                             bottomHalfRight: 2428,
                             functionKeysLeft: 2535,
                             functionKeysRight: 2785,
                             spaceLeft: 468,
                             spaceRight: 1800,
                             ctrlRight: 302,
                             restoreLeft: 2234,
                             returnLeft: 2123,
                             leftShiftLeft: 198,
                             leftShiftRight: 421,
                             rightShiftLeft: 1898,
                             rightShiftRight: 2120),
        
        "X16": Keyboard(x16WithImageName: "X16 Keyboard",
                        rows: [152, 242, 325, 408, 493, 578],
                        left: 29,
                        right: 1294,
                        backspaceLeft: 1123,
                        tabRight: 168,
                        poundLeft: 1165,
                        shiftLockRight: 180,
                        returnLeft: 1101,
                        leftShiftRight: 221,
                        rightShiftLeft: 1061,
                        spaceLeft: 349,
                        spaceRight: 872,
                        extraLeft: 1312,
                        extraRight: 1569,
                        functionRowTop: 31,
                        functionRowBottom: 123,
                        escapeRight: 120,
                        functionBlock1Left: 197,
                        functionBlock1Right: 540,
                        functionBlock2Left: 574,
                        functionBlock2Right: 917,
                        functionBlock3Left: 951),
        
        "ZX Spectrum": Keyboard(zxSpectrumWithImageName: "ZX Spectrum Keyboard",
                                rows: [138, 466, 807, 1146, 1473],
                                left: [35, 205, 288],
                                right: [3422, 3588, 3648],
                                capsRight: 453,
                                spaceLeft: 3155),
        
        "ZX Spectrum+": Keyboard(zxSpectrumPlusWithImageName: "ZX Spectrum Plus Keyboard",
                                 rows: [52, 200, 342, 480, 622, 768],
                                 left: 54,
                                 right: 1968,
                                 breakLeft: 1755,
                                 deleteRight: 273,
                                 extendedRight: 273,
                                 editRight: 452,
                                 returnLeft: 1720,
                                 leftCapsShiftRight: 380,
                                 rightCapsShiftLeft: 1649,
                                 spaceLeft: 768,
                                 spaceRight: 1404),
        
        "ZX Spectrum +2": Keyboard(zxSpectrumPlusWithImageName: "ZX Spectrum +2 Keyboard",
                                   rows: [53, 162, 275, 390, 505, 624],
                                   left: 47,
                                   right: 1583,
                                   breakLeft: 1390,
                                   deleteRight: 216,
                                   extendedRight: 241,
                                   editRight: 350,
                                   returnLeft: 1364,
                                   leftCapsShiftRight: 296,
                                   rightCapsShiftLeft: 1309,
                                   spaceLeft: 602,
                                   spaceRight: 1116)
    ]
    
    public static func keyboard(named name: String) -> Keyboard? {
        return keyboards[name]
    }
}

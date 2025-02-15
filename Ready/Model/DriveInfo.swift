/*
 DriveInfo.swift -- Configure DriveStatusView
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

extension DriveStatusView {
    func configureFrom(drive: DiskDrive) {
        for index in (0 ..< numberOfLeds) {
            if index < drive.leds.count {
                ledViews[index].isRound = drive.leds[index].isRound
                ledViews[index].darkColor = drive.leds[index].darkColor
                ledViews[index].lightColor = drive.leds[index].lightColor
                ledViews[index].isHidden = false
            }
            else {
                ledViews[index].isHidden = true
            }
        }
        
        backgroundColor = drive.caseColor
        textColor = drive.textColor
        trackView.isDoubleSided = drive.isDoubleSided

        configureFrom(image: drive.image)
    }
    
    func configureFrom(image: DiskImage?) {
        if let image = image {
            trackView.tracks = image.tracks
            if trackView.isDoubleSided && !DiskDrive.isDoubleSided(connector: image.connector) {
                // single sided disk in double sided drive: only first side is used
                trackView.tracks *= 2
            }
        }
        else {
            trackView.tracks = 35
        }
        trackView.currentTrack = 1
    }
}

/*
 X16Thread.h -- EmulatorThread for X16 Emulator
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

#ifndef HAD_X16_THREAD_H
#define HAD_X16_THREAD_H

@import UIKit;
@import Emulator;

@protocol X16ThreadDelegate
@required
//- (NSString *_Nonnull)getDirectoryPath;
//- (void)updateDriveUnit:(int) unit track: (double)track;
//- (void)updateDriveUnit:(int) uint led1Intensity: (double)intensity1 led2Intensity: (double)intensity2;
//- (void)updateTapeControlStatus: (int)control;
//- (void)updateTapeCounter: (double)counter;
//- (void)updateTapeIsMotorOn: (int)motor;
//- (void)setupVice;
//- (void)viceSetResources;
//- (void)autostartInjectDeviceInfo;
- (BOOL)handleEvents;
//- (void)updateStatusBar;
@end

@interface X16Thread : EmulatorThread

@property NSString *dataDir;

@property BufferedAudio *_Nullable audio;

- (void)runEmulator;

@end

extern X16Thread * _Nullable x16Thread;

int x16_emulator_main(int argc, char **argv);

#endif /* HAD_X16_THREAD_H */

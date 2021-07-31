/*
 video.m -- Platform Specific Video Functions for Atari800 Emulator
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

#import <Foundation/Foundation.h>

#include "screen.h"
#include "Atari800Thread.h"

static uint32_t palette[] = {
    0x000000ff,
    0x1c1c1cff,
    0x393939ff,
    0x595959ff,
    0x797979ff,
    0x929292ff,
    0xabababff,
    0xbcbcbcff,
    0xcdcdcdff,
    0xd9d9d9ff,
    0xe6e6e6ff,
    0xecececff,
    0xf2f2f2ff,
    0xf8f8f8ff,
    0xffffffff,
    0xffffffff,
    0x391701ff,
    0x5e2304ff,
    0x833008ff,
    0xa54716ff,
    0xc85f24ff,
    0xe37820ff,
    0xff911dff,
    0xffab1dff,
    0xffc51dff,
    0xffce34ff,
    0xffd84cff,
    0xffe651ff,
    0xfff456ff,
    0xfff977ff,
    0xffff98ff,
    0xffff98ff,
    0x451904ff,
    0x721e11ff,
    0x9f241eff,
    0xb33a20ff,
    0xc85122ff,
    0xe36920ff,
    0xff811eff,
    0xff8c25ff,
    0xff982cff,
    0xffae38ff,
    0xffc545ff,
    0xffc559ff,
    0xffc66dff,
    0xffd587ff,
    0xffe4a1ff,
    0xffe4a1ff,
    0x4a1704ff,
    0x7e1a0dff,
    0xb21d17ff,
    0xc82119ff,
    0xdf251cff,
    0xec3b38ff,
    0xfa5255ff,
    0xfc6161ff,
    0xff706eff,
    0xff7f7eff,
    0xff8f8fff,
    0xff9d9eff,
    0xffabadff,
    0xffb9bdff,
    0xffc7ceff,
    0xffc7ceff,
    0x050568ff,
    0x3b136dff,
    0x712272ff,
    0x8b2a8cff,
    0xa532a6ff,
    0xb938baff,
    0xcd3ecfff,
    0xdb47ddff,
    0xea51ebff,
    0xf45ff5ff,
    0xfe6dffff,
    0xfe7afdff,
    0xff87fbff,
    0xff95fdff,
    0xffa4ffff,
    0xffa4ffff,
    0x280479ff,
    0x400984ff,
    0x590f90ff,
    0x70249dff,
    0x8839aaff,
    0xa441c3ff,
    0xc04adcff,
    0xd054edff,
    0xe05effff,
    0xe96dffff,
    0xf27cffff,
    0xf88affff,
    0xff98ffff,
    0xfea1ffff,
    0xfeabffff,
    0xfeabffff,
    0x35088aff,
    0x420aadff,
    0x500cd0ff,
    0x6428d0ff,
    0x7945d0ff,
    0x8d4bd4ff,
    0xa251d9ff,
    0xb058ecff,
    0xbe60ffff,
    0xc56bffff,
    0xcc77ffff,
    0xd183ffff,
    0xd790ffff,
    0xdb9dffff,
    0xdfaaffff,
    0xdfaaffff,
    0x051e81ff,
    0x0626a5ff,
    0x082fcaff,
    0x263dd4ff,
    0x444cdeff,
    0x4f5aeeff,
    0x5a68ffff,
    0x6575ffff,
    0x7183ffff,
    0x8091ffff,
    0x90a0ffff,
    0x97a9ffff,
    0x9fb2ffff,
    0xafbeffff,
    0xc0cbffff,
    0xc0cbffff,
    0x0c048bff,
    0x2218a0ff,
    0x382db5ff,
    0x483ec7ff,
    0x584fdaff,
    0x6159ecff,
    0x6b64ffff,
    0x7a74ffff,
    0x8a84ffff,
    0x918effff,
    0x9998ffff,
    0xa5a3ffff,
    0xb1aeffff,
    0xb8b8ffff,
    0xc0c2ffff,
    0xc0c2ffff,
    0x1d295aff,
    0x1d3876ff,
    0x1d4892ff,
    0x1c5cacff,
    0x1c71c6ff,
    0x3286cfff,
    0x489bd9ff,
    0x4ea8ecff,
    0x55b6ffff,
    0x70c7ffff,
    0x8cd8ffff,
    0x93dbffff,
    0x9bdfffff,
    0xafe4ffff,
    0xc3e9ffff,
    0xc3e9ffff,
    0x2f4302ff,
    0x395202ff,
    0x446103ff,
    0x417a12ff,
    0x3e9421ff,
    0x4a9f2eff,
    0x57ab3bff,
    0x5cbd55ff,
    0x61d070ff,
    0x69e27aff,
    0x72f584ff,
    0x7cfa8dff,
    0x87ff97ff,
    0x9affa6ff,
    0xadffb6ff,
    0xadffb6ff,
    0x0a4108ff,
    0x0d540aff,
    0x10680dff,
    0x137d0fff,
    0x169212ff,
    0x19a514ff,
    0x1cb917ff,
    0x1ec919ff,
    0x21d91bff,
    0x47e42dff,
    0x6ef040ff,
    0x78f74dff,
    0x83ff5bff,
    0x9aff7aff,
    0xb2ff9aff,
    0xb2ff9aff,
    0x04410bff,
    0x05530eff,
    0x066611ff,
    0x077714ff,
    0x088817ff,
    0x099b1aff,
    0x0baf1dff,
    0x48c41fff,
    0x86d922ff,
    0x8fe924ff,
    0x99f927ff,
    0xa8fc41ff,
    0xb7ff5bff,
    0xc9ff6eff,
    0xdcff81ff,
    0xdcff81ff,
    0x02350fff,
    0x073f15ff,
    0x0c4a1cff,
    0x2d5f1eff,
    0x4f7420ff,
    0x598324ff,
    0x649228ff,
    0x82a12eff,
    0xa1b034ff,
    0xa9c13aff,
    0xb2d241ff,
    0xc4d945ff,
    0xd6e149ff,
    0xe4f04eff,
    0xf2ff53ff,
    0xf2ff53ff,
    0x263001ff,
    0x243803ff,
    0x234005ff,
    0x51541bff,
    0x806931ff,
    0x978135ff,
    0xaf993aff,
    0xc2a73eff,
    0xd5b543ff,
    0xdbc03dff,
    0xe1cb38ff,
    0xe2d836ff,
    0xe3e534ff,
    0xeff258ff,
    0xfbff7dff,
    0xfbff7dff,
    0x401a02ff,
    0x581f05ff,
    0x702408ff,
    0x8d3a13ff,
    0xab511fff,
    0xb56427ff,
    0xbf7730ff,
    0xd0853aff,
    0xe19344ff,
    0xeda04eff,
    0xf9ad58ff,
    0xfcb75cff,
    0xffc160ff,
    0xffc671ff,
    0xffcb83ff,
    0xffcb83ff
};

int display_init(void) {
    RendererSize size = {Screen_visible_x2 - Screen_visible_x1, Screen_visible_y2 - Screen_visible_y1};
    RendererRect screenPosition = {{8, 24}, {320, 192}};
    [atari800Thread.renderer resize:size];
    atari800Thread.renderer.palette = palette;
    atari800Thread.renderer.screenPosition = screenPosition;
    
    return 0;
}

void display_fini(void) {
    [atari800Thread.renderer close];
}

void PLATFORM_DisplayScreen(void) {
    RendererImage image;
    image.data = (uint8_t *)Screen_atari + Screen_visible_y1 * Screen_WIDTH + Screen_visible_x1;
    image.rowSize = Screen_WIDTH;
    image.size.width = Screen_visible_x2 - Screen_visible_x1;
    image.size.height = Screen_visible_y2 - Screen_visible_y1;

    [atari800Thread.renderer render:&image];
    [atari800Thread displayImage];
}


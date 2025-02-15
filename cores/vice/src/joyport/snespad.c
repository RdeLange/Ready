/*
 * snespad.c - Single SNES PAD emulation.
 *
 * Written by
 *  Marco van den Heuvel <blackystardust68@yahoo.com>
 *
 * This file is part of VICE, the Versatile Commodore Emulator.
 * See README for copyright notice.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307  USA.
 *
 */

#include "vice.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "joyport.h"
#include "joystick.h"
#include "snespad.h"
#include "resources.h"
#include "snapshot.h"


#include "log.h"

/* Control port <--> SNES PAD connections:

   cport | SNES PAD | I/O
   -------------------------
     1   |   DATA1  |  I
     2   |   DATA2  |  I
     3   |   DATA3  |  I
     4   |   CLOCK  |  O
     6   |   RESET  |  O
 */


static int snespad_enabled = 0;

static int data_line = 0;

static int counter = 0;

static uint8_t clock_line = 0;
static uint8_t reset_line = 0;

/* Up Down Left Right Fire Fire2 Fire3  A L R Select Start */

static uint8_t button_sequence[12] = {
    4, /* B */
    5, /* Y */
    10, /* Select */
    11, /* Start */
    0, /* Up */
    1, /* Down */
    2, /* Left */
    3, /* Right */
    7, /* A */
    6, /* X */
    8, /* L */
    9 /* R */
};

/* Change this to change the default fire button */
#define SNESPAD_FIRE_BUTTON    SNESPAD_BUTTON_B

/* ------------------------------------------------------------------------- */

static int joyport_snespad_enable(int port, int value)
{
    int val = value ? 1 : 0;

    if (val == snespad_enabled) {
        return 0;
    }

    if (val) {
        counter = 0;
        data_line = 2; /* for Trap Them */
    }

    snespad_enabled = val;

    return 0;
}

static uint8_t snespad_read(int port)
{
    uint32_t retval;

    if (counter < 12) {
        retval = get_joystick_value(port + 1) & (1 << button_sequence[counter]);
    }
    else if (counter < 16) {
        retval = 1;
    }
    else {
        retval = 0;
    }

    return ((retval ? 1 : 0) << data_line) ^ 0xff;
}

static void snespad_store(uint8_t val)
{
    uint8_t new_clock = (val & 0x08) >> 3;
    uint8_t new_reset = (val & 0x10) >> 4;

    if (reset_line && !new_reset) {
        counter = 0;
    }

    if (clock_line && !new_clock) {
        if (counter != SNESPAD_EOS) {
            counter++;
        }
    }

    reset_line = new_reset;
    clock_line = new_clock;
}

/* ------------------------------------------------------------------------- */

static joyport_t joyport_snespad_device = {
    "SNES PAD",              /* name of the device */
    JOYPORT_RES_ID_NONE,     /* device can be used in multiple ports at the same time */
    JOYPORT_IS_NOT_LIGHTPEN, /* device is NOT a lightpen */
    JOYPORT_POT_OPTIONAL,    /* device does NOT use the potentiometer lines */
    joyport_snespad_enable,  /* device enable function */
    snespad_read,            /* digital line read function */
    snespad_store,           /* digital line store function */
    NULL,                    /* NO pot-x read function */
    NULL,                    /* NO pot-y read function */
    NULL,                    /* NO device write snapshot function */
    NULL                     /* NO device read snapshot function */
};

/* ------------------------------------------------------------------------- */

int joyport_snespad_resources_init(void)
{
    return joyport_device_register(JOYPORT_ID_SNESPAD, &joyport_snespad_device);
}

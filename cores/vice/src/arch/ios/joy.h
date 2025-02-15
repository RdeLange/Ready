/** \file   joy-unix.h
 * \brief   Joystick support for Linux - header
 *
 * \author  Bernhard Kuhn <kuhn@eikon.e-technik.tu-muenchen.de>
 * \author  Ulmer Lionel <ulmer@poly.polytechnique.fr>
 * \author  Daniel Sladic <sladic@eecg.toronto.edu>
 * \author  Luca Montecchiani <m.luca@usa.net> (http://i.am/m.luca)
 */

/*
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

#ifndef VICE_JOY_UNIX_H
#define VICE_JOY_UNIX_H

void joystick(void);
void joystick_close(void);
void old_joystick_init(void);
void old_joystick_close(void);
void old_joystick(void);
void new_joystick_init(void);
void new_joystick_close(void);
void new_joystick(void);

#ifdef HAS_USB_JOYSTICK
int usb_joystick_init(void);
void usb_joystick_close(void);
void usb_joystick(void);
#endif

/* standard devices */
#define JOYDEV_NONE      0
#define JOYDEV_NUMPAD    1
#define JOYDEV_KEYSET1   2
#define JOYDEV_KEYSET2   3
/* extra devices */
#define JOYDEV_MFI_0  4
#define JOYDEV_MFI_1  5

#define JOYDEV_DEFAULT   JOYDEV_NUMPAD

#define JOYDEV_MAX          JOYDEV_MFI_1

void joystick_ui_reset_device_list(void);
const char *joystick_ui_get_next_device_name(int *id);

#endif

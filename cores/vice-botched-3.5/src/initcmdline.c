/*
 * initcmdline.c - Initial command line options.
 *
 * Written by
 *  Andreas Boose <viceteam@t-online.de>
 *  Ettore Perazzoli <ettore@comm2000.it>
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

/* #define DEBUG_CMDLINE */

#include "vice.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "archdep.h"
#include "attach.h"
#include "autostart.h"
#include "cartridge.h"
#include "cmdline.h"
#include "initcmdline.h"
#include "ioutil.h"
#include "lib.h"
#include "log.h"
#include "machine.h"
#include "maincpu.h"
#include "resources.h"
#include "tape.h"
#include "util.h"
#include "vicefeatures.h"

#ifdef DEBUG_CMDLINE
#define DBG(x)  printf x
#else
#define DBG(x)
#endif

#define NUM_STARTUP_DISK_IMAGES 8
static char *autostart_string = NULL;
static char *startup_disk_images[NUM_STARTUP_DISK_IMAGES];
static char *startup_tape_image;
static unsigned int autostart_mode = AUTOSTART_MODE_NONE;


/** \brief  Get autostart mode
 *
 * \return  autostart mode
 */
int cmdline_get_autostart_mode(void)
{
    return autostart_mode;
}


void cmdline_set_autostart_mode(int mode)
{
    autostart_mode = mode;
}


static void cmdline_free_autostart_string(void)
{
    lib_free(autostart_string);
    autostart_string = NULL;
}

void initcmdline_shutdown(void)
{
    int unit;

    for (unit = 0; unit < NUM_STARTUP_DISK_IMAGES; unit++) {
        if (startup_disk_images[unit] != NULL) {
            //lib_free(startup_disk_images[unit]);
        }
        startup_disk_images[unit] = NULL;
    }
    if (startup_tape_image != NULL) {
        //lib_free(startup_tape_image);
    }
    startup_tape_image = NULL;
}

static int cmdline_help(const char *param, void *extra_param)
{
    cmdline_show_help(NULL);
    archdep_vice_exit(0);
    return 0;   /* OSF1 cc complains */
}

static int cmdline_features(const char *param, void *extra_param)
{
    const feature_list_t *list = vice_get_feature_list();

    printf("Compile time options:\n");
    while (list->symbol) {
        printf("%-25s %4s %s\n", list->symbol, list->isdefined ? "yes " : "no  ", list->descr);
        ++list;
    }

    archdep_vice_exit(0);
    return 0;   /* OSF1 cc complains */
}

static int cmdline_config(const char *param, void *extra_param)
{
    /* "-config" needs to be handled before this gets called
       but it also needs to be registered as a cmdline option,
       hence this kludge. */
    return 0;
}

static int cmdline_add_config(const char *param, void *extra_param)
{
    return resources_load(param);
}

static int cmdline_dumpconfig(const char *param, void *extra_param)
{
    return resources_dump(param);
}

static int cmdline_default(const char *param, void *extra_param)
{
    return resources_set_defaults();
}

static int cmdline_chdir(const char *param, void *extra_param)
{
    return ioutil_chdir(param);
}

static int cmdline_limitcycles(const char *param, void *extra_param)
{
    uint64_t clk_limit = strtoull(param, NULL, 0);
    if (clk_limit > CLOCK_MAX) {
        fprintf(stderr, "too many cycles, use max %u\n", CLOCK_MAX);
        return -1;
    }
    maincpu_clk_limit = (CLOCK)clk_limit;
    return 0;
}

static int cmdline_autostart(const char *param, void *extra_param)
{
    cmdline_free_autostart_string();
    autostart_string = lib_strdup(param);
    autostart_mode = AUTOSTART_MODE_RUN;
    return 0;
}

static int cmdline_autoload(const char *param, void *extra_param)
{
    cmdline_free_autostart_string();
    autostart_string = lib_strdup(param);
    autostart_mode = AUTOSTART_MODE_LOAD;
    return 0;
}

#if !defined(__OS2__) && !defined(__BEOS__)
static int cmdline_console(const char *param, void *extra_param)
{
    console_mode = 1;
    video_disabled_mode = 1;
    return 0;
}
#endif


static int cmdline_attach(const char *param, void *extra_param)
{
    int unit = vice_ptr_to_int(extra_param);

    switch (unit) {
        case 1:
            lib_free(startup_tape_image);
            startup_tape_image = lib_strdup(param);
            break;
        case 8:
        case 9:
        case 10:
        case 11:
            lib_free(startup_disk_images[unit - 8]);
            startup_disk_images[unit - 8] = lib_strdup(param);
            break;
        case 64:
        case 65:
        case 66:
        case 67:
            lib_free(startup_disk_images[unit - 64 + 4]);
            startup_disk_images[unit - 64 + 4] = lib_strdup(param);
            break;
        default:
            archdep_startup_log_error("cmdline_attach(): unexpected unit number %d?!\n", unit);
    }

    return 0;
}

static const cmdline_option_t common_cmdline_options[] =
{
    { "-help", CALL_FUNCTION, CMDLINE_ATTRIB_NONE,
      cmdline_help, NULL, NULL, NULL,
      NULL, "Show a list of the available options an_vice_xit normally" },
    { "-?", CALL_FUNCTION, CMDLINE_ATTRIB_NONE,
      cmdline_help, NULL, NULL, NULL,
      NULL, "Show a list of the available options and exit normally" },
    { "-h", CALL_FUNCTION, CMDLINE_ATTRIB_NONE,
      cmdline_help, NULL, NULL, NULL,
      NULL, "Show a list of the available options and exit normally" },
    { "-features", CALL_FUNCTION, CMDLINE_ATTRIB_NONE,
      cmdline_features, NULL, NULL, NULL,
      NULL, "Show a list of the available compile-time options and their configuration." },
    { "-default", CALL_FUNCTION, CMDLINE_ATTRIB_NONE,
      cmdline_default, NULL, NULL, NULL,
      NULL, "Restore default settings" },
    { "-config", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_config, NULL, NULL, NULL,
      "<filename>", "Specify config file" },
    { "-addconfig", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_add_config, NULL, NULL, NULL,
      "<filename>", "Specify extra config file for loading additional resources." },
    { "-dumpconfig", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_dumpconfig, NULL, NULL, NULL,
      "<filename>", "Dump all resources to specified config file" },
    { "-chdir", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_chdir, NULL, NULL, NULL,
      "Directory", "Change current working directory." },
    { "-limitcycles", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_limitcycles, NULL, NULL, NULL,
      "<value>", "Specify number of cycles to run before quitting with an error." },
    { "-console", CALL_FUNCTION, CMDLINE_ATTRIB_NONE,
      cmdline_console, NULL, NULL, NULL,
      NULL, "Console mode (for music playback)" },
    { "-core", SET_RESOURCE, CMDLINE_ATTRIB_NONE,
      NULL, NULL, "DoCoreDump", (resource_value_t)1,
      NULL, "Allow production of core dumps" },
    { "+core", SET_RESOURCE, CMDLINE_ATTRIB_NONE,
      NULL, NULL, "DoCoreDump", (resource_value_t)0,
      NULL, "Do not produce core dumps" },
    CMDLINE_LIST_END
};

/* These are the command-line options for the initialization sequence.  */

static const cmdline_option_t cmdline_options[] =
{
    { "-autostart", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_autostart, NULL, NULL, NULL,
      "<Name>", "Attach and autostart tape/disk image <name>" },
    { "-autoload", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_autoload, NULL, NULL, NULL,
      "<Name>", "Attach and autoload tape/disk image <name>" },
    { "-1", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)1, NULL, NULL,
      "<Name>", "Attach <name> as a tape image" },
    { "-8", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)8, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #8" },
    { "-8d1", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)64, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #8 drive #1" },
    { "-9", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)9, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #9" },
    { "-9d1", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)65, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #9 drive #1" },
    { "-10", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)10, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #10" },
    { "-10d1", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)66, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #10 drive #1" },
    { "-11", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)11, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #11" },
    { "-11d1", CALL_FUNCTION, CMDLINE_ATTRIB_NEED_ARGS,
      cmdline_attach, (void *)67, NULL, NULL,
      "<Name>", "Attach <name> as a disk image in unit #11 drive #1" },
    CMDLINE_LIST_END
};

int initcmdline_init(void)
{
    if (cmdline_register_options(common_cmdline_options) < 0) {
        return -1;
    }

    /* Disable autostart options for vsid */
    if (machine_class != VICE_MACHINE_VSID) {
        if (cmdline_register_options(cmdline_options) < 0) {
            return -1;
        }
    }

    return 0;
}

int initcmdline_check_psid(void)
{
    /* Check for PSID here since we don't want to allow autodetection
       in autostart.c. */
    if (machine_class == VICE_MACHINE_VSID) {
        if (autostart_string != NULL
            && machine_autodetect_psid(autostart_string) == -1) {
            log_error(LOG_DEFAULT, "`%s' is not a valid PSID file.",
                      autostart_string);
            return -1;
        }
    }

    return 0;
}

int initcmdline_check_args(int argc, char **argv)
{
    DBG(("initcmdline_check_args (argc:%d)\n", argc));
    if (cmdline_parse(&argc, argv) < 0) {
        archdep_startup_log_error("Error parsing command-line options, bailing out. For help use '-help'\n");
        return -1;
    }
    DBG(("initcmdline_check_args 1 (argc:%d)\n", argc));

    /* The last orphan option is the same as `-autostart'.  */
    if ((argc > 1) && (autostart_string == NULL)) {
        autostart_string = lib_strdup(argv[1]);
        autostart_mode = AUTOSTART_MODE_RUN;
        argc--, argv++;
    }
    DBG(("initcmdline_check_args 2 (argc:%d)\n", argc));

    if (argc > 1) {
        int len = 0, j;

        for (j = 1; j < argc; j++) {
            len += argv[j] ? (int)strlen(argv[j]) : 0;
        }

        {
            char *txt = lib_calloc(1, len + argc + 1);
            for (j = 1; j < argc; j++) {
                if (argv[j]) {
                    strcat(strcat(txt, " "), argv[j]);
                }
            }
            archdep_startup_log_error("Extra arguments on command-line: %s\n",
                                      txt);
            lib_free(txt);
        }
        return -1;
    }

    return 0;
}

void initcmdline_check_attach(void)
{
    if (machine_class != VICE_MACHINE_VSID) {
        /* Handle general-purpose command-line options.  */

        /* `-autostart' */
        if (autostart_string != NULL) {
            if (autostart_autodetect_opt_prgname(autostart_string, 0, autostart_mode) < 0) {
                log_error(LOG_DEFAULT,
                        "Failed to autostart '%s'", autostart_string);
                if (autostart_string != NULL) {
                    lib_free(autostart_string);
                }
                archdep_vice_exit(1);
            }
        }
        /* `-8', `-9', `-10' and `-11': Attach specified disk image.  */
        {
            int i;

            for (i = 0; i < 4; i++) {
                if (startup_disk_images[i] != NULL
                    && file_system_attach_disk(i + 8, 0, startup_disk_images[i])
                    < 0) {
                    log_error(LOG_DEFAULT,
                              "Cannot attach disk image `%s' to unit %d.",
                              startup_disk_images[i], i + 8);
                }
            }
            for (i = 4; i < 8; i++) {
                if (startup_disk_images[i] != NULL
                    && file_system_attach_disk(i + 4, 1, startup_disk_images[i])
                    < 0) {
                    log_error(LOG_DEFAULT,
                              "Cannot attach disk image `%s' to unit %d drive 1.",
                              startup_disk_images[i], i + 4);
                }
            }
        }

        /* `-1': Attach specified tape image.  */
        if (startup_tape_image && tape_image_attach(1, startup_tape_image) < 0) {
            log_error(LOG_DEFAULT, "Cannot attach tape image `%s'.",
                      startup_tape_image);
        }
    }

    cmdline_free_autostart_string();
}

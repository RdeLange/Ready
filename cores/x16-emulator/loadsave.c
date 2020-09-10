// Commander X16 Emulator
// Copyright (c) 2019 Michael Steil
// All rights reserved. License: 2-clause BSD

#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fnmatch.h>
#include <unistd.h>
#include <SDL.h>
#include "glue.h"
#include "memory.h"
#include "video.h"
#include "rom_symbols.h"
#include "loadsave.h"

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))

char *sdcard_dir;

#define IO_MAX_FILES 16

enum mode {
    FILE_COMMAND,
    FILE_CLOSED,
    FILE_WRITE,
    FILE_READ,
};

struct io_file {
    enum mode mode;
    uint8_t *data;
    size_t data_length;
    size_t data_capacity;
};

static struct io_file files[IO_MAX_FILES];

static int active_input;
static int active_output;

static const char *get_filename();

static bool handle_dos();
static void LOAD();
static void SAVE();

void io_init() {
    active_input = -1;
    active_output = -1;
    
    for (int i = 0; i < IO_MAX_FILES; i++) {
        files[i].mode = FILE_CLOSED;
        files[i].data = NULL;
        files[i].data_length = 0;
        files[i].data_capacity = 0;
    }
}

bool IO_CALL() {
    bool call_handled = false;
    switch (pc) {
    case DOS:
        printf("dos...\n");
        return handle_dos();

    case KERNAL_CLOSE:
        printf("CLOSE(%d)\n", a);
        break;
        
    case KERNAL_CHKIN:
        printf("CHKIN(%d)\n", x);
        break;
        
    case KERNAL_CHKOUT:
        printf("CHKIN(%d)\n", x);
        break;
        
    case KERNAL_CHRIN:
        printf("CHRIN()\n");
        break;
        
    case KERNAL_CHROUT:
        printf("CHROUT()\n");
        break;
        
    case KERNAL_CLRCHN:
        active_input = -1;
        active_output = -1;
        return false;
        
    case KERNAL_OPEN:
        if (RAM[FA] == 8) {
            printf("OPEN(%d, %d, %d, %s)\n", RAM[LA], RAM[FA], RAM[SA], get_filename());
            call_handled = true;
        }
        break;
        
    case KERNAL_LOAD:
        if (RAM[FA] == 8) {
            LOAD();
            call_handled = true;
        }
        break;
        
    case KERNAL_SAVE:
        if (RAM[FA] == 8) {
            SAVE();
            call_handled = true;
        }
        break;
        
    default:
        break;
    }
    
    return call_handled;
}

#if 0
static void convert_name(char *name, size_t length) {
    for (size_t i = 0; i < length; i++) {
        if (name[i] >= 'A' && name[i] <= 'Z') {
            name[i] = name[i] - 'A' + 'a';
        }
        else if  (name[i] >= 'a' && name[i] <= 'z') {
            name[i] = name[i] - 'a' + 'A';
        }
    }
}
#else
#define convert_name(name, length) (void)(0)
#endif

static void get_full_name(char *full_name, size_t length, const char *directory, const char *filename) {
    int found = 0;

    if (strcspn(filename, "*?") != strlen(filename)) {
        DIR *dirp;
        struct dirent *dp;
        
        if ((dirp = opendir(sdcard_dir))) {
            while ((dp = readdir(dirp))) {
                if (strcmp(dp->d_name, ".") == 0 || strcmp(dp->d_name, "..") == 0) {
                    continue;
                }
                if (fnmatch(filename, dp->d_name, FNM_NOESCAPE) == 0) {
                    snprintf(full_name, length, "%s/%s", directory, dp->d_name);
                    found = 1;
                    break;
                }
            }
        }
        (void)closedir(dirp);
    }
    
    if (!found) {
        snprintf(full_name, length, "%s/%s", directory, filename);
    }
}



static int
create_directory_listing(uint8_t *data)
{
	uint8_t *data_start = data;
	struct stat st;
	DIR *dirp;
	struct dirent *dp;
	int file_size;

	// We inject this directly into RAM, so
	// this does not include the load address!

	// link
	*data++ = 1;
	*data++ = 1;
	// line number
	*data++ = 0;
	*data++ = 0;
	*data++ = 0x12; // REVERSE ON
	*data++ = '"';
	for (int i = 0; i < 16; i++) {
		*data++ = ' ';
	}
    if (strcmp(sdcard_dir, ".") == 0) {
        if (!(getcwd((char *)data - 16, 256))) {
            return false;
        }
    }
    else {
        char *name = strrchr(sdcard_dir, '/');
        if (name == NULL) {
            name = sdcard_dir;
        }
        else {
            name += 1;
        }
        for (int i = 0; i < 16 && i < strlen(name); i++) {
            data[i - 16] = name[i];
        }
    }
    convert_name((char *)data - 16, 16);
	*data++ = '"';
	*data++ = ' ';
	*data++ = '0';
	*data++ = '0';
	*data++ = ' ';
	*data++ = 'P';
	*data++ = 'C';
	*data++ = 0;

	if (!(dirp = opendir(sdcard_dir))) {
		return 0;
	}
	while ((dp = readdir(dirp))) {
        if (strcmp(dp->d_name, ".") == 0 || strcmp(dp->d_name, "..") == 0) {
            continue;
        }
        char full_name[8192];
        snprintf(full_name, sizeof(full_name), "%s/%s", sdcard_dir, dp->d_name);
		size_t namlen = strlen(dp->d_name);
		stat(full_name, &st);
		file_size = (st.st_size + 255)/256;
		if (file_size > 0xFFFF) {
			file_size = 0xFFFF;
		}

		// link
		*data++ = 1;
		*data++ = 1;

		*data++ = file_size & 0xFF;
		*data++ = file_size >> 8;
		if (file_size < 1000) {
			*data++ = ' ';
			if (file_size < 100) {
				*data++ = ' ';
				if (file_size < 10) {
					*data++ = ' ';
				}
			}
		}
		*data++ = '"';
		if (namlen > 16) {
			namlen = 16; // TODO hack
		}
		memcpy(data, dp->d_name, namlen);
        convert_name((char *)data, namlen);
		data += namlen;
		*data++ = '"';
		for (int i = namlen; i < 16; i++) {
			*data++ = ' ';
		}
		*data++ = ' ';
		*data++ = 'P';
		*data++ = 'R';
		*data++ = 'G';
		*data++ = 0;
	}

	// link
	*data++ = 1;
	*data++ = 1;

	*data++ = 255; // "65535"
	*data++ = 255;

	char *blocks_free = "BLOCKS FREE.";
	memcpy(data, blocks_free, strlen(blocks_free));
	data += strlen(blocks_free);
	*data++ = 0;

	// link
	*data++ = 0;
	*data++ = 0;
	(void)closedir(dirp);
	return data - data_start;
}

void
LOAD()
{
	char filename[41];
	uint8_t len = MIN(RAM[FNLEN], sizeof(filename) - 1);
	memcpy(filename, (char *)&RAM[RAM[FNADR] | RAM[FNADR + 1] << 8], len);
	filename[len] = 0;
    convert_name(filename, len);

	uint16_t override_start = (x | (y << 8));

	if (filename[0] == '$') {
		uint16_t dir_len = create_directory_listing(RAM + override_start);
		uint16_t end = override_start + dir_len;
		x = end & 0xff;
		y = end >> 8;
		status &= 0xfe;
		RAM[STATUS] = 0;
		a = 0;
	} else {
        char full_name[8192];
        get_full_name(full_name, sizeof(full_name), sdcard_dir, filename);
		SDL_RWops *f = SDL_RWFromFile(full_name, "rb");
		if (!f) {
			a = 4; // FNF
			RAM[STATUS] = a;
			status |= 1;
			return;
		}
		uint8_t start_lo = SDL_ReadU8(f);
		uint8_t start_hi = SDL_ReadU8(f);

		uint16_t start;
		if (!RAM[SA]) {
			start = override_start;
		} else {
			start = start_hi << 8 | start_lo;
		}

		size_t bytes_read = 0;
		if(a > 1) {
			// Video RAM
			video_write(0, start & 0xff);
			video_write(1, start >> 8);
			video_write(2, ((a - 2) & 0xf) | 0x10);
			uint8_t buf[2048];
			while(1) {
				size_t n = SDL_RWread(f, buf, 1, sizeof buf);
				if(n == 0) break;
				for(size_t i = 0; i < n; i++) {
					video_write(3, buf[i]);
				}
				bytes_read += n;
			}
		} else if(start < 0x9f00) {
			// Fixed RAM
			bytes_read = SDL_RWread(f, RAM + start, 1, 0x9f00 - start);
		} else if(start < 0xa000) {
			// IO addresses
		} else if(start < 0xc000) {
			// banked RAM
			while(1) {
				size_t len = 0xc000 - start;
				bytes_read = SDL_RWread(f, RAM + ((uint16_t)memory_get_ram_bank() << 13) + start, 1, len);
				if(bytes_read < len) break;

				// Wrap into the next bank
				start = 0xa000;
				memory_set_ram_bank(1 + memory_get_ram_bank());
			}
		} else {
			// ROM
		}

		SDL_RWclose(f);

		uint16_t end = start + bytes_read;
		x = end & 0xff;
		y = end >> 8;
		status &= 0xfe;
		RAM[STATUS] = 0;
		a = 0;
	}
}

void
SAVE()
{
	char filename[41];
	uint8_t len = MIN(RAM[FNLEN], sizeof(filename) - 1);
	memcpy(filename, (char *)&RAM[RAM[FNADR] | RAM[FNADR + 1] << 8], len);
	filename[len] = 0;
    convert_name(filename, len);

	uint16_t start = RAM[a] | RAM[a + 1] << 8;
	uint16_t end = x | y << 8;
	if (end < start) {
		status |= 1;
		a = 0;
		return;
	}

    char full_name[8192];
    get_full_name(full_name, sizeof(full_name), sdcard_dir, filename);
	SDL_RWops *f = SDL_RWFromFile(full_name, "wb");
	if (!f) {
		a = 4; // FNF
		RAM[STATUS] = a;
		status |= 1;
		return;
	}

	SDL_WriteU8(f, start & 0xff);
	SDL_WriteU8(f, start >> 8);

	SDL_RWwrite(f, RAM + start, 1, end - start);
	SDL_RWclose(f);

	status &= 0xfe;
	RAM[STATUS] = 0;
	a = 0;
}

static const char *get_filename() {
    static char filename[256];
    
    size_t len = RAM[FNLEN];
    memcpy(filename, (char *)&RAM[RAM[FNADR] | RAM[FNADR + 1] << 8], len);
    filename[len] = 0;

    return filename;
}

static bool handle_dos() {
    char command[256];
    
    /* TODO: check that current device is 8 */
    
    if ((status & 0x02) == 0x02 || a == 0) {
        /* TODO: print status */
        return true;
    }
    
    memcpy(command, RAM + (RAM[INDEX1] + (RAM[INDEX1 + 1] << 8)), a);
    command[a] = '\0';
    
    if (isdigit(command[0]) && command[1] == '\0') {
        /* change device */
        return false;
    }
    
    printf("DOS(%s)\n", command);
    
    return true;
}

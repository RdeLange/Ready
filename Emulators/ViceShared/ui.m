/*
 ui.m -- UI Glue Code
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

#include "uiapi.h"
#include "archdep.h"
#import "ViceThread.h"

static int is_paused;

/** \brief  Pre-initialize the UI before the canvas window gets created
 *
 * \return  0 on success, -1 on failure
 */
int c128ui_init_early(void)
{
    return 0;
}


/** \brief  Initialize the UI
 *
 * \return  0 on success, -1 on failure
 */
int c128ui_init(void) {
    return 0;
}


/** \brief  Shut down the UI
 */
void c128ui_shutdown(void) {
}


/** \brief  Pre-initialize the UI before the canvas window gets created
 *
 * \return  0 on success, -1 on failure
 */
int c64scui_init_early(void)
{
    return 0;
}


/** \brief  Initialize the UI
 *
 * \return  0 on success, -1 on failure
 */
int c64scui_init(void) {
    return 0;
}


/** \brief  Shut down the UI
 */
void c64scui_shutdown(void) {
}


/** \brief  Pre-initialize the UI before the canvas window gets created
 *
 * \return  0 on success, -1 on failure
 */
int c64ui_init_early(void)
{
    return 0;
}


/** \brief  Initialize the UI
 *
 * \return  0 on success, -1 on failure
 */
int c64ui_init(void) {
    return 0;
}


/** \brief  Shut down the UI
 */
void c64ui_shutdown(void) {
}


/** \brief  Pre-initialize the UI before the canvas window gets created
 *
 * \return  0 on success, -1 on failure
 */
int plus4ui_init_early(void)
{
    return 0;
}


/** \brief  Initialize the UI
 *
 * \return  0 on success, -1 on failure
 */
int plus4ui_init(void) {
    return 0;
}


/** \brief  Shut down the UI
 */
void plus4ui_shutdown(void) {
}


/** \brief  Pre-initialize the UI before the canvas window gets created
 *
 * \return  0 on success, -1 on failure
 */
int scpu64ui_init_early(void)
{
    return 0;
}


/** \brief  Initialize the UI
 *
 * \return  0 on success, -1 on failure
 */
int scpu64ui_init(void) {
    return 0;
}


/** \brief  Shut down the UI
 */
void scpu64ui_shutdown(void) {
}


/** \brief  Initialize the UI
 *
 * \return  0 on success, -1 on failure
 */
int vic20ui_init(void) {
    return 0;
}


/** \brief  Pre-initialize the UI before the canvas window gets created
 *
 * \return  0 on success, -1 on failure
 */
int vic20ui_init_early(void)
{
    return 0;
}

void vic20ui_shutdown(void) {
}


/** \brief  Initialize command line options (generic)
 *
 * \return  0 on success, -1 on failure
 */
int ui_cmdline_options_init(void) {
    return 0;
}


/** \brief Statusbar API function to report mounting or unmounting of
 *         a disk image.
 *
 *  \param drive_number 0-3 to represent drives at device 8-11.
 *  \param image        The filename of the disk image (if mounted),
 *                      or the empty string or NULL (if unmounting).
 *  \todo This API is insufficient to describe drives with two disk units.
 */
void ui_display_drive_current_image(unsigned int unit_number, unsigned int drive_number, const char *image) {
}


/** \brief Statusbar API function to report changes in drive LED
 *         intensity.
 *  \param drive_number The unit to update (0-3 for drives 8-11)
 *  \param led_pwm1         The intensity of the first LED (0=off,
 *                      1000=maximum intensity)
 *  \param led_pwm2     The intensity of the second LED (0=off,
 *                      1000=maximum intensity)
 *  \todo The statusbar API does not yet support dual-unit disk
 *        drives.
 */
// TODO 3.5: what's drive_base?
void ui_display_drive_led(unsigned int drive_number, unsigned int drive_base, unsigned int led_pwm1, unsigned int led_pwm2) {
    [viceThread.delegate updateDriveUnit:drive_number led1Intensity:led_pwm1 / 1000.0 led2Intensity: led_pwm2 / 1000.0];
}

/** \brief Statusbar API function to report changes in drive head
 *         location.
 *  \param drive_number      The unit to update (0-3 for drives 8-11)
 *  \param drive_base        Currently unused.
 *  \param half_track_number Twice the value of the head
 *                           location. 18.0 is 36, while 18.5 would be
 *                           37.
 *  \todo The statusbar API does not yet support dual-unit disk
 *        drives. The drive_base argument will likely come into play
 *        once it does.
 */
void ui_display_drive_track(unsigned int drive_number, unsigned int drive_base, unsigned int half_track_number) {
    [viceThread.delegate updateDriveUnit:drive_number track:half_track_number / 2.0];
}


/** \brief Statusbar API function to register an elapsed time.
 *
 *  \param current The current time value.
 *  \param total   The maximum time value
 */
void ui_display_event_time(unsigned int current, unsigned int total) {
}


/** \brief Statusbar API function to display current joyport inputs.
 *  \param joyport An array of bytes of size at least
 *                 JOYPORT_MAX_PORTS+1, with data regarding each
 *                 active joyport.
 *  \warning The joyport array is, for all practical purposes,
 *           _1-indexed_. joyport[0] is unused.
 *  \sa ui_sb_state_s::current_joyports Describes the format of the
 *      data encoded in the joyport array. Note that current_joyports
 *      is 0-indexed as is typical for C arrays.
 */
void ui_display_joyport(uint8_t *joyport) {
}


/** \brief Statusbar API function to display playback status.
 *
 *  \param playback_status Unknown.
 *  \param version         Unknown.
 *
 *  \todo This function is not implemented and its API is not
 *        understood.
 */
void ui_display_playback(int playback_status, char *version) {
}


/** \brief Statusbar API function to display recording status.
 *
 *  \param recording_status Unknown.
 *
 *  \todo This function is not implemented and its API is not
 *        understood.
 */
void ui_display_recording(int recording_status) {
}


/** \brief Statusbar API function to report mounting or unmounting of
 *         a tape image.
 *
 *  \param image The filename of the tape image (if mounted), or the
 *               empty string or NULL (if unmounting).
 */
void ui_display_tape_current_image(const char *image) {
}


/** \brief Statusbar API function to report changes in tape control
 *         status.
 *
 *  \param control The new tape control. See the DATASETTE_CONTROL_*
 *                 constants in datasette.h for legal values of this
 *                 parameter.
 */
void ui_display_tape_control_status(int control) {
    [viceThread.delegate updateTapeControlStatus: control];
}


/** \brief Statusbar API function to report changes in tape position.
 *
 *  \param counter The new value of the position counter.
 */
void ui_display_tape_counter(double counter) {
    [viceThread.delegate updateTapeCounter:counter];
}


/** \brief Statusbar API function to report changes in the tape motor.
 *
 *  \param motor Nonzero if the tape motor is now on.
 */
void ui_display_tape_motor_status(int motor) {
    [viceThread.delegate updateTapeIsMotorOn: motor != 0];
}


/** \brief Statusbar API function to display current volume
 *

 * \param[in]   vol     new volume level
 */
void ui_display_volume(int vol) {
}

/** \brief  This should display some 'pause' status indicator on the statusbar
 *
 * \param[in]   flag    pause state
 */
void ui_display_paused(int flag)
{
    // TODO: implement
}


/** \brief  Get pause active state
 *
 * \return  boolean
 */
int ui_pause_active(void) {
    return is_paused;
}

/** \brief  Pause emulation
 */
void ui_pause_enable(void) {
    if (!ui_pause_active()) {
        is_paused = 1;
        ui_display_paused(1);
    }
}


/** \brief  Unpause emulation
 */
void ui_pause_disable(void)
{
    if (ui_pause_active()) {
        is_paused = 0;
        ui_display_paused(0);
    }
}


/** \brief Update information about each drive.
 *
 *  \param state           A bitmask int, where bits 0-3 indicate
 *                         whether or not drives 8-11 respectively are
 *                         being emulated carefully enough to provide
 *                         LED information.
 *  \param drive_led_color An array of size at least DRIVE_NUM that
 *                         provides information about the LEDs on this
 *                         drive. An element of this array will only
 *                         be checked if the corresponding bit in
 *                         state is 1.
 *  \note Before calling this function, the drive configuration
 *        resources (Drive8Type, Drive9Type, etc) should all be set to
 *        the values you wish to display.
 *  \warning If a drive's LEDs are active when its LED values change,
 *           the UI will not reflect the LED type change until the
 *           next time the led's values are updated. This should not
 *           happen under normal circumstances.
 *  \sa compute_drives_enabled_mask() for how this function determines
 *      which drives are truly active
 *  \sa ui_sb_state_s::drive_led_types for the data in each element of
 *      drive_led_color
 */
void ui_enable_drive_status(ui_drive_enable_t state, int *drive_led_color) {
}


/** \brief  Display error message through the UI
 *
 * \param[in]   format  format string for the error
 */
void ui_error(const char *format, ...) {
}


/** \brief  Display the "Do you want to extend the disk image to
 *          40-track format?" dialog
 *
 * \return  nonzero to extend the image, 0 otherwise
 */
int ui_extend_image_dialog(void) {
    return 0;
}


/** \brief  Display a generic file chooser dialog
 *
 * \param[in]   format  format string for the dialog's title
 *
 * \return  a copy of the chosen file's name; free it with lib_free()
 *
 * \note    This is currently only called by event_playback_attach_image()
 *
 * \warning This function is unimplemented and will intentionally crash
 *          VICE if it is called.
 */
char *ui_get_file(const char *format, ...) {
    return NULL;
}


/** \brief  Initialize UI
 *
 * \param[in]   argc    pointer to main()'s argc
 * \param[in]   argv    main()'s argv
 *
 * \return  0 on success, -1 on failure
 */
int ui_init(int *argc, char **argv) {
    [viceThread.delegate setupVice];
    archdep_set_resources();
    return 0;
}


/** \brief  Finalize initialization after creating the main window(s)
 *
 * \return  0 on success, -1 on failure
 *
 * \sa      ui_init_finish()
 */
int ui_init_finalize(void)
{
    return 0;
}


/** \brief  Finish initialization after loading the resources
 *
 * \note    This function exists for compatibility with other UIs.
 *
 * \return  0 on success, -1 on failure
 *
 * \sa      ui_init_finalize()
 */
int ui_init_finish(void) {
    return 0;
}


/** \brief  Display a dialog box in response to a CPU jam
 *
 * \param[in]   format  format string for the message to display
 *
 * \return  the action the user selected in response to the jam
 */
ui_jam_action_t ui_jam_dialog(const char *format, ...) {
    return UI_JAM_NONE;
}


/* Print a message.  */
void ui_message(const char *format, ...) {
}


/** \brief  Pause emulation
 *
 * \param[in]   flag    toggle pause state if true
 */
void ui_pause_emulation(int flag)
{
}


/** \brief  Initialize resources related to the UI in general
 *
 * \return  0 on success, -1 on failure
 */
int ui_resources_init(void) {
    return 0;
}


/** \brief  Clean up memory used by VICE resources
 */
void ui_resources_shutdown(void) {
}


/** \brief Statusbar API function to report changes in tape status.
 *  \param tape_status The new tape status.
 *  \note This function does nothing and its API is not
 *        understood. Furthermore, no other extant UIs appear to react
 *        to this call.
 */
void ui_set_tape_status(int tape_status) {
}


/** \brief Clean up memory used by the UI system itself
 */
void ui_shutdown(void) {
}


/** \brief  Update all menu item checkmarks on all windows
 *
 * \note    This is called from multiple functions in autostart.c and also
 *          mon_resource_set() in monitor/monitor.c when they change the
 *          value of resources.
 *
 * \todo    This is unimplemented, but will be much easier to implement if we
 *          switch to using a GtkApplication/GMenu based UI.
 */
void ui_update_menus(void) {
}


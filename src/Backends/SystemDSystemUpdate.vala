/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

[DBus (name="io.elementary.settings_daemon.SystemUpdate")]
public class SettingsDaemon.Backends.SystemDSystemUpdate : Object {
    public struct UpdateDetails {
        string[] packages;
        uint64 size;
        Pk.Info[] info;
    }

    private const string NOTIFICATION_ID = "system-update";

    public signal void state_changed ();

    private static Settings settings = new GLib.Settings ("io.elementary.settings-daemon.system-update");

    private PkUtils.CurrentState current_state;
    private UpdateDetails update_details;

    private SysupdateTarget target;
    private SysupdateJob? current_job;

    construct {
        current_state = {
            UP_TO_DATE,
            "",
            0,
            0
        };

        update_details = {
            {},
            0,
            {}
        };
    }

    public async void check_for_updates (bool force, bool notify) throws DBusError, IOError {
        if (SettingsDaemon.Utils.is_running_in_demo_mode () && !force) {
            return;
        }

        if (current_state.state != UP_TO_DATE && current_state.state != AVAILABLE && !force) {
            return;
        }

        update_state (CHECKING);

        var update_available = false;
        try {
            var new_version = yield target.check_new ();

            update_available = new_version != null;
        } catch (Error e) {
            critical ("Failed to check for updates: %s", e.message);
            update_state (UP_TO_DATE);
            return;
        }

        if (update_available) {
            update_state (AVAILABLE);
        } else {
            update_state (UP_TO_DATE);
        }
    }

    public async void update () throws DBusError, IOError {
        if (current_state.state != AVAILABLE) {
            return;
        }

        update_state (DOWNLOADING);

        try {
            current_job = yield target.update (NEWEST);
        } catch (Error e) {
            critical ("Failed to start update: %s", e.message);
            send_error (e.message);
            return;
        }

        current_job.completed.connect (on_job_completed);
    }

    public void cancel () throws DBusError, IOError {
        if (current_state.state != DOWNLOADING) {
            return;
        }

        current_job.cancel ();
    }

    private void progress_callback (Pk.Progress progress, Pk.ProgressType progress_type) {
        update_state (
            current_state.state,
            PkUtils.status_to_title (progress.status),
            progress.percentage,
            progress.download_size_remaining
        );
    }

    private void on_job_completed (Error? error) {

    }

    private void send_error (string message) {
        var notification = new Notification (_("System updates couldn't be installed"));
        notification.set_body (_("An error occurred while trying to update your system"));
        notification.set_icon (new ThemedIcon ("dialog-error"));
        notification.set_default_action (Application.ACTION_PREFIX + Application.SHOW_UPDATES_ACTION);

        GLib.Application.get_default ().send_notification (NOTIFICATION_ID, notification);

        update_state (ERROR, message);
    }

    private void update_state (
        PkUtils.State state,
        string message = "",
        uint percentage = 0,
        uint64 download_size_remaining = 0
    ) {
        current_state = {
            state,
            message,
            percentage,
            download_size_remaining
        };

        state_changed ();
    }

    public async PkUtils.CurrentState get_current_state () throws DBusError, IOError {
        return current_state;
    }

    public async UpdateDetails get_update_details () throws DBusError, IOError {
        return update_details;
    }

    public async int64 get_last_refresh_time () throws DBusError, IOError {
        return settings.get_int64 ("last-refresh-time");
    }
}

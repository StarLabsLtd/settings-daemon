/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

private interface Sysupdate.Job : Object {
    public abstract async string check_new () throws DBusError, IOError;
    public abstract async void update (string new_version, uint64 flags) throws DBusError, IOError;
}

public class SettingsDaemon.Backends.SysupdateJob : Object {
    public signal void completed (Error? error);

    public ObjectPath path { private get; construct; }

    private Sysupdate.Job? job;

    private bool is_completed = false;

    public SysupdateJob (ObjectPath path) {
        Object (path: path);
    }

    construct {

    }

    internal void notify_completed (int status) {
        is_completed = true;

        if (status == 0) {
            completed (null);
        } else {
            completed (new IOError.FAILED ("Job failed with status: %d".printf (status)));
        }
    }

    public void cancel () {
    }
}

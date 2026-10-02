/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

namespace Sysupdate {
    public const string BUS_NAME = "org.freedesktop.sysupdate1";
    public const string HOST_PATH = "/org/freedesktop/sysupdate1/target/host";
}

private interface Sysupdate.Target : Object {
    public abstract async string check_new () throws DBusError, IOError;
    public abstract async string get_version () throws DBusError, IOError;
    public abstract async void update (string? new_version, int64 flags, out string used_version, out int64 job_id, out ObjectPath job_path) throws DBusError, IOError;
}

/**
 * This class represents the sysupdate host target i.e. the operating system.
 * The usually use of this class is to
 * - first check if there is an ongoing job either started by you or somebody else
 * - then check if there is a new version available
 * - finally start an update if desired and connect to the signals on the job to monitor progress
 *   and success
 */
public class SettingsDaemon.Backends.SysupdateTarget : Object {
    public enum UpdateVersion {
        NEWEST,
        CURRENT,
    }

    public string path { get; construct; }

    private Sysupdate.Target? target;

    public SysupdateTarget (string path) {
        Object (path: path);
    }

    construct {
        Bus.watch_name (SYSTEM, Sysupdate.BUS_NAME, NONE, () => on_name_appeared.begin (), on_name_vanished);
    }

    private async void on_name_appeared () {
        try {
            target = yield Bus.get_proxy (SYSTEM, Sysupdate.BUS_NAME, path, NONE, null);
        } catch (Error e) {
            warning ("Failed to get sysupdate host target proxy: %s", e.message);
        }
    }

    private void on_name_vanished () {
        target = null;
    }

    public async SysupdateJob? check_for_ongoing_job () throws Error {
        // TODO
        return null;
    }

    public async string? check_new () throws Error {
        if (target == null) {
            throw new IOError.NOT_CONNECTED ("Sysupdate host target is not available");
        }

        var new_version = yield target.check_new ();

        if (new_version == "") {
            /* According to docs empty string means no new version is available so make that clearer
               by returning null */
            return null;
        }

        return new_version;
    }

    /**
     * Starts an update. This is both used to actually update the system to a newer version
     * but also to apply newly selected or deselected features.
     * You can specify what version you want to use with {@link version}.
     */
    public async SysupdateJob update (UpdateVersion version) throws Error {
        if (target == null) {
            throw new IOError.NOT_CONNECTED ("Sysupdate host target is not available");
        }

        /* Null means newest available so we use it when version is UpdateVersion.NEWEST */
        string? version_string = null;

        if (version == CURRENT) {
            version_string = yield target.get_version ();
        }

        ObjectPath job_path;
        yield target.update (version_string, 0, null, null, out job_path);

        return new SysupdateJob (job_path);
    }
}

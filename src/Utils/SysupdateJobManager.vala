/*
 * Copyright 2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */


[DBus (name = "org.freedesktop.sysupdate1.Manager")]
private interface Sysupdate.Manager : Object {
    public const string PATH = "/org/freedesktop/sysupdate1";

    public signal void job_removed (int64 job_id, ObjectPath object_path, int status);
}

public class SettingsDaemon.Backends.SysupdateJobManager : Object {
    private static Once<SysupdateJobManager> instance;

    public static SysupdateJobManager get_default () {
        return instance.once (() => new SysupdateJobManager ());
    }

    private Sysupdate.Manager? manager;

    private HashTable<ObjectPath, SysupdateJob> jobs;

    private SysupdateJobManager () { }

    construct {
        jobs = new HashTable<ObjectPath, SysupdateJob> (str_hash, str_equal);

        Bus.watch_name (SYSTEM, Sysupdate.BUS_NAME, NONE, () => on_name_appeared.begin (), on_name_vanished);
    }

    private async void on_name_appeared () {
        try {
            manager = yield Bus.get_proxy (SYSTEM, Sysupdate.BUS_NAME, Sysupdate.Manager.PATH, NONE, null);

            manager.job_removed.connect (on_job_removed);
        } catch (Error e) {
            warning ("Failed to get sysupdate manager proxy: %s", e.message);
        }
    }

    private void on_name_vanished () {
        manager = null;
    }

    private void on_job_removed (int64 job_id, ObjectPath object_path, int status) {
        var job = jobs[object_path];

        job.notify_completed (status);

        jobs.remove (object_path);
    }
}

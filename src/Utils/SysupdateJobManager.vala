/*
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class SettingsDaemon.Utils.SysupdateJobManager : Object {
    private Sysupdate.Manager manager;
    private string? owner;

    private HashTable<string, int> received_object_paths;

    public async SysupdateJobManager (Cancellable cancellable) throws Error {
        manager = yield Bus.get_proxy (SYSTEM, Sysupdate.BUS_NAME, Sysupdate.Manager.PATH, NONE, cancellable);
        owner = manager.g_name_owner;
        manager.job_removed.connect (on_job_removed);
    }

    construct {
        received_object_paths = new HashTable<string, int> (str_hash, str_equal);
    }

    private void on_job_removed (uint64 finished_job_id, string finished_object_path, int status) {
        if (manager.g_name_owner == owner) {
            received_object_paths[finished_object_path] = status;
        }
    }

    /**
     * Waits for the job to complete or returns immediately if the job has already completed.
     * If the job has failed an error will be thrown.
     * Note that for this to reliably work without races the this has to have been created before
     * the job was started.
     */
    public async void wait_for_job (SysupdateJob job) throws Error {
        if (job.path in received_object_paths) {
            check_status (job);
            return;
        }

        if (owner == null || manager.g_name_owner != owner) {
            job.notify_completed ();
            throw new IOError.CLOSED ("Update service disappeared");
        }

        var signal_id = manager.job_removed.connect ((job_id, job_path) => {
            if (job_path == job.path) {
                wait_for_job.callback ();
            }
        });

        var owner_id = manager.notify["g-name-owner"].connect (() => {
            if (manager.g_name_owner != owner) {
                wait_for_job.callback ();
            }
        });

        yield;

        manager.disconnect (signal_id);
        manager.disconnect (owner_id);

        if (!(job.path in received_object_paths)) {
            job.notify_completed ();
            throw new IOError.CLOSED ("Update service disappeared");
        }

        check_status (job);
    }

    private void check_status (SysupdateJob job) throws Error {
        job.notify_completed ();

        var status = received_object_paths[job.path];

        if (status == 0) {
            return;
        }

        if (status > 0) {
            throw new IOError.FAILED ("Job failed with exit code: %d".printf (status));
        }

        if (status < 0) {
            throw IOError.from_errno (-status);
        }
    }
}

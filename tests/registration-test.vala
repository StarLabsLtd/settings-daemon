[DBus (name = "org.freedesktop.sysupdate1.Target")]
public class TestUpdateTarget : Object {
    public bool fail_check;
    public bool fail_version;
    public string available = "";
    public string installed = "pending";

    public async string check_new () throws DBusError, IOError {
        if (fail_check) {
            throw new DBusError.FAILED ("Controlled update check failure");
        }
        return available;
    }

    public async void update (string version, uint64 flags, out string used_version,
                              out uint64 job_id, out ObjectPath job_path) throws DBusError, IOError {
        used_version = "next";
        job_id = 1;
        job_path = (ObjectPath) "/org/freedesktop/sysupdate1/job/1";
        throw new IOError.CANCELLED ("Operation was cancelled");
    }

    public async string get_version () throws DBusError, IOError {
        if (fail_version) {
            throw new DBusError.FAILED ("Controlled installed-version failure");
        }
        return installed;
    }
}

private void check_update (SettingsDaemon.Backends.SystemUpdate update,
                           SettingsDaemon.PkUtils.State expected,
                           string expected_error = "") throws Error {
    var loop = new MainLoop ();
    Error? failure = null;
    update.check_for_updates.begin (true, false, (obj, result) => {
        try {
            update.check_for_updates.end (result);
        } catch (Error e) {
            failure = e;
        }
        loop.quit ();
    });
    loop.run ();
    if (failure != null) throw failure;
    update.get_current_state.begin ((obj, result) => {
        try {
            var state = update.get_current_state.end (result);
            assert (state.state == expected);
            assert (expected_error in state.status);
        } catch (Error e) {
            failure = e;
        }
        loop.quit ();
    });
    loop.run ();
    if (failure != null) throw failure;
}

/* SPDX-License-Identifier: GPL-3.0-or-later */

public int main (string[] args) {
    assert (args.length == 2);
    var sysupdate = args[1] == "sysupdate";
    var command_line = Path.build_filename (Environment.get_tmp_dir (), "settings-daemon-cmdline-%u".printf (Random.next_int ()));
    try {
        FileUtils.set_contents (command_line, sysupdate ? "mount.usr=dissect" : "quiet splash");
    } catch (FileError e) {
        assert_not_reached ();
    }
    Environment.set_variable ("SETTINGS_DAEMON_TEST_CMDLINE", command_line, true);

    var bus = new TestDBus (TestDBusFlags.NONE);
    bus.up ();
    var application = new SettingsDaemon.Application ();
    try {
        var flags = DBusConnectionFlags.AUTHENTICATION_CLIENT |
            DBusConnectionFlags.MESSAGE_BUS_CONNECTION;
        var service = new DBusConnection.for_address_sync (bus.get_bus_address (), flags);
        var client = new DBusConnection.for_address_sync (bus.get_bus_address (), flags);
        var object_path = "/io/elementary/settings_daemon/Test";
        assert (application.register_backends (service, object_path));
        Variant? reply = null;
        Error? call_error = null;
        var loop = new MainLoop ();
        client.call.begin (
            service.get_unique_name (), object_path,
            "org.freedesktop.DBus.Introspectable", "Introspect", null,
            new VariantType ("(s)"), DBusCallFlags.NONE, -1, null, (obj, result) => {
                try {
                    reply = client.call.end (result);
                } catch (Error e) {
                    call_error = e;
                }
                loop.quit ();
            }
        );
        loop.run ();
        if (call_error != null) throw call_error;
        string xml;
        reply.get ("(s)", out xml);
        assert ("io.elementary.settings_daemon.Audio" in xml);
        assert ("io.elementary.settings_daemon.SystemUpdate" in xml);

        var update = new SettingsDaemon.Backends.SystemUpdate ();
        assert (update.provider_name == (sysupdate ? "systemd-sysupdate" : "packagekit"));
        if (sysupdate) {
            Environment.set_variable ("DBUS_SYSTEM_BUS_ADDRESS", bus.get_bus_address (), true);
            var target = new TestUpdateTarget ();
            service.register_object (Sysupdate.Target.HOST_PATH, target);
            service.call_sync ("org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "RequestName",
                new Variant ("(su)", Sysupdate.BUS_NAME, 0),
                new VariantType ("(u)"), DBusCallFlags.NONE, -1);
            target.fail_check = true;
            check_update (update, ERROR, "Controlled update check failure");
            target.fail_check = false;
            target.available = "next";
            check_update (update, AVAILABLE);
            update.update.begin ((obj, result) => {
                try {
                    update.update.end (result);
                } catch (Error e) {
                    call_error = e;
                }
                loop.quit ();
            });
            loop.run ();
            if (call_error != null) throw call_error;
            update.get_current_state.begin ((obj, result) => {
                try {
                    assert (update.get_current_state.end (result).state == AVAILABLE);
                } catch (Error e) {
                    call_error = e;
                }
                loop.quit ();
            });
            loop.run ();
            if (call_error != null) throw call_error;
            target.available = "";
            target.fail_version = true;
            check_update (update, ERROR, "Controlled installed-version failure");
            target.fail_version = false;
            target.installed = "pending";
            check_update (update, RESTART_REQUIRED);
            var booted_version = Environment.get_os_info ("IMAGE_VERSION");
            if (booted_version != null) {
                target.installed = booted_version;
                check_update (update, UP_TO_DATE);
            }
        }
        client.close_sync ();
        service.close_sync ();
    } catch (Error e) {
        critical (e.message);
        assert_not_reached ();
    }
    bus.stop ();
    FileUtils.remove (command_line);
    return 0;
}

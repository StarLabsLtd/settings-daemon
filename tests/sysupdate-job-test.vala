// Exercise the production job observer against an isolated D-Bus service.
[DBus (name = "org.freedesktop.sysupdate1.Manager")]
public class TestJobManager : Object {
    public signal void job_removed (uint64 id, ObjectPath path, int status);
}

[DBus (name = "org.freedesktop.sysupdate1.Job")]
public class TestJob : Object {
    public uint progress { get { return 0; } }
    public async void cancel () throws DBusError, IOError {
    }
}

private async void run_case (string mode) throws Error {
    var service = new DBusConnection.for_address_sync (
        Environment.get_variable ("DBUS_SYSTEM_BUS_ADDRESS"),
        DBusConnectionFlags.AUTHENTICATION_CLIENT | DBusConnectionFlags.MESSAGE_BUS_CONNECTION);
    var mock = new TestJobManager ();
    var path = (ObjectPath) "/org/freedesktop/sysupdate1/job/1";
    service.register_object (Sysupdate.Manager.PATH, mock);
    service.register_object (path, new TestJob ());
    yield service.call ("org.freedesktop.DBus", "/org/freedesktop/DBus",
        "org.freedesktop.DBus", "RequestName", new Variant ("(su)", Sysupdate.BUS_NAME, 0),
        null, DBusCallFlags.NONE, -1);
    var observer = yield new SettingsDaemon.Utils.SysupdateJobManager (new Cancellable ());
    var job = yield new SettingsDaemon.Utils.SysupdateJob (path, new Cancellable (), (message, progress) => {});
    if (mode == "owner-loss-before-wait" || mode == "completed-before-wait" || mode == "replacement-before-wait") {
        if (mode == "owner-loss-before-wait") {
            yield service.close ();
        } else if (mode == "replacement-before-wait") {
            yield service.close ();
            service = yield new DBusConnection.for_address (
                Environment.get_variable ("DBUS_SYSTEM_BUS_ADDRESS"),
                DBusConnectionFlags.AUTHENTICATION_CLIENT | DBusConnectionFlags.MESSAGE_BUS_CONNECTION);
            mock = new TestJobManager ();
            service.register_object (Sysupdate.Manager.PATH, mock);
            service.register_object (path, new TestJob ());
            yield service.call ("org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "RequestName", new Variant ("(su)", Sysupdate.BUS_NAME, 0),
                null, DBusCallFlags.NONE, -1);
            mock.job_removed (1, path, 0);
        } else {
            mock.job_removed (1, path, 0);
        }
        Timeout.add (20, () => {
            run_case.callback ();
            return Source.REMOVE;
        });
        yield;
    }
    Timeout.add (20, () => {
        if (mode == "owner-loss") {
            service.close.begin ();
        } else {
            mock.job_removed (1, path, mode == "failure" ? 1 : 0);
        }
        return Source.REMOVE;
    });
    try {
        yield observer.wait_for_job (job);
        assert (mode == "success" || mode == "completed-before-wait");
    } catch (IOError.CLOSED e) {
        assert (mode == "owner-loss" || mode == "owner-loss-before-wait" || mode == "replacement-before-wait");
    } catch (IOError.FAILED e) {
        assert (mode == "failure");
    }
}

int main (string[] args) {
    var loop = new MainLoop ();
    int status = 0;
    run_case.begin (args[1], (obj, result) => {
        try {
            run_case.end (result);
        } catch (Error e) {
            stderr.printf ("%s\n", e.message);
            status = 1;
        }
        loop.quit ();
    });
    Timeout.add_seconds (5, () => { error ("Job wait timed out"); });
    loop.run ();
    return status;
}

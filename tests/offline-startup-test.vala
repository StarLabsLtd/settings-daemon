/* SPDX-License-Identifier: GPL-3.0-or-later */

[CCode (cname = "test_offline_calls")]
extern uint offline_calls ();

[DBus (name = "org.freedesktop.Notifications")]
public class Notifications : Object {
    public uint received;

    public new uint notify (string app, uint replaces, string icon, string summary,
                        string body, string[] actions, HashTable<string, Variant> hints,
                        int timeout) throws DBusError, IOError {
        assert (GLib.Application.get_default ().is_registered);
        received++;
        return received;
    }

    public void close_notification (uint id) throws DBusError, IOError {
    }
}

public class SettingsDaemon.Application : GLib.Application {
    public const string ACTION_PREFIX = "app.";
    public const string SHOW_UPDATES_ACTION = "show-updates";
    public uint errors;
    private Backends.PackageKit provider;

    public Application () {
        Object (application_id: "io.elementary.settings-daemon.OfflineTest");
    }

    protected override bool dbus_register (DBusConnection connection, string path) throws Error {
        base.dbus_register (connection, path);
        provider = new Backends.PackageKit ();
        provider.state_changed.connect (() => errors++);
        assert (offline_calls () == 0);
        return true;
    }
}

public int main (string[] args) {
    assert (args.length == 2);
    Environment.set_variable ("TEST_OFFLINE_RESULT", args[1], true);
    var address = Environment.get_variable ("DBUS_SESSION_BUS_ADDRESS");
    assert (address != null);
    Environment.set_variable ("DBUS_SYSTEM_BUS_ADDRESS", address, true);
    var application = new SettingsDaemon.Application ();
    try {
        var connection = Bus.get_sync (SESSION);
        var notifications = new Notifications ();
        connection.register_object ("/org/freedesktop/Notifications", notifications);
        connection.call_sync ("org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "RequestName",
            new Variant ("(su)", "org.freedesktop.Notifications", 0),
            new VariantType ("(u)"), DBusCallFlags.NONE, -1);
        assert (application.register (null));
        assert (application.is_registered);
        assert (offline_calls () == 1);
        assert (application.errors == (args[1] == "failure" ? 1 : 0));
        if (args[1] == "failure") {
            var loop = new MainLoop ();
            Timeout.add (10, () => {
                if (notifications.received == 1) {
                    loop.quit ();
                    return Source.REMOVE;
                }
                return Source.CONTINUE;
            });
            uint timeout = Timeout.add_seconds (2, () => {
                error ("Offline failure notification was not delivered");
            });
            loop.run ();
            Source.remove (timeout);
        }
    } catch (Error e) {
        error (e.message);
    }
    print ("PASS offline %s processed after registration\n", args[1]);
    return 0;
}

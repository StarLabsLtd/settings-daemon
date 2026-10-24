/* SPDX-License-Identifier: GPL-3.0-or-later */

// Only the AccountsService property sink is substituted.
namespace Pantheon {
    public class AccountsService : Object {
        public int prefers_color_scheme { get; set; }
    }
}

[DBus (name = "org.freedesktop.GeoClue2.Manager")]
private class DeniedLocation : Object {
    [DBus (visible = false)]
    public uint requests { get; private set; }

    public ObjectPath get_client () throws DBusError, IOError {
        requests++;
        throw new DBusError.ACCESS_DENIED ("Location denied by the test service");
    }
}

[CCode (cname = "appearance_clock_set")]
private extern void set_clock (string time, string zone);

private void expect_scheme (GLib.Settings settings, Pantheon.AccountsService account, string expected) {
    var loop = new MainLoop ();
    Timeout.add (1500, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
    var actual = settings.get_string ("color-scheme");
    Test.message ("Expected %s, actual %s", expected, actual);
    assert (actual == expected);
    assert (account.prefers_color_scheme == settings.get_enum ("color-scheme"));
}

private void run_case (string mode) throws Error {
    var bus = new TestDBus (TestDBusFlags.NONE);
    bus.up ();
    Environment.set_variable ("DBUS_SYSTEM_BUS_ADDRESS", bus.get_bus_address (), true);
    var denied = new DeniedLocation ();
    if (mode == "denied") {
        var connection = Bus.get_sync (SYSTEM);
        connection.register_object ("/org/freedesktop/GeoClue2/Manager", denied);
        var reply = connection.call_sync (
            "org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "RequestName",
            new Variant ("(su)", "org.freedesktop.GeoClue2", 0U),
            new VariantType ("(u)"), DBusCallFlags.NONE, -1
        );
        assert (reply.get_child_value (0).get_uint32 () == 1);
    }

    set_clock ("2026-10-24T18:00:00Z", "UTC");
    var settings = new GLib.Settings ("io.elementary.settings-daemon.prefers-color-scheme");
    bool fallback = mode == "fallback" || mode == "denied";
    settings.set_string ("prefer-dark-schedule", "sunset-to-sunrise");
    settings.set_value ("last-coordinates", new Variant ("(dd)", fallback ? 91.0 : 51.5, fallback ? 181.0 : 0.0));
    var account = new Pantheon.AccountsService ();
    Test.expect_message (null, LogLevelFlags.LEVEL_WARNING, "*Failed to connect to GeoClue2 service*");
    var backend = new SettingsDaemon.Backends.PrefersColorSchemeSettings (account);
    assert (backend.accounts_service == account);
    expect_scheme (settings, account, fallback ? "no-preference" : "prefer-dark");
    Test.assert_expected_messages ();

    if (mode == "timezone") {
        set_clock ("2026-10-24T18:00:00Z", "America/New_York");
        expect_scheme (settings, account, "prefer-dark");
    } else if (mode == "date") {
        set_clock ("2026-06-24T18:00:00Z", "UTC");
        expect_scheme (settings, account, "no-preference");
    } else if (fallback) {
        set_clock ("2026-10-24T23:00:00Z", "UTC");
        expect_scheme (settings, account, "prefer-dark");
        set_clock ("2026-10-24T23:00:00Z", "Pacific/Honolulu");
        expect_scheme (settings, account, "no-preference");
        if (mode == "denied") {
            assert (denied.requests > 0);
        }
    } else if (mode == "manual") {
        settings.set_double ("prefer-dark-schedule-from", 17.0);
        settings.set_double ("prefer-dark-schedule-to", 7.0);
        settings.set_string ("prefer-dark-schedule", "manual");
        expect_scheme (settings, account, "prefer-dark");
        set_clock ("2026-10-24T12:00:00Z", "UTC");
        expect_scheme (settings, account, "no-preference");
    } else {
        settings.set_string ("prefer-dark-schedule", "disabled");
        settings.set_string ("color-scheme", "prefer-light");
        set_clock ("2026-10-24T23:00:00Z", "UTC");
        expect_scheme (settings, account, "prefer-light");
    }
    bus.stop ();
}

private string selected_mode;

private void run_selected_case () {
    try {
        run_case (selected_mode);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

public int main (string[] args) {
    Test.init (ref args);
    assert (args.length == 2);
    selected_mode = args[1];
    Test.add_func ("/appearance/" + selected_mode, run_selected_case);
    return Test.run ();
}

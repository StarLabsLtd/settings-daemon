/* SPDX-License-Identifier: GPL-3.0-or-later */

// Serve synchronous production D-Bus calls on a separate main context.
[DBus (name = "org.gnome.Shell")]
public class TestGrabber : Object {
    public signal void accelerator_activated (uint action, HashTable<string, Variant> parameters);
    public AsyncQueue<bool> initial_grab = new AsyncQueue<bool> ();
    private uint grabs;
    private uint ungrabs;

    public uint[] grab_accelerators (Accelerator[] accelerators) throws DBusError, IOError {
        grabs++;
        assert (ungrabs == grabs - 1);
        if (grabs == 1) {
            assert (accelerators.length == 4);
            string[] names = { "<Super>a", "invalid", "<Super>b", "<Super>c" };
            for (int i = 0; i < names.length; i++) {
                assert (accelerators[i].name == names[i]);
                assert (accelerators[i].mode_flags == ActionMode.NONE);
                assert (accelerators[i].grab_flags == Meta.KeyBindingFlags.NONE);
            }
            initial_grab.push (true);
            return { 11, 0, 12, 13 };
        }
        if (grabs == 3) {
            throw new DBusError.FAILED ("Test grab failure");
        }
        if (grabs == 4) {
            assert (accelerators.length == 0);
            return {};
        }
        assert (accelerators.length == 1);
        return grabs == 2 ? new uint[] { 21 } : new uint[] { 31 };
    }

    public bool ungrab_accelerators (uint[] actions) throws DBusError, IOError {
        ungrabs++;
        if (ungrabs == 1) {
            assert (actions.length == 3);
            assert (11 in actions && 12 in actions && 13 in actions);
        } else if (ungrabs == 2) {
            assert (actions.length == 1 && actions[0] == 21);
        } else {
            assert (actions.length == 0);
        }
        return true;
    }
}

private void drain_events () {
    var loop = new MainLoop ();
    Timeout.add (100, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
}

private string output_dir;

private void activate (TestGrabber grabber, uint id, string? expected) {
    var contexts = Gdk.Display.contexts;
    grabber.accelerator_activated (id, new HashTable<string, Variant> (str_hash, str_equal));
    drain_events ();
    if (expected != null) {
        var marker = Path.build_filename (output_dir, expected);
        var deadline = get_monotonic_time () + 5 * TimeSpan.SECOND;
        while (!FileUtils.test (marker, FileTest.EXISTS) && get_monotonic_time () < deadline) {
            drain_events ();
        }
        assert (FileUtils.test (marker, FileTest.EXISTS));
        assert (FileUtils.unlink (marker) == 0);
    }
    assert (Gdk.Display.contexts == contexts + (expected == null ? 0 : 1));
    // A wrong target must not leave extra markers.
    try {
        assert (Dir.open (output_dir).read_name () == null);
    } catch (FileError e) {
        error ("%s", e.message);
    }
}

private void set_shortcuts (GLib.Settings settings, string value) throws Error {
    var shortcuts = Variant.parse (null, value.replace ("@OUTPUT@", output_dir));
    assert (settings.set_value ("application-shortcuts", shortcuts));
}

private void run_case () {
    try {
        output_dir = DirUtils.make_tmp ("application-shortcuts-XXXXXX");
        var settings = new GLib.Settings ("io.elementary.settings-daemon.applications");
        // Empty actions must not shift following bindings; one action has three
        // bindings, including a failed grab between two successful grabs.
        set_shortcuts (settings, "[(1, '/usr/bin/touch @OUTPUT@/empty', @a{sv} {}, @as []), " +
            "(1, '/usr/bin/touch @OUTPUT@/first', {}, ['<Super>a', 'invalid', '<Super>b']), " +
            "(1, '/usr/bin/touch @OUTPUT@/second', {}, ['<Super>c'])]");

        var grabber = new TestGrabber ();
        var ready = new AsyncQueue<bool> ();
        var context = new MainContext ();
        var service_loop = new MainLoop (context);
        var thread = new Thread<void*> ("shortcut-grabber", () => {
            context.push_thread_default ();
            try {
                var connection = new DBusConnection.for_address_sync (
                    Environment.get_variable ("DBUS_SESSION_BUS_ADDRESS"),
                    DBusConnectionFlags.AUTHENTICATION_CLIENT | DBusConnectionFlags.MESSAGE_BUS_CONNECTION);
                connection.register_object ("/org/gnome/Shell", grabber);
                connection.call_sync ("org.freedesktop.DBus", "/org/freedesktop/DBus",
                    "org.freedesktop.DBus", "RequestName", new Variant ("(su)", "org.gnome.Shell", 0),
                    null, DBusCallFlags.NONE, -1);
                ready.push (true);
                service_loop.run ();
                connection.close_sync ();
            } catch (Error e) {
                error ("%s", e.message);
            }
            context.pop_thread_default ();
            return null;
        });
        assert (ready.pop ());
        var backend = new SettingsDaemon.Backends.ApplicationShortcuts ();
        while (!grabber.initial_grab.try_pop ()) {
            drain_events ();
        }
        activate (grabber, 11, "first");
        activate (grabber, 12, "first");
        activate (grabber, 13, "second");
        activate (grabber, 0, null);
        activate (grabber, 999, null);

        set_shortcuts (settings, "[(1, '/usr/bin/touch @OUTPUT@/replacement', @a{sv} {}, ['<Super>d'])]");
        activate (grabber, 11, null);
        activate (grabber, 12, null);
        activate (grabber, 13, null);
        activate (grabber, 21, "replacement");

        Test.expect_message (null, LogLevelFlags.LEVEL_CRITICAL, "*Test grab failure*");
        set_shortcuts (settings, "[(1, '/usr/bin/touch @OUTPUT@/failed', @a{sv} {}, ['<Super>e'])]");
        Test.assert_expected_messages ();
        activate (grabber, 21, null);

        // Empty configuration after a failed request must ungrab no stale IDs.
        set_shortcuts (settings, "@a(isa{sv}as) []");
        activate (grabber, 21, null);
        set_shortcuts (settings, "[(1, '/usr/bin/touch @OUTPUT@/recovered', @a{sv} {}, ['<Super>f'])]");
        activate (grabber, 31, "recovered");
        activate (grabber, 0, null);
        assert (backend != null);
        service_loop.quit ();
        thread.join ();
        assert (DirUtils.remove (output_dir) == 0);
    } catch (Error e) {
        error ("%s", e.message);
    }
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/application-shortcuts/binding-actions", run_case);
    return Test.run ();
}

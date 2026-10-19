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
        var connection = Bus.get_sync (BusType.SESSION);
        var object_path = "/io/elementary/settings_daemon/Test";
        assert (application.register_backends (connection, object_path));
        Variant? reply = null;
        Error? call_error = null;
        var loop = new MainLoop ();
        connection.call.begin (
            connection.get_unique_name (), object_path,
            "org.freedesktop.DBus.Introspectable", "Introspect", null,
            new VariantType ("(s)"), DBusCallFlags.NONE, -1, null, (obj, result) => {
                try {
                    reply = connection.call.end (result);
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
    } catch (Error e) {
        critical (e.message);
        assert_not_reached ();
    }
    bus.stop ();
    FileUtils.remove (command_line);
    return 0;
}

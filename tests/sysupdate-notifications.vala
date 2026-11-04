/* SPDX-License-Identifier: GPL-3.0-or-later */
// Exercise the production provider with private notification and update endpoints.
[DBus (name = "org.freedesktop.Notifications")]
public class UpdateNotifications : Object {
    private string[] records = {};
    public string[] summaries { get { return records; } }

    public new uint notify (string app, uint replaces, string icon, string summary,
                           string body, string[] actions, HashTable<string, Variant> hints,
                           int timeout) throws DBusError, IOError {
        assert ("default" in actions);
        records += summary;
        return summaries.length;
    }

    public void close_notification (uint id) throws DBusError, IOError {
    }
}

public class SettingsDaemon.Application : GLib.Application {
    public const string ACTION_PREFIX = "app.";
    public const string SHOW_UPDATES_ACTION = "show-updates";

    public Application () {
        Object (application_id: "io.elementary.settings-daemon.UpdateTest");
        add_action (new SimpleAction (SHOW_UPDATES_ACTION, null));
    }
}

namespace SettingsDaemon.Utils {
    public bool is_running_in_demo_mode () {
        return false;
    }

    public class SysupdateTarget : Object {
        public enum UpdateVersion { NEWEST, CURRENT }
        public delegate void ProgressCallback (string message, uint percentage);
        public static string mode;
        public static uint updates;

        public SysupdateTarget (string path) {
            assert (path == Sysupdate.Target.HOST_PATH);
        }

        public async string? check_new () throws Error {
            return mode.has_prefix ("staged") ? null : "2";
        }

        public async bool has_newer_unapplied_version () throws Error {
            return mode.has_prefix ("staged");
        }

        public async void update (UpdateVersion version, Cancellable cancellable,
                                  ProgressCallback progress) throws Error {
            updates++;
            Idle.add (() => {
                update.callback ();
                return Source.REMOVE;
            });
            yield;
            if (mode == "cancel") {
                throw new IOError.CANCELLED ("Cancelled test update");
            }
            if (mode == "failure") {
                throw new IOError.FAILED ("Failed test update");
            }
            progress ("Complete", 100);
        }
    }
}

public int main (string[] args) {
    Test.init (ref args);
    assert (args.length == 2);
    var mode = args[1];
    SettingsDaemon.Utils.SysupdateTarget.mode = mode;
    Environment.set_variable ("TEST_METERED", mode == "metered" ? "1" : "0", true);
    var settings = new Settings ("io.elementary.settings-daemon.system-update");
    bool automatic = mode == "automatic" || mode == "metered";
    settings.set_boolean ("automatic-updates", automatic);
    bool quiet = mode == "quiet" || mode == "staged-quiet";
    bool explicit_update = mode == "failure" || mode == "cancel";
    var notifications = new UpdateNotifications ();
    var application = new SettingsDaemon.Application ();
    var loop = new MainLoop ();
    bool finished = false;
    try {
        var connection = Bus.get_sync (SESSION);
        connection.register_object ("/org/freedesktop/Notifications", notifications);
        connection.call_sync ("org.freedesktop.DBus", "/org/freedesktop/DBus",
            "org.freedesktop.DBus", "RequestName",
            new Variant ("(su)", "org.freedesktop.Notifications", 0),
            new VariantType ("(u)"), DBusCallFlags.NONE, -1);
        assert (application.register (null));
        var provider = new SettingsDaemon.Backends.SystemDSystemUpdate ();
        if (mode == "failure") {
            Test.expect_message (null, LogLevelFlags.LEVEL_CRITICAL, "*Failed to update:*");
        }
        provider.check_for_updates.begin (false, !quiet && !explicit_update, (obj, result) => {
            try {
                provider.check_for_updates.end (result);
                if (explicit_update) {
                    provider.update.begin ((obj, result) => {
                        try {
                            provider.update.end (result);
                        } catch (Error e) {
                            error (e.message);
                        }
                        finished = true;
                    });
                } else {
                    finished = true;
                }
            } catch (Error e) {
                error (e.message);
            }
        });
        Timeout.add (300, () => {
            assert (finished);
            uint expected = quiet || mode == "cancel" ? 0 : 1;
            assert (notifications.summaries.length == expected);
            if (expected != 0) {
                string summary = mode == "failure" ? "System updates couldn't be installed" :
                    mode == "automatic" || mode.has_prefix ("staged") ? "Restart required" : "Update available";
                assert (notifications.summaries[0] == summary);
            }
            assert (SettingsDaemon.Utils.SysupdateTarget.updates == (automatic && mode != "metered" || explicit_update ? 1 : 0));
            provider.get_current_state.begin ((obj, result) => {
                try {
                    var state = provider.get_current_state.end (result);
                    var expected_state = mode == "failure" ? SettingsDaemon.PkUtils.State.ERROR :
                        mode == "automatic" || mode.has_prefix ("staged") ? SettingsDaemon.PkUtils.State.RESTART_REQUIRED :
                        SettingsDaemon.PkUtils.State.AVAILABLE;
                    assert (state.state == expected_state);
                } catch (Error e) {
                    error (e.message);
                }
                loop.quit ();
            });
            return Source.REMOVE;
        });
        loop.run ();
        if (mode == "failure") {
            Test.assert_expected_messages ();
        }
    } catch (Error e) {
        error (e.message);
    }
    print ("PASS sysupdate notifications: %s\n", mode);
    return 0;
}

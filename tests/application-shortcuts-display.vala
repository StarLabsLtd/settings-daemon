/* SPDX-License-Identifier: GPL-3.0-or-later */

// Supply a launch context without a graphical session. AppInfo still launches
// real harmless commands, so the test observes the backend's selected target.
namespace Gdk {
    public const uint32 CURRENT_TIME = 0;

    public class AppLaunchContext : GLib.AppLaunchContext {
        public void set_timestamp (uint32 timestamp) {
        }
    }

    public class Display : Object {
        public static uint contexts;

        public static Display get_default () {
            return new Display ();
        }

        public AppLaunchContext get_app_launch_context () {
            contexts++;
            return new AppLaunchContext ();
        }
    }
}

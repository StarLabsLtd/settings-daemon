/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 */

namespace SettingsDaemon.Backends.EqualizerControl {
    internal int slot (string name) {
        if (!name.has_prefix ("eos_eq_")) {
            return -1;
        }
        if (name == "eos_eq_h:Mult") return 45;
        if (name == "eos_eq_h:Add") return 46;
        if (name == "eos_eq_h:Control") return 47;
        if (name.length <= 9 || name[7] < '1' || name[7] > '5' || name[8] != ':') {
            return -2;
        }

        string[] ports = { "Freq", "Q", "Gain", "b0", "b1", "b2", "a0", "a1", "a2" };
        var port_name = name.substring (9);
        for (int port = 0; port < ports.length; port++) {
            if (port_name == ports[port]) {
                return (name[7] - '1') * 9 + port;
            }
        }
        return -2;
    }
}

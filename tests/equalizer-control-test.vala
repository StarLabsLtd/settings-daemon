/* SPDX-License-Identifier: GPL-3.0-or-later */

private void test_bands () {
    string[] ports = { "Freq", "Q", "Gain", "b0", "b1", "b2", "a0", "a1", "a2" };
    for (int band = 0; band < 5; band++) {
        for (int port = 0; port < ports.length; port++) {
            assert (SettingsDaemon.Backends.EqualizerControl.slot (
                "eos_eq_%d:%s".printf (band + 1, ports[port])
            ) == band * 9 + port);
        }
    }
}

private void test_helper () {
    assert (SettingsDaemon.Backends.EqualizerControl.slot ("eos_eq_h:Mult") == 45);
    assert (SettingsDaemon.Backends.EqualizerControl.slot ("eos_eq_h:Add") == 46);
    assert (SettingsDaemon.Backends.EqualizerControl.slot ("eos_eq_h:Control") == 47);
}

private void test_namespaces_and_malformed () {
    assert (SettingsDaemon.Backends.EqualizerControl.slot ("foreign:Gain") == -1);
    string[] malformed = {
        "eos_eq_0:Gain", "eos_eq_6:Gain", "eos_eq_1:gain", "eos_eq_1:Gain:extra",
        "eos_eq_01:Gain", "eos_eq_h:Unknown", "eos_eq_1:", "eos_eq_1:Out"
    };
    foreach (var name in malformed) {
        assert (SettingsDaemon.Backends.EqualizerControl.slot (name) == -2);
    }
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/equalizer-control/bands", test_bands);
    Test.add_func ("/equalizer-control/helper", test_helper);
    Test.add_func ("/equalizer-control/malformed", test_namespaces_and_malformed);
    return Test.run ();
}

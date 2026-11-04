/* SPDX-License-Identifier: GPL-3.0-or-later */

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/echo/remember-latest-target", () => {
        var loop = new PulseAudio.GLibMainLoop ();
        var context = new PulseAudio.Context (loop.get_api (), "record test");
        var processor = new SettingsDaemon.Backends.EchoProcessor (context);
        processor.remember_stream_for_test (true, 7, "recording-a");
        processor.remember_stream_for_test (true, 7, "recording-b");
        assert (processor.remembered_count_for_test (true) == 1);
        assert (processor.remembered_target_for_test (true, 7) == "recording-b");

        processor.remember_stream_for_test (false, 9, "playback-a");
        processor.remember_stream_for_test (false, 9, "playback-b");
        assert (processor.remembered_count_for_test (false) == 1);
        assert (processor.remembered_target_for_test (false, 9) == "playback-b");
        processor.stop ();
    });
    return Test.run ();
}

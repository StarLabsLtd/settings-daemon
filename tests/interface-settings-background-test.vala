/* SPDX-License-Identifier: GPL-3.0-or-later */

private class TestAccounts : Object,
    SettingsDaemon.AccountsService,
    DisplayManager.AccountsService {
    public SettingsDaemon.AccountsService.KeyboardLayout[] keyboard_layouts {
        owned get { return {}; }
        set {}
    }
    public uint active_keyboard_layout { get; set; }
    public SettingsDaemon.AccountsService.XkbOption[] xkb_options {
        owned get { return {}; }
        set {}
    }
    public bool left_handed { get; set; }
    public int accel_profile { get; set; }
    public bool mouse_natural_scroll { get; set; }
    public double mouse_speed { get; set; }
    public int touchpad_click_method { get; set; }
    public bool touchpad_disable_while_typing { get; set; }
    public bool touchpad_edge_scrolling { get; set; }
    public bool touchpad_natural_scroll { get; set; }
    public int touchpad_send_events { get; set; }
    public double touchpad_speed { get; set; }
    public bool touchpad_tap_to_click { get; set; }
    public bool touchpad_two_finger_scrolling { get; set; }
    public int accent_color { get; set; }
    public bool cursor_blink { get; set; }
    public int cursor_blink_time { get; set; }
    public int cursor_blink_timeout { get; set; }
    public int cursor_size { get; set; }
    public bool locate_pointer { get; set; }
    public double text_scaling_factor { get; set; }
    public int picture_options { get; set; }
    public string primary_color { owned get; set; default = ""; }
    public string document_font_name { owned get; set; default = ""; }
    public string font_name { owned get; set; default = ""; }
    public string monospace_font_name { owned get; set; default = ""; }
    public bool orientation_lock { get; set; }
    public bool wingpanel_use_transparency { get; set; }
    public bool wingpanel_show_percentage { get; set; }
    public SettingsDaemon.AccountsService.Coordinates last_coordinates { get; set; }
    public int prefer_dark_schedule { get; set; }
    public double prefer_dark_schedule_from { get; set; }
    public double prefer_dark_schedule_to { get; set; }
    public bool night_light_enabled { get; set; }
    public bool night_light_schedule_automatic { get; set; }
    public double night_light_schedule_from { get; set; }
    public double night_light_schedule_to { get; set; }
    public uint night_light_temperature { get; set; }
    public int prefers_color_scheme { get; set; }
    public int prefers_accent_color { get; set; }
    public string background_file { owned get; set; default = ""; }
}

private void assert_copy (string path, string expected) throws Error {
    for (int i = 0; i < 100; i++) {
        while (MainContext.default ().iteration (false));

        string actual;
        size_t length;
        try {
            FileUtils.get_contents (path, out actual, out length);
            if (actual == expected) {
                return;
            }
        } catch (Error e) {
            // The startup copy may not exist until the main context runs.
        }

        Thread.usleep (10 * 1000);
    }

    error ("Wallpaper copy did not contain the selected image: %s", path);
}

private void test_selected_wallpaper_is_copied_at_startup () throws Error {
    var temp_dir = DirUtils.make_tmp ("vale-greeter-wallpaper-XXXXXX");
    var greeter_dir = Path.build_filename (temp_dir, "greeter-data");
    var default_wallpaper = Path.build_filename (temp_dir, "default.jpg");
    var custom_wallpaper = Path.build_filename (temp_dir, "chosen.jpg");
    var destination = Path.build_filename (greeter_dir, "wallpaper");

    FileUtils.set_contents (default_wallpaper, "default wallpaper");
    FileUtils.set_contents (custom_wallpaper, "chosen wallpaper");
    Environment.set_variable ("XDG_GREETER_DATA_DIR", greeter_dir, true);

    var settings = new GLib.Settings ("org.gnome.desktop.background");
    settings.set_enum ("picture-options", 5);
    settings.set_string ("picture-uri", File.new_for_path (default_wallpaper).get_uri ());

    var accounts = new TestAccounts ();
    var interface_settings = new SettingsDaemon.Backends.InterfaceSettings (accounts, accounts);
    assert (interface_settings != null);

    assert_copy (destination, "default wallpaper");
    assert (accounts.background_file == destination);

    settings.set_string ("picture-uri", File.new_for_path (custom_wallpaper).get_uri ());
    assert_copy (destination, "chosen wallpaper");
    assert (accounts.background_file == destination);

    settings.set_enum ("picture-options", 0);
    settings.set_string ("primary-color", "#123456");
    assert (accounts.picture_options == 0);
    assert (accounts.primary_color == "#123456");

    FileUtils.remove (destination);
    DirUtils.remove (greeter_dir);
    FileUtils.remove (default_wallpaper);
    FileUtils.remove (custom_wallpaper);
    DirUtils.remove (temp_dir);
}

private void run_test () {
    try {
        test_selected_wallpaper_is_copied_at_startup ();
    } catch (Error e) {
        error ("%s", e.message);
    }
}

public int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/interface-settings/selected-wallpaper-startup", run_test);
    return Test.run ();
}

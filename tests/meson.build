equalizer_control_test = executable(
    'equalizer-control-test',
    'equalizer-control-test.vala',
    meson.project_source_root() / 'src' / 'Backends' / 'EqualizerControl.vala',
    dependencies: glib_dep,
    install: false
)

test('equalizer control names', equalizer_control_test)

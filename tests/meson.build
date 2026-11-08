test_schema_dir = meson.current_build_dir() / 'schemas'
custom_target(
    'test-schemas',
    input: [
        meson.project_source_root() / 'data' / 'io.elementary.settings-daemon.gschema.xml',
        'fixtures/greeter-background.gschema.xml',
    ],
    output: 'schemas.stamp',
    command: ['sh', '-c', 'mkdir -p "$1" && cp "$2" "$1" && cp "$3" "$1" && glib-compile-schemas "$1" && touch "$4"',
        'sh', test_schema_dir, '@INPUT0@', '@INPUT1@', '@OUTPUT@'],
    build_by_default: true
)

test_environment = environment()
test_environment.set('GSETTINGS_BACKEND', 'memory')
test_environment.set('GSETTINGS_SCHEMA_DIR', test_schema_dir)

interface_settings_background_test = executable(
    'interface-settings-background-test',
    'interface-settings-background-test.vala',
    meson.project_source_root() / 'src' / 'AccountsService.vala',
    meson.project_source_root() / 'src' / 'Backends' / 'InterfaceSettings.vala',
    dependencies: gio_dep,
    install: false
)
test('greeter receives selected wallpaper at startup', interface_settings_background_test,
    env: test_environment)

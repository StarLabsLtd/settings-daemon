equalizer_control_test = executable(
    'equalizer-control-test',
    'equalizer-control-test.vala',
    meson.project_source_root() / 'src' / 'Backends' / 'EqualizerControl.vala',
    dependencies: glib_dep,
    install: false
)

test('equalizer control names', equalizer_control_test)

test_schema_dir = meson.current_build_dir() / 'schemas'
custom_target(
    'test-schemas',
    input: meson.project_source_root() / 'data' / 'io.elementary.settings-daemon.gschema.xml',
    output: 'schemas.stamp',
    command: ['sh', '-c', 'mkdir -p "$1" && cp "$2" "$1" && glib-compile-schemas "$1" && touch "$3"',
        'sh', test_schema_dir, '@INPUT@', '@OUTPUT@'],
    build_by_default: true
)

test_environment = environment()
test_environment.set('GSETTINGS_BACKEND', 'memory')
test_environment.set('GSETTINGS_SCHEMA_DIR', test_schema_dir)

echo_records_test = executable(
    'echo-records-test',
    'echo-records-test.vala',
    meson.project_source_root() / 'src' / 'Backends' / 'EchoProcessor.vala',
    dependencies: [pulse_dep, pulse_loop_dep, gio_dep],
    vala_args: ['--define=ECHO_TEST', '--vapidir=' + meson.project_source_root() / 'vapi', '--pkg=libpulse-operation'],
    install: false
)
test('echo restored stream records', echo_records_test, env: test_environment)

registration_test = executable(
    'registration-test',
    'registration-test.vala',
    sources,
    link_with: equalizer_library,
    include_directories: include_directories('../src'),
    dependencies: backend_dependencies,
    vala_args: args + ['--define=REGISTRATION_TEST', '--vapidir=' + meson.project_source_root() / 'vapi',
        '--vapidir=' + meson.project_build_root(), '--pkg=libpulse-operation', '--pkg=speaker-equalizer-profile'],
    install: false
)
test('D-Bus registration without sysupdate', registration_test, args: ['non-sysupdate'], env: test_environment)
test('D-Bus registration with sysupdate', registration_test, args: ['sysupdate'], env: test_environment)

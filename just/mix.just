# MIX recipes: just mix <recipe>. Run `just mix` to list them.

# Relative to this file: ~/dotfiles/just -> ~/memryx/MIX
set working-directory := '../../memryx/MIX'

root := home_directory() / "memryx/MIX"

# The environment setup_env.sh sets up, minus its tool installs: MIX_HOME,
# MIX's bin folders and its .venv, so mix_bench, pytest etc. just work
export MIX_HOME := root
export VIRTUAL_ENV := root / ".venv"
export PATH := root / ".venv/bin:" + root / "bin:" + root / "simulators/bin:" + env("PATH")

# List recipes
[private]
default:
    @{{just_executable()}} --justfile {{justfile()}} --list mix

# Run any command in MIX's environment, from where you are: just mix run python no_device_app.py
[no-cd]
[positional-arguments]
run +cmd:
    @"$@"

# Open a new shell with MIX's venv active, from where you are; `exit` to leave it
[no-cd]
activate:
    #!/usr/bin/env zsh
    # A recipe can't change the shell that ran it, so hand over to a new one
    pushd ~/memryx/MIX >/dev/null && source .venv/bin/activate && source setup_env.sh; popd >/dev/null
    exec zsh

# Run the runtime tests, optionally only those matching: just mix test test_op_freq
test filter="" *flags:
    pytest runtime/tests/test_accl.py -s -x -v -o log_cli=true --log-cli-level=DEBUG \
        {{ if filter == "" { "" } else { "-k '" + filter + "'" } }} {{flags}}

# Run the runtime tests in gdb: just mix dbg test_op_freq
dbg filter *flags:
    gdb --args python -m pytest runtime/tests/test_accl.py -s -x -v -k '{{filter}}' {{flags}}

# Benchmark a model (relative paths are from where you run it): just mix bench x.dfp --op_freq 800
[no-cd]
bench dfp="~/memryx/models/mobilenet.dfp" *flags:
    mix_bench -d {{dfp}} -f 2000 -s {{flags}}

# The venv active where you ran just (the exports above hide it from recipes),
# or MIX's own when none is active
caller_py := env("VIRTUAL_ENV", root / ".venv") / "bin/python"

# Show where the memryx Python modules and the runtime and driver libraries come from
[no-cd]
where:
    #!{{caller_py}}
    import importlib, os, sys
    def show_path(kind, path):
        if path is None:
            print(f"  {kind:15}", '(no file)', end='\n\n')
            return
        real = os.path.realpath(path)
        print(f'  {kind:15}', path)
        print(f"  {'Links to:':15}", real if real != path else '(not a link, the file itself)')
        if not os.path.exists(path):
            print(f"  {'Missing:':15}", real)
        print()

    print('python')
    show_path('Path:', sys.executable)
    for name in ('memryx', 'mxapi', 'mxa'):
        requested = 'memryx' if name == 'memryx' else 'memryx.' + name
        try:
            memryx = importlib.import_module('memryx')
            # Match `from memryx import mxapi`, including runtime re-exports.
            mod = memryx if name == 'memryx' else (
                getattr(memryx, name, None) or importlib.import_module(requested))
        except Exception as exc:
            print(name)
            if isinstance(exc, ModuleNotFoundError):
                print(f"  {'Missing module:':15}", exc.name)
            print(f"  {'Import failed:':15}", f'{type(exc).__name__}: {exc}', end='\n\n')
            continue
        print(f'{name}  ({mod.__name__})')
        show_path('Imported from:', getattr(mod, '__file__', None))

    for title, path in (
        ('runtime  (libmx_accl.so)', '/lib/x86_64-linux-gnu/libmx_accl.so'),
        ('driver  (libmemx.so)', '/lib/x86_64-linux-gnu/libmemx.so'),
    ):
        print(title)
        show_path('Path:', path)

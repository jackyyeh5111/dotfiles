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

# Show which memryx, mxapi and mxa modules Python imports and the files they link to
[no-cd]
which-py:
    #!/usr/bin/env python
    import importlib, os
    memryx = importlib.import_module('memryx')
    # Same as `from memryx import mxapi`, which may hand back memryx.runtime.mxapi
    mods = {'memryx': memryx}
    for name in ('mxapi', 'mxa'):
        mods[name] = getattr(memryx, name, None) or importlib.import_module('memryx.' + name)
    # A blank line keeps the sanitizer noise from the import apart
    print()
    for label, mod in mods.items():
        path = mod.__file__
        real = os.path.realpath(path)
        print(f'{label}  ({mod.__name__})')
        print('  Imported from:', path)
        print('  Links to:     ', real if real != path else '(not a link, the file itself)')
        print()

# MX_API recipes: just mxapi <recipe>. Run `just mxapi` to list them.

# Relative to this file: ~/dotfiles/just -> ~/memryx/MX_API
set working-directory := '../../memryx/MX_API'

root := home_directory() / "memryx/MX_API"
tests := "build/mx_accl"
# The active venv, or mx3p0 (the one cdpy uses) when none is active
py := env("VIRTUAL_ENV", home_directory() / ".virtualenvs/mx3p0") / "bin/python"
dkms := "/lib/modules/$(uname -r)/updates/dkms"

# List recipes
[private]
default:
    @{{just_executable()}} --justfile {{justfile()}} --list mxapi

# Configure (Debug, tests, no sanitizer) and build
build:
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=1 -DBUILD_TESTS_PREPOST=1 \
        -DDISABLE_SAN=1 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    make -C build -j$(nproc)

# Build, then run tests: just mxapi test '*PassThrough*' --local
test filter="*" *flags: build
    ./{{tests}}/all_tests --gtest_filter='{{filter}}' -v {{flags}}

# Build, then run the pre/post tests: just mxapi prepost '*PassThrough*'
prepost filter="*" *flags: build
    ./{{tests}}/all_tests_prepost --gtest_filter='{{filter}}' -v {{flags}}

# Run tests in gdb, stopping at the first failure: just mxapi dbg accl_dfp_tests.foo
dbg filter *flags:
    gdb --args ./{{tests}}/all_tests --gtest_filter='{{filter}}' --gtest_break_on_failure {{flags}}

# Benchmark a model (relative paths are from where you run it): just mxapi bench x.dfp 1000
[no-cd]
bench dfp="~/memryx/models/mobilenet.dfp" frames="2000":
    {{root}}/build/tools/acclBench/acclBench -d {{dfp}} -f {{frames}} -s

# Run mxa_manager: just mxapi mgr --no_dfp_reuse -c 500
mgr *flags:
    sudo mkdir -p /run/mxa_manager
    sudo chmod a+rwx /run/mxa_manager
    cd build/mxa_manager && ./mxa_manager {{flags}}

# Build mx_accl and the Python module, then run its tests: just mxapi pytest test_op_freq
pytest filter="" *flags: build
    cmake -S mx_accl/pymodule -B mx_accl/pymodule/build -DCMAKE_BUILD_TYPE=Debug
    make -C mx_accl/pymodule/build -j$(nproc)
    cd mx_accl/pymodule/tests && ln -sf ../build/mxapi.cpython-*.so .
    {{py}} -m pytest mx_accl/pymodule/tests/test_accl.py -s -x -v -o log_cli=true --log-cli-level=DEBUG \
        {{ if filter == "" { "" } else { "-k '" + filter + "'" } }} {{flags}}

# Build the PCIe kernel driver and install it with the firmware
driver:
    make -C driver/kdriver/linux/pcie
    sudo mkdir -p {{dkms}}
    # Named .ko.zst so it takes the place of the apt package's module
    sudo ln -sfv {{root}}/driver/kdriver/linux/pcie/memx_cascade_plus_pcie.ko {{dkms}}/memx_cascade_plus_pcie.ko.zst
    sudo cp -v driver/binary_release/firmware/cascadeplus/product_signed/*.bin /lib/firmware/
    sudo depmod -a

# Build and run the full test suite (run_test.sh)
test-all:
    ./run_test.sh

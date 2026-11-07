# MX_API recipes: just mxapi <recipe>. Run `just mxapi` to list them.

# Relative to this file: ~/dotfiles/just -> ~/memryx/MX_API
set working-directory := '../../memryx/MX_API'

root := home_directory() / "memryx/MX_API"
tests := "build/mx_accl"
# The active venv, or mx3p0 (the one cdpy uses) when none is active
py := env("VIRTUAL_ENV", home_directory() / ".virtualenvs/mx3p0") / "bin/python"
mx3p0 := home_directory() / ".virtualenvs/mx3p0"
dkms := "/lib/modules/$(uname -r)/updates/dkms"
# Outside /lib/modules so depmod doesn't pick up the copies
dkms_backup := "/var/backups/memx-dkms/$(uname -r)"
fw_src := "driver/binary_release/firmware/cascadeplus/product_signed"
fw_backup := "/var/backups/memx-firmware"
memx_h := "/usr/include/memx/memx.h"
libmemx := "/usr/lib/x86_64-linux-gnu/libmemx.so"
udriver_backup := "/var/backups/memx-udriver"

# List recipes
[private]
default:
    @{{just_executable()}} --justfile {{justfile()}} --list mxapi

# Configure (Debug, tests, no sanitizer) and build
[private]
build-core:
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=1 -DBUILD_TESTS_PREPOST=1 \
        -DDISABLE_SAN=1 -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    make -C build -j$(nproc)

# Build mx_accl, then rebuild the Python module from scratch
build: build-core
    rm -rf mx_accl/pymodule/build
    # On PATH because CMake runs bare python3 to find the numpy headers
    PATH={{mx3p0}}/bin:$PATH cmake -S mx_accl/pymodule -B mx_accl/pymodule/build -DCMAKE_BUILD_TYPE=Debug
    make -C mx_accl/pymodule/build -j$(nproc)

# Build, then run tests: just mxapi test '*PassThrough*' --local
test filter="*" *flags: build-core
    ./{{tests}}/all_tests --gtest_filter='{{filter}}' -v {{flags}}

# Build, then run the pre/post tests: just mxapi prepost '*PassThrough*'
prepost filter="*" *flags: build-core
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
    cd build/mxa_manager && exec ./mxa_manager {{flags}}

# Build mx_accl and the Python module, then run its tests: just mxapi pytest test_op_freq
pytest filter="" *flags: build-core
    cmake -S mx_accl/pymodule -B mx_accl/pymodule/build -DCMAKE_BUILD_TYPE=Debug
    make -C mx_accl/pymodule/build -j$(nproc)
    cd mx_accl/pymodule/tests && ln -sf ../build/mxapi.cpython-*.so .
    {{py}} -m pytest mx_accl/pymodule/tests/test_accl.py -s -x -v -o log_cli=true --log-cli-level=DEBUG \
        {{ if filter == "" { "" } else { "-k '" + filter + "'" } }} {{flags}}

# Link the system memx.h and libmemx.so to this repo's copies
udriver:
    sudo mkdir -p /usr/include/memx {{udriver_backup}}
    # After the first run memx.h is our link, so only a real file is the original
    if [ -f {{memx_h}} ] && [ ! -L {{memx_h}} ]; then sudo cp -av {{memx_h}} {{udriver_backup}}/; fi
    sudo ln -sfv {{root}}/driver/udriver/include/common/memx.h {{memx_h}}
    sudo ln -sfv {{root}}/driver/udriver/build/libmemx.so {{libmemx}}
    @printf '%s\n' '' 'Done:' \
        '  sudo mkdir -p /usr/include/memx {{udriver_backup}}' \
        '  sudo cp -av {{memx_h}} {{udriver_backup}}/  (first run only)' \
        '  sudo ln -sfv {{root}}/driver/udriver/include/common/memx.h {{memx_h}}' \
        '  sudo ln -sfv {{root}}/driver/udriver/build/libmemx.so {{libmemx}}'

# Undo udriver: link memx.h to its backup and libmemx.so to the newest installed version
udriver-rollback:
    # Without a backup the link below would point at nothing
    test -f {{udriver_backup}}/memx.h
    sudo ln -sfv {{udriver_backup}}/memx.h {{memx_h}}
    lib=$(ls -v {{libmemx}}.* | tail -n 1); [ -n "$lib" ] && sudo ln -sfv "${lib##*/}" {{libmemx}}
    @printf '%s\n' '' 'Done:' \
        '  sudo ln -sfv {{udriver_backup}}/memx.h {{memx_h}}' \
        "  sudo ln -sfv $(readlink {{libmemx}}) {{libmemx}}"

# Build the PCIe kernel driver and install it with the firmware
kdriver:
    # Merges into the backup, so reruns keep the original modules
    sudo mkdir -p {{dkms}} {{dkms_backup}} {{fw_backup}}
    sudo cp -av {{dkms}}/. {{dkms_backup}}/
    # No overwriting: on reruns /lib/firmware already holds the repo's files
    for f in {{fw_src}}/*.bin; do b=/lib/firmware/${f##*/}; if [ -f "$b" ]; then sudo cp -anv "$b" {{fw_backup}}/; fi; done
    sudo rm -rf {{dkms}}
    make -C driver/kdriver/linux/pcie
    sudo mkdir -p {{dkms}}
    # Named .ko.zst so it takes the place of the apt package's module
    sudo ln -sfv {{root}}/driver/kdriver/linux/pcie/memx_cascade_plus_pcie.ko {{dkms}}/memx_cascade_plus_pcie.ko.zst
    sudo cp -v {{fw_src}}/*.bin /lib/firmware/
    sudo depmod -a
    @printf '%s\n' '' 'Done:' \
        "  sudo mkdir -p {{dkms}} {{dkms_backup}} {{fw_backup}}" \
        "  sudo cp -av {{dkms}}/. {{dkms_backup}}/" \
        '  sudo cp -anv /lib/firmware/<each repo .bin> {{fw_backup}}/' \
        "  sudo rm -rf {{dkms}}" \
        '  make -C driver/kdriver/linux/pcie' \
        "  sudo mkdir -p {{dkms}}" \
        "  sudo ln -sfv {{root}}/driver/kdriver/linux/pcie/memx_cascade_plus_pcie.ko {{dkms}}/memx_cascade_plus_pcie.ko.zst" \
        '  sudo cp -v {{fw_src}}/*.bin /lib/firmware/' \
        '  sudo depmod -a'

# Undo kdriver: put the backed-up modules and firmware back
kdriver-rollback:
    # Stop before changing anything if either backup is missing
    ls {{dkms_backup}}/*.ko {{fw_backup}}/*.bin
    sudo mkdir -p {{dkms}}
    sudo cp -av {{dkms_backup}}/*.ko {{dkms}}/
    sudo rm -fv {{dkms}}/memx_cascade_plus_pcie.ko.zst
    sudo cp -av {{fw_backup}}/*.bin /lib/firmware/
    sudo depmod -a
    @printf '%s\n' '' 'Done:' \
        "  sudo mkdir -p {{dkms}}" \
        "  sudo cp -av {{dkms_backup}}/*.ko {{dkms}}/" \
        "  sudo rm -fv {{dkms}}/memx_cascade_plus_pcie.ko.zst" \
        '  sudo cp -av {{fw_backup}}/*.bin /lib/firmware/' \
        '  sudo depmod -a'

# Build and run the full test suite (run_test.sh)
test-all:
    ./run_test.sh

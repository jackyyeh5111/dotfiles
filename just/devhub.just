# DevHub recipes: just devhub <recipe>. Run `just devhub` to list them.

# Relative to this file: ~/dotfiles/just -> ~/memryx/DevHub
set working-directory := '../../memryx/DevHub'

# docsenv on PATH, like `workon docsenv` (it has no activate hooks)
venv := home_directory() / ".virtualenvs/docsenv"
export VIRTUAL_ENV := venv
export PATH := venv / "bin:" + env("PATH")

# List recipes
[private]
default:
    @{{just_executable()}} --justfile {{justfile()}} --list devhub

# Build the HTML docs
build:
    make -C docs html -j16

# Serve the built docs at http://localhost:8080
run:
    python3 -m http.server 8080 -d docs/build_release/html

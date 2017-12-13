#!/bin/bash
set -eu

# Compile the Castle Game Engine build tool
# ("castle-engine" binary, "castle-engine.exe" on Windows).
# See https://github.com/castle-engine/castle-engine/wiki/Build-Tool .
#
# Call this script from it's directory (castle_game_engine/tools/build-tool/),
# or from the main castle_game_engine/ directory.
# Or just do "make examples" in main castle_game_engine/ directory.
#
# Note: Once you have compiled the build tool and made it on $PATH,
# you can later compile build tool by itself (bootstrap) using:
#   castle-engine compile
# in this directory (castle_game_engine/tools/build-tool/).

# Allow calling this script from it's dir.
if [ -f code/castle-engine.lpr ]; then cd ../../; fi

fpc -dRELEASE @castle-fpc.cfg \
  -Futools/build-tool/embedded_images/ \
  tools/build-tool/code/castle-engine.lpr

# move binaries up
if [ -f tools/build-tool/code/castle-engine.exe ]; then
  mv -f tools/build-tool/code/castle-engine.exe tools/build-tool/
fi
if [ -f tools/build-tool/code/castle-engine ]; then
  mv -f tools/build-tool/code/castle-engine tools/build-tool/
fi

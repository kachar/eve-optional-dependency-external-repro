#!/bin/sh
# Inspect the build output: is next inlined into the server bundle?
S=.output/server
echo "server bundle size:        $(du -sk $S | cut -f1) KB"
echo "files containing NextResponse: $(grep -rl 'NextResponse' $S --include='*.mjs' | wc -l | tr -d ' ')"
echo "build-machine node_modules paths in bundle: $(grep -rhoF "$PWD/node_modules" $S --include='*.mjs' | wc -l | tr -d ' ')"
echo "traced node_modules: $(ls $S/node_modules 2>/dev/null | tr '\n' ' ')"

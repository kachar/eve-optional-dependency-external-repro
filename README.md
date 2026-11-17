# eve: `build.externalDependencies` inlines packages that only optionally depend on a listed name

Tested with eve 1.0.2 (also present in 1.0.1), Node 24, pnpm 10.

Listing a package in `build.externalDependencies` (here `sharp`) makes eve bundle (inline) every
installed package that has that name anywhere in its dependency closure, including as an
`optionalDependencies` entry. `next` lists `sharp` as an optional dependency, so `next` is inlined
into the server chunk instead of staying external. Inlined CommonJS keeps absolute build-machine
paths (`__require("<repo>/node_modules/.pnpm/next@.../...")`), so the output only works on the
machine that built it. On a host that builds and runs in different places, startup or the first
request fails with `Cannot find module '<build path>/node_modules/.pnpm/next@...'`.

Cause: `canHostBundleInstalledPackage` in `dist/src/internal/authored-package-boundary.js` returns
`false` when `installedDependencyClosure` (`dist/src/internal/installed-packages.js`) reaches a listed
name. The closure follows `dependencies`, `optionalDependencies` and `peerDependencies`.

Second defect: an entry such as `"sharp*"` is never matched, because
`resolveConfiguredExternalDependency` only accepts `name` or `name/...`. Sharp itself is then inlined.

## Repro

```sh
pnpm install
pnpm build            # agent/agent.ts has externalDependencies: ["sharp"]
./check.sh
```

`agent/tools/ping.ts` imports `next/server.js`. `agent/agent.ts` sets
`build: { externalDependencies: ["sharp"] }`. Nothing else differs from `eve init`.

Compare with an empty list: set `externalDependencies: []`, then `rm -rf .output && pnpm build && ./check.sh`.

Runtime effect: move `node_modules` away and start the output.

```sh
mv node_modules node_modules.bak
node .output/server/index.mjs        # or: PORT=3101 node .output/server/index.mjs
mv node_modules.bak node_modules
```

## Expected vs actual

| | `["sharp"]` (actual) | `[]` |
| --- | --- | --- |
| `next` in output | inlined into `_chunks/node-server.mjs` (about 508 kB) | separate `_libs/next.mjs`, chunk about 386 kB |
| build-machine `node_modules` paths in output | 2 (`__require("<repo>/node_modules/.pnpm/next@...")`) | 0 |
| start after `node_modules` removed | crashes: `Error: Cannot find module '<repo>/node_modules/.pnpm/next@.../next/dist/c...'` | starts; `POST /eve/v1/session` returns 401 |

Expected: listing `sharp` keeps `sharp` external and does not change how `next` is packaged,
because `sharp` is only an optional dependency of `next`.

## Fix idea

In `canHostBundleInstalledPackage`, walk only `dependencies` and `peerDependencies` (skip
`optionalDependencies`) when checking whether a package reaches a listed name. With that change
`next` is no longer inlined, the output has no build-machine paths, and `sharp` is still traced.
Also let `resolveConfiguredExternalDependency` honour a trailing `*`.

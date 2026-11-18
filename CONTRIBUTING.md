# Contributing

Use an issue to describe a bug or propose a change. Include your client build, profession, recipe spell ID and steps to reproduce it. For data corrections, include a source URL or an in-game observation. Remove private chat from screenshots. Do not upload your WTF folder or account data.

## Local checks

Install Node.js and Python 3.11 or later, then run from the repository root:

```sh
npm ci --ignore-scripts
npm test
python tools/test_package.py
python tools/package.py
```

The tests parse every runtime file as Lua 5.1 and execute mocked WoW API checks through Fengari. They cover profession scanning, delayed data, eligibility, filters, tooltips, chat drafts, carried materials and crate quantities. The catalog checks validate identifiers, references, quantities and evidence for asserted skill requirements. These checks do not replace testing inside WoW.

The package builder uses release-manifest.json, rejects unexpected runtime files and verifies every ZIP member against its source. Media, developer dependencies and saved data stay outside the installable ZIP.

Packaging tests build isolated miniature repositories and check version mismatches, invalid manifests, missing files, reproducible ZIP contents and release tags. Keep the TOC, package.json and both package-lock.json version fields in agreement.

## Source and data changes

Implement features against the WoW APIs and our tests. Do not copy code or databases from ARL or another project without a compatible license. Preserve Recipe Registry's included MIT notice. See docs/data-sources.md and docs/origin-review.md before changing the data.

Recipe, learning and storage tables are checked-in snapshots. Keep source URLs and evidence notes with corrections. Never turn an unknown requirement into a guessed value. The private import caches and upstream ARL package are not part of this repository.

For a release, update the TOC version, run the checks and publish a matching v-prefixed prerelease tag. GitHub Actions builds and attaches the installable ZIP and SHA256SUMS.txt.

## Test dependency audit

`npm audit` reported zero vulnerabilities on 18 November 2026. GitHub withdrew [GHSA-hp3w-g68c-fv3c](https://github.com/advisories/GHSA-hp3w-g68c-fv3c), the earlier sprintf-js advisory. Fengari runs only the repository's tests and is not shipped in the add-on. The runner executes Lua with standard libraries enabled, so run it only with trusted repository code.

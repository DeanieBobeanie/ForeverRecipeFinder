# Contributing

Use an issue to describe a bug or propose a change. Include your client build, profession, recipe spell ID and steps to reproduce it. For data corrections, include a source URL or an in-game observation. Remove private chat from screenshots. Do not upload your WTF folder or account data.

## Local checks

Install Node.js and Python 3.11 or later, then run from the repository root:

```sh
npm ci --ignore-scripts
npm test
python tools/package.py
```

The tests parse every runtime file as Lua 5.1 and execute mocked WoW API checks through Fengari. They cover profession scanning, delayed data, eligibility, filters, tooltips, chat drafts and crate quantities. These checks do not replace testing inside WoW.

The package builder uses release-manifest.json, rejects unexpected runtime files and verifies every ZIP member against its source. Media, developer dependencies and saved data stay outside the installable ZIP.

## Source and data changes

Implement features against the WoW APIs and our tests. Do not copy code or databases from ARL or another project without a compatible license. Preserve Recipe Registry's included MIT notice. See docs/data-sources.md and docs/origin-review.md before changing the data.

Recipe, learning and storage tables are checked-in snapshots. Keep source URLs and evidence notes with corrections. Never turn an unknown requirement into a guessed value. The private import caches and upstream ARL package are not part of this repository.

For a release, update the TOC version, run the checks and publish a matching v-prefixed prerelease tag. GitHub Actions builds and attaches the installable ZIP and SHA256SUMS.txt.

## Test dependency audit

The 21 October 2026 npm audit reports GHSA-hp3w-g68c-fv3c in sprintf-js through Fengari, with no fixed version available. It concerns denial of service from excessive format precision. Fengari is used only to run this repository's tests and is not shipped in the add-on. Do not use this test runner as a service for untrusted Lua input.

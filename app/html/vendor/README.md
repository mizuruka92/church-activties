# Vendored libraries

The HTML dashboard draws its charts with three open-source JavaScript libraries. They are copied here unchanged so that
the dashboard opens without internet. All three are BSD-3-Clause; the licence texts sit next to the files.

| File | Package | Version | Source | sha256 of the file |
|---|---|---|---|---|
| `vega.min.js` | vega | 5.30.0 | `build-es5/vega.min.js` of the npm package | `e432c751a6363f4a61da62920cc7d7ebd13cf09d82949f8f486248f8071dc3ce` |
| `vega-lite.min.js` | vega-lite | 5.21.0 | `build/vega-lite.min.js` of the npm package | `cd32314b1e76e7d879dc9f0534b62be714df03554486c7ca2381abfd0a92d2f4` |
| `vega-embed.min.js` | vega-embed | 6.26.0 | `build/vega-embed.min.js` of the npm package | `072c054f2a6310725e038c38a71e00052705e31835632462c9717a23a384e895` |

The npm tarballs were downloaded from `registry.npmjs.org` and checked against the integrity value that the registry
publishes for each version:

* `vega-5.30.0.tgz`: `sha512-ZGoC8LdfEUV0LlXIuz7hup9jxuQYhSaWek2M7r9dEHAPbPrzSQvKXZ0BbsJbrarM100TGRpTVN/l1AFxCwDkWw==`
* `vega-lite-5.21.0.tgz`: `sha512-hNxM9nuMqpI1vkUOhEx6ewEf23WWLmJxSFJ4TA86AW43ixJyqcLV+iSCO0NipuVTE0rlDcc2e8joSewWyOlEwA==`
* `vega-embed-6.26.0.tgz`: `sha512-AZCTdKHDAuhp6TFZRQOOs332tStCwZr/5e4uZMNEuJL69A57cT66NNZJdNiCP6u66REzIToYtMJhMTL9wl5B3A==`

To upgrade, download the new tarballs, check their integrity the same way, replace the three files and the licences,
update this table, and run `python scripts/build_html_dashboard.py` and the tests. The build script removes the trailing
`//# sourceMappingURL` comment of each library from the generated page (the files here keep it), so that no browser
tries to look up a source map.

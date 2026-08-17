# HermesMacOS Field Manual

This directory is a standalone static documentation site generated from every Markdown document in `../docs/` and `../specs/`. The generator copies no source Markdown: it scans the repository each time and writes browser-ready HTML to `site/`.

## Build

```sh
cd wiki
python3 build.py
```

## Preview locally

```sh
cd wiki/site
python3 -m http.server 8000
```

Open `http://localhost:8000/` in a browser.

## Validate

```sh
cd wiki
python3 validate.py
```

Validation checks that every Markdown source has an HTML counterpart, all generated internal links resolve, every output page has essential accessibility landmarks, and the search index covers the full source set.

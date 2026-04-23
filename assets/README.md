# assets/

Store images, diagrams, figures, and other media here. Reference them in drafts with standard markdown:

```markdown
![Alt text describing the image](assets/diagram-name.png)
```

## Naming conventions

Use lowercase, hyphen-separated names:
- `assets/architecture-overview.png`
- `assets/figure-01-layering.png`
- `assets/ch3-state-diagram.svg`

## Format and DPI requirements

| Use case | Format | Minimum DPI |
|----------|--------|-------------|
| KDP print | PNG or JPEG | 300 DPI |
| arXiv / HTML | PNG or SVG | 150 DPI |
| EPUB | PNG or JPEG | 72 DPI |

**KDP print requires 300 DPI.** Lower-resolution images will appear blurry in print. Check DPI with:
```bash
identify -verbose assets/your-image.png | grep Resolution
# or
file assets/your-image.png
```

## SVG for diagrams

Prefer SVG for diagrams and architecture figures — they scale perfectly at any DPI. Pandoc converts SVG to PDF when building the KDP target (requires `librsvg`: `brew install librsvg`).

## Cover image for EPUB

Place your cover image at `book-cover/cover.jpg` — `build.sh` will automatically include it in EPUB builds if the file exists.

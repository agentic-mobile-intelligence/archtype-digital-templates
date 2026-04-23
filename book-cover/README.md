# book-cover/

Store cover design files here. The build pipeline uses `cover.jpg` for EPUB covers automatically if it exists.

## KDP print cover specifications (8×10 trim size)

KDP requires a single flat PDF combining front cover, spine, and back cover.

### Spine width formula

```
spine_width_inches = page_count × 0.002252
```

For a 300-page book: `300 × 0.002252 = 0.676 inches`

Use KDP's cover calculator for the exact value: https://kdp.amazon.com/en_US/cover-calculator

### Full cover dimensions (8×10 trim)

```
Total width  = back_cover + spine + front_cover + (2 × bleed)
             = 8 + spine_width + 8 + (2 × 0.125)
             = 16.25 + spine_width inches

Total height = trim_height + (2 × bleed)
             = 10 + (2 × 0.125)
             = 10.25 inches
```

### Safe zone

Keep all text and important elements at least **0.25 inches** from any edge (outside the bleed zone).

## Files

| File | Purpose |
|------|---------|
| `cover.jpg` | EPUB cover (1600×2400 px recommended, 300 DPI) |
| `cover-kdp.pdf` | Full KDP print cover (front + spine + back, flat PDF) |
| `back-cover.md` | Back cover copy (text draft) |

## Tools

- **Canva / Adobe InDesign** — for designing the cover layout
- **KDP Cover Calculator** — https://kdp.amazon.com/en_US/cover-calculator
- **ImageMagick** — for resizing/converting: `magick cover-source.png -resize 1600x2400 cover.jpg`

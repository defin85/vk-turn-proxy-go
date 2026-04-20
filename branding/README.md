# Branding

`branding/source/app_icon.svg` is the editable vector master for the app icon.

`branding/source/app_icon.png` is the generated raster master that packaging
workflows consume. `scripts/generate_app_icons.py` refreshes that PNG from the
SVG first when the SVG is newer and `rsvg-convert` is available.

`scripts/generate_app_icons.py` resizes that source into the platform packaging
assets for Android, iOS, macOS, Windows, plus the Linux runtime asset used by
the desktop shell bundle.

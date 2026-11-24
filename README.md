<!--
DRAFT NOTE (Wright, 24 Nov 2026, remove before publishing):
The plugin id io.github.advocu.periodic-table and the repo URL
github.com/advocu/omarchy-periodic-table are proposed, not confirmed.
Suyash has not confirmed them yet. Plugin ids are permanent once listed.
-->

# Periodic Table for Omarchy

A periodic table that lives in the Omarchy top bar. Click the `⚛ Pt` button to open it. Point at an element, or move to it with the keyboard, and the card under the grid shows its details. **More Details** opens that element's properties and an animated Bohr shell diagram.

Needs Omarchy 4.x (the Quattro shell with plugin support). It is plain QML and JavaScript with the element data bundled. It starts no processes and makes no network requests.

## Install

```sh
omarchy plugin add https://github.com/advocu/omarchy-periodic-table --enable
```

The widget goes to the right side of the bar. To put it somewhere else:

```sh
omarchy bar move io.github.advocu.periodic-table --section left
```

Sections are `left`, `centerBegin`, `center`, `centerEnd`, `tray`, and `right`.

## Use

| Input | What it does |
| --- | --- |
| Click `⚛ Pt` | Open or close the table |
| Mouse over a tile | Show that element in the card |
| Arrow keys or `h` `j` `k` `l` | Move around the grid |
| Left/Right or `h` `l` in More Details, or its Prev/Next buttons | Previous or next element by atomic number |
| `Enter` or `m`, the **More Details** bar, or double-click a tile | Open or close More Details |
| `v` | Cycle tile colours: family, valence electrons, electronegativity, van der Waals radius |
| `t` | Show or hide the temperature presets (4 K to 5,800 K) and the state at that temperature |
| Category buttons | Dim every element outside that family. Click again, or **All**, to clear |
| `Tab` / `Shift+Tab` | Move to the next or previous bar popup |
| `Esc` | Close More Details, then close the table |

You can also open and close it from a terminal or a key binding:

```sh
omarchy-shell shell summon io.github.advocu.periodic-table '{}'
omarchy-shell shell hide io.github.advocu.periodic-table
```

## Missing data

Some values are not known, mostly for the heaviest elements. The plugin never fills those in.

- In the card and in More Details, a missing value reads **no data**.
- With the temperature presets on, the state reads **Unknown (no melting/boiling data)** in amber when the data can't decide it.
- In the colour modes, elements without a value are grey, and the mode label says so. They are left out of the colour scale.

Masses in square brackets, such as `[295]`, are mass numbers for elements with no standard atomic weight. Electron configurations marked `(predicted)` or `(calculated)` are shown as the source gives them.

## Data sources

Each field in `ElementsData.js` names its source in the file header:

- IUPAC/CIAAW abridged standard atomic weights (2024)
- IUPAC Periodic Table of the Elements
- PubChem Periodic Table (NCBI)
- NIST Atomic Spectra Database

## Remove

```sh
omarchy plugin remove io.github.advocu.periodic-table
```

The plugin writes no files of its own, so removing it leaves nothing behind.

## Check a local copy

```sh
omarchy plugin validate ./omarchy-periodic-table
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml BohrCanvas.qml
```

## License

MIT. See [LICENSE](LICENSE), which also lists the data sources.

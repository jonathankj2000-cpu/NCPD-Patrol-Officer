# Bean Bagger appearance source

The v0.16b private appearance is authored from the user's `Beanbagger (2).zip`.
Only the two required skinned meshes, one default appearance, default material
setups/masks and a private plastic template are retained. `visuals/authoring.json`
records the input ZIP hash, original geometry hashes, selected areas, decoded
mask preservation and hashes of the eleven source resources.

The pump coating reuses previously empty layer 9 and requires both the original
polymer coverage and the moving foreend bone. The rear coating reuses empty
layer 8 and covers the lower pistol grip, below Y=-0.022 m and Z<=0.047 m in
the exported mesh. Separate FPP and TPP masks follow the corresponding UVs.
Every other mask layer decodes identically to its source. Layer counts remain
20 and 19; no twenty-first layer is added. The original stock, butt pad,
receiver, barrel, magazine cap, metal fittings and sights retain their materials.

The private template uses linear RGB corresponding to sRGB `#28567D` and
roughness scale/bias `[0.14, 0.68]`, giving a nominal matte range 0.68-0.82.
Existing wear/dirt layers above the coating remain active. In-game lighting
and the layered shader determine the final displayed color.

All new resources live under `base\ncpd_patrol\beanbagger`. The ArchiveXL
`factories` entry registers `factory.csv`, which maps `NCPDPatrol_BeanBagger`
to the private `.app`. Only `Items.NCPDBeanBagger_M2038.appearanceResourceName`
selects it. No vanilla depot path or factory entry is overridden. The appearance
keeps the original component names, IDs, rig/animation resources and transform
bindings; both mesh render buffers and their skeleton data are retained.

Build with WolvenKit CLI 9.1.1 and its .NET 10 runtime:

```sh
python tools/build_beanbagger_assets.py --wk-cli /path/to/WolvenKit.CLI
python tools/build_beanbagger_visual_release.py
```

The first command round-trips all eleven compiled resources and extracts the
packed archive to compare every resource byte. `compiled.json` records hashes
and the result. Private resource references may display as native FNV-1a hashes
when WolvenKit's path dictionary does not contain the new depot path; the build
check resolves those hashes for comparison. The second command runs the portable
suites, verifies unchanged native scripts/previous archives and builds the full
install ZIP. Actual rendering, pickup/equip and pump motion need an in-game test.

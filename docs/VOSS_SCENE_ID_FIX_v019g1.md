# v0.19g1 — local scene identifiers

The user reports a desktop crash on approaching Voss, before the first spoken
line. Their REDscript log ends with successful compilation and cache output;
it contains no native exception or stack. No actual native crash reproduction
or definitive crash-cause claim is made by the offline checks below.

The generated v0.19g scene has a concrete format error: its dialogue item IDs
are `100001, 100002, ...`. The working Andrea Olivato reference and our previous
working scene use `(array_index << 8) | 1` for dialogue and a type byte of `2`
for options. The old first item has type byte `161` and upper index `390`,
although its line array contains only ten entries. It is not a valid dialogue
identifier under that reference-backed layout.

The generator now produces `1, 257, 513, ... 2305`, updates every dialogue
event reference and keeps the line-array order consistent. It also restores
a conservative dense, ordered 1–15 node layout, matching the working reference.
All edges and the final receipt target are updated. Start/end/intro and the
unreachable legacy workspot node retain their established IDs.

The earlier Python scene interpreter searched the line array for a matching
integer, so it accepted the same invalid ID in both the event and its line.
It now checks the type byte, bounds and indexed entry. A separate schema test
uses extracted ID arrays from Andrea's pinned MIT `fixer01_face.scene.json`
(commit `4aeaad5d235e3a0244c0f1857757d1b01cbcd58e`, blob
`82f4a677128dff4765fe66276c7eefa8b8b2ce2d`). The shipped v0.19g data is a negative
control: its first item and sparse graph are rejected. Bad type, out-of-bounds
index, reordered array, missing event/edge targets and node order are tested.

This changes local scene identifiers, not the supplied original V string IDs.
All speech text, six voices, merged animation bank, caption timings, SMS, pose,
quest phase and journal are unchanged. All 46 REDscript files and eight other
archives are byte-identical to v0.19g. The private archive is rebuilt and
roundtrip/extraction checked; production dispatch and saved ledgers are untouched.

The invalid scene layout is a strong candidate for an immediate native crash,
but the supplied compilation log cannot prove the native fault location. Game
confirmation is still required. Do not rerun the unchanged crashing package
to try to obtain more REDscript compiler output.

Install the complete 123-file v0.19g1 package and fully restart. Use a save made
before activating the old Voss test, or clear an inactive/far-away old test
before updating. Activate the same OFF DUTY test and approach Voss once. Check
that her first line starts, then let all ten automatic turns finish. If it
still crashes, the next investigation needs native crash evidence or a controlled
resource-isolation build; repeating the old compiler-log check will not identify
that cause.

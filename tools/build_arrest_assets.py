"""Build the private vanilla-workspot anchor with WolvenKit Console 9.1.1.

Developer tool only. Players install the compiled archive from the release ZIP.
Requires the runtime needed by the chosen WolvenKit CLI (9.1.1 uses .NET 10).
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = r"base\workspots\common\ground\generic__lie_ground_lean_front_handcuffs_a__aggressive__01.workspot"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wk-cli", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "archive/pc/mod/NCPDPatrol_Arrest.archive")
    args = parser.parse_args()
    cli = str(args.wk_cli.resolve())

    def run(*arguments):
        subprocess.run([cli, *map(str, arguments)], check=True)

    with tempfile.TemporaryDirectory(prefix="ncpd-arrest-build-") as scratch:
        temp = Path(scratch)
        raw = temp / "source"
        raw.mkdir()
        source = raw / "arrest_workspot.ent.json"
        shutil.copy2(ROOT / "assets/arrest/arrest_workspot.ent.json", source)
        packed = temp / "NCPDPatrol_Arrest"
        depot = packed / "base/ncpd_patrol"
        depot.mkdir(parents=True)
        run("convert", "deserialize", source, "--outpath", depot)
        entity = depot / "arrest_workspot.ent"
        if not entity.exists() or entity.read_bytes()[:4] != b"CR2W":
            raise RuntimeError("WolvenKit did not produce the anchor entity")

        roundtrip = temp / "roundtrip"
        roundtrip.mkdir()
        run("convert", "serialize", entity, "--outpath", roundtrip)
        data = json.loads((roundtrip / "arrest_workspot.ent.json").read_text(encoding="utf-8-sig"))
        root = data["Data"]["RootChunk"]
        components = root["components"]
        if len(components) != 1 or components[0]["$type"] != "workWorkspotResourceComponent":
            raise RuntimeError("Anchor component did not survive serialization")
        if components[0]["workspotResource"]["DepotPath"]["$value"] != RESOURCE:
            raise RuntimeError("Unexpected workspot dependency")

        output = temp / "compiled"
        output.mkdir()
        run("pack", packed, "--outpath", output)
        archive = output / "NCPDPatrol_Arrest.archive"
        extracted = temp / "extracted"
        extracted.mkdir()
        run("extract", archive, "--outpath", extracted)
        files = [path for path in extracted.rglob("*") if path.is_file()]
        if len(files) != 1 or files[0].read_bytes() != entity.read_bytes():
            raise RuntimeError("Packed archive did not preserve the anchor bytes")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(archive, args.output)
        print(f"Built and verified {args.output}")


if __name__ == "__main__":
    main()

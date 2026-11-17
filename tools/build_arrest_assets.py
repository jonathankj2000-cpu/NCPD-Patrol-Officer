"""Build the private arrest anchor and infinite idle with WolvenKit Console 9.1.1.

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
RESOURCE = r"base\ncpd_patrol\arrest_lying_loop.workspot"
CLIP = "lie_ground_0__2h_back_handcuffs_a__01"


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
        if root.get("cookingPlatform") != "PLATFORM_PC":
            raise RuntimeError("Anchor must be cooked for PC")
        components = root["components"]
        if len(components) != 1 or components[0]["$type"] != "workWorkspotResourceComponent":
            raise RuntimeError("Anchor component did not survive serialization")
        if components[0]["name"]["$value"] != "NCPDPatrolArrestLoop":
            raise RuntimeError("Outdated arrest component name")
        if components[0]["workspotResource"]["DepotPath"]["$value"] != RESOURCE:
            raise RuntimeError("Unexpected workspot dependency")

        loop_source = raw / "arrest_lying_loop.workspot.json"
        shutil.copy2(ROOT / "assets/arrest/arrest_lying_loop.workspot.json", loop_source)
        run("convert", "deserialize", loop_source, "--outpath", depot)
        loop_file = depot / "arrest_lying_loop.workspot"
        if not loop_file.exists() or loop_file.read_bytes()[:4] != b"CR2W":
            raise RuntimeError("WolvenKit did not produce the private loop resource")
        run("convert", "serialize", loop_file, "--outpath", roundtrip)
        loop_data = json.loads((roundtrip / "arrest_lying_loop.workspot.json").read_text(encoding="utf-8-sig"))
        loop_root = loop_data["Data"]["RootChunk"]
        if loop_root.get("cookingPlatform") != "PLATFORM_PC":
            raise RuntimeError("Loop must be cooked for PC")
        handles = {}
        def collect(value):
            if isinstance(value, dict):
                if "HandleId" in value and "Data" in value:
                    handles[value["HandleId"]] = value["Data"]
                for item in value.values(): collect(item)
            elif isinstance(value, list):
                for item in value: collect(item)
        collect(loop_data)
        def resolve(value):
            return value["Data"] if "Data" in value else handles[value["HandleRefId"]]
        tree = resolve(loop_root["workspotTree"])
        outer = resolve(tree["rootEntry"])
        inner = resolve(outer["list"][0])
        pause = resolve(inner["list"][0])
        if (outer["$type"], inner["$type"], pause["$type"]) != ("workSequence", "workSequence", "workPauseClip"):
            raise RuntimeError("Unexpected loop topology")
        if not outer["loopInfinitely"] or not inner["loopInfinitely"] or tree["initialCanUseExits"] or tree["useTimeLimitForSequences"]:
            raise RuntimeError("Loop permits natural sequence completion/exit")
        if len(outer["list"]) != 1 or len(inner["list"]) != 1 or inner["idleAnim"]["$value"] != CLIP or inner["id"]["id"] != 2:
            raise RuntimeError("Loop must contain only the intended lying idle at entry 2")
        if tree.get("customTransitionAnims", []) or tree.get("finalAnimsets", []):
            raise RuntimeError("Loop must have no transitions or bundled animation bindings")
        graph = resolve(loop_root["rootNode"])
        output_node = resolve(graph["nodes"][0])
        hub = resolve(output_node["node"]["node"])
        if (graph["$type"], output_node["$type"], hub["$type"]) != ("animAnimNode_Root", "animAnimNode_Output", "animAnimNode_WorkspotHub"):
            raise RuntimeError("Incomplete native workspot animation graph")

        output = temp / "compiled"
        output.mkdir()
        run("pack", packed, "--outpath", output)
        archive = output / "NCPDPatrol_Arrest.archive"
        extracted = temp / "extracted"
        extracted.mkdir()
        run("extract", archive, "--outpath", extracted)
        files = [path for path in extracted.rglob("*") if path.is_file()]
        expected = {"arrest_workspot.ent": entity.read_bytes(), "arrest_lying_loop.workspot": loop_file.read_bytes()}
        if len(files) != 2 or {path.name: path.read_bytes() for path in files} != expected:
            raise RuntimeError("Packed archive did not preserve both authored resources")
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(archive, args.output)
        print(f"Built and verified {args.output}")


if __name__ == "__main__":
    main()

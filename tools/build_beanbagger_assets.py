"""Compile and round-trip the isolated Bean Bagger appearance with WolvenKit 9.1.1.

The authored JSON includes original skinned geometry supplied by the user.
Players install the compiled archive; this is a developer tool only.
"""
from pathlib import Path
import argparse, hashlib, json, math, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/beanbagger/visuals'
DEPOT = 'base/ncpd_patrol/beanbagger'


def canonical(value):
    """Unknown private resource paths round-trip as their native FNV-1a hashes."""
    if isinstance(value, dict):
        if value.get('$type') == 'ResourcePath':
            if value.get('$storage') == 'string':
                result = 14695981039346656037
                for char in value['$value'].encode():
                    result = ((result ^ char) * 1099511628211) & 0xffffffffffffffff
                return str(result)
            return value['$value']
        return {k: canonical(v) for k, v in value.items() if k not in ['BufferId', 'HandleId']}
    if isinstance(value, list):
        return [canonical(v) for v in value]
    return value


def equivalent(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(equivalent(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(equivalent(x, y) for x, y in zip(a, b))
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return math.isclose(a, b, rel_tol=2e-7, abs_tol=1e-8)
    return a == b


def components(document):
    handles = {}
    def collect(value):
        if isinstance(value, dict):
            if 'HandleId' in value and 'Data' in value:
                handles[value['HandleId']] = value['Data']
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)
    collect(document)
    def resolve(value):
        if isinstance(value, dict):
            if 'HandleRefId' in value:
                return resolve(handles[value['HandleRefId']])
            if 'HandleId' in value and 'Data' in value:
                return resolve(value['Data'])
            return {k: resolve(v) for k, v in value.items()}
        if isinstance(value, list):
            return [resolve(v) for v in value]
        return value
    return resolve(document['Data']['RootChunk']['appearances'][0]['Data']['components'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wk-cli', required=True, type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'archive/pc/mod/NCPDPatrol_BeanBagger.archive')
    args = parser.parse_args()
    cli = str(args.wk_cli.resolve())
    manifest = json.loads((SOURCE / 'authoring.json').read_text())

    def run(*arguments):
        subprocess.run([cli, *map(str, arguments)], check=True)

    with tempfile.TemporaryDirectory(prefix='ncpd-beanbagger-assets-') as scratch:
        temp = Path(scratch)
        packed = temp / 'NCPDPatrol_BeanBagger'
        depot = packed / DEPOT
        depot.mkdir(parents=True)
        roundtrip = temp / 'roundtrip'
        roundtrip.mkdir()
        expected = {}
        for name, entry in manifest['files'].items():
            path = SOURCE / name
            assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], name
            run('convert', 'deserialize', path, '--outpath', depot)
            resource = depot / name.removesuffix('.json')
            assert resource.read_bytes()[:4] == b'CR2W', name
            run('convert', 'serialize', resource, '--outpath', roundtrip)
            source_doc = json.loads(path.read_text())
            restored_doc = json.loads((roundtrip / name).read_text(encoding='utf-8-sig'))
            original, restored = source_doc['Data']['RootChunk'], restored_doc['Data']['RootChunk']
            assert restored['$type'] == original['$type']
            assert restored['cookingPlatform'] == 'PLATFORM_PC'
            if original['$type'] == 'CMesh':
                assert equivalent(canonical(restored['renderResourceBlob']), canonical(original['renderResourceBlob'])), 'geometry changed: ' + name
                assert restored['boneNames'] == original['boneNames']
                assert restored['boneRigMatrices'] == original['boneRigMatrices']
                assert restored['materialEntries'] == original['materialEntries']
                assert canonical(restored['localMaterialBuffer']['materials']) == canonical(original['localMaterialBuffer']['materials']), 'material edits lost: ' + name
            elif original['$type'] == 'appearanceAppearanceResource':
                a, b = original['appearances'][0]['Data'], restored['appearances'][0]['Data']
                assert len(restored['appearances']) == 1
                assert restored['preset']['$value'] == 'Items.NCPDBeanBagger_M2038'
                # Handle numbering can change on a round-trip. Resource paths,
                # component IDs, animation setups and binding names must survive.
                for key in ['name', 'visualTags', 'resolvedDependencies']:
                    assert canonical(a[key]) == canonical(b[key]), key
                assert equivalent(canonical(components(source_doc)), canonical(components(restored_doc))), 'component, rig, animation or transform binding changed'
            elif original['$type'] == 'Multilayer_Mask':
                assert restored['renderResourceBlob'] == original['renderResourceBlob'], 'mask changed: ' + name
            elif original['$type'] == 'C2dArray':
                for key in original:
                    assert equivalent(canonical(restored[key]), canonical(original[key])), (name, key)
            else:
                assert equivalent(canonical(restored), canonical(original)), name
            expected[resource.name] = resource.read_bytes()
        assert len(expected) == 11
        output = temp / 'compiled'
        output.mkdir()
        run('pack', packed, '--outpath', output)
        archive = output / 'NCPDPatrol_BeanBagger.archive'
        extracted = temp / 'extracted'
        extracted.mkdir()
        run('extract', archive, '--outpath', extracted)
        files = [p for p in extracted.rglob('*') if p.is_file()]
        assert len(files) == 11 and {p.name: p.read_bytes() for p in files} == expected
        args.output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(archive, args.output)
        report = {'tool': 'WolvenKit CLI 9.1.1', 'resource_count': len(expected),
                  'archive_sha256': hashlib.sha256(args.output.read_bytes()).hexdigest(),
                  'resources': {DEPOT + '/' + k: hashlib.sha256(v).hexdigest() for k, v in expected.items()},
                  'roundtrip_preserves_geometry_rig_materials_masks_and_animations': True,
                  'archive_extract_matches_compiled_resources': True,
                  'game_rendering_tested': False}
        (ROOT / 'assets/beanbagger/compiled.json').write_text(json.dumps(report, indent=2) + '\n')
        print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()

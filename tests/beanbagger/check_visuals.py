"""Check the shipped private factory, geometry, material/mask bindings and build evidence."""
from pathlib import Path
import base64, hashlib, json, struct

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/beanbagger/visuals'
PREFIX = 'base\\ncpd_patrol\\beanbagger\\'


def load(name):
    return json.loads((SOURCE / (name + '.json')).read_text())['Data']['RootChunk']


def paths(value):
    if isinstance(value, dict):
        if value.get('$type') == 'ResourcePath' and value.get('$storage') == 'string':
            yield value['$value']
        for child in value.values():
            yield from paths(child)
    elif isinstance(value, list):
        for child in value:
            yield from paths(child)


def main():
    report = json.loads((SOURCE / 'authoring.json').read_text())
    expected = {'beanbagger.app', 'factory.csv', 'pump.mesh', 'grip.mesh', 'pump.mlsetup',
                'grip.mlsetup', 'ncpd_grip.mltemplate', 'pump_fpp.mlmask', 'pump_tpp.mlmask',
                'grip_fpp.mlmask', 'grip_tpp.mlmask'}
    assert {name.removesuffix('.json') for name in report['files']} == expected
    for name, info in report['files'].items():
        data = (SOURCE / name).read_bytes()
        assert len(data) == info['bytes'] and hashlib.sha256(data).hexdigest() == info['sha256'], name
    for name in expected:
        resource = load(name)
        assert resource['cookingPlatform'] == 'PLATFORM_PC'
        for reference in paths(resource):
            assert '\\\\' not in reference, reference
            if reference.startswith(PREFIX):
                assert reference.removeprefix(PREFIX) in expected, reference

    factory = load('factory.csv')
    assert factory['compiledHeaders'] == ['name', 'path', 'preload']
    assert factory['compiledData'] == [['NCPDPatrol_BeanBagger', PREFIX + 'beanbagger.app', 'false']]
    xl = (ROOT / 'archive/pc/mod/NCPDPatrol_BeanBagger.archive.xl').read_text()
    assert xl.splitlines() == ['factories:', '  - ' + PREFIX + 'factory.csv']
    yaml = (ROOT / 'r6/tweaks/NCPDBeanBagger/NCPDBeanBagger.yaml').read_text()
    assert '  appearanceResourceName: NCPDPatrol_BeanBagger\n' in yaml
    assert '  $base: Items.Preset_Tactician_Default\n' in yaml
    app = load('beanbagger.app')
    assert app['preset']['$value'] == 'Items.NCPDBeanBagger_M2038' and len(app['appearances']) == 1
    appearance = app['appearances'][0]['Data']
    assert appearance['name']['$value'] == 'default'
    assert {v['$value'] for v in appearance['visualTags']['tags']} == {'default', 'Default'}
    assert {p for p in paths(appearance) if p.startswith(PREFIX)} == {PREFIX + 'pump.mesh', PREFIX + 'grip.mesh'}
    components = appearance['components']
    assert len(components) == 24
    assert any(c['$type'] == 'entAnimatedComponent' and c['name']['$value'] == 'Barrel' for c in components)

    for part, count, index in [('pump', 3, 9), ('grip', 2, 8)]:
        mesh = load(part + '.mesh')
        original = report['original_resources'][part]
        render_hash = hashlib.sha256(json.dumps(mesh['renderResourceBlob'], sort_keys=True).encode()).hexdigest()
        assert render_hash == original['render_blob_sha256'] and mesh['boneNames'] == original['bones']
        assert len(mesh['appearances']) == 1 and len(mesh['materialEntries']) == count
        assert len(mesh['localMaterialBuffer']['materials']) == count
        for i, material in enumerate(mesh['localMaterialBuffer']['materials'][:2]):
            references = set(paths(material))
            assert PREFIX + part + '.mlsetup' in references
            assert PREFIX + part + ('_tpp.mlmask' if i == 0 else '_fpp.mlmask') in references
        setup = load(part + '.mlsetup')
        assert len(setup['layers']) == report['parts'][part]['original_layers'] <= 20
        layer = setup['layers'][index]
        assert layer['material']['DepotPath']['$value'] == PREFIX + 'ncpd_grip.mltemplate'
        assert layer['colorScale']['$value'] == 'ncpd_blue_28567d' and layer['opacity'] == 1
        assert layer['roughLevelsOut']['$value'] == 'ncpd_matte'
        for lod in ['fpp', 'tpp']:
            mask = load(part + '_' + lod + '.mlmask')['renderResourceBlob']['renderResourceBlobPC']['Data']
            h = mask['header']
            assert h['numLayers'] == len(setup['layers']) and h['maskTileSize'] == 14
            atlas = base64.b64decode(mask['atlasData']['Bytes'])
            assert len(atlas) == h['atlasWidth'] * h['atlasHeight'] // 2
            assert h['atlasWidth'] % 16 == h['atlasHeight'] % 16 == 0
            data = base64.b64decode(mask['tilesData']['Bytes'])
            words = struct.unpack('<' + 'I' * (len(data) // 4), data)
            size = h['maskTileSize']
            ceil = lambda value: (value + size - 1) // size
            entries = ceil(h['maskWidth']) * ceil(h['maskHeight']) + ceil(h['maskWidthLow']) * ceil(h['maskHeightLow'])
            blue_tiles = 0
            for i in range(entries):
                offset, flags = words[2*i:2*i+2]
                assert flags < 1 << h['numLayers'] and offset + flags.bit_count() <= len(words)
                blue_tiles += bool(flags & (1 << index))
                for declaration in words[offset:offset+flags.bit_count()]:
                    assert (declaration & 1023) < h['atlasWidth'] // 16
                    assert ((declaration >> 10) & 1023) < h['atlasHeight'] // 16
            assert blue_tiles > 0 and report['parts'][part]['masks'][lod]['selected_pixels'] > 0
            assert report['parts'][part]['masks'][lod]['other_layers_byte_identical_after_decode']

    template = load('ncpd_grip.mltemplate')['overrides']
    color = template['colorScale'][0]
    assert len(template['colorScale']) == 1 and color['n']['$value'] == 'ncpd_blue_28567d'
    assert color['v']['Elements'] == report['color_linear'] and report['color_srgb'] == '#28567D'
    assert next(v for v in template['roughLevelsOut'] if v['n']['$value'] == 'ncpd_matte')['v']['Elements'] == [.14, .68]

    compiled = json.loads((ROOT / 'assets/beanbagger/compiled.json').read_text())
    archive = ROOT / 'archive/pc/mod/NCPDPatrol_BeanBagger.archive'
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == compiled['archive_sha256']
    assert compiled['resource_count'] == 11
    assert set(compiled['resources']) == {'base/ncpd_patrol/beanbagger/' + n for n in expected}
    assert compiled['roundtrip_preserves_geometry_rig_materials_masks_and_animations']
    assert compiled['archive_extract_matches_compiled_resources'] and not compiled['game_rendering_tested']
    print('PASS: private Bean Bagger factory and item binding; 11 authored/compiled resources, exact original geometry, rig and animation structure; bounded FPP/TPP coating masks within 20 layers; private blue/matte template and archive integrity (game rendering still requires testing)')


if __name__ == '__main__':
    main()

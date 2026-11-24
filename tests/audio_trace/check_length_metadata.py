"""Execute the actual length-map merge; native loading/mixing remain boundaries."""
from pathlib import Path
import argparse
import json
import re
import struct
import subprocess
import sys
import tempfile
from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'tools/voss_length_test/NCPDPatrolVossLengthTest.reds'
sys.path.insert(0, str(ROOT/'tests/arrests'))
from translate import translate
sys.path.insert(0, str(ROOT/'tools'))
from build_voss_wem_header_test import chunks

FIXTURE = r'''
F={registrations=0,unregistrations=0}
function IsDefined(x) return x~=nil end
function HashToCRUID(x) return x end
function CRUIDToHash(x) return x end
function ArraySize(x) return x.n end
function CopyLengthEntry(x)
 return {stringId=x.stringId,femaleLength=x.femaleLength,maleLength=x.maleLength}
end
function ArrayPush(x,v) x[x.n]=CopyLengthEntry(v);x.n=x.n+1 end
function AsJsonResource(x) return x and x.kind=='JsonResource' and x or nil end
function AsLengthMap(x) return x and x.kind=='locVoiceoverLengthMap' and x or nil end
function NewMap() return {kind='locVoiceoverLengthMap',entries={n=0}} end
function NativeEvent(map)
 return {GetResource=function() return {kind='JsonResource',root=map} end}
end
F.callbacks={}
function F.callbacks:UnregisterCallback(name,owner,method)
 assert(name=='Resource/PostLoad' and method=='OnLengthsLoaded');F.unregistrations=F.unregistrations+1
end
function F.callbacks:RegisterCallback(name,owner,method,sticky)
 assert(name=='Resource/PostLoad' and method=='OnLengthsLoaded' and sticky==true)
 F.registrations=F.registrations+1
 return {AddTarget=function(_,target) F.target=target;return {} end}
end
GameInstance={GetCallbackSystem=function() return not F.noCallbacks and F.callbacks or nil end}
ResourceTarget={Path=function(_,path) return {path=path} end}
'''


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(FIXTURE)
    source = SOURCE.read_text()
    # Preserve the native cast and value-struct boundaries in the recording
    # engine. uint64 values stay exact LuaJIT cdata; no floating-point IDs.
    source = source.replace('event.GetResource() as JsonResource', 'AsJsonResource(event.GetResource())')
    source = source.replace('resource.root as locVoiceoverLengthMap', 'AsLengthMap(resource.root)')
    with tempfile.TemporaryDirectory(prefix='voss-length-execution-') as temp:
        path = Path(temp)/'fixture.reds'
        path.write_text(source)
        code = translate(path)
    code = re.sub(r'\b(\d+)ul\b', r'\1ULL', code)
    code = code.replace('local entry = nil', 'local entry = {}')
    code = code.replace('entry = map.entries[j]', 'entry = CopyLengthEntry(map.entries[j])')
    service = lua.execute(code)
    lua.globals().Service = service
    return lua, service, lua.globals().F


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    source = SOURCE.read_text()
    for forbidden in ['SetFact', 'ExecuteNode', 'GetAudioSystem', 'SetTimeDilation', 'persistent let', '@wrapMethod', '@replaceMethod']:
        assert forbidden not in source, forbidden
    lua, service, fixture = runtime()
    service.OnLoad(service)
    assert fixture.registrations == fixture.unregistrations == 1
    assert fixture.target.path == r'base\localization\en-us\stringidvariantlengthsreport.json'
    rows = json.loads((ROOT/'assets/quest_giver_test/contract.json').read_text())['conversation']
    voices = json.loads((ROOT/'assets/quest_giver_test/vomap.json.json').read_text())['Data']['RootChunk']['root']['Data']['entries']
    for i, (row, voice) in enumerate(zip([x for x in rows if x['speaker']=='voss'], voices)):
        expected_id = lua.eval(voice['stringId']+'ULL')
        assert lua.eval('function(a,b) return a==b end')(service.OwnID(service, i), expected_id)
        wem = (ROOT/'assets/quest_giver_test/media'/row['wem']).read_bytes()
        fmt = chunks(wem)[b'fmt '][0]
        samples = struct.unpack_from('<I', wem, fmt+24)[0]
        rate = struct.unpack_from('<I', wem, fmt+4)[0]
        assert samples/rate == row['audio_seconds']
        expected_length = struct.unpack('<f', struct.pack('<f', samples/rate))[0]
        assert service.OwnLength(service, i) == expected_length
    # Empty and native-stock reports both receive only the six private IDs.
    lua.execute('Map=NewMap();Service:OnLengthsLoaded(NativeEvent(Map))')
    assert service.m_added == service.m_verified == 6 and service.m_updated == 0
    assert lua.globals().Map.entries.n == 6
    lua.execute('Service:OnLengthsLoaded(NativeEvent(Map))')
    assert service.m_callbacks == 2 and service.m_added == 0 and service.m_updated == 6
    assert lua.globals().Map.entries.n == 6
    lua.execute('''Map=NewMap();ArrayPush(Map.entries,{stringId=1938843197804515328ULL,femaleLength=2.817,maleLength=3.3});
      ArrayPush(Map.entries,{stringId=1895381798296993792ULL,femaleLength=3.463,maleLength=4.2});
      Service:OnLengthsLoaded(NativeEvent(Map))''')
    m = lua.globals().Map
    assert m.entries.n == 8 and m.entries[0].femaleLength == 2.817 and m.entries[0].maleLength == 3.3
    assert m.entries[1].femaleLength == 3.463 and m.entries[1].maleLength == 4.2
    assert service.m_added == service.m_verified == 6
    # Partial/duplicated existing private rows are corrected in place; stock
    # rows keep their own gender-specific lengths. A reload is a new map.
    lua.execute('''Map=NewMap();ArrayPush(Map.entries,{stringId=Service:OwnID(0),femaleLength=999,maleLength=998});
      ArrayPush(Map.entries,{stringId=Service:OwnID(0),femaleLength=997,maleLength=996});
      Service:OnLengthsLoaded(NativeEvent(Map))''')
    assert lua.globals().Map.entries.n == 7
    assert service.m_added == 5 and service.m_updated == 2 and service.m_verified == 6
    lua.execute('Service:OnLengthsLoaded(NativeEvent(Map))')
    assert service.m_added == 0 and service.m_updated == 7 and service.m_verified == 6
    lua.execute('Map=NewMap();Service:OnLengthsLoaded(NativeEvent(Map))')
    assert lua.globals().Map.entries.n == 6 and service.m_added == 6
    lua.execute('Map.entries[5].maleLength=0')
    assert service.VerifyLengths(service, lua.globals().Map) == 5
    lua.execute('Service:OnLengthsLoaded({GetResource=function() return {kind="Other"} end})')
    assert service.m_verified == service.m_added == service.m_updated == 0
    assert service.m_failure == 'Expected JsonResource'
    lua.execute('Service:OnLengthsLoaded(NativeEvent({kind="Other"}))')
    assert service.m_verified == 0 and service.m_failure == 'Expected locVoiceoverLengthMap'
    assert service.VerifyLengths(service, None) == 0
    service.ApplyLengths(service, None)
    fixture.noCallbacks = True
    service.OnLoad(service)
    assert not service.m_registered and service.m_failure == 'CallbackSystem unavailable'
    result = {'six_ids_match_actual_private_voice_map': True, 'lengths_match_wem_sample_counts_as_float32': True,
              'actual_merge_executed': True, 'foreign_stock_and_gender_lengths_preserved': True,
              'repeated_load_and_existing_duplicates_do_not_add_duplicate_ids': True,
              'callback_registration_and_readback_diagnostics_tested': True,
              'mismatched_resources_rejected': True, 'gameplay_and_audio_overrides': False,
              'offline_api_compile': False, 'actual_game_callback_and_mixer_validation': False}
    if args.compiler:
        subprocess.run([str(args.compiler.resolve()), str(ROOT/'tests/audio_trace/length-api.reds'), '--', str(SOURCE)], check=True)
        result['offline_api_compile'] = True
    if args.report:
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    print('PASS: actual six-row native length-map merge, exact uint64 private IDs/WEM lengths, '
          'stock rows and gender lengths preserved, idempotence/reload/duplicate/private-row update, '
          'registration and malformed-resource diagnostics. Native resource delivery/mixing unverified.')
    return result


if __name__ == '__main__':
    main()

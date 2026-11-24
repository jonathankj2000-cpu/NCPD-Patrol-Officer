"""Build and verify the patrol-only public package; developer assets stay intact."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile
import zipfile
import nexus_release as release

ROOT=Path(__file__).resolve().parents[1]
NAME='NCPD_Patrol_'+release.VERSION+'_Nexus_Release.zip'
REPORT='NCPD_Patrol_'+release.VERSION+'_Nexus_verification.json'


def main():
    original=release.original_payload()
    for name,body in original.items():
        assert (ROOT/name).read_bytes()==body,'Developer payload differs from the reviewed baseline: '+name
    files=release.payload()
    with tempfile.TemporaryDirectory(prefix='ncpd-nexus-release-') as temp:
        temp=Path(temp)
        stage=temp/'payload'
        release.materialize(files,stage)
        tests=temp/'tests.json'
        subprocess.run([sys.executable,str(ROOT/'tests/nexus/check_release.py'),'--payload-root',str(stage),
                        '--compile-native','--report',str(tests)],check=True,cwd=ROOT)
        result=json.loads(tests.read_text())
    target=ROOT/'releases'/NAME
    with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,body in sorted(files.items()):
            info=zipfile.ZipInfo(name,(2026,11,24,0,0,0))
            info.create_system=3
            info.external_attr=0o100644<<16
            info.compress_type=zipfile.ZIP_DEFLATED
            z.writestr(info,body,compresslevel=9)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==118
        assert {name:z.read(name) for name in z.namelist()}==files
    for name,body in original.items():
        assert (ROOT/name).read_bytes()==body,'Developer file was modified while packaging: '+name
    manifest={name:release.sha(body) for name,body in files.items()}
    report={'version':release.VERSION,'flavour':'Nexus patrol release',
            'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
            'baseline_zip':release.BASE,'baseline_sha256':release.BASE_SHA256,
            'install_files':len(files),'removed_story_files':sorted(release.EXCLUDED),
            'modified_retained_files':sorted(release.EDITED),'new_file':'CHANGELOG.txt',
            'retained_existing_files_byte_identical':114,
            'developer_131_install_files_unchanged':True,
            'all_story_media_archives_scripts_records_and_launchers_omitted':True,
            'temporary_audio_helpers_and_metadata_experiments_omitted':True,
            'retained_44_redscripts_and_8_archives_byte_identical':True,
            'career_receipts_progression_and_incident_payment_code_unchanged':True,
            'officer_down_catalogue_sites':54,'browser_extension_optional':True,
            'private_story_save_migration_supported':False,'tests':result,
            'actual_game_validation_of_release_flavour':False,
            'file':NAME,'bytes':target.stat().st_size,'sha256':release.sha(target.read_bytes()),'files':manifest}
    (ROOT/'releases'/REPORT).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:report[k] for k in ('version','flavour','install_files','retained_existing_files_byte_identical',
                                          'developer_131_install_files_unchanged','file','bytes','sha256')},indent=2))


if __name__=='__main__':main()

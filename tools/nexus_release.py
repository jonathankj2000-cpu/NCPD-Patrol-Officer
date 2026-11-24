"""Produce a patrol-only payload without changing the developer working tree."""
from pathlib import Path
import hashlib
import re
import zipfile

ROOT=Path(__file__).resolve().parents[1]
VERSION='v0.20g'
BASE='NCPD_Patrol_v0.20f1_Dialogue_Handoff_TEST.zip'
BASE_SHA256='d6493b500015e0877d28b4d85570ad9ec165a07c877c7ceb75643b1b61cc9bb4'
PREFIX='bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol/'
EXCLUDED={
    PREFIX+'quest_giver_test.lua', PREFIX+'off_the_books.lua',
    *('r6/scripts/NCPDPatrol/'+name+'.reds' for name in (
        'NCPDPatrolQuestGiverTest','NCPDPatrolVossSubtitles','NCPDPatrolOffBooksSystem',
        'NCPDPatrolOffBooksEvents','NCPDPatrolOffBooksCombat','NCPDPatrolOffBooksLoot')),
    'r6/tweaks/NCPDPatrol_QuestGiverTest.yaml','r6/tweaks/NCPDPatrol_OffTheBooks.yaml',
    *('archive/pc/mod/'+name+suffix for name in ('NCPDPatrol_QuestGiverTest','NCPDPatrol_OffTheBooks')
      for suffix in ('.archive','.archive.xl')),
}
EDITED={PREFIX+'init.lua',PREFIX+'cet_ui.lua','README.txt'}
FORBIDDEN_CONTENT=re.compile(
    r'NCPDPatrol(?:OffBooks|QuestGiverTest|Voss)|NCPDPatrol_(?:Voss|QG_)|\b(?:QuestGiver|OffBooks)\b|'
    r'quest_giver_test|off_the_books|ncpd_patrol_(?:qgiver|otb)|Mara Voss|Adrian Kessler',re.I)


def sha(body):return hashlib.sha256(body).hexdigest()


def original_payload():
    path=ROOT/'releases'/BASE
    assert sha(path.read_bytes())==BASE_SHA256
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None and len(z.namelist())==len(set(z.namelist()))==131
        files={name:z.read(name) for name in z.namelist()}
    assert EXCLUDED<=files.keys() and len(EXCLUDED)==14
    return files


def remove_block(text,start,end):
    pattern=r'^[ \t]*'+re.escape(start)+r'\n.*?^[ \t]*'+re.escape(end)+r'\n'
    text,count=re.subn(pattern,'',text,flags=re.M|re.S)
    assert count==1,(start,count)
    return text


def entrypoint(text):
    text=remove_block(text,'-- qgiver guard begin','-- qgiver guard end')
    text=remove_block(text,'-- qgiver setup begin','-- qgiver setup end')
    lines=text.splitlines(keepends=True)
    removed=[s for s in lines if re.search(r'-- (?:qgiver|offbooks) hook\s*$',s)]
    assert len(removed)==12,len(removed)
    text=''.join(s for s in lines if s not in removed)
    before='-- NCPD Patrol v0.20f1 Dialogue Handoff | speech events cover existing section tails'
    assert text.count(before)==1
    text=text.replace(before,'-- NCPD Patrol '+VERSION+' | Nexus patrol release')
    text,count=re.subn(r'^    status\("v0\.20f1 Dialogue Handoff loaded\.[^\n]+\n',
                      '    status("'+VERSION+' loaded. Patrol, dispatch, backup, arrests and career systems ready.")\n',text,flags=re.M)
    assert count==1
    assert not FORBIDDEN_CONTENT.search(text)
    return text


def menu(text):
    text=remove_block(text,'-- qgiver UI begin','-- qgiver UI end')
    before='NCPD Patrol - v0.20f1 Dialogue Handoff###NCPDPatrolWindow'
    assert text.count(before)==1
    text=text.replace(before,'NCPD Patrol - '+VERSION+'###NCPDPatrolWindow')
    assert not FORBIDDEN_CONTENT.search(text)
    return text


def payload():
    before=original_payload()
    files={name:body for name,body in before.items() if name not in EXCLUDED}
    files[PREFIX+'init.lua']=entrypoint(files[PREFIX+'init.lua'].decode()).encode()
    files[PREFIX+'cet_ui.lua']=menu(files[PREFIX+'cet_ui.lua'].decode()).encode()
    files['README.txt']=(ROOT/'tools/nexus/README.txt').read_bytes()
    files['CHANGELOG.txt']=(ROOT/'tools/nexus/CHANGELOG.txt').read_bytes()
    assert len(files)==118
    assert {name for name in files.keys()&before.keys() if files[name]!=before[name]}==EDITED
    return files


def materialize(files,root):
    root=Path(root)
    for name,body in files.items():
        path=root/name
        assert not Path(name).is_absolute() and '..' not in Path(name).parts
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(body)

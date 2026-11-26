"""Read this package's simple record declarations; no YAML dependency is added."""
from pathlib import Path
import re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]

def records(source=None):
    text=source if source is not None else (ROOT/'r6/tweaks/NCPDPatrol_OffTheBooks.yaml').read_text()
    result={};row=None
    for raw in text.splitlines():
        line=raw.split('# ',1)[0].rstrip()
        if not line.strip() or line.lstrip().startswith('#'):continue
        if not line.startswith(' '):
            assert line.endswith(':'),line
            name=line[:-1];assert name not in result,name
            row={};result[name]=row;continue
        key,value=line.strip().split(':',1);value=value.strip()
        if value.startswith('['):value=[v.strip() for v in value[1:-1].split(',') if v.strip()]
        elif value in ('true','false'):value=value=='true'
        elif re.fullmatch(r'-?\d+',value):value=int(value)
        elif re.fullmatch(r'-?\d+\.\d+',value):value=float(value)
        assert key not in row,key
        row[key]=value
    return result

def prepare(lua):
    data=records();actor=data['Character.NCPDPatrol_VossContractor01']
    drop=data[actor['lootDrop']];item=data[drop['lootItems'][0]]
    lua.globals().OTBDeathLoot=lua.table_from({'tableID':actor['lootDrop'],'table':drop,'entry':item},recursive=True)

from pathlib import Path
import json,re

def translate(path):
    source=Path(path).read_text()
    source=re.sub(r'//[^\n]*','',source)
    source=re.sub(r'\n\s*&&', ' &&', source)
    strings={}
    def quote(m):
        token=m.group()
        key=f'__STR{len(strings)}__'
        if token.startswith('s"'):
            text=token[2:-1]
            pieces=[]; start=0
            for match in re.finditer(r'\\\(([^()]*)\)',text):
                pieces.append(json.dumps(text[start:match.start()], ensure_ascii=False))
                pieces.append('tostring('+match.group(1).replace('this.','self.')+')')
                start=match.end()
            pieces.append(json.dumps(text[start:], ensure_ascii=False))
            strings[key]='('+' .. '.join(pieces)+')'
        else:
            strings[key]=token[1:] if token[0] in 'ntr' else token
        return key
    source=re.sub(r'(?:[sntr])?"(?:\\.|[^"\\])*"',quote,source)
    source=source[source.index('{')+1:source.rindex('}')]
    fields=[]
    def field(m):
        name,typ=m.groups(); fields.append((name,typ)); return ''
    source=re.sub(r'private\s+(?:persistent\s+)?let\s+(\w+)\s*:\s*([^;]+);',field,source)
    def function(m):
        name,params=m.groups()
        names=','.join(p.split(':')[0].strip().removeprefix('opt ').removeprefix('const ') for p in params.split(',') if p.strip())
        defaults=[]
        for p in params.split(','):
            if p.strip().startswith('opt '):
                param,typ=p.strip().removeprefix('opt ').removeprefix('const ').split(':',1)
                default={'Bool':'false','Float':'0.0','Int32':'0','String':'""'}.get(typ.strip(),'nil')
                if default!='nil': defaults.append(f'if {param.strip()} == nil '+'{ '+f'{param.strip()} = {default}; '+'};')
        return f'function Patrol:{name}({names}) '+'{ '+''.join(defaults)
    source=re.sub(r'(?:public|private)\s+(?:(?:static|const|final)\s+)*func\s+(\w+)\(([^)]*)\)\s*(?:->\s*[^\{]+)?\{',function,source)
    source=re.sub(r'pins\[i\]\s+as\s+PointOfInterestMappin',r'AsPointOfInterest(pins[i])',source)
    source=source.replace('pins[i].GetScriptData() as NCPDPatrolDispatchMappinData', 'AsDispatchMappinData(pins[i].GetScriptData())')
    source=source.replace('new NCPDPatrolDispatchMappinData()', 'NewDispatchMappinData()')
    source=source.replace('new NCPDPatrolNotice()', 'NewPatrolNotice()')
    source=re.sub(r'\s+as\s+\w+','',source)
    source=re.sub(r'\bnull\b','nil',source)
    source=re.sub(r'(IntEnum|Cast)<[^>]+>\(',r'\1(',source)
    source=re.sub(r'\b(\d+)u\b',r'\1',source)
    source=source.replace('!=','~=')
    source=re.sub(r'(__STR\d+__)\s+\+\s+', r'\1 .. ', source)
    source=source.replace('this.','self.').replace('&&',' and ').replace('||',' or ')
    source=re.sub(r'\bthis\b','self',source)
    source=re.sub(r'!(?!=)','not ',source)
    source=re.sub(r'\.(\w+)\(',r':\1(',source)
    source=source.replace('} else {','\nelse\n')
    source=source.replace('{','{\n').replace('}','\n}\n').replace(';',';\n')
    parts=re.split(r'([{};])',source)
    lines=[]
    string_locals=set()
    for i,part in enumerate(parts):
        part=part.strip()
        if not part or part==';':continue
        if part=='{':continue
        if part=='}':lines.append('end');continue
        for line in part.splitlines():
            line=line.strip()
            if not line:continue
            if line.startswith('function Patrol:'): string_locals=set()
            if line.startswith('let '):
                inferred=re.match(r'let\s+(\w+)\s*=\s*(.*)$',line)
                if inferred:
                    name,value=inferred.groups()
                    line=f'local {name} = {value}'
                    lines.append(line)
                    continue
                m=re.match(r'let\s+(\w+)\s*:\s*([\w<>]+)(?:\s*=\s*(.*))?$',line)
                assert m,line
                name,typ,value=m.groups()
                if typ=='String': string_locals.add(name)
                if value is None:
                    value='{n=0}' if typ.startswith('array') else ('{}' if typ in ('SimpleScreenMessage','OpenWorldActivityState','MappinData','NewMappinID') else 'nil')
                line=f'local {name} = {value}'
                if 'GetPointOfInterestMappinSavedState' in line:
                    assert line=='local found = system:GetPointOfInterestMappinSavedState(hash, phase, variant, active)',line
                    line='local found; found, phase, variant, active = system:GetPointOfInterestMappinSavedState(hash)'
            compound=re.match(r'(.*?)\s*([+-])=\s*(.*)',line)
            if compound:
                lhs,op,rhs=compound.groups()
                line=f'{lhs} = {lhs} {op} {rhs}'
            assignment=re.match(r'(?:local\s+)?(\w+)\s*=',line)
            if assignment and assignment.group(1) in string_locals:
                line=line.replace(' + ',' .. ')
            if '?' in line:
                m=re.match(r'(.+?=\s*)(.*?)\?\s*(.*?)\s*:\s*(.*)',line)
                assert m,line
                lhs,cond,yes,no=m.groups()
                line=f'{lhs}({cond} and {yes} or {no})'
            if line.startswith('if '):line+=' then'
            elif line.startswith('while '):line+=' do'
            lines.append(line)
    translated='local Patrol = {}\n'
    for name,typ in fields:
        value='{n=0}' if typ.startswith('array') else ('false' if typ=='Bool' else ('""' if typ=='String' else '0'))
        translated+=f'Patrol.{name} = {value}\n'
    translated+='\n'.join(lines)+'\nreturn Patrol'
    for key,value in strings.items():translated=translated.replace(key,value)
    return translated

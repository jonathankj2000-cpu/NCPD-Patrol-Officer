"""Limit original native owners to navigation-path indirection and reset fields."""
from pathlib import Path
import re,subprocess
BASE='a669ec8ea5e42ef99c4c035866e2803e8247d27a'

def methods(text):
    result={}
    for match in re.finditer(r'(?:public|private|protected)\s+(?:(?:static|cb|const|final)\s+)*func\s+(\w+)\([^\n]*?\)\s*(?:->[^\{]+)?\{',text):
        depth=1;pos=match.end()
        while depth:
            if text[pos]=='{':depth+=1
            if text[pos]=='}':depth-=1
            pos+=1
        result[match[1]]=text[match.start():pos]
    return result

def check_owners(root):
    basepaths={
        'DispatchJournal':{'ObjectivePath','DescriptionPath','OursTracked'},
        'Cyberpsycho':{'ResponsePath','ResponseDescriptionPath','ObjectivePath','DescriptionPath'},
        'VIP':{'ResponsePath','ResponseDescriptionPath','ObjectivePath','DescriptionPath'},
    }
    for kind,changed in basepaths.items():
        file=f'r6/scripts/NCPDPatrol/NCPDPatrol{kind}System.reds'
        old=subprocess.check_output(['git','show',f'{BASE}:{file}'],cwd=root,text=True)
        new=(root/file).read_text()
        for field in (['m_pickupSite','m_deliverySite'] if kind=='VIP' else ['m_navigationSite']):
            new=new.replace(f'private let {field}: Int32;','')
            new=new.replace(f'this.{field} = 0;','')
        before,after=methods(old),methods(new)
        assert set(after)-set(before)=={'GetNavigationSite','SelectNavigationSite'},kind
        assert not set(before)-set(after),kind
        for name in set(before)-changed:
            assert re.sub(r'\s+','',before[name])==re.sub(r'\s+','',after[name]),(kind,name)
        # No fields or persistent ledgers beyond the reviewed transient sites.
        fields=lambda text:re.findall(r'private\s+(?:persistent\s+)?let\s+\w+\s*:[^;]+;',text)
        assert fields(old)==fields(new),kind

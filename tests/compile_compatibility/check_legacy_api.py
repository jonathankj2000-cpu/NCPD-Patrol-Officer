"""Compatibility lint for errors observed in the v0.15c and r4 game logs.

The offline source checker uses a newer redscript front end. It accepts some
operators/import resolution that the user's in-game compiler rejected. These
guards reject those constructs before packaging; they are not a game-cache build.
"""
from pathlib import Path
import re,sys
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[2]

def compatibility_errors(source):
 # Remove comments and literals so labels/docs cannot trigger a code diagnostic.
 code=re.sub(r'((?:[sntr])?"(?:\\.|[^"\\])*")|//[^\n]*|/\*.*?\*/',' ',source,flags=re.S)
 bool_names=set(re.findall(r'\b(\w+)\s*:\s*Bool\b',code))|{'true','false'}
 bool_calls=set(re.findall(r'\bfunc\s+(\w+)\([^)]*\)\s*->\s*Bool\b',code))
 errors=[]
 # r4 failed in the actual game compiler: questNodeDefinition.id is Uint16,
 # while an untyped integer literal is Int32. The newer offline checker had
 # accepted that implicit narrowing, so require an explicit cast here.
 quest_nodes=set(re.findall(r'\blet\s+(\w+)\s*:\s*ref<quest\w*NodeDefinition>',code))
 for name in quest_nodes:
  if re.search(r'\b'+re.escape(name)+r'\.id\s*=\s*\d+[uU]?\s*;',code):
   errors.append('quest node id requires explicit Uint16 conversion: '+name)
 # Redscript's Equals/NotEquals intrinsics support Bool across the supported
 # game compiler versions; native ==/!= Bool overloads must not be assumed.
 for name in bool_names:
  if re.search(r'\b'+re.escape(name)+r'\s*(?:==|!=)|(?:==|!=)\s*'+re.escape(name)+r'\b',code):
   errors.append('native comparison on Bool '+name)
 for name in bool_calls:
  if re.search(r'\b'+re.escape(name)+r'\([^()\n]*\)\s*(?:==|!=)|(?:==|!=)\s*(?:this\.)?'+re.escape(name)+r'\(',code):
   errors.append('native comparison on Bool return '+name)
 if re.search(r'\.ShowPopup\s*\(',code):
  # Older game compilers resolve ShowPopup's CustomPopup parameter in the
  # caller's import scope. Importing CustomPopupManager alone is insufficient.
  imports=set(re.findall(r'\bimport\s+Codeware\.UI\.(\w+|\*)',code))
  if not ({'*','CustomPopup'} & imports):
   errors.append('ShowPopup requires CustomPopup in caller import scope')
 return errors

def main():
 # Negative/positive controls model the actual rejected source constructs, not
 # an engine stub that silently accepts the unsupported comparison/import.
 assert compatibility_errors('func Read(wanted: Bool) -> Bool { return wanted != this.WantsReady(); }')
 assert compatibility_errors('func Read(wanted: Bool) -> Bool { return this.IsReady(actor) == wanted; }')
 assert compatibility_errors('import Codeware.UI.CustomPopupManager\nmanager.ShowPopup(popup);')
 assert not compatibility_errors('func Read(wanted: Bool) -> Bool { return NotEquals(wanted, this.WantsReady()); }')
 assert not compatibility_errors('import Codeware.UI.*\nmanager.ShowPopup(popup);')
 assert not compatibility_errors('import Codeware.UI.CustomPopup\nmanager.ShowPopup(popup);')
 rejected='let node: ref<questMappinManagerNodeDefinition> = new questMappinManagerNodeDefinition(); node.id = 0;'
 assert compatibility_errors(rejected)
 assert not compatibility_errors(rejected.replace('node.id = 0;', 'node.id = Cast<Uint16>(0);'))
 failures=[]
 paths=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 for path in paths:
  failures.extend(path.name+': '+error for error in compatibility_errors(path.read_text()))
 assert not failures,'\n'.join(failures)
 print(f'PASS: {len(paths)} scripts checked for observed Bool-operator, popup-import and quest-node Uint16 incompatibilities (lint, not a game-cache compile)')
if __name__=='__main__':main()

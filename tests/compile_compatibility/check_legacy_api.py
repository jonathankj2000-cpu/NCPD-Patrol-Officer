"""Compatibility lint for errors observed in the supplied game logs.

The offline source checker uses a newer redscript front end. It accepts some
operators/import resolution that the user's in-game compiler rejected. These
guards reject those constructs before packaging; they are not a game-cache build.
"""
from pathlib import Path
import re,sys
ROOT=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[2]

def compatibility_errors(source):
 # Retain a typed placeholder for String literals. Names, resource paths and
 # TweakDBID literals have different operator contracts and stay excluded.
 string_literal='__compat_string_literal__'
 def scrub(match):
  token=match[1]
  return string_literal if token and token[0] not in 'ntr' else ' '
 code=re.sub(r'((?:[sntr])?"(?:\\.|[^"\\])*")|//[^\n]*|/\*.*?\*/',scrub,source,flags=re.S)
 bool_names=set(re.findall(r'\b(\w+)\s*:\s*Bool\b',code))|{'true','false'}
 bool_calls=set(re.findall(r'\bfunc\s+(\w+)\([^)]*\)\s*->\s*Bool\b',code))
 errors=[]
 # v0.18e failed in the user's game cache: Dispose appears in engine/RTTI
 # references, but is not a callable REDscript method on VehicleObject.
 if re.search(r'\.\s*Dispose\s*\(',code):
  errors.append('Dispose is unavailable in the observed REDscript game cache')
 if re.search(r'\bnative\s+func\s+Dispose\s*\(',code):
  errors.append('Do not invent a REDscript Dispose import from engine/RTTI references')
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
 # v0.20a failed on the user's actual game compiler: String == String has
 # no supported OperatorEqual overload. The newer offline front end accepts
 # it, so reject the construct here and require Equals/NotEquals intrinsics.
 string_calls=set(re.findall(r'\bfunc\s+(\w+)\([^)]*\)\s*->\s*String\b',code))
 fields=set(re.findall(r'\b(?:private|public)\s+(?:persistent\s+)?let\s+(\w+)\s*:\s*String\b',code))
 scopes=[]
 for match in re.finditer(r'\bfunc\s+\w+\([^)]*\)(?:\s*->\s*[^;{}]+)?\s*\{',code):
  depth=1;end=match.end()
  while end<len(code) and depth:
   depth+=(code[end]=='{')-(code[end]=='}');end+=1
  scopes.append(code[match.start():end])
 for scope in scopes or [code]:
  # Local names can have different types in different methods (e.g. rank
  # String in a caption method, rank Int32 in a reward method).
  string_names=set(re.findall(r'\b(\w+)\s*:\s*String\b',scope))|fields|{string_literal}
  for name in string_names:
   if re.search(r'\b'+re.escape(name)+r'\s*(?:==|!=)|(?:==|!=)\s*'+re.escape(name)+r'\b',scope):
    errors.append('native comparison on String '+name)
  for name in string_calls:
   if re.search(r'\b'+re.escape(name)+r'\([^()\n]*\)\s*(?:==|!=)|(?:==|!=)\s*(?:this\.)?'+re.escape(name)+r'\(',scope):
    errors.append('native comparison on String return '+name)
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
 assert compatibility_errors('vehicle.Dispose();')
 assert compatibility_errors('@addMethod(Entity) public final native func Dispose() -> Void;')
 assert not compatibility_errors('// vehicle.Dispose();\nlet note: String = "vehicle.Dispose()";')
 assert compatibility_errors('func Read(path: String) -> Bool { return path == "evidence"; }')
 assert compatibility_errors('func Read(path: String) -> Bool { return "evidence" != path; }')
 assert compatibility_errors('func Read() -> Bool { return "one" == "two"; }')
 assert not compatibility_errors('func Read(path: String) -> Bool { return Equals(path, "evidence"); }')
 assert not compatibility_errors('func Read(path: String) -> Bool { return NotEquals("evidence", path); }')
 assert not compatibility_errors('// path == "text"\nlet note: String = "path == text";')
 assert not compatibility_errors('let item: TweakDBID; return item == t"Items.evidence";')
 assert not compatibility_errors('let actor: ref<GameObject>; return actor != null;')
 assert not compatibility_errors('let count: Int32; return count == 1;')
 assert not compatibility_errors('func Caption() -> Void { let rank: String = "Officer"; }\nfunc Issue(rank: Int32) -> Bool { return rank == 1; }')
 # Re-run the exact rejected production version as a negative control, so
 # this is tied to the observed failure rather than only toy expressions.
 import subprocess
 old=subprocess.check_output(['git','show','720ea85924a52fbc2eb98c54ad62349c7057eaf1:r6/scripts/NCPDPatrol/NCPDPatrolOffBooksSystem.reds'],cwd=ROOT,text=True)
 assert 'ReadAction.GetJournalEntryFromAction(read.GetID()) == this.ShardPath()' in old
 assert any('String' in error for error in compatibility_errors(old))
 assert not compatibility_errors(old.replace('ReadAction.GetJournalEntryFromAction(read.GetID()) == this.ShardPath()',
  'Equals(ReadAction.GetJournalEntryFromAction(read.GetID()), this.ShardPath())'))
 contract=(ROOT/'tests/officer_down/native-api.reds').read_text()
 assert not compatibility_errors(contract),'Offline contract reintroduced the invalid Dispose import'
 failures=[]
 paths=sorted((ROOT/'r6/scripts/NCPDPatrol').glob('*.reds'))
 for path in paths:
  failures.extend(path.name+': '+error for error in compatibility_errors(path.read_text()))
 assert not failures,'\n'.join(failures)
 print(f'PASS: {len(paths)} scripts checked for observed Bool/String-operator, popup-import, quest-node Uint16 and unavailable REDscript Dispose errors; exact v0.20a String comparison rejected (lint, not a game-cache compile)')
if __name__=='__main__':main()

"""Compile the actual timer getter against the game's CeilF -> Int32 contract.

Uses the local ncpd-check compiler API driver (contract files, --, source files).
Pass its path as the first argument; an optional second argument is the mod root.
This is a native-signature check, not compilation against a game script cache.
"""
from pathlib import Path
import re, subprocess, sys, tempfile
HERE=Path(__file__).resolve().parent
compiler=Path(sys.argv[1]).resolve()
root=Path(sys.argv[2]).resolve() if len(sys.argv)>2 else HERE.parents[1]
source=(root/'r6/scripts/NCPDPatrol/NCPDPatrolTrunkSystem.reds').read_text()
m=re.search(r'public func GetRepairSeconds\(\) -> Int32 \{',source)
assert m
body=source.index('{',m.start()); end=body+1; depth=1
while depth:
 depth+=(source[end]=='{')-(source[end]=='}'); end+=1
method=source[m.start():end]
with tempfile.TemporaryDirectory(prefix='ncpd-ceil-type-') as scratch:
 p=Path(scratch)/'TimerGetter.reds'
 prefix='public class TimerGetter extends IScriptable {\nprivate let m_repairPending: Bool;\nprivate let m_repairElapsed: Float;\n'
 p.write_text(prefix+method+'\n}')
 args=[str(compiler),str(HERE/'ceilf-contract.reds'),'--',str(p)]
 result=subprocess.run(args,text=True,capture_output=True)
 assert result.returncode==0,result.stdout+result.stderr
 bad=method.replace('return CeilF(10.0 - this.m_repairElapsed);','return Cast<Int32>(CeilF(10.0 - this.m_repairElapsed));')
 assert bad!=method
 p.write_text(prefix+bad+'\n}')
 result=subprocess.run(args,text=True,capture_output=True)
 assert result.returncode!=0,'The known v0.8a invalid cast unexpectedly compiled'
 assert 'TYPE_ERR' in result.stderr or 'UNRESOLVED_FN' in result.stderr,result.stderr
print('PASS: actual timer getter compiles with CeilF -> Int32; original v0.8a cast is rejected by the same compiler/signature')

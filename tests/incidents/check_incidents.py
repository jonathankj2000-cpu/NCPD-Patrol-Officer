"""Execute actual generated-quest, reward, career and mixed-dispatch logic.

Only engine objects, transactions, save restoration and presentation are mocked.
"""
from pathlib import Path
import re,sys
from lupa.luajit21 import LuaRuntime
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'arrests'))
from translate import translate
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute((HERE.parent/'arrests/mappin-native-mocks.lua').read_text())
for name,alias in [('NCPDPatrolIncidentSystem','IncidentNative'),('NCPDPatrolCyberpsychoSystem','CyberNative'),('NCPDPatrolDispatchJournalSystem','DispatchJournalNative'),('NCPDPatrolVIPSystem','VIPNative'),('NCPDPatrolCareerSystem','CareerNative')]:
 lua.globals()[alias]=lua.execute(translate(ROOT/'r6/scripts/NCPDPatrol'/f'{name}.reds'))
lua.execute((HERE.parent/'dispatch_journal/native-mocks.lua').read_text())
lua.execute((HERE.parent/'cyberpsycho/native-mocks.lua').read_text())
lua.globals().MOD_DIR=str(ROOT/'bin/x64/plugins/cyber_engine_tweaks/mods/NCPDPatrol')
lua.execute('package.path=MOD_DIR.."/?.lua;"..package.path')
lua.execute((HERE.parent/'vip/native-mocks.lua').read_text())
lua.execute((HERE/'engine-mocks.lua').read_text())
lua.execute((HERE/'native-scenarios.lua').read_text())
lua.execute((HERE/'mixed-scenarios.lua').read_text())
lua.execute((HERE/'background-scenarios.lua').read_text())
source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolIncidentSystem.reds').read_text()
for field in ['m_serial','m_completedIds','m_completedKinds','m_completedAmounts','m_paidIds']:
 assert re.search(r'private persistent let '+field+r'\s*:',source),field
assert all(name not in source for name in ['m_paidActivities','m_paidSuspects','SetFact'])
print('PASS: actual VIP 2000 / cyberpsycho 3000+500 non-lethal outcomes; one career incident, duplicate/cancel/stale/load/failure guards, persistent unique IDs and payment retries, delayed receipts, preserved scanner/arrest records; authored 50/30/20 mix/fallback; automatic resume after VIP with/without retained ambush, concurrent standby, paused gates and refused/deferred cleanup (engine APIs mocked)')

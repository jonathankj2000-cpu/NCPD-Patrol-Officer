"""Load pinned BEF reference sources for tests only; never bundled in the mod."""
from pathlib import Path
import hashlib,os,tempfile,urllib.request
REPO='GreenManNK/Cyberpunk-2077-mod'
COMMIT='e2012d2d7778e5101526f9e7115708d2159e6c35'
FILES={'BrowserExtension.Classes.reds':'933d329d4872133bd705017392d8d739db2657f5',
       'BrowserExtension.System.reds':'22560810fec53bf0b16240623fa76e383b336b6d',
       'BrowserExtension.DataStructures.reds':'c4d5540e50845b955be3104f0ca54e45667656ab'}
def sources():
 folder=Path(os.environ.get('NCPD_BEF_SOURCE',Path(tempfile.gettempdir())/'ncpd-bef-reference'))
 folder.mkdir(parents=True,exist_ok=True)
 result={}
 for name,sha in FILES.items():
  path=folder/name
  if not path.exists():
   url=f'https://raw.githubusercontent.com/{REPO}/{COMMIT}/r6/scripts/BrowserExtension/{name}'
   with urllib.request.urlopen(url,timeout=30) as response:path.write_bytes(response.read())
  data=path.read_bytes();blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
  assert blob==sha,f'BEF reference changed: {name}'
  result[name]=data.decode()
 return result

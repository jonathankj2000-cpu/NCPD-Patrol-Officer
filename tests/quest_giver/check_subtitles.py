"""Execute the actual six-turn subtitle wrapper and native callback code.

Engine UI/delay are recording boundaries, not a game rendering/voice test.
"""
from pathlib import Path
import argparse,json,re,subprocess,sys,tempfile
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));import build_quest_giver_assets as assets
sys.path.insert(0,str(ROOT/'tests/arrests'));from translate import translate

def main():
    c=assets.read('contract.json');npcs=[t for t in c['conversation'] if t['speaker']=='voss']
    source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds').read_text();assert source==assets.subtitle_controller(c)
    docs,_=assets.outputs();assets.validate(docs)
    entries=docs['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries'];texts={e['secondaryKey']:e['femaleVariant'] for e in entries};assert all(e['femaleVariant']==e['maleVariant'] for e in entries)
    for row in npcs:
        assert ' '.join(p['text'] for p in row['subtitle_parts'])==row['text']
        assert texts['NCPDPatrol_QG_'+row['key']+'_Full']==row['text']
    # The new conversation changes its scene/text/media, while keeping phone
    # history, quest graph and grounded body helper exactly as in v0.19f1.
    base='59fb2d4898d59909a9540af500bad390815ecab0'
    for name in ['voss_wait_pose.ent.json','sms-templates.json']:
        path='assets/quest_giver_test/'+name
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',f'{base}:{path}'],cwd=ROOT)
    old=json.loads(subprocess.check_output(['git','show',f'{base}:assets/quest_giver_test/contract.json'],cwd=ROOT));assert c['sms']==old['sms'] and c['presentation']==old['presentation']
    head,callback=source.split('public class NCPDPatrolVossSubtitleStep extends DelayCallback',1)
    head=re.sub(r'@(?:addField|wrapMethod|addMethod)\(SubtitleLineLogicController\)\s*','',head)
    head=head.replace('data.speaker as NPCPuppet','AsNPC(data.speaker)').replace('this.m_lineData.speaker as NPCPuppet','AsNPC(this.m_lineData.speaker)')
    head=head.replace('wrappedMethod(', 'WrappedMethod(this, ').replace('new NCPDPatrolVossSubtitleStep()', 'NewSubtitleStep()')
    lua=LuaRuntime(unpack_returned_tuples=True)
    with tempfile.TemporaryDirectory(prefix='ncpd-voss-subtitles-') as d:
        p=Path(d)/'fixture.reds';p.write_text('public class Fixture extends IScriptable {\n'+head+'\n}');lua.globals().Subtitle=lua.execute(translate(p))
        p.write_text('public class Callback extends DelayCallback'+callback);lua.globals().Step=lua.execute(translate(p))
    lua.globals().Localized=lua.table_from(texts);lua.globals().Turns=lua.table_from(npcs,recursive=True)
    lua.globals().SubtitleDelay=c['timing']['subtitle_delay_ms']/1000
    lua.execute('''
        function IsDefined(x) return type(x)=='table' and not x.destroyed end
        function AsNPC(x) if IsDefined(x) and x.kind=='npc' then return x end end
        function Equals(a,b) return a==b end
        function Deref(d) local out={};for k,v in pairs(d) do out[k]=v end;return out end
        function GetLocalizedTextByKey(key) return assert(Localized[key],key) end
        function WrappedMethod(self,data)
            self.originalCalls=self.originalCalls+1;self.m_lineData=Deref(data);self.m_targetTextWidgetRef.text=data.text
        end
        inkTextRef={SetText=function(_,widget,text) widget.text=text;widget.writes=widget.writes+1 end}
        GameInstance={GetQuestsSystem=function(_,game) return game end,GetDelaySystem=function(_,game) return game end}
        function NewSubtitleStep() return setmetatable({}, {__index=Step}) end
        function Fixture(row)
            local game={stage=2,now=0,pending={},paused=false}
            function game:GetFactStr(name) assert(name=='ncpd_patrol_qgiver_test_stage');return self.stage end
            function game:DelayCallback(cb,delay,dilation) assert(not dilation);self.pending[#self.pending+1]={cb=cb,at=self.now+delay} end
            function game:advance(seconds)
                if self.paused then return end
                self.now=self.now+seconds
                for _,q in ipairs(self.pending) do if not q.done and q.at<=self.now then q.done=true;q.cb:Call() end end
            end
            local actor={kind='npc',attached=true,record='Character.NCPDPatrol_QG_Investigator'}
            function actor:IsAttached() return self.attached end
            function actor:GetRecordID() return self.record end
            function actor:GetGame() return game end
            local ui=setmetatable({originalCalls=0,m_targetTextWidgetRef={writes=0}}, {__index=Subtitle})
            local data={id='original-line-id',text=row.text,speaker=actor,speakerName='Lt. Mara Voss',duration=row.audio_seconds,type='Regular',isPersistent=false}
            return game,actor,ui,data
        end
        for _,row in ipairs(Turns) do
            local game,actor,ui,data=Fixture(row);ui:SetLineData(data)
            assert(ui.originalCalls==1 and ui.m_targetTextWidgetRef.text==row.subtitle_parts[1].text)
            assert(data.text==row.text and ui.m_lineData.id==data.id and ui.m_lineData.duration==data.duration)
            assert(ui.m_lineData.speaker==actor and ui.m_lineData.type==data.type and ui.m_lineData.speakerName==data.speakerName)
            assert(#game.pending==#row.subtitle_parts-1)
            for i=2,#row.subtitle_parts do
                local part=row.subtitle_parts[i];local at=part.start_seconds+SubtitleDelay
                assert(math.abs(game.pending[i-1].at-at)<.00001)
                game:advance(at-game.now-.01);assert(ui.m_targetTextWidgetRef.text==row.subtitle_parts[i-1].text)
                game.paused=true;game:advance(60);assert(ui.m_targetTextWidgetRef.text==row.subtitle_parts[i-1].text)
                game.paused=false;game:advance(.02);assert(ui.m_targetTextWidgetRef.text==part.text)
            end
            game:advance(60);assert(ui.originalCalls==1 and ui.m_targetTextWidgetRef.writes==#row.subtitle_parts-1)
            for _,case in ipairs({'npc','player','missing','other-line','inactive','completed','detached'}) do
                game,actor,ui,data=Fixture(row)
                if case=='npc' then actor.record='Character.Other' end
                if case=='player' then actor.kind='player' end
                if case=='missing' then data.speaker=nil end
                if case=='other-line' then data.text='Unrelated dialogue' end
                if case=='inactive' then game.stage=0 end
                if case=='completed' then game.stage=3 end
                if case=='detached' then actor.attached=false end
                ui:SetLineData(data);assert(ui.originalCalls==1 and ui.m_targetTextWidgetRef.text==data.text and #game.pending==0,case)
            end
            for _,case in ipairs({'reuse','cancel','complete','detach','destroy'}) do
                game,actor,ui,data=Fixture(row);ui:SetLineData(data)
                if case=='reuse' then local d=Deref(data);d.text='V original reply';ui:SetLineData(d) end
                if case=='cancel' then game.stage=0 end
                if case=='complete' then game.stage=3 end
                if case=='detach' then actor.attached=false end
                if case=='destroy' then ui.destroyed=true end
                local before=ui.m_targetTextWidgetRef.text;game:advance(60)
                assert(ui.m_targetTextWidgetRef.text==before and ui.m_targetTextWidgetRef.writes==0,case)
            end
        end
        -- Reuse one widget for two different Voss turns. The earlier line's
        -- timers cannot inject an old caption into the new speech.
        local first,second=Turns[1],Turns[6]
        local game,actor,ui,data=Fixture(first);ui:SetLineData(data)
        local oldCallbacks=game.pending
        local nextData=Deref(data);nextData.text=second.text;nextData.duration=second.audio_seconds
        ui:SetLineData(nextData)
        for i=1,#first.subtitle_parts-1 do oldCallbacks[i].cb:Call() end
        assert(ui.m_targetTextWidgetRef.text==second.subtitle_parts[1].text and ui.m_targetTextWidgetRef.writes==0)
        game:advance(60);assert(ui.m_targetTextWidgetRef.text==second.subtitle_parts[#second.subtitle_parts].text)
    ''')
    parts={t['key']:t['subtitle_parts'] for t in npcs}
    result={'subtitle_parts':parts,'subtitle_delay_ms':c['timing']['subtitle_delay_ms'],'voss_turns':6,'caption_blocks':sum(len(v) for v in parts.values()),'complete_original_media_per_turn':True,'native_ui_wrapper_executed':True,'original_method_once_per_line':True,'exact_private_actor_text_stage_scope':True,'line_metadata_and_duration_preserved':True,'stale_reuse_cancel_completion_detach_and_destroy_guards':True,'native_font_speaker_and_settings_retained':True,'actual_game_validation':False,'native_delay_pause_and_rendering_require_game_check':True}
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args()
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: actual six-turn Voss subtitle wrapper/callback: 19 complete timed blocks, delayed switches, native method once, unchanged line identity/duration; exact actor/text/stage scope, native V fallthrough, stale callbacks across different speech turns/reuse/cancel/completion/detach/destroy (native UI/delay boundaries mocked)')

if __name__=='__main__':main()

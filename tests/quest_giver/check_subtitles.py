"""Execute the actual subtitle wrapper/callback; native UI/delay are boundaries.

The existing scene/audio/lipsync payload is compared with the preceding build.
This is not an in-game subtitle/rendering test.
"""
from pathlib import Path
import argparse,json,re,subprocess,sys,tempfile
from lupa.luajit21 import LuaRuntime

ROOT=Path(__file__).resolve().parents[2]
BASE='6605d15f0a5f251ef89024dac66f54f0a0b4e5c5'
sys.path.insert(0,str(ROOT/'tools'))
import build_quest_giver_assets as assets
sys.path.insert(0,str(ROOT/'tests/arrests'))
from translate import translate

def main():
    c=assets.read('contract.json');parts=c['briefing']['subtitle_parts']
    source=(ROOT/'r6/scripts/NCPDPatrol/NCPDPatrolVossSubtitles.reds').read_text()
    assert source==assets.subtitle_controller(c)
    assert len(parts)==3 and ' '.join(p['text'] for p in parts)==c['briefing']['text']
    assert [p['start_seconds'] for p in parts]==[0,15.0,28.5]
    docs,_=assets.outputs();assets.validate(docs)
    entries=docs['onscreens.json.json']['Data']['RootChunk']['root']['Data']['entries']
    texts={e['secondaryKey']:e['femaleVariant'] for e in entries}
    assert all(e['femaleVariant']==e['maleVariant'] for e in entries)
    assert texts['NCPDPatrol_QG_BriefingFull']==c['briefing']['text']
    assert [texts['NCPDPatrol_QG_BriefingPart'+str(i)] for i in [1,2,3]]==[p['text'] for p in parts]
    # Rebuilding the archive must not change the single native speech event,
    # the scene graph, phone intro, body workspot or any original media.
    unchanged=['conversation.scene.json','quest_giver.questphase.json','quest_giver.journal.json',
        'lines.json.json','subtitles.json.json','vomap.json.json','voss.lipmap.json','voss_wait_pose.ent.json',
        'media/voss_briefing.wem','media/voss_briefing.anims']
    for name in unchanged:
        path='assets/quest_giver_test/'+name
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT),name
    for path in subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'--','r6/scripts/NCPDPatrol'],cwd=ROOT,text=True).splitlines():
        assert (ROOT/path).read_bytes()==subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT),path
    # Translate only actual authored method bodies; adapt casts, constructors
    # and the wrap intrinsic at their native boundaries, not the policy.
    head,callback=source.split('public class NCPDPatrolVossSubtitleStep extends DelayCallback',1)
    head=re.sub(r'@(?:addField|wrapMethod|addMethod)\(SubtitleLineLogicController\)\s*','',head)
    head=head.replace('data.speaker as NPCPuppet','AsNPC(data.speaker)').replace('this.m_lineData.speaker as NPCPuppet','AsNPC(this.m_lineData.speaker)')
    head=head.replace('wrappedMethod(', 'WrappedMethod(this, ').replace('new NCPDPatrolVossSubtitleStep()', 'NewSubtitleStep()')
    lua=LuaRuntime(unpack_returned_tuples=True)
    with tempfile.TemporaryDirectory(prefix='ncpd-voss-subtitles-') as d:
        p=Path(d)/'fixture.reds';p.write_text('public class Fixture extends IScriptable {\n'+head+'\n}')
        lua.globals().Subtitle=lua.execute(translate(p))
        p.write_text('public class Callback extends DelayCallback'+callback)
        lua.globals().Step=lua.execute(translate(p))
    lua.globals().Localized=lua.table_from(texts)
    lua.globals().Full=c['briefing']['text']
    lua.execute('''
        function IsDefined(x) return type(x)=='table' and not x.destroyed end
        function AsNPC(x) if IsDefined(x) and x.kind=='npc' then return x end end
        function Equals(a,b) return a==b end
        function Deref(d) local out={};for k,v in pairs(d) do out[k]=v end;return out end
        function GetLocalizedTextByKey(key) return assert(Localized[key],key) end
        function WrappedMethod(self,data)
            self.originalCalls=self.originalCalls+1
            self.m_lineData=Deref(data)
            self.m_targetTextWidgetRef.text=data.text
            self.rendered[#self.rendered+1]=data.text
        end
        inkTextRef={SetText=function(_,widget,text) widget.text=text;widget.writes=widget.writes+1 end}
        GameInstance={GetQuestsSystem=function(_,game) return game end,
            GetDelaySystem=function(_,game) return game end}
        function NewSubtitleStep() return setmetatable({}, {__index=Step}) end
        function Fixture()
            local game={stage=2,now=0,pending={},paused=false}
            function game:GetFactStr(name) assert(name=='ncpd_patrol_qgiver_test_stage');return self.stage end
            function game:DelayCallback(cb,delay,dilation)
                assert(dilation==false);self.pending[#self.pending+1]={cb=cb,at=self.now+delay}
            end
            function game:advance(seconds)
                if self.paused then return end
                self.now=self.now+seconds
                for _,row in ipairs(self.pending) do if not row.done and row.at<=self.now then row.done=true;row.cb:Call() end end
            end
            local actor={kind='npc',attached=true,record='Character.NCPDPatrol_QG_Investigator'}
            function actor:IsAttached() return self.attached end
            function actor:GetRecordID() return self.record end
            function actor:GetGame() return game end
            local ui=setmetatable({originalCalls=0,rendered={},m_targetTextWidgetRef={writes=0}}, {__index=Subtitle})
            local data={id='original-line-id',text=Full,speaker=actor,speakerName='Lt. Mara Voss',duration=41.967,type='Regular',isPersistent=false}
            return game,actor,ui,data
        end
        function Part(i) return Localized['NCPDPatrol_QG_BriefingPart'..i] end
        local game,actor,ui,data=Fixture()
        ui:SetLineData(data)
        assert(ui.originalCalls==1 and ui.m_targetTextWidgetRef.text==Part(1))
        assert(data.text==Full and ui.m_lineData.id==data.id and ui.m_lineData.duration==data.duration)
        assert(ui.m_lineData.speaker==actor and ui.m_lineData.type==data.type and ui.m_lineData.speakerName==data.speakerName)
        assert(#game.pending==2 and game.pending[1].at==15.0 and game.pending[2].at==28.5)
        game:advance(14.99);assert(ui.m_targetTextWidgetRef.text==Part(1))
        game.paused=true;game:advance(60);assert(ui.m_targetTextWidgetRef.text==Part(1))
        game.paused=false;game:advance(.02);assert(ui.m_targetTextWidgetRef.text==Part(2))
        game:advance(13.48);assert(ui.m_targetTextWidgetRef.text==Part(2))
        game:advance(.02);assert(ui.m_targetTextWidgetRef.text==Part(3))
        game:advance(60);assert(ui.originalCalls==1 and ui.m_targetTextWidgetRef.writes==2)
        -- Exact text, actor, attachment and quest-stage scope; unrelated calls
        -- retain their original data and schedule no callbacks.
        for _,case in ipairs({'npc','vehicle','missing','hello','option','inactive','completed','detached'}) do
            game,actor,ui,data=Fixture()
            if case=='npc' then actor.record='Character.Other' end
            if case=='vehicle' then actor.kind='vehicle' end
            if case=='missing' then data.speaker=nil end
            if case=='hello' then data.text='quest giver hello' end
            if case=='option' then data.text='option 1' end
            if case=='inactive' then game.stage=0 end
            if case=='completed' then game.stage=3 end
            if case=='detached' then actor.attached=false end
            ui:SetLineData(data)
            assert(ui.originalCalls==1 and ui.m_targetTextWidgetRef.text==data.text and #game.pending==0,case)
        end
        -- Reused widgets, cancelled/completed scenes, detached speakers and
        -- destroyed controllers must ignore old delayed writes.
        for _,case in ipairs({'reuse','cancel','complete','detach','destroy','new-generation'}) do
            game,actor,ui,data=Fixture();ui:SetLineData(data)
            if case=='reuse' then local nextData=Deref(data);nextData.text='Another subtitle';ui:SetLineData(nextData) end
            if case=='cancel' then game.stage=0 end
            if case=='complete' then game.stage=3 end
            if case=='detach' then actor.attached=false end
            if case=='destroy' then ui.destroyed=true end
            if case=='new-generation' then game:advance(1);ui:SetLineData(data) end
            local prior=ui.m_targetTextWidgetRef.text
            if case=='new-generation' then
                game:advance(14.01);assert(ui.m_targetTextWidgetRef.text==Part(1))
                game:advance(1);assert(ui.m_targetTextWidgetRef.text==Part(2))
            else game:advance(50);assert(ui.m_targetTextWidgetRef.text==prior and ui.m_targetTextWidgetRef.writes==0,case) end
        end
    ''')
    result={'subtitle_parts':parts,'continuous_original_media_and_scene_unchanged':True,
        'native_ui_wrapper_executed':True,'original_method_once_per_line':True,
        'exact_private_actor_text_stage_scope':True,'line_metadata_and_duration_preserved':True,
        'stale_reuse_cancel_completion_detach_and_destroy_guards':True,
        'native_font_speaker_and_settings_retained':True,'actual_game_validation':False,
        'native_delay_pause_and_rendering_require_game_check':True}
    parser=argparse.ArgumentParser();parser.add_argument('--report',type=Path);args=parser.parse_args()
    if args.report:args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('PASS: actual Voss subtitle wrapper/callback: three complete timed blocks, native method once, unchanged line identity/duration and continuous scene/voice/lipsync; exact actor/text/stage scope, stale widget/reuse/cancel/completion/detach/destroy guards (native UI/delay boundaries mocked; game timing unverified)')

if __name__=='__main__':main()

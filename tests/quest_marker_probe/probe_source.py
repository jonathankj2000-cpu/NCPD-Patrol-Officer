"""Remove only the explicitly reviewed r4 opt-in hooks for earlier oracles."""
import re

def without_offbooks_encounter(source):
    source=source.replace('-- NCPD Patrol v0.20c Off the Books Encounter | scoped combat and native corpse loot refresh','-- NCPD Patrol v0.20b Voss Continuation | durable briefing receipt and pending journal activation')
    source=source.replace('v0.20c Off the Books Encounter loaded. Restaurant-scoped Tier2 exception and native corpse loot refresh; Voss conversation retained. Install the complete package and fully restart the game.','v0.20b Voss Continuation loaded. Completed briefing is retained independently of delayed journal state; Off the Books retries activation and keeps Voss. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.20c Off the Books Encounter###','NCPD Patrol - v0.20b Voss Continuation###')

def without_offbooks_handoff(source):
    source=without_offbooks_encounter(source)
    source=source.replace('-- NCPD Patrol v0.20b Voss Continuation | durable briefing receipt and pending journal activation','-- NCPD Patrol v0.20a1 Startup Fix | compatible readable-path comparison')
    source=source.replace('v0.20b Voss Continuation loaded. Completed briefing is retained independently of delayed journal state; Off the Books retries activation and keeps Voss. Install the complete package and fully restart the game.','v0.20a1 Startup Fix loaded. Off the Books readable-path comparison corrected for the game compiler. Existing quest, actors, shard and Voss conversation retained. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.20b Voss Continuation###','NCPD Patrol - v0.20a1 Startup Fix###')
    return source.replace('onBriefingComplete=function() return OffBooks.continueAfterBriefing() end,','onBriefingComplete=function() OffBooks.begin(status) end,')

def without_offbooks_compile_fix(source):
    source=without_offbooks_handoff(source)
    source=source.replace('-- NCPD Patrol v0.20a1 Startup Fix | compatible readable-path comparison','-- NCPD Patrol v0.20a Off the Books | off-duty contractor, native evidence and retained Voss')
    source=source.replace('v0.20a1 Startup Fix loaded. Off the Books readable-path comparison corrected for the game compiler. Existing quest, actors, shard and Voss conversation retained. Install the complete package and fully restart the game.','v0.20a Off the Books loaded. OFF DUTY: Testing > Quest giver prototype. After the briefing: eliminate the contractor, loot his evidence shard, lose any pursuing NCPD and return to Voss. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.20a1 Startup Fix###','NCPD Patrol - v0.20a Off the Books###')

def without_offbooks(source):
    source=without_offbooks_compile_fix(source)
    source=source.replace('-- NCPD Patrol v0.20a Off the Books | off-duty contractor, native evidence and retained Voss','-- NCPD Patrol v0.19h1 Voss Idle Pose | one idle-only request for the existing workspot')
    source=source.replace('v0.20a Off the Books loaded. OFF DUTY: Testing > Quest giver prototype. After the briefing: eliminate the contractor, loot his evidence shard, lose any pursuing NCPD and return to Voss. Install the complete package and fully restart the game.','v0.19h1 Voss Idle Pose loaded. OFF DUTY: Testing > Quest giver prototype. Idle-only mode requested once for Voss after pose activation; v0.19h conversation and caption timing retained. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.20a Off the Books###','NCPD Patrol - v0.19h1 Voss Idle Pose###')
    source=re.sub(r'^.* -- offbooks hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^-- offbooks setup begin\n.*?^-- offbooks setup end\n','',source,flags=re.M|re.S)
    source=source.replace('end,\n-- offbooks callbacks begin','end\n-- offbooks callbacks begin')
    source=re.sub(r'^-- offbooks callbacks begin\n.*?^-- offbooks callbacks end\n','',source,flags=re.M|re.S)
    source=source.replace('end\n})\n-- qgiver setup end','end})\n-- qgiver setup end')
    source=re.sub(r'^            -- offbooks UI begin\n.*?^            -- offbooks UI end\n','',source,flags=re.M|re.S)
    return source

def without_location_exclusion(source):
    # Exact reviewed H10 eligibility addition only; historical traces retain
    # all other geography/RNG/actor policy. New target cases test the exclusion.
    source=source.replace('local LocationPolicy = require("dispatch_location_policy")\n','')
    source=source.replace('if metres>=500 and metres<=2000 and LocationPolicy.allowed(pin,point,true) then',
                          'if metres>=500 and metres<=2000 then')
    source=source.replace('if (variant==gamedataMappinVariant.FastTravelVariant\n                    or variant==gamedataMappinVariant.ServicePointDropPointVariant)\n                    and LocationPolicy.allowed(pin,point,variant==gamedataMappinVariant.FastTravelVariant) then',
                          'if variant==gamedataMappinVariant.FastTravelVariant\n                    or variant==gamedataMappinVariant.ServicePointDropPointVariant then')
    return source

def without_voss_idle_branding(source):
    source=without_offbooks(source)
    source=source.replace('-- NCPD Patrol v0.19h1 Voss Idle Pose | one idle-only request for the existing workspot','-- NCPD Patrol v0.19h Voss Timing | delayed captions and guarded automatic turns')
    source=source.replace('v0.19h1 Voss Idle Pose loaded. OFF DUTY: Testing > Quest giver prototype. Idle-only mode requested once for Voss after pose activation; v0.19h conversation and caption timing retained. Install the complete package and fully restart the game.','v0.19h Voss Timing loaded. Longer Voss turn windows and pauses; 19 subtitle blocks with later switches. Clear the old quest-giver test, install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19h1 Voss Idle Pose###','NCPD Patrol - v0.19h Voss Timing###')

def without_voss_timing_branding(source):
    source=without_voss_idle_branding(source)
    source=source.replace('-- NCPD Patrol v0.19h Voss Timing | delayed captions and guarded automatic turns','-- NCPD Patrol v0.19g1 Voss Scene ID Fix | packed screenplay IDs and canonical scene nodes')
    source=source.replace('v0.19h Voss Timing loaded. Longer Voss turn windows and pauses; 19 subtitle blocks with later switches. Clear the old quest-giver test, install the complete package and fully restart the game.','v0.19g1 Voss Scene ID Fix loaded. Corrected local dialogue type/index IDs and scene-node layout. Six-part Voss/V conversation, SMS, waiting pose and all media retained. Install the complete package, fully restart, and test from a save made before activating the previous Voss test.')
    return source.replace('NCPD Patrol - v0.19h Voss Timing###','NCPD Patrol - v0.19g1 Voss Scene ID Fix###')

def without_voss_scene_id_branding(source):
    source=without_voss_timing_branding(source)
    source=source.replace('-- NCPD Patrol v0.19g1 Voss Scene ID Fix | packed screenplay IDs and canonical scene nodes','-- NCPD Patrol v0.19g Voss Conversation | six voiced Voss turns and four automatic native V replies')
    source=source.replace('v0.19g1 Voss Scene ID Fix loaded. Corrected local dialogue type/index IDs and scene-node layout. Six-part Voss/V conversation, SMS, waiting pose and all media retained. Install the complete package, fully restart, and test from a save made before activating the previous Voss test.','v0.19g Voss Conversation loaded. OFF DUTY: Testing > Quest giver prototype. The meeting uses the supplied six-part Voss briefing, matching lipsync and four automatic original V replies. SMS and grounded waiting pose retained. Clear the old test, install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19g1 Voss Scene ID Fix###','NCPD Patrol - v0.19g Voss Conversation###')

def without_voss_conversation_branding(source):
    source=without_voss_scene_id_branding(source)
    source=source.replace('-- NCPD Patrol v0.19g Voss Conversation | six voiced Voss turns and four automatic native V replies','-- NCPD Patrol v0.19f1 Voss Pose Check Fix | retain the quest when pose confirmation is unavailable')
    source=source.replace('v0.19g Voss Conversation loaded. OFF DUTY: Testing > Quest giver prototype. The meeting uses the supplied six-part Voss briefing, matching lipsync and four automatic original V replies. SMS and grounded waiting pose retained. Clear the old test, install the complete package and fully restart the game.','v0.19f1 Voss Pose Check Fix loaded. OFF DUTY: Testing > Quest giver prototype. Native pose activity no longer requires a registered helper user; waiting-pose failures retain Voss, the car and the conversation quest. SMS, three subtitle blocks, voice and lipsync retained. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19g Voss Conversation###','NCPD Patrol - v0.19f1 Voss Pose Check Fix###')

def without_voss_pose_fix_branding(source):
    source=without_voss_conversation_branding(source)
    source=source.replace('-- NCPD Patrol v0.19f1 Voss Pose Check Fix | retain the quest when pose confirmation is unavailable','-- NCPD Patrol v0.19f Voss Subtitles | three timed blocks with continuous voice and lipsync')
    source=source.replace('v0.19f1 Voss Pose Check Fix loaded. OFF DUTY: Testing > Quest giver prototype. Native pose activity no longer requires a registered helper user; waiting-pose failures retain Voss, the car and the conversation quest. SMS, three subtitle blocks, voice and lipsync retained. Install the complete package and fully restart the game.','v0.19f Voss Subtitles loaded. OFF DUTY: Testing > Quest giver prototype. Native SMS and grounded waiting pose retained; the briefing uses three timed subtitle blocks with continuous voice and lipsync. Install the complete package, including the new subtitle script and archive, and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19f1 Voss Pose Check Fix###','NCPD Patrol - v0.19f Voss Subtitles###')

def without_voss_subtitles_branding(source):
    source=without_voss_pose_fix_branding(source)
    source=source.replace('-- NCPD Patrol v0.19f Voss Subtitles | three timed blocks with continuous voice and lipsync','-- NCPD Patrol v0.19e Voss Waiting Pose | grounded pose before the conversation')
    source=source.replace('v0.19f Voss Subtitles loaded. OFF DUTY: Testing > Quest giver prototype. Native SMS and grounded waiting pose retained; the briefing uses three timed subtitle blocks with continuous voice and lipsync. Install the complete package, including the new subtitle script and archive, and fully restart the game.','v0.19e Voss Waiting Pose loaded. OFF DUTY: Testing > Quest giver prototype. SMS invitation retained; Voss prepares her arms-crossed pose at a grounded anchor before you approach. Greeting keeps the existing body pose. Install the complete package, including scripts/archive, and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19f Voss Subtitles###','NCPD Patrol - v0.19e Voss Waiting Pose###')

def without_voss_waiting_branding(source):
    source=without_voss_subtitles_branding(source)
    source=source.replace('-- NCPD Patrol v0.19e Voss Waiting Pose | grounded pose before the conversation','-- NCPD Patrol v0.19d Voss SMS Intro | native phone invitation before the meeting')
    source=source.replace('v0.19e Voss Waiting Pose loaded. OFF DUTY: Testing > Quest giver prototype. SMS invitation retained; Voss prepares her arms-crossed pose at a grounded anchor before you approach. Greeting keeps the existing body pose. Install the complete package, including scripts/archive, and fully restart the game.','v0.19d Voss SMS Intro loaded. OFF DUTY: Testing > Quest giver prototype sends the native SMS invitation and activates the meeting marker. Read Messages, meet Mara Voss and use the existing conversation. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19e Voss Waiting Pose###','NCPD Patrol - v0.19d Voss SMS Intro###')

def without_voss_sms_branding(source):
    source=without_voss_waiting_branding(source)
    source=source.replace('-- NCPD Patrol v0.19d Voss SMS Intro | native phone invitation before the meeting','-- NCPD Patrol v0.19c Voss Presentation | native workspot and eye-slot LookAt')
    source=source.replace('v0.19d Voss SMS Intro loaded. OFF DUTY: Testing > Quest giver prototype sends the native SMS invitation and activates the meeting marker. Read Messages, meet Mara Voss and use the existing conversation. Install the complete package and fully restart the game.',"v0.19c Voss Presentation loaded. OFF DUTY: Testing > Quest giver prototype. Voss uses the arms-crossed workspot and native eye/head LookAt toward V's pla_default_tgt during dialogue. Voice, choices and silent V replies are retained. Install the complete package and fully restart the game.")
    return source.replace('NCPD Patrol - v0.19d Voss SMS Intro###','NCPD Patrol - v0.19c Voss Presentation###')

def without_voss_presentation_branding(source):
    source=without_voss_sms_branding(source)
    source=source.replace('-- NCPD Patrol v0.19c Voss Presentation | native workspot and eye-slot LookAt','-- NCPD Patrol v0.19b Voss Briefing | isolated native voice and lipsync test')
    source=source.replace("v0.19c Voss Presentation loaded. OFF DUTY: Testing > Quest giver prototype. Voss uses the arms-crossed workspot and native eye/head LookAt toward V's pla_default_tgt during dialogue. Voice, choices and silent V replies are retained. Install the complete package and fully restart the game.",'v0.19b Voss Briefing loaded. OFF DUTY: Testing > Quest giver prototype. Hello, uninterrupted voiced Voss briefing with lipsync, two text choices and goodbye. V remains silent. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19c Voss Presentation###','NCPD Patrol - v0.19b Voss Briefing###')

def without_voss_briefing_branding(source):
    source=without_voss_presentation_branding(source)
    source=source.replace('-- NCPD Patrol v0.19b Voss Briefing | isolated native voice and lipsync test','-- NCPD Patrol v0.19a1 Scene Guard Fix | precise dialogue and scene-tier player guards')
    source=source.replace('v0.19b Voss Briefing loaded. OFF DUTY: Testing > Quest giver prototype. Hello, uninterrupted voiced Voss briefing with lipsync, two text choices and goodbye. V remains silent. Install the complete package and fully restart the game.','v0.19a1 Scene Guard Fix loaded. Quest giver activation and greeting allow normal gameplay with background scene membership. Active dialogue and restricted scene tiers still pause the test. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19b Voss Briefing###','NCPD Patrol - v0.19a1 Scene Guard Fix###')

def without_quest_giver_guard_fix(source):
    source=without_voss_briefing_branding(source)
    source=source.replace('-- NCPD Patrol v0.19a1 Scene Guard Fix | precise dialogue and scene-tier player guards','-- NCPD Patrol v0.19a Quest Giver Prototype | isolated silent native dialogue test')
    source=source.replace('v0.19a1 Scene Guard Fix loaded. Quest giver activation and greeting allow normal gameplay with background scene membership. Active dialogue and restricted scene tiers still pause the test. Install the complete package and fully restart the game.','v0.19a Quest Giver Prototype loaded. OFF DUTY: Testing > Quest giver prototype activates the separate investigator quest. Silent native subtitles, two choices and goodbye complete the quest. Install the complete package and fully restart the game.')
    return source.replace('NCPD Patrol - v0.19a1 Scene Guard Fix###','NCPD Patrol - v0.19a Quest Giver Prototype###')

def without_quest_giver(source):
    source=without_quest_giver_guard_fix(source)
    source=source.replace('-- NCPD Patrol v0.19a Quest Giver Prototype | isolated silent native dialogue test','-- NCPD Patrol v0.18i CET Menu Cleanup | current dispatch controls and live catalogue summary')
    source=source.replace('v0.19a Quest Giver Prototype loaded. OFF DUTY: Testing > Quest giver prototype activates the separate investigator quest. Silent native subtitles, two choices and goodbye complete the quest. Install the complete package and fully restart the game.','v0.18i CET Menu Cleanup loaded. Officer Down requests use the nearby 54-site catalogue. Fixed-intersection and old marker launchers removed from CET; current dispatch tests, survey, discovery and recovery remain. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.19a Quest Giver Prototype###','NCPD Patrol - v0.18i CET Menu Cleanup###')
    source=re.sub(r'^.* -- qgiver hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^-- qgiver setup begin\n.*?^-- qgiver setup end\n\n','',source,flags=re.M|re.S)
    source=re.sub(r'^    -- qgiver guard begin\n.*?^    -- qgiver guard end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^        -- qgiver UI begin\n.*?^        -- qgiver UI end\n','',source,flags=re.M|re.S)
    return source

def without_probe(source):
    source=without_quest_giver(source)
    # v0.18i changes the menu and adds read-only catalogue metadata only.
    source=source.replace('-- NCPD Patrol v0.18i CET Menu Cleanup | current dispatch controls and live catalogue summary','-- NCPD Patrol v0.18h Expanded Officer Down | 38 imported compact placements, 54 stable dispatch sites')
    source=source.replace('v0.18i CET Menu Cleanup loaded. Officer Down requests use the nearby 54-site catalogue. Fixed-intersection and old marker launchers removed from CET; current dispatch tests, survey, discovery and recovery remain. Install the complete package and fully restart the game.','v0.18h Expanded Officer Down loaded. 38 approved compact discovery placements added; 54 dispatch sites total across City Center, Heywood, Pacifica, Santo Domingo and Watson. Existing 10% frequency, rewards and scene lifecycle remain. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18i CET Menu Cleanup###','NCPD Patrol - v0.18h Expanded Officer Down###')
    source=re.sub(r'^-- v018i catalogue metadata begin\n.*?^-- v018i catalogue metadata end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^        -- v018i legacy recovery UI begin\n.*?^        -- v018i legacy recovery UI end\n','',source,flags=re.M|re.S)
    source=source.replace('-- NCPD Patrol v0.18h Expanded Officer Down | 38 imported compact placements, 54 stable dispatch sites','-- NCPD Patrol v0.18g1 Discovery Landing Fix | supported offset staging and retained stop reasons')
    source=source.replace('v0.18h Expanded Officer Down loaded. 38 approved compact discovery placements added; 54 dispatch sites total across City Center, Heywood, Pacifica, Santo Domingo and Watson. Existing 10% frequency, rewards and scene lifecycle remain. Install the complete package and fully restart the game.','v0.18g1 Discovery Landing Fix loaded. Terminal-offset searches use safe nearby staging when the terminal itself lacks navmesh. Existing successful discovery results remain compatible; stop reasons stay visible during return. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18h Expanded Officer Down###','NCPD Patrol - v0.18g1 Discovery Landing Fix###')
    source=source.replace('-- NCPD Patrol v0.18g1 Discovery Landing Fix | supported offset staging and retained stop reasons','-- NCPD Patrol v0.18g Scene Discovery | off-duty terminal-offset search and separate placement evidence')
    source=source.replace('v0.18g1 Discovery Landing Fix loaded. Terminal-offset searches use safe nearby staging when the terminal itself lacks navmesh. Existing successful discovery results remain compatible; stop reasons stay visible during return. Install the complete package and fully restart the game.','v0.18g Scene Discovery loaded. Testing > Scene discovery searches shifted centers around 60 existing terminals with both layouts. Start with the three closest terminals. Developer test only; approved dispatch sites and original survey results are preserved. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18g1 Discovery Landing Fix###','NCPD Patrol - v0.18g Scene Discovery###')
    # Scene discovery adds isolated developer controls; existing session routes retain their labels-only comparison.
    source=source.replace('-- NCPD Patrol v0.18g Scene Discovery | off-duty terminal-offset search and separate placement evidence','-- NCPD Patrol v0.18f Scene Arrival and Stray Fire | 50 m mounted activation and bounded police-hit allowance')
    source=source.replace('v0.18g Scene Discovery loaded. Testing > Scene discovery searches shifted centers around 60 existing terminals with both layouts. Start with the three closest terminals. Developer test only; approved dispatch sites and original survey results are preserved. Install the complete package and fully restart the game.','v0.18f Scene Arrival and Stray Fire loaded. Officer Down combat starts at 50 m, including from a vehicle; live NPCs use physical safety instead of spawn precision. One stray police discharge per 10 s may be excused during hostile combat; deliberate aim and repeated fire retain normal wanted rules. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18g Scene Discovery###','NCPD Patrol - v0.18f Scene Arrival and Stray Fire###')
    source=re.sub(r'^        -- v018g discovery UI begin\n.*?^        -- v018g discovery UI end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^                -- v018f police fire UI begin\n.*?^                -- v018f police fire UI end\n','',source,flags=re.M|re.S)
    source=source.replace('-- NCPD Patrol v0.18f Scene Arrival and Stray Fire | 50 m mounted activation and bounded police-hit allowance','-- NCPD Patrol v0.18e2 Detached Actor Cleanup | owned NPC/car ID retirement and fresh world checks')
    source=source.replace('v0.18f Scene Arrival and Stray Fire loaded. Officer Down combat starts at 50 m, including from a vehicle; live NPCs use physical safety instead of spawn precision. One stray police discharge per 10 s may be excused during hostile combat; deliberate aim and repeated fire retain normal wanted rules. Install the complete package and fully restart the game.','v0.18e2 Detached Actor Cleanup loaded. Completed Officer Down scenes can retain detached NPC/car ID bookkeeping without blocking the next call. Fresh entity/spawning checks still protect live actors. Cleanup API v3; install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18f Scene Arrival and Stray Fire###','NCPD Patrol - v0.18e2 Detached Actor Cleanup###')
    source=source.replace('-- NCPD Patrol v0.18e2 Detached Actor Cleanup | owned NPC/car ID retirement and fresh world checks','-- NCPD Patrol v0.18e1 Startup Fix | observed REDscript Dispose compatibility')
    source=source.replace('v0.18e2 Detached Actor Cleanup loaded. Completed Officer Down scenes can retain detached NPC/car ID bookkeeping without blocking the next call. Fresh entity/spawning checks still protect live actors. Cleanup API v3; install the complete package and fully restart the game.','v0.18e1 Startup Fix loaded. Unsupported REDscript Dispose call removed; optional CET disposal is capability-checked. Officer Down ownership, detached vehicle receipts and manual retry are retained. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18e2 Detached Actor Cleanup###','NCPD Patrol - v0.18e1 Startup Fix###')
    source=source.replace('-- NCPD Patrol v0.18e1 Startup Fix | observed REDscript Dispose compatibility','-- NCPD Patrol v0.18e Officer Down Cleanup | accepted vehicle teardown and repeat-call ownership')
    source=source.replace('v0.18e1 Startup Fix loaded. Unsupported REDscript Dispose call removed; optional CET disposal is capability-checked. Officer Down ownership, detached vehicle receipts and manual retry are retained. Install the complete package and fully restart the game.','v0.18e Officer Down Cleanup loaded. Repeat calls wait for physical cleanup, not stale vehicle registrations. Accepted vehicle deletion has a scoped native fallback. Manual Officer Down retry ends completed-scene retention early. Existing dispatch/rewards and v0.18d controls remain. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18e1 Startup Fix###','NCPD Patrol - v0.18e Officer Down Cleanup###')
    source=source.replace('-- NCPD Patrol v0.18e Officer Down Cleanup | accepted vehicle teardown and repeat-call ownership','-- NCPD Patrol v0.18d Shift Controls | Career End Shift and scoped partner police-hit safety')
    source=source.replace('v0.18e Officer Down Cleanup loaded. Repeat calls wait for physical cleanup, not stale vehicle registrations. Accepted vehicle deletion has a scoped native fallback. Manual Officer Down retry ends completed-scene retention early. Existing dispatch/rewards and v0.18d controls remain. Install the complete package and fully restart the game.','v0.18d Shift Controls loaded. Career Start/End Shift; Officer Down under Testing > Dispatch scenarios; registered partner gun hits on non-hostile police are ignored on duty. Existing dispatch, rewards and wanted termination remain active. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18e Officer Down Cleanup###','NCPD Patrol - v0.18d Shift Controls###')
    source=source.replace('-- NCPD Patrol v0.18d Shift Controls | Career End Shift and scoped partner police-hit safety','-- NCPD Patrol v0.18c Officer Down Dispatch | surveyed sites and gameplay reliability logs')
    source=source.replace('v0.18d Shift Controls loaded. Career Start/End Shift; Officer Down under Testing > Dispatch scenarios; registered partner gun hits on non-hostile police are ignored on duty. Existing dispatch, rewards and wanted termination remain active. Install the complete package and fully restart the game.','v0.18c Officer Down Dispatch loaded. 16 surveyed City Center/Watson sites; mix 45% scanner, 27% VIP, 18% cyberpsycho, 10% Officer Down. Dispatch tab has a direct request; Diagnostics exports gameplay reliability logs. Survey tools and existing results are preserved. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18d Shift Controls###','NCPD Patrol - v0.18c Officer Down Dispatch###')
    source=source.replace('-- NCPD Patrol v0.18c Officer Down Dispatch | surveyed sites and gameplay reliability logs','-- NCPD Patrol v0.18b3 Functional Scene Survey | injured usability replaces spawn precision')
    source=source.replace('v0.18c Officer Down Dispatch loaded. 16 surveyed City Center/Watson sites; mix 45% scanner, 27% VIP, 18% cyberpsycho, 10% Officer Down. Dispatch tab has a direct request; Diagnostics exports gameplay reliability logs. Survey tools and existing results are preserved. Install the complete package and fully restart the game.','v0.18b3 Functional Scene Survey loaded. Normal 17-site buttons validate injured ground, clearance, down-state and a reachable aid position. Landing displacement is informational; no injured corrections or precision anchor. Existing results are preserved by validation profile. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18c Officer Down Dispatch###','NCPD Patrol - v0.18b3 Functional Scene Survey###')
    source=re.sub(r'^        -- Officer Down catalogue UI begin\n.*?^        -- Officer Down catalogue UI end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^            -- Officer Down catalogue UI begin\n.*?^            -- Officer Down catalogue UI end\n','',source,flags=re.M|re.S)
    source=source.replace('-- NCPD Patrol v0.18b3 Functional Scene Survey | injured usability replaces spawn precision','-- NCPD Patrol v0.18b2 Injured Placement Pilot | bounded staging then uncorrected validation')
    source=source.replace('v0.18b3 Functional Scene Survey loaded. Normal 17-site buttons validate injured ground, clearance, down-state and a reachable aid position. Landing displacement is informational; no injured corrections or precision anchor. Existing results are preserved by validation profile. Install the complete package and fully restart the game.','v0.18b2 Injured Placement Pilot loaded. Use TEST: Injured placement pilot (3 sites). Only this pilot corrects injured placement during staging, then stops corrections before strict observation. Full tours, passive settling and live incidents retain their procedures. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18b3 Functional Scene Survey###','NCPD Patrol - v0.18b2 Injured Placement Pilot###')
    source=source.replace('-- NCPD Patrol v0.18b2 Injured Placement Pilot | bounded staging then uncorrected validation','-- NCPD Patrol v0.18b1 Injured Settling Pilot | opt-in three-site transition measurements')
    source=source.replace('v0.18b2 Injured Placement Pilot loaded. Use TEST: Injured placement pilot (3 sites). Only this pilot corrects injured placement during staging, then stops corrections before strict observation. Full tours, passive settling and live incidents retain their procedures. Install the complete package and fully restart the game.','v0.18b1 Injured Settling Pilot loaded. Testing has an opt-in three-site injured transition probe. Full 17-site surveys retain their original procedure. Existing results are preserved; pilot results use a separate validation profile. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18b2 Injured Placement Pilot###','NCPD Patrol - v0.18b1 Injured Settling Pilot###')
    source=source.replace('-- NCPD Patrol v0.18b1 Injured Settling Pilot | opt-in three-site transition measurements','-- NCPD Patrol v0.18b Scene Survey | compact layout and 17-site off-duty tour')
    source=source.replace('v0.18b1 Injured Settling Pilot loaded. Testing has an opt-in three-site injured transition probe. Full 17-site surveys retain their original procedure. Existing results are preserved; pilot results use a separate validation profile. Install the complete package and fully restart the game.','v0.18b Scene Survey loaded. Compact Officer Down layout and an explicit off-duty 17-site test tour. City Center and Watson only. Use a manual test save; survey evidence is stored in the CET mod folder. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18b1 Injured Settling Pilot###','NCPD Patrol - v0.18b Scene Survey###')
    source=source.replace('-- NCPD Patrol v0.18b Scene Survey | compact layout and 17-site off-duty tour','-- NCPD Patrol v0.18a3 Officer Down placement | automatic rotations and vehicle clearance')
    source=source.replace('v0.18b Scene Survey loaded. Compact Officer Down layout and an explicit off-duty 17-site test tour. City Center and Watson only. Use a manual test save; survey evidence is stored in the CET mod folder. Install the complete package and fully restart the game.','v0.18a3 Officer Down placement loaded. Automatic rotations, vehicle clearance and early preparation with bounded retry. Combat, revive, rewards and dispatch markers are unchanged. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18b Scene Survey###','NCPD Patrol - v0.18a3 Officer Down placement###')
    source=re.sub(r'^.* -- scene survey hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^    -- scene survey guard begin\n.*?^    -- scene survey guard end\n','',source,flags=re.M|re.S)
    source=re.sub(r'^-- scene survey setup begin\n.*?^-- scene survey setup end\n\n','',source,flags=re.M|re.S)
    source=source.replace('-- NCPD Patrol v0.18a3 Officer Down placement | automatic rotations and vehicle clearance','-- NCPD Patrol v0.18a2 Officer Down ground fix | typed navigation and full probe height')
    source=source.replace('v0.18a3 Officer Down placement loaded. Automatic rotations, vehicle clearance and early preparation with bounded retry. Combat, revive, rewards and dispatch markers are unchanged. Install the complete package and fully restart the game.','v0.18a2 Officer Down ground fix loaded. Character navigation receives Vector4 ground; probes cover the accepted height range. Other scene behavior and dispatch markers are unchanged. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a3 Officer Down placement###','NCPD Patrol - v0.18a2 Officer Down ground fix###')
    source=source.replace('-- NCPD Patrol v0.18a2 Officer Down ground fix | typed navigation and full probe height','-- NCPD Patrol v0.18a1 Officer Down locator | manual test waypoint button')
    source=source.replace('v0.18a2 Officer Down ground fix loaded. Character navigation receives Vector4 ground; probes cover the accepted height range. Other scene behavior and dispatch markers are unchanged. Install the complete package and fully restart the game.','v0.18a1 Officer Down locator loaded. CET Testing includes a manual waypoint to the test intersection. Existing dispatch markers and scene behavior are unchanged. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a2 Officer Down ground fix###','NCPD Patrol - v0.18a1 Officer Down locator###')
    source=source.replace('-- NCPD Patrol v0.18a1 Officer Down locator | manual test waypoint button','-- NCPD Patrol v0.18a Officer Down | fixed intersection rescue scene')
    source=source.replace('v0.18a1 Officer Down locator loaded. CET Testing includes a manual waypoint to the test intersection. Existing dispatch markers and scene behavior are unchanged. Install the complete package and fully restart the game.','v0.18a Officer Down loaded. Manual fixed-intersection rescue under CET Testing; staged protection, combat and officer revive. VIP routes and arrest fix retained. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a1 Officer Down locator###','NCPD Patrol - v0.18a Officer Down###')
    source=source.replace('-- NCPD Patrol v0.18a Officer Down | fixed intersection rescue scene','-- NCPD Patrol v0.17f VIP route catalogue | fixed endpoint pairs from the native marker bank')
    source=source.replace('v0.18a Officer Down loaded. Manual fixed-intersection rescue under CET Testing; staged protection, combat and officer revive. VIP routes and arrest fix retained. Install the complete package and fully restart the game.','v0.17f VIP route catalogue loaded. 360 baked routes use 60 canonical native-marker endpoints. Includes the arrest initialization fix. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.18a Officer Down###','NCPD Patrol - v0.17f VIP route catalogue###')
    # Reviewed additive manual Officer Down controls; old menu routes remain.
    source=re.sub(r'^        -- Officer Down UI begin\n.*?^        -- Officer Down UI end\n','',source,flags=re.M|re.S)
    # Reviewed VIP route release labels; coordinator/session code is unchanged.
    source=source.replace('-- NCPD Patrol v0.17f VIP route catalogue | fixed endpoint pairs from the native marker bank','-- NCPD Patrol v0.17e2 arrest initialization | prepare private bindings before helper attachment')
    source=source.replace('v0.17f VIP route catalogue loaded. 360 baked routes use 60 canonical native-marker endpoints. Includes the arrest initialization fix. Install the complete package and fully restart the game.','v0.17e2 arrest initialization loaded. Private animation bindings are prepared before helper attachment. Includes the H10 dispatch exclusion. Install the complete package and fully restart the game.')
    source=source.replace('NCPD Patrol - v0.17f VIP route catalogue###','NCPD Patrol - v0.17e2 arrest initialization###')
    # Reviewed arrest-initialization build labels only.
    source=source.replace('-- NCPD Patrol v0.17e2 arrest initialization | prepare private bindings before helper attachment','-- NCPD Patrol v0.17e1 H10 location fix | excludes indoor H10 Atrium from generated dispatch')
    source=source.replace('v0.17e2 arrest initialization loaded. Private animation bindings are prepared before helper attachment. Includes the H10 dispatch exclusion. Install the complete package and fully restart the game.','v0.17e1 H10 location fix loaded. Indoor H10 Atrium excluded from VIP pickup/delivery and cyberpsycho dispatch. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17e2 arrest initialization###','NCPD Patrol - v0.17e1 H10 location fix###')
    # Reviewed H10 hotfix build labels.
    source=source.replace('-- NCPD Patrol v0.17e1 H10 location fix | excludes indoor H10 Atrium from generated dispatch','-- NCPD Patrol v0.17e patrol improvements | catalogue/diagnostics, career duty entry and road-checked backup')
    source=source.replace('v0.17e1 H10 location fix loaded. Indoor H10 Atrium excluded from VIP pickup/delivery and cyberpsycho dispatch. Install the complete package and restart.','v0.17e patrol improvements loaded. Marker catalogue/diagnostics refactored; Start Shift in NCPD Career; backup uses checked off-camera road approaches. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17e1 H10 location fix###','NCPD Patrol - v0.17e patrol improvements###')
    source=without_location_exclusion(source)
    # Reviewed v0.17e build labels only; session behavior is still compared.
    source=source.replace('-- NCPD Patrol v0.17e patrol improvements | catalogue/diagnostics, career duty entry and road-checked backup','-- NCPD Patrol v0.17d fixed quest markers r5c | finite journal marker bank')
    source=source.replace('v0.17e patrol improvements loaded. Marker catalogue/diagnostics refactored; Start Shift in NCPD Career; backup uses checked off-camera road approaches. Install the complete package and restart.','v0.17d fixed quest markers r5c loaded. Scanner, VIP and cyberpsycho activate fixed journal pins. Unmapped sites use independent quest-style markers. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17e patrol improvements###','NCPD Patrol - v0.17d fixed quest markers r5c###')
    source=re.sub(r"fixed quest markers r5[abc]", "fixed quest markers r5", source)
    # Exact navigation adapters only. Bank-present behavior has its own suite;
    # historical oracles exercise the unavailable-bank compatibility boundary.
    source=re.sub(r'^.* -- r5 marker hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^        -- r5 marker UI begin\n.*?^        -- r5 marker UI end\n','',source,flags=re.M|re.S)
    source=source.replace('Navigation.place(patrol, chosen.position, "scanner")','patrol:PlaceDispatchWaypoint(chosen.position)')
    source=source.replace('Navigation.place(patrol,origin,"cyberpsycho")','patrol:PlaceDispatchWaypoint(origin)')
    source=source.replace('Navigation.place(patrol,point,"vip")','patrol:PlaceDispatchWaypoint(point)')
    source=source.replace('Navigation.place(patrol,waypointPoint,"vip")','patrol:PlaceDispatchWaypoint(waypointPoint)')
    source=source.replace('function M.navigationState() return Navigation.describe(active and active.waypoint, navigation) end','function M.navigationState() return navigation end')
    source=source.replace('-- NCPD Patrol v0.17d fixed quest markers r5 | finite journal marker bank','-- NCPD Patrol v0.17d quest marker test r4e | isolated opt-in experiment')
    source=source.replace('v0.17d fixed quest markers r5 loaded. Scanner, VIP and cyberpsycho activate fixed journal pins. Unmapped sites use independent quest-style markers. Install the complete package and restart.','v0.17d quest marker test r4e loaded. Opt-in fixed-position quest marker under CET Testing. Normal dispatch retains its existing waypoint. Install the complete package and restart.')
    source=source.replace('NCPD Patrol - v0.17d fixed quest markers r5###','NCPD Patrol - v0.17d quest marker test r4e###')
    source=re.sub(r'quest marker test r4[abcde]', 'quest marker test r4', source)
    source=re.sub(r'^.* -- r4 probe hook[^\n]*\n','',source,flags=re.M)
    source=re.sub(r'^        -- r4 probe UI begin\n.*?^        -- r4 probe UI end\n','',source,flags=re.M|re.S)
    return source.replace('-- NCPD Patrol v0.17d quest marker test r4 | isolated opt-in experiment',
                          '-- NCPD Patrol v0.17d VIP refactor r3 | extracted locations and waypoint ownership').replace(
        'v0.17d quest marker test r4 loaded. Opt-in fixed-position quest marker under CET Testing. Normal dispatch retains its existing waypoint. Install the complete package and restart.',
        'v0.17d VIP refactor r3 loaded. VIP locations and waypoint ownership are separate modules. Transport, ambush, rewards and the CET menu retain their existing behavior. Install the complete package and restart.').replace(
        'NCPD Patrol - v0.17d quest marker test r4###','NCPD Patrol - v0.17d VIP refactor r3###')

PROBE_BUTTONS={'Log active dispatch marker diagnostics','Log legacy Coyote test diagnostics','TEST: Start static quest marker','TEST: Relocate native marker near V','TEST: Andrea visual marker','Remove quest marker test'}
PROBE_BUTTONS.update({'TEST: Survey all recorded sites (compact)','TEST: Survey all recorded sites (standard)','TEST: Retry unverified survey sites','Stop survey and return','Recover survey cleanup and return','Load saved survey results','Export scene survey report','Log scene survey diagnostics'})
PROBE_BUTTONS.add('TEST: Injured settling pilot (3 sites)')
PROBE_BUTTONS.add('TEST: Injured placement pilot (3 sites)')
PROBE_BUTTONS.update({'Request Officer Down dispatch','Export Officer Down gameplay report'})
PROBE_BUTTONS.add('TEST: Request Officer Down dispatch')
PROBE_BUTTONS.add('Log police fire diagnostics')
PROBE_BUTTONS.update({'TEST: Discover scenes near 3 closest terminals','TEST: Discover scenes near all 60 terminals','Stop discovery and return','Recover discovery cleanup and return','Load discovery results','Export discovery report'})
PROBE_BUTTONS.update({'TEST: Request Officer Down','TEST: Rotate Officer Down scene 90 degrees','Revive scene officer (nearby)','Clear Officer Down scene','Log Officer Down diagnostics','TEST: Waypoint to Officer Down intersection'})

# Retired menu launchers remain classified for historical-oracle filtering;
# current UI must not expose them. Backend ownership/cleanup tests still run.
RETIRED_BUTTONS={
 'TEST: Request Officer Down','TEST: Rotate Officer Down scene 90 degrees',
 'TEST: Waypoint to Officer Down intersection',
 'TEST: Injured placement pilot (3 sites)','TEST: Injured settling pilot (3 sites)',
 'TEST: Start static quest marker','TEST: Relocate native marker near V',
 'TEST: Andrea visual marker','Remove quest marker test','Log legacy Coyote test diagnostics'}
PROBE_BUTTONS.add('Clear leftover quest marker experiment')

PROBE_BUTTONS.update({'TEST: Activate quest giver quest','Clear quest giver test','Log quest giver diagnostics'})
PROBE_BUTTONS.update({'TEST: Continue Off the Books after briefing','Clear Off the Books encounter only','Log Off the Books diagnostics'})

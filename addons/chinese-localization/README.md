# Chinese localization preview 0.1a

[Download the optional ZIP](https://github.com/jonathankj2000-cpu/NCPD-Patrol-Officer/raw/refs/heads/main/releases/NCPD_Patrol_Chinese_Localization_Preview_v0.1a.zip)

Simplified Chinese (`zh-cn`) and Traditional Chinese (`zh-tw`) are included.
Requires NCPD Patrol and its existing dependencies. Main 0.17d and the earlier
career build were checked offline with the localized provider; the older build's
16 interaction keys retain their English values/fallback. Actual game rendering
and terminology need a Chinese player's review.

## Install and remove

Install the main mod first, then extract this ZIP into the game folder containing
`r6` and `archive`. Allow this add-on's **NCPDPatrolLocalization.reds** to overwrite
the main text provider, or let the language pack win that file's conflict in the
mod manager. It changes no gameplay scripts, quest graphs or reward records.
Select the game's Chinese interface/text language and restart. Reapply this pack
after main-mod updates.

To remove, delete **NCPDPatrol_Chinese.archive** and its **.archive.xl** from
`archive/pc/mod`, then reinstall the main package to restore its English text
provider. Restart. Keep the other main-mod files.

## Coverage

| Translated | Keys per language |
| --- | ---: |
| Interaction/button captions and Bean Bagger name/description | 19 |
| Six scanner dispatch journal variants | 18 |
| VIP journal entries | 6 |
| Cyberpsycho journal entries | 6 |
| Total | 49 |

**Still English:** HUD, notifications, career pages, CET controls/logs and
hardcoded popup headings/help. Features absent from older main versions remain
absent; their extra translation keys do not add those features.

## Validation and feedback

Both scripts and the main mod passed offline source/API compilation with and
without Browser Extension Framework. Chinese journal resources were compiled,
round-tripped and extracted with WolvenKit; exact keys and resource bytes were
checked. The install ZIP is deterministic and checked against all five files.
This is not an installed-game-cache compile or a native-speaker review.

For a quick game check, inspect Start Shift at a fast-travel point, the trunk
menu button captions, and an assigned scanner quest in the journal. On a main
version with those features, also inspect VIP/cyberpsycho journals and the Bean
Bagger's inventory name/description. Report square/missing glyphs, clipped labels
and wording that differs from the game's Chinese terminology. Popup headers and
notifications remaining English are expected in this preview.

Translation source is **translations.json**. Rebuild with:

```sh
python3 tools/build_chinese_localization.py --wk-cli /path/to/WolvenKit.CLI
python3 tools/build_chinese_localization.py --check
```

The first command requires WolvenKit 9.1.1 and its .NET runtime. Verification of
the already-built files uses only the Python standard library.

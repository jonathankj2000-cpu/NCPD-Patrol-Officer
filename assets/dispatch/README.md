# Dispatch journal asset

These are authored sources for the two resources in NCPDPatrol_Dispatch.archive.
They define six mod-owned MinorQuest variants, each with one phase/objective
and three text keys (18 total). Only one variant is active at a time. Variant
zero keeps the original v0.9a path for upgrade/load cleanup. ArchiveXL merges
the branch under quests/minor_quest and loads onscreens.
No game journal is bundled, no clone API is used, and no native map pin is
authored at a placeholder position. The existing dispatcher owns its marker.

Developer build:

    python tools/build_dispatch_assets.py --wk-cli /path/to/WolvenKit.CLI

WolvenKit Console 9.1.1 and .NET 10 are used. Players install the compiled archive
and its .archive.xl from the full ZIP, plus ArchiveXL separately.

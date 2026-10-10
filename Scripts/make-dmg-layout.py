#!/usr/bin/env python3
"""Create Finder metadata for the branded YouTube Downloader DMG."""

import argparse
from pathlib import Path

from ds_store import DSStore
from mac_alias import Alias, ALIAS_EJECTABLE_DISK, ALIAS_NO_CNID


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("staging", type=Path)
    args = parser.parse_args()

    staging = args.staging.resolve()
    background = staging / ".background" / "installer.png"
    alias = Alias.for_file(str(background))

    # The file is currently in a staging folder, but Finder will resolve it
    # from the root of the mounted disk image.
    alias.volume.name = b"YouTube Downloader"
    alias.volume.disk_type = ALIAS_EJECTABLE_DISK
    alias.volume.posix_path = b"/Volumes/YouTube Downloader"
    alias.target.folder_cnid = ALIAS_NO_CNID
    alias.target.cnid = ALIAS_NO_CNID
    alias.target.folder_name = b".background"
    alias.target.cnid_path = []
    alias.target.carbon_path = b"YouTube Downloader:.background:installer.png"
    alias.target.posix_path = b"/.background/installer.png"

    bounds = "{{180, 140}, {660, 420}}"
    bwsp = {
        "ShowStatusBar": False,
        "WindowBounds": bounds,
        "ContainerShowSidebar": False,
        "PreviewPaneVisibility": False,
        "SidebarWidth": 0,
        "ShowTabView": False,
        "ShowToolbar": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
    }
    icvp = {
        "viewOptionsVersion": 1,
        "backgroundType": 2,
        "backgroundColorRed": 1.0,
        "backgroundColorGreen": 0.95,
        "backgroundColorBlue": 0.90,
        "backgroundImageAlias": alias.to_bytes(),
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "gridSpacing": 100.0,
        "arrangeBy": "none",
        "showIconPreview": True,
        "showItemInfo": False,
        "labelOnBottom": True,
        "textSize": 13.0,
        "iconSize": 128.0,
        "scrollPositionX": 0.0,
        "scrollPositionY": 0.0,
    }

    store_path = staging / ".DS_Store"
    if store_path.exists():
        store_path.unlink()
    with DSStore.open(str(store_path), "w+") as store:
        store["."]["vSrn"] = ("long", 1)
        store["."]["bwsp"] = bwsp
        store["."]["icvp"] = icvp
        store["."]["icvl"] = (b"type", b"icnv")
        store["YouTube Downloader.app"]["Iloc"] = (205, 220)
        store["Applications"]["Iloc"] = (455, 220)


if __name__ == "__main__":
    main()

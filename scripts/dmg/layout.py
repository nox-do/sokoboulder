"""Write Finder's DMG layout directly, without driving the user's Finder."""
import sys
from pathlib import Path
from ds_store import DSStore
from mac_alias import Alias

volume = Path(sys.argv[1])
with DSStore.open(str(volume / '.DS_Store'), 'w+') as store:
    store['.']['vstl'] = ('type', b'icnv')
    store['.']['icvl'] = ('type', b'icnv')
    store['.']['bwsp'] = {
        'WindowBounds': '{{180, 140}, {720, 548}}',
        'ShowToolbar': False,
        'ShowStatusBar': False,
        'ShowPathbar': False,
        'ShowSidebar': False,
        'ContainerShowSidebar': False,
        'ShowTabView': False,
        'PreviewPaneVisibility': False,
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1,
        'backgroundType': 2,
        'backgroundImageAlias': Alias.for_file(str(volume / '.background' / 'background.png')).to_bytes(),
        'backgroundColorRed': 1.0,
        'backgroundColorGreen': 1.0,
        'backgroundColorBlue': 1.0,
        'arrangeBy': 'none',
        'gridOffsetX': 0.0,
        'gridOffsetY': 0.0,
        'gridSpacing': 100.0,
        'iconSize': 104.0,
        'textSize': 14.0,
        'labelOnBottom': True,
        'showIconPreview': True,
        'showItemInfo': False,
        'scrollPositionX': 0.0,
        'scrollPositionY': 0.0,
    }
    store['SokoBoulder.app']['Iloc'] = (190, 250)
    store['Programme']['Iloc'] = (530, 250)

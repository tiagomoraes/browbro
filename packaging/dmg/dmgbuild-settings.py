# dmgbuild settings for the styled BrowBro installer window.
# Usage: BB_APP=/path/BrowBro.app BB_BACKGROUND=packaging/dmg/background.tiff \
#        dmgbuild -s packaging/dmg/dmgbuild-settings.py "BrowBro" BrowBro.dmg
import os

application = os.environ["BB_APP"]
appname = os.path.basename(application)

format = "UDZO"                       # compressed, read-only
files = [application]
symlinks = {"Applications": "/Applications"}
badge_icon = os.path.join(application, "Contents/Resources/AppIcon.icns")
background = os.environ["BB_BACKGROUND"]

icon_size = 128
text_size = 13
icon_locations = {
    appname: (180, 220),
    "Applications": (480, 220),
}
window_rect = ((240, 180), (660, 460))
default_view = "icon-view"
arrange_by = None
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

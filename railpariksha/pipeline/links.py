"""The public links every post, video and page uses, in one place.

People are sent to https://railpariksha.in/app, never straight to Google Play. While the app is not public that
page says it is coming soon and points to Telegram; on launch day set APP_LIVE = True and the same address
redirects to the Play listing, so nothing already posted (videos, Telegram messages, the site) has to change.
"""

SITE_URL = "https://railpariksha.in"
APP_URL = SITE_URL + "/app"
PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=app.railpariksha"
TELEGRAM_URL = "https://t.me/RailParikshaApp"
YOUTUBE_URL = "https://www.youtube.com/@RailPariksha_Official"

# Set to True (or build the site with the environment variable APP_LIVE=1, e.g. in Cloudflare's build variables) when
# the app is public on Google Play, meaning the listing returns 200 for everyone and not only for testers.
import os  # noqa: E402

APP_LIVE = os.environ.get("APP_LIVE", "") == "1"

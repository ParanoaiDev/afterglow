import locale
import os

STRINGS = {
    "continuePlaying": ("Continue Playing", "Продолжить"),
    "onSource": ("on {0}", "в {0}"),
    "nothingQueued": ("Search for something to play", "Найди что-нибудь в поиске"),
    "notPlaying": ("Not Playing", "Ничего не играет"),
    "playSomething": ("Play something", "Включи что-нибудь"),
    "search": ("Search songs, artists…", "Песни, исполнители…"),
    "topResults": ("Top Results", "Лучшие результаты"),
    "songs": ("Songs", "Треки"),
    "artists": ("Artists", "Исполнители"),
    "song": ("Song", "Трек"),
    "video": ("Video", "Клип"),
    "noResults": ("Nothing found", "Ничего не найдено"),
    "searching": ("Searching…", "Ищу…"),
    "otherLyrics": ("Other lyrics", "Другой текст"),
    "noLyrics": ("No lyrics for this song", "Текста для этой песни нет"),
    "loadingLyrics": ("Looking for lyrics…", "Ищу текст…"),
    "lyricsPlain": ("Lyrics without timing", "Текст без синхронизации"),
    "automatic": ("Automatic", "Автоматически"),
    "settings": ("Settings", "Настройки"),
    "background": ("Background", "Фон"),
    "bgClip": ("Music video", "Клип"),
    "bgCover": ("Blurred cover", "Размытая обложка"),
    "bgImage": ("Image", "Картинка"),
    "bgVideo": ("Video file", "Видеофайл"),
    "bgColor": ("Solid color", "Цвет"),
    "choose": ("Choose…", "Выбрать…"),
    "dim": ("Darken background", "Затемнение фона"),
    "accent": ("Accent color", "Цвет акцента"),
    "accentAuto": ("From cover", "Из обложки"),
    "accentFixed": ("Fixed", "Свой"),
    "show": ("Show", "Показывать"),
    "clock": ("Clock", "Часы"),
    "lyrics": ("Lyrics", "Текст песни"),
    "queue": ("Queue", "Очередь"),
    "card": ("Cover card", "Карточку трека"),
    "glow": ("Screen edge glow", "Свечение по краям"),
    "glowStrength": ("Glow strength", "Яркость свечения"),
    "clock24": ("24-hour clock", "24-часовой формат"),
    "source": ("Music source", "Источник музыки"),
    "signIn": ("YouTube sign-in from browser", "Вход YouTube из браузера"),
    "myMix": ("My Mix", "Мой микс"),
    "needSignIn": ("Sign in to YouTube in your browser first", "Сначала войди в YouTube в браузере"),
    "mixEmpty": ("Could not load your mix", "Не получилось загрузить микс"),
    "signedInAs": ("Signed in through {0}", "Вход выполнен через {0}"),
    "notSignedIn": ("Not signed in", "Вход не выполнен"),
    "welcomeTitle": ("Sign in to YouTube", "Войди в YouTube"),
    "welcomeText": ("Sign in at youtube.com in Firefox or Chrome. Afterglow will pick up the sign-in and play your recommendations with music videos.",
                    "Зайди на youtube.com в Firefox или Chrome и войди в аккаунт. Afterglow подхватит вход и сам включит твои рекомендации с клипами."),
    "openYouTube": ("Open YouTube", "Открыть YouTube"),
    "checkAgain": ("Check again", "Проверить вход"),
    "autoplay": ("Play My Mix on start", "Включать «Мой микс» при запуске"),
    "auto": ("Auto", "Авто"),
    "off": ("Off", "Выкл"),
    "signInHint": ("YouTube may ask to sign in. Afterglow can borrow the cookies of a browser where you are signed in; they stay on this computer and go only to YouTube.",
                   "YouTube может требовать вход. Afterglow может взять куки браузера, где ты вошёл; они остаются на компьютере и уходят только в YouTube."),
    "none": ("None", "Нет"),
    "clipQuality": ("Music video quality", "Качество клипа"),
    "language": ("Language", "Язык"),
    "autostart": ("Start with the session", "Запускать при входе"),
    "close": ("Close", "Закрыть"),
    "quit": ("Quit Afterglow", "Выйти из Afterglow"),
    "showHide": ("Show / hide", "Показать / скрыть"),
    "playPause": ("Play / pause", "Пауза / продолжить"),
    "reset": ("Reset settings", "Сбросить настройки"),
    "errBot": ("YouTube wants a sign-in. Pick your browser in Settings → YouTube sign-in.",
               "YouTube просит вход. Выбери браузер в Настройках → Вход YouTube."),
    "errDrm": ("This track is DRM-protected on SoundCloud, trying YouTube…", "Трек на SoundCloud защищён DRM, ищу на YouTube…"),
    "errPlay": ("Could not play this track", "Не получилось включить трек"),
    "errSearch": ("Search failed: {0}", "Поиск не удался: {0}"),
    "errMpv": ("mpv is not installed", "Не установлен mpv"),
    "loadingTrack": ("Loading…", "Загружаю…"),
    "external": ("Other player", "Другой плеер"),
}


def pick_language(setting):
    if setting in ("en", "ru"):
        return setting
    lang = os.environ.get("LANGUAGE") or os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or ""
    if not lang:
        try:
            lang = locale.getlocale()[0] or ""
        except ValueError:
            lang = ""
    return "ru" if lang.lower().startswith(("ru", "uk", "be", "kk")) else "en"


def strings(lang):
    idx = 1 if lang == "ru" else 0
    return {k: v[idx] for k, v in STRINGS.items()}

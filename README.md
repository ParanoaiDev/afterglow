# Afterglow

Your music, right on the desktop of a Linux machine: the music video plays as the wallpaper, synced lyrics punch in line by line, and a big clock and a neon edge glow take their color from the cover art.

Afterglow is a full-screen surface on the **desktop layer** (`wlr-layer-shell`, below every window). Minimize your windows (or press Meta+D on KDE) and your desktop becomes the player.

> На русском — [ниже](#на-русском).

## Features

- **Search everywhere**: YouTube and SoundCloud in one search box. Pick the source in the player bar, or leave it on *Automatic*.
- **Music video background**: Afterglow finds the official music video, caches a video-only copy and plays it behind everything. When the track itself is the music video, picture and sound stay in sync.
- **Synced lyrics** from [LRCLIB](https://lrclib.net), with big kinetic lines. *Other lyrics* switches to another version when the first match is wrong.
- **Accent color from the cover**: the clock, glow, queue highlight and progress bar all follow the current album art. You can also fix your own color.
- **Continue Playing**: an endless queue built from YouTube's radio for the song you picked.
- **Media keys and the Plasma media widget** work through MPRIS.
- **Background modes**: music video, blurred cover, your own image, your own video file, or a solid color.
- Russian and English UI.

## Requirements

- A Wayland compositor with `wlr-layer-shell`: KDE Plasma 6, Hyprland, Sway, niri, and others. GNOME is not supported. Afterglow falls back to a normal window when it can't use the desktop layer.
- Python 3.11+, PySide6 (Qt 6.8+), `layer-shell-qt`, Qt Multimedia with the FFmpeg backend
- `mpv` and `yt-dlp`
- Optional: `python-dbus-fast` for media keys

Arch / CachyOS:

```sh
sudo pacman -S --needed pyside6 python-requests python-dbus-fast mpv yt-dlp layer-shell-qt qt6-multimedia-ffmpeg
```

## Install

```sh
git clone https://github.com/ParanoaiDev/afterglow
cd afterglow
./install.sh          # copies to ~/.local/share/afterglow and adds the afterglow launcher
afterglow
```

Or run it from the source folder without installing: `python -m afterglow`.

## Using it

| | |
|---|---|
| Space | play / pause |
| Ctrl+F or / | search |
| ← → | seek 5 s |
| ↑ ↓ | volume |
| N / P | next / previous |
| Esc | close panels |

The desktop layer only gets keyboard focus when you click it. To open the search from anywhere, bind `afterglow --search` to a key in *System Settings → Shortcuts*. Other commands: `--toggle`, `--next`, `--prev`, `--play "artist song"`, `--quit`, `--windowed`.

There is no taskbar entry. Use the tray icon to open settings, hide the player or quit.

### "YouTube wants a sign-in"

YouTube sometimes refuses anonymous playback with *Sign in to confirm you're not a bot*, depending on your network. If that happens, open **Settings → YouTube sign-in from browser** and pick a browser where you are logged in to YouTube. yt-dlp then reads that browser's YouTube cookies locally. They are only sent to YouTube.

SoundCloud never needs a sign-in. Major-label tracks there are DRM-locked, though, and in that case Afterglow plays the same song from YouTube instead.

## How it works

```
QML scene (layer-shell surface)  <->  Backend (Python, PySide6)
  Background: QtMultimedia video        search: YouTube InnerTube API, SoundCloud via yt-dlp
  Clock, card, lyrics, queue, bar       audio:  mpv over JSON IPC (yt-dlp hook)
                                        clips:  yt-dlp -> ~/.cache/afterglow/clips (LRU)
                                        lyrics: LRCLIB, covers: iTunes Search API
                                        MPRIS:  dbus-fast
```

Settings live in `~/.config/afterglow/settings.json`.

## License

MIT. Afterglow streams from third-party services. Their content belongs to the respective rights holders, and you are responsible for following their terms.

---

## На русском

**Afterglow** превращает рабочий стол Linux в музыкальный плеер. На фоне идёт клип текущего трека, поверх появляется синхронный текст, а большие часы и неоновая рамка по краю экрана берут цвет из обложки.

Приложение живёт на слое рабочего стола, под всеми окнами. Сверни окна (Meta+D в KDE), и рабочий стол станет плеером.

- Поиск сразу по YouTube и SoundCloud. Источник выбирается кнопкой слева в плеере.
- Клип на фоне: приложение само находит официальный клип и кэширует его.
- Синхронный текст из LRCLIB. Кнопка «Другой текст» переключает на другую версию.
- Цвет акцента берётся из обложки, его можно и задать свой.
- Очередь «Продолжить» строится из радио YouTube.
- Работают медиаклавиши и виджет плеера в Plasma.
- Фон на выбор: клип, размытая обложка, своя картинка, своё видео или цвет.

Установка: `./install.sh`, потом `afterglow`. Нужны пакеты из списка выше.

Если YouTube пишет «Sign in to confirm you're not a bot», открой **Настройки → Вход YouTube из браузера** и выбери браузер, в котором ты вошёл в YouTube.

Глобальная горячая клавиша для поиска: *Параметры системы → Комбинации клавиш*, команда `afterglow --search`.

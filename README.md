# linuxmintcustom / Mint Aesthetic Setup

This repository contains `mint-aesthetic-setup.sh`, a script that helps apply an aesthetic desktop setup on Linux Mint (Cinnamon).

What the script does (safe actions):
- Installs a small set of packages (Plank, Papirus icons, Arc theme, Conky, neofetch, variety)
- Downloads a wallpaper to the desktop user's `~/.local/share/backgrounds`
- Applies themes / icons / cursor / fonts / wallpaper via `gsettings` (attempts to run as the desktop user)
- Adds a per-user autostart for Plank (`~/.config/autostart/plank.desktop`)
- Backs up the user's dconf settings before changing them (`~/.config/mint-aesthetic-dconf-backup-*.dconf`)
- Installs Roboto and Fira Code fonts into `~/.local/share/fonts`
- Installs a small sample Conky config in `~/.config/conky/conky.conf`

How to run (recommended):

Open a terminal and run:

```bash
sudo bash ./mint-aesthetic-setup.sh
```

Notes:
- The script tries to detect the real desktop user and run `gsettings` as that user so settings are applied correctly. If you run this as a regular user (no sudo), it will operate on the current user.
- After running: sign out and back in (or reboot) to fully apply all desktop changes.

Reverting changes:
- The script creates a dconf dump backup in `~/.config/` (filename starts with `mint-aesthetic-dconf-backup-`). To revert the desktop settings, run:

```bash
# as the desktop user
dconf load / < ~/.config/mint-aesthetic-dconf-backup-YYYYMMDD-HHMMSS.dconf
```

Optional manual follow-ups:
- Use Cinnamon → Applets to arrange applets and panel items.
- Fine-tune theme CSS (some tweaks require editing the theme's `cinnamon.css`).
- Replace the default wallpaper URL in the script with your preferred wallpaper(s).

If you want me to fully automate installing a specific theme/icon/conky bundle from the video or BuyMeACoffee page, paste the download links and I'll wire them into the script.

Resources the script will attempt to fetch (best-effort):

- Themes (GNOME-Look pages):
	- https://www.gnome-look.org/p/1715554
	- https://www.gnome-look.org/p/1681313
	- https://www.gnome-look.org/p/1403328

- Icons (GNOME-Look pages):
	- https://www.gnome-look.org/p/1937741
	- https://www.gnome-look.org/p/1961046
	- https://www.gnome-look.org/p/1296407

- Ulauncher themes (GitHub):
	- https://github.com/catppuccin/ulauncher
	- https://github.com/SylEleuth/ulauncher-gruvbox

- Fonts pages (best-effort scraping):
	- https://fonts.google.com/specimen/Bitcount+Single+Ink?selection.family=Bitcount+Single+Ink:wght@100..900
	- https://www.dafont.com/nasalization.font

Notes on best-effort installs:
- GNOME-Look pages sometimes require clicking through and are not always directly linked to downloadable archives; the script will try to find common archive links on the page, but manual download may be required.
- GitHub repos are cloned when possible.
- Font pages are scraped for direct .ttf/.otf links; if a page doesn't expose direct links the fonts may need to be downloaded manually and placed in `~/.local/share/fonts`.

License & CI
------------
This project is licensed under the MIT License (see `LICENSE`). A simple GitHub Actions workflow runs ShellCheck on the main script to catch obvious shell issues.

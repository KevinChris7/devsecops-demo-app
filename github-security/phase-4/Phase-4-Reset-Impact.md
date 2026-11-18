# Phase 4 — What "Reset this PC" Removes

**For:** developers following **Phase 4A Reset**, before they start step 3A.
**Reset type:** Settings → System → Recovery → **Reset PC → Remove everything → Cloud download**.

The reset wipes the Windows drive (C:) and installs a fresh copy of Windows from Microsoft. Read this page first, so nothing you need is lost and no old code survives.

---

## What happens to each folder

| Folder or location | What happens |
| --- | --- |
| `C:\Users\<every user>\`: Desktop, Documents, Downloads, Pictures, Music, Videos | **Deleted**, for every user account on the laptop |
| `C:\Users\<user>\AppData` (app settings, browser profiles, VS Code, Discord, npm cache) | **Deleted.** This is where the worm hides, so this is intended |
| Hidden files in your user folder (`.ssh`, `.gitconfig`, `.npmrc`, `.git-credentials`, `.vscode`) | **Deleted** |
| `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData` | **Deleted.** Every installed program is removed |
| Your own folders directly on C:, such as `C:\projects` or `C:\code` | **Deleted** |
| `C:\Windows` | **Reinstalled fresh** |
| Recycle Bin on C: | **Emptied** |
| Saved passwords (Credential Manager, browsers, Wi-Fi) | **Deleted.** They're treated as stolen anyway |
| **Other drives (D:, E:, …)** | **Kept by default.** Wiped only if you turn on **Delete files from all drives** under *Change settings* during the reset |
| **OneDrive, Google Drive, Dropbox folders** | Local copies are deleted, but the **cloud copy stays and downloads again** when you sign in |
| USB drives and external disks | Not touched. Unplug them before the reset anyway |

## What comes back after the reset

| Item | How |
| --- | --- |
| Windows licence | Reactivates automatically |
| Drivers | Mostly reinstalled by Windows Update. Reinstall the manufacturer's utility only if something doesn't work |
| Microsoft 365, Outlook, Teams | Sign in again. Mail and files are in the cloud |
| OneDrive files | Download again after you sign in (see the warning below) |
| Browser bookmarks and extensions | Come back if browser sync is on. Remove any extension you don't recognise straight away |
| Programs | **You reinstall them**, from official sites only (runbook step 4 for the developer tools) |
| Code | **Fresh clones of cleaned repos only** (runbook step 8). Never from a backup |

**Not affected at all:** your GitHub repos, your email, the authenticator app on your phone, and anything stored in the cloud.

---

## Two things that catch people out

1. **Code on other drives survives the reset.** If you have repos on D: or E:, either delete those code folders yourself before the reset, or turn on **Delete files from all drives** (which wipes everything on those drives). Old repo copies must not survive: they may contain the worm's files.
2. **Code in OneDrive comes back.** Delete code folders from OneDrive **and** its online recycle bin before the reset, or they download again afterwards. The same applies to Google Drive and Dropbox.

**Find every repo folder before the reset.** Run the triage check with your other drives included; its report lists every repo it found:
```powershell
powershell -ExecutionPolicy Bypass -File .\machine-check.ps1 -ExtraPaths D:\,E:\
```
To list your drives first: `Get-PSDrive -PSProvider FileSystem`.

---

## Checklist before you press Reset

- [ ] **Uncommitted work saved as patch files** (runbook step 3A), one per repo. Never copy repo folders.
- [ ] **Personal documents** copied to OneDrive or a company share: documents, photos and PDFs only. No code, scripts (`.bat`, `.cmd`, `.ps1`, `.js`, `.vbs`), installers, browser profile folders or VS Code settings.
- [ ] **Code folders deleted** from other drives and from OneDrive, Google Drive and Dropbox, including their online recycle bins.
- [ ] **Programs you need** listed, with any licence keys (Office signs in with your Microsoft account; others may need a key).
- [ ] **BitLocker recovery key** saved: run `manage-bde -protectors -get C:` as administrator and write down the 48-digit **Numerical Password**, or check it's at [aka.ms/myrecoverykey](https://aka.ms/myrecoverykey).
- [ ] **Company management checked with IT:** if the laptop is joined to the company domain, Entra ID or Intune, it may leave company management after the reset. Ask IT before resetting.
- [ ] **Wi-Fi password** to hand, to reconnect after the reset.
- [ ] **Secret files list** sent to the tech lead (runbook step 1), so those secrets can be changed.
- [ ] **USB drives and external disks unplugged.**

## Time

About one working day in total, of which about half a day you can't use the laptop. The reset and updates run by themselves. See *Time and window* in the Phase 4A runbook.

# MATAM Car System — Installation Guide

**Read this first.** It walks you through the whole setup — from an empty
Windows PC to a running server that clients can log into.

Estimated time: **10 minutes** on the server, **~30 seconds per client**.

---

## What you're installing

Two roles, one deployment:

1. **Server** — one Windows PC that runs the database and serves the web app.
   Anyone on the same network can reach it.
2. **Clients** — any PC / laptop / tablet with a browser. Just open a URL.
   Nothing to install on client machines (a desktop shortcut is optional).

---

## PART A — Set up the SERVER (do this ONCE)

### Prerequisites

- Windows 10 or Windows 11 (64-bit)
- ~50 MB free disk space
- PowerShell 5 or later (already built into every modern Windows)
- Network connectivity for clients to reach the server
- Administrator access on the server PC **only** for step A5 (firewall)

Nothing else — no Python, no Node.js, no Docker.

### A1. Copy the package

You should have received a file named **`matam_server.zip`** (~12 MB).

Copy it to the server PC by any method that works for you: USB stick,
OneDrive, email attachment, network share, etc.

### A2. Extract

1. Right-click `matam_server.zip`
2. Choose **Extract All...**
3. Pick a folder, for example `C:\matam_server\`
4. Click **Extract**

You should now have `C:\matam_server\` (or whatever you chose) containing
files like `pocketbase.exe`, `install_server.cmd`, `pb_public\`, etc.

### A3. (Optional but recommended) Change the admin password

The default password is `matam2026`. It works, but everyone reading this
guide knows it. To change it BEFORE first install:

1. Open `deploy_config.env` in Notepad
2. Find the line `ADMIN_PASSWORD=matam2026`
3. Replace `matam2026` with a private password of your choice
4. Save and close Notepad

**Write down the password somewhere safe.** You'll need it to log in.

You can also change it later via the app or the `change_admin_password.cmd`
script, so this step isn't blocking.

### A4. Run the installer

**Double-click `install_server.cmd`**.

A black window opens. You'll see progress lines:

```
[1/7] Stopping any running PocketBase process...
[2/7] Creating/updating superuser admin@matam.local...
[3/7] Starting PocketBase on 0.0.0.0:8090...
[4/7] Waiting for PocketBase to be ready...
[5/7] Applying collection schema...
[6/7] Registering Windows auto-start...
[7/7] Determining server URLs...
```

When it asks:

> `Create the initial admin manager account? [Y/n]:`

Press **Enter** (defaults to Yes). This creates the first user
`admin@matam.local` that you'll log in with.

At the end it prints URLs like:

```
   http://192.168.1.42:8090/
   http://your-pc-name:8090/
```

**Write these URLs down.** You'll share them with clients.

Press any key to close the window.

### A5. Enable Windows Firewall access

Right-click **`enable_firewall.cmd`** and choose **"Run as administrator"**.

Windows will show a UAC prompt — click **Yes**.

Look for the confirmation:
```
Windows Firewall rule "MATAM_PocketBase" is now active.
```

This step needs admin rights ONLY this one time. Without it, other PCs on
the same network can't reach the server.

### A6. Verify locally

On the SAME PC where you just installed:

1. Open Chrome / Edge / any browser
2. Go to `http://127.0.0.1:8090/`
3. You should see the MATAM login page (Hebrew, red Toyota-style header)
4. Log in with:
   - Email: `admin@matam.local`
   - Password: `matam2026` (or whatever you set in A3)
5. You should see the vehicle inventory dashboard

If this works, the server is fully operational.

### A7. Note the URLs for clients

Any time you need to remind yourself what URL to give clients, double-click
**`show_server_url.cmd`**. It prints the current URLs (hostname and IP).

---

## PART B — Client access (any Windows / Mac / Linux / phone)

There is **no installation** for clients. They just need a browser and
network access to the server.

### B1. Test from any client device

1. Make sure the device is on the same network / VPN as the server
2. Open a browser
3. Type one of the URLs from step A4 (or A7)
4. Press Enter
5. The MATAM login page should appear
6. Log in with a real user account (create these in Part C first)

Press **Ctrl+D** to bookmark the URL. Done.

### B2. (Optional) Put a desktop icon on the client

If you want a clickable icon instead of typing a URL every day:

**Way 1 — pass the URL as an argument (fastest)**

Open PowerShell or Command Prompt in the folder containing
`install_client_shortcut.cmd`, then run:

```
install_client_shortcut.cmd http://your-server-name:8090/
```

Replace `your-server-name` with the actual server URL from A4/A7.

**Way 2 — interactive**

Just double-click `install_client_shortcut.cmd`, paste the URL when
prompted.

Either way, a **MATAM Car System** shortcut appears on the desktop.
Double-click to open the app in the default browser.

**Do NOT type the placeholder examples** shown in the prompt — use the
real URL your server admin gave you.

---

## PART C — Create employee accounts

The first login is the manager (`admin@matam.local`). From there the
manager creates individual accounts for each employee.

1. Log in as `admin@matam.local`
2. In the top navigation bar, click **הנהלת חשבונות ואבטחה**
   (Accounting & Security)
3. Scroll to the **ניהול משתמשים** (User Management) section at the bottom
4. Click **הוסף משתמש חדש** (Add New User)
5. Fill in:
   - **שם תצוגה** (Display name): the employee's name in Hebrew, e.g. `דוד גל`
   - **אימייל**: their login email, e.g. `davidg@matam.local`
   - **תפקיד** (Role):
     - **סוכן (agent)** = normal sales agent, can view/edit cars, no admin
     - **מנהל (manager)** = full access, can create/delete other users
   - **סיסמה**: minimum 8 characters
6. Click **שמור** (Save)
7. Repeat for each employee

Give each employee their email + password. They log in the same way as
you did (the URL from A4/A7).

**Reset a forgotten password**: click the key icon (🔑) next to the user's
row, type a new password, save. Tell them the new password.

**Change a role**: click the key icon, pick a new role from the dropdown,
save.

**Delete an employee (e.g. they left the company)**: click the trash icon
(🗑) next to their row. You cannot delete yourself.

---

## PART D — Day-to-day operation

### The server just works

Once installed, PocketBase runs in the background and starts automatically
every time the server PC is turned on and someone logs in.

### If the server PC is rebooted

Auto-start is enabled by the installer. After Windows finishes booting
and you log into Windows, PocketBase starts within a few seconds.

### If you want to stop the server manually

Open Task Manager, find `pocketbase.exe`, click End Task. Or from cmd:
`taskkill /IM pocketbase.exe /F`.

### If you want to un-register auto-start

Double-click `disable_autostart.cmd`.

### Backing up your data

The entire database is in the `pb_data\` folder. To back up:

1. Close browsers using the app (optional but recommended)
2. Copy `pb_data\` to an external drive / OneDrive / anywhere

To restore: replace `pb_data\` with the backup and restart PocketBase.

### Moving the server to a different PC

1. On the old server, stop PocketBase (`taskkill /IM pocketbase.exe /F`)
2. Copy the entire folder to the new PC
3. On the new PC, double-click `install_server.cmd` — it will detect
   existing data and skip creating a new schema
4. Run `enable_firewall.cmd` as admin on the new PC
5. Get the new URL with `show_server_url.cmd`
6. Update client bookmarks with the new URL

---

## Troubleshooting

### Server side

| Problem | Solution |
|---|---|
| `install_server.cmd` says "pocketbase.exe not found" | You didn't extract the ZIP, or you're running the .cmd from outside the extracted folder. Re-extract, run from inside. |
| `install_server.cmd` says "port 8090 already in use" | Something else is on port 8090. Edit `deploy_config.env`, change `BIND=0.0.0.0:8091` (or any free port), and re-run. Clients now use `:8091` in the URL. |
| Superuser upsert fails | An old PocketBase is still running with a locked database. Kill it: `taskkill /IM pocketbase.exe /F` and re-run. |
| PocketBase starts but browser shows a blank / broken page | The `pb_public\index.html` file is missing from your extraction. Re-extract the ZIP. |
| I forgot the admin password | Double-click `change_admin_password.cmd`, type a new password. |

### Client side

| Problem | Solution |
|---|---|
| Browser says `ERR_CONNECTION_TIMED_OUT` | You're not on the same network as the server, OR the server PC is off, OR the firewall step (A5) wasn't done. |
| Browser says `ERR_NAME_NOT_RESOLVED` | You used the hostname (`http://myserver:8090/`) on a network that doesn't resolve it. Try the IP form (`http://192.168.1.42:8090/`) instead. |
| Login page opens but "Failed to authenticate" | Wrong email or password. Ask the manager to reset your password via Settings → ניהול משתמשים. |
| Page opens but tables are empty and a red banner appears | Old cached copy of the HTML in your browser. Hard-refresh: **Ctrl+Shift+R** (or **Cmd+Shift+R** on Mac). |
| Login works but I can't see the Accounting tab | You're logged in as an agent, not a manager. Only managers see the admin sections. |

### Where to look for more info

- `README_SERVER.md` — full server admin reference
- `client\README_CLIENT.md` — end-user cheat sheet
- PocketBase admin console: `http://<server>:8090/_/` (advanced, use your admin password)

---

## Quick reference card — print this and stick it near the server PC

```
+------------------------------------------------------+
|  MATAM Car System — Server Quick Reference           |
+------------------------------------------------------+
|  Admin email     : admin@matam.local                 |
|  Admin password  : (see deploy_config.env)           |
|  App URL         : http://<server>:8090/             |
|  Admin console   : http://127.0.0.1:8090/_/          |
|                                                      |
|  Start server    : double-click start_pocketbase.cmd |
|  Stop server     : taskkill /IM pocketbase.exe /F    |
|  See client URL  : double-click show_server_url.cmd  |
|  Change my pwd   : change_admin_password.cmd         |
|  Backup data     : copy pb_data\ folder              |
+------------------------------------------------------+
```

---

## Security notes for production use

Before going live at your dealership:

1. **Change the default password** — see step A3
2. **Delete or rename `admin@matam.local`** — create real user accounts
   for the dealership manager and each employee, then log out and delete
   the default account via the admin console
3. **Consider running behind HTTPS** — if the server is reachable from
   outside your LAN, plain HTTP is not safe. PocketBase supports Let's
   Encrypt automatic HTTPS if the PC has a public DNS name
4. **Regular backups** — schedule a copy of `pb_data\` to an off-site
   location (OneDrive, external HDD) at least weekly
5. **Physical security** — the server PC has plain-text access to all
   customer PII and financial data. Keep it in a locked location and
   Bitlocker the drive if possible

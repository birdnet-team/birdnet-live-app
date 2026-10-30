# Uploads

Uploads send finished sessions from many phones into one project folder. A project lead sets up a folder once and hands out a link or a QR code; each contributor pastes or scans it, and from then on any session can be sent to that folder with two taps from the Share dialog. ARU deployments can send every finished session on their own.

Uploads are one-way. The app writes files to the project folder and never reads, lists, or deletes anything there. Deleting a session on your phone leaves the uploaded copy untouched, and nothing is ever uploaded unless you ticked a destination or turned on automatic ARU uploads.

## How It Works

A **destination** is a WebDAV folder the app can write to. Three kinds work out of the box:

- a **Nextcloud File Drop** share, the recommended choice for most projects;
- any **WebDAV address** with a user name and password, for example a folder in your own cloud account or an institutional server;
- the **reference drop server** that ships with BirdNET Live, for leads who want per-contributor tokens and a ready-made CSV export (see the [Developer Guide](../developer/upload-drop-server.md)).

Every upload is **one ZIP file per session**, named like the Share export, for example `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. It always holds the session's JSON record and, depending on what you tick, the audio, the detection tables, the HTML report, and the app metadata file. The ZIP lands in a folder named by your **upload ID**, an eight-character code the app derives from a random identity it keeps for this install. The project lead's folder therefore looks like this:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

The `.birdnet-live` folder holds one small registration file per device, written by the connection test. Nextcloud hides it unless "Show hidden files" is on. It carries the upload ID, the app version, the platform, and the optional **participant identifier** (a name, email, or participant number) a contributor entered, so the lead can tell who is behind each code without any name ever becoming a folder name. The same identifier is written into the JSON record of every uploaded session.

## For Project Leads

### Option A: a Nextcloud File Drop

1. In Nextcloud, create a folder for the project, for example `Spring Survey 2027`.
2. Open its sharing panel, create a **share link**, and set its permissions to **File drop (upload only)**. Contributors can then add files but never see what others sent.
3. Set a **password** on the link. Without one, anyone who finds the link can upload into the folder. A File Drop cannot be read even then, so a missing password is a choice the app accepts without complaint.
4. Optionally set an expiration date for the end of the project.
5. Copy the share link. It looks like `https://cloud.example.org/s/AbCdEf123456`.

The app turns that link into the share's WebDAV endpoint itself; contributors never see a WebDAV address. A File Drop never overwrites: when a contributor uploads the same session again, Nextcloud keeps the older copy under a numbered name, so the newest file is the one without a number.

Nextcloud shares with **upload and editing** permission also work, but the app will warn contributors that the credential can list the folder, because anyone with the link can then read everyone else's data. Read-only shares are refused by the connection test.

### Option B: your own WebDAV folder

Any WebDAV server works: a folder in a personal cloud account, an institutional file server, ownCloud, or Nextcloud with a regular account. Contributors enter the address plus a user name and password under **Advanced** when joining. For a Nextcloud or ownCloud account use an **app password** from the account's security settings, never the login password; when only a host name is given, the app also tries the usual Nextcloud and ownCloud locations on that host.

Such a credential can usually read the folder, so the connection test shows a warning. Prefer a write-only setup when contributors are not all in one team.

### Option C: the reference drop server

`tools/webdav_drop_server` in the source repository is a small Python server with per-contributor tokens you can revoke, a `collect` command that merges every uploaded JSON record into `sessions.csv`, `detections.csv`, and `species_summary.csv`, and an `invite` command that prints a join link and QR code. Setup and deployment are described in the [Developer Guide](../developer/upload-drop-server.md).

### Making the join link and QR code

A join link carries everything a contributor needs in one piece: the destination, the credential, a project name, and your suggested defaults. Open the [join page](../join.md) on this site and fill in:

- **Share link or WebDAV address**: the Nextcloud share link from above, or the WebDAV folder address.
- **User name**: leave empty for a Nextcloud share link.
- **Share password or token**: the share password, or the account or token secret.
- **Project name shown in the app**: what contributors will see as the destination's name. They can rename it, but this is the default.
- **Suggest including audio** and **Suggest Wi-Fi only**: the defaults for the destination's switches.

Press **Build link and QR code**. Everything happens in your browser; nothing is sent anywhere. The secret sits in the part of the link after `#`, which browsers never transmit to the web server hosting the page.

Alternatively, join the destination on your own phone first (see below), then open the destination in **Settings → Export & Sync → Upload destinations** and tap **Show join code**. The app shows the same kind of QR code with a **Copy link** button.

### Handing it out

Print the QR code on the field sheet, show it on a screen at the briefing, or send the link by message. **Treat the link and the code like a password**: anyone holding it can upload into your project. If it leaks, change the share password or revoke the token and hand out a new code.

When a contributor scans the code with their phone camera, the browser opens a small landing page with an **Open in BirdNET Live** button, which lands in the app's Add destination screen with the link filled in. Pasting the link directly into that screen works just the same.

### What you will see

One folder per device, one ZIP per session, and the hidden `.birdnet-live` registrations. Open a ZIP to find the JSON record (always present), and the tables, report, and audio the contributor chose to include. To learn which person is behind an upload ID, read the registration file for that code or the `meta.participant` field inside any of its JSON records. With the reference drop server, `collect` does this for you and writes a `participant` column.

## For Contributors

### Joining a destination

1. Open **Settings → Export & Sync → Upload destinations** and tap **Add destination**. Scanning a project's QR code with your camera, or tapping a join link you received, takes you to the same screen with the link already filled in.
2. Paste the join link, the Nextcloud share link, or a WebDAV address into **Join link or server address**. The **Paste** button takes it from the clipboard.
3. Optionally enter a **Participant, name, or email**. It is saved with every upload so the project lead knows who sent it, and it never appears in folder names. Below the field the app shows **Your upload ID**, the folder your uploads will land in.
4. For a plain WebDAV address, open **Advanced** and enter the **User name** and **Password or token**. A Nextcloud share link needs neither; if the share has a password, enter it as the password.
5. Tap **Test connection**. The app contacts the server, creates the hidden registration folder, checks whether the credential can list the folder, and writes your registration file. The result is one sentence: **Connection works**, a warning you should read, or a failure with the likely fix.
6. Give the destination a **Destination name** (prefilled from the join link), decide whether to **Upload on Wi-Fi only**, and tap **Save destination**.

Nothing is stored until the test has passed. The credential goes into the device keychain, never into exported data.

Warnings worth understanding:

- **This credential can list the destination** means the share or account can read other contributors' data. Uploads work, but ask the lead for a File Drop or a write-only token if the project involves people outside your team.
- **This share has no password and can be listed** combines the two risks: anyone with the link can read everything. Ask the lead to set a password or use a File Drop.
- **This server does not allow folders** is informational: uploads use flat file names such as `4ee91c8f__BirdNET_Live_….zip` instead of a folder.

### The destination screen

Tapping a destination in the list opens its screen with the server address, when it was added and last used, and these controls:

- **Rename** (the pencil in the app bar) changes the name shown in the app.
- **Upload on Wi-Fi only** holds uploads while the phone is on cellular.
- **Upload all sessions automatically** queues every finished session from any mode for this destination without asking, using the Export & Sync defaults for Audio and Metadata. While it is on, **Upload ARU sessions automatically** stays on too. Discarding a session in Session Review afterwards cancels an upload that has not started, but anything already sent stays on the server.
- **Upload ARU sessions automatically** queues every finished ARU Session for this destination without asking (see below).
- **Test connection** repeats the connection test, for example after the lead changed the password.
- **Show join code** displays a QR code plus **Copy link** so a second phone can join the same destination.
- **Remove destination** forgets the destination and its credential and drops pending uploads to it. Sessions already uploaded stay on the server.

The first entry of the destination list is **Your upload ID**, with the participant identifier under it; tap it to change the identifier. Changing it does not move anything on the server, since folders are named by the ID.

### Uploading a session

Uploads start from the same **Share** action you already use, in three places:

- the **three-dot menu** (:app-moreVert:) of a session card in Session Library;
- the **Share** button after selecting several sessions in Session Library;
- the **Share** icon (:app-share:) in the Session Review toolbar.

The Share dialog has two tabs once at least one destination exists:

- **Content** chooses what the export holds: **Audio** (the full recording, or the detection clips when only clips were kept) and **Metadata** (the tables, report, and app metadata file enabled under Export & Sync). The boxes start out matching your settings and apply to this share only.
- **Send to** lists **Share sheet** (other apps, files, messages) and one box per destination. The badge on the tab counts the ticked destinations. Destinations ticked last time are pre-ticked, except those this session already went to: they start unticked and show **Uploaded** with the date and **Tick to upload again**. When the dialog opens, the app quietly checks each destination; if the server states that it would refuse the upload, for example because the password changed or the share was removed, the row turns red with the reason.

Untick **Share sheet** and the button reads **Upload**; with both ticked it reads **Share and upload**. A snackbar confirms how many sessions were queued. A session always goes into the queue first and is uploaded in the background, so you can keep working.

### Following an upload

The session card in Session Library shows the state as the first line under the session title: **Queued**, **Waiting for Wi-Fi**, **Waiting for a network**, **Uploading…**, **Uploaded** with the date, or a failure. Tap the line for the per-destination list with **Retry now** and **Remove from queue**. Session Review shows the same state as a cloud icon in the app bar; tapping it opens the same list.

Failed uploads retry on their own with growing delays, up to six hours apart, for up to thirty attempts. **Failed, will retry** means the app will try again. **Upload failed. Check the destination settings.** means the server refused and a retry cannot help: the password changed, uploads were switched off, or the destination was removed. Open the destination, run **Test connection**, and remove and re-add it if the credential changed.

The line and the icon only appear while at least one destination the session was sent to still exists in Settings. Remove the destination and they disappear, because "uploaded" is no longer a fact about any destination you have.

### What runs in the background

Queued uploads run while the app is open and whenever it returns to the foreground. On Android they also run with the app closed: the system starts them once a suitable network is available, Wi-Fi when the destination asks for it, and keeps retrying until the queue is empty. On iOS uploads run while the app is open.

### Uploading a session again

Uploading the same session again, for example after correcting detections in Session Review, writes the same file name into the same folder. Servers that allow it replace the file; a Nextcloud File Drop keeps the older copy under a numbered name instead. Either way the project lead gets the newest version, and nothing is deleted.

## ARU Mode

Field deployments produce many sessions, often while nobody is at the phone. Turn on **Upload ARU sessions automatically** on a destination, and every finished ARU Session is queued for it without a dialog, using the Export & Sync defaults for Audio and Metadata. A deployment that saves each cycle as its own session uploads cycle by cycle; the combined deployment session is not uploaded twice.

Leave **Upload on Wi-Fi only** on for a station on a cellular plan unless the plan can take the audio, and consider recording **Detections Only** or **Off** when the audio would be too large to send. The uploads then flow out whenever the phone sees a suitable network, also while the app is in the background on Android.

## Two Worked Examples

### A weekend survey with a Nextcloud File Drop

The lead creates a `Birdathon 2027` folder in the university Nextcloud, shares it as a File Drop with a password, pastes the share link and password into the join page, names the project, and prints the QR code on the briefing sheet. Twenty volunteers scan it on Saturday morning, enter their name as participant identifier, pass the connection test, and save.

On Sunday evening each volunteer opens Session Library, selects the weekend's sessions, taps Share, leaves the project ticked under Send to, and taps **Upload**. The uploads wait for Wi-Fi at home and finish overnight. On Monday the lead finds twenty folders named by upload ID, each with a handful of ZIPs, and reads the volunteers' names from the hidden registration files or the `meta.participant` field inside the JSON records.

### Corrections in Session Review, then an ARU station

A contributor reviews a session, removes two false detections, adds a species by hand, and saves. The cloud icon in the Session Review app bar shows that the session was uploaded on Saturday. They tap the Share icon in the toolbar, tick the project under Send to, where it starts unticked and says **Uploaded** with the date, and press **Upload**. The corrected ZIP replaces the earlier one, or lands beside it with a numbered name on a File Drop.

The same contributor leaves a phone as an ARU station at a reed bed with a Wi-Fi hotspot in the hut. They join the project destination on that phone, turn on **Upload ARU sessions automatically** and keep **Upload on Wi-Fi only** on. Every morning the finished night cycles are queued and uploaded while the station idles; the lead sees new ZIPs appear under that phone's upload ID without anyone touching it.

## Privacy and Responsibility

Upload destinations are run by project organizers, not by the BirdNET team. The folder, the server, who can read it, and how long the data is kept are governed by the organizer's own privacy and security rules; ask them for details before you join. BirdNET Live only writes what you chose to send and keeps the credential in your device's keychain.

An upload contains what a Share would contain: the session's JSON record with detections, times, coordinates, the observer name and location name if set, the device's upload ID, the participant identifier you entered, and the app version; plus the audio, tables, and report you ticked. Review the Content tab before sending, and leave out audio when a recording may contain voices or anything else you would not hand to the project. **You are responsible for what you upload.** Do not upload or share data you consider private or confidential, and do not upload recordings you are not allowed to pass on.

## Troubleshooting

| Message | What it means | What to do |
| --- | --- | --- |
| This does not look like a link or server address. | The text is not a URL. | Paste the whole join link, share link, or `https://` address. |
| The server rejected the credentials. | Wrong or missing password, or a removed share. Nextcloud answers this way for deleted shares too. | Use the share password or an app password; ask the lead whether the share still exists. |
| This address is not a WebDAV endpoint. | You pasted the web page of a folder, not a share link or WebDAV address. | Paste the share link (`…/s/…`) or the WebDAV address. |
| Uploads are not allowed here. | The share is read-only. | Ask the lead for a File Drop or upload permission. |
| The folder does not exist on the server. | The address points at nothing, or the folder was deleted. | Check the address with the lead. |
| The server's certificate could not be verified. | Self-signed or broken TLS. | Ask the lead for an address with a valid certificate. |
| This address uses plain HTTP. | Unencrypted connection outside your local network. | Use an `https://` address. |
| Waiting for Wi-Fi | The destination is set to Wi-Fi only and the phone is on cellular. | Wait, or switch the destination's Wi-Fi only switch off. |
| Failed, will retry | A temporary problem such as a dropped connection or a server error. | Nothing; the app retries on its own. **Retry now** forces an attempt. |
| Upload failed. Check the destination settings. | The server refused for a reason a retry cannot fix. | Open the destination, run **Test connection**, and remove and re-add it if the credential changed. |
| The credential for this destination is missing from the device keychain. | The keychain entry was lost, for example after a restore to a new phone. | Remove the destination and add it again. |

See also the [Upload destinations](settings.md#upload-destinations) setting and the [Session Library](session-library.md) and [Session Review](session-review.md) guides.

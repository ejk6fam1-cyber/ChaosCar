# Putting Chaos Car online

When this is done, you and anyone you send a link to can race in a browser: one player creates a race,
gets a 4-letter code, and the others join with it. It costs nothing and takes about 20 minutes, once.

There are two pieces:

| Piece | What it is | Where it lives |
|---|---|---|
| **The game** | the browser version everyone plays | GitHub Pages (free), built automatically |
| **The server** | a copy of the game with no screen that runs the races | Render (free), built automatically |

Both rebuild by themselves whenever new code is pushed to GitHub, so updates are just "push and refresh".

---

## 1. Put the project on GitHub

1. Make a free account at <https://github.com> if you don't have one.
2. Click **New repository**. Name it `chaos-car`, set it to **Public** (free GitHub Pages needs a public
   repo), and create it **empty** (no README).
3. Get the files into it, either:
   - **Easiest:** tell Claude the repo name (e.g. `yourname/chaos-car`) and let it push the code, or
   - **By hand:** on the repo page click **uploading an existing file**, drag in everything from this
     folder (including the hidden `.github` folder), and commit.

## 2. Start the server on Render

1. Make a free account at <https://render.com> (signing in with GitHub is quickest).
2. Click **New -> Blueprint**, pick your `chaos-car` repo, and click **Apply**. Render reads
   `render.yaml`, which asks for one free web service called `chaos-car`.
3. Wait for the first build to finish (5-10 minutes the first time; it downloads Godot). The log should
   end with `Chaos Car server listening on port 10000`.
4. Copy the service's address from the top of its page, e.g. `https://chaos-car-ab12.onrender.com`.
   **Your server address is the same thing starting with `wss://` instead of `https://`**:
   `wss://chaos-car-ab12.onrender.com`

The free server goes to sleep after 15 minutes with nobody playing. The first person to connect after
that waits about a minute while it wakes up (the game says so).

## 3. Turn on the browser game (GitHub Pages)

1. In your GitHub repo: **Settings -> Pages**. Under **Build and deployment -> Source**, choose
   **GitHub Actions**.
2. **Settings -> Secrets and variables -> Actions -> Variables tab -> New repository variable**:
   - Name: `SERVER_URL`
   - Value: your `wss://...` server address from step 2
3. **Actions** tab -> **Build web game** -> **Run workflow** (it also runs by itself on every push).
4. When it goes green (2-3 minutes), the game is at
   **`https://YOUR-GITHUB-NAME.github.io/chaos-car/`**

## 4. Race

1. Open the game link, click **Online Race**, type your name, click **Create a Race**.
2. Send your brother the game link and the 4-letter **race code** from the lobby.
3. He opens the link, clicks **Online Race**, types the code, and clicks **Join**.
4. The host picks laps (1-20) and the grid (**Random spots** or **Pick your spot**); with pick-your-spot,
   everyone chooses their own starting spot (1 = pole). Then the host clicks **Start Race**.
   Up to 4 people per race; the computer drives the other cars.

The server address is already filled in on the online screen (it comes from `SERVER_URL`).

---

## Updating the game later

Ask Claude for a change. Once it pushes to GitHub, both the server (Render) and the browser game (GitHub
Pages) rebuild on their own. Refresh the page a few minutes later. If someone has an old page open, the
game tells them to refresh when the two don't match.

## Playing on your own computer

- **Single player:** open the project in Godot 4.7 and press F5, or use the browser version.
- **Testing online locally:** run a server with
  `godot --headless --path . -- --server` (it listens on port 9080), then in the game use the server
  address `ws://localhost:9080`.

## If something goes wrong

- **"Couldn't reach the server"**: check the address starts with `wss://` (not `https://`), and wait a
  minute in case the server was asleep. On Render, check the service's log.
- **The Actions build fails at "Download Godot"**: Godot's release file names occasionally change. Open
  `.github/workflows/web.yml` and the `Dockerfile` and check `GODOT_VERSION` matches a release on
  <https://github.com/godotengine/godot/releases> (currently `4.7-stable`).
- **The page loads but stays black**: open the browser's developer console (F12) and send Claude what it
  says.

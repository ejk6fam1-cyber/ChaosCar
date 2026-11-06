# Chaos Car online server: a headless copy of the game that hosts race rooms over WebSockets.
# Render builds this automatically from the repo (see render.yaml).
FROM debian:bookworm-slim
ARG GODOT_VERSION=4.7-stable
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" -O /tmp/godot.zip \
 && unzip -q /tmp/godot.zip -d /opt \
 && mv "/opt/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
 && rm /tmp/godot.zip
WORKDIR /app
COPY . .
# import the project once at build time so the server starts fast
RUN godot --headless --path /app --import || true
ENV CHAOS_SERVER=1
# Render tells us which port to use in $PORT (main.gd reads it)
CMD ["godot", "--headless", "--path", "/app", "--max-fps", "60"]

var id = "dQw4w9WgXcQ";

(async () => {
    try {
        const req = await fetch("LATEST_VIDEO_ID");

        if (req.ok) {
            id = await req.text();
        }
    } catch (e) {}

    latest_video_embed.src = `https://youtube.com/embed/${id}`;
})();

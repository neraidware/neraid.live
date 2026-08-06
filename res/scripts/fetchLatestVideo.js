(async () => {
    try {
        const req = await fetch("LATEST_VIDEO_ID");

        if (req.ok) {
            const id = (await req.text()).trim();

            if (/^[A-Za-z0-9_-]{11}$/.test(id)) {
                latest_video_embed.src = `https://youtube.com/embed/${id}`;
            }
        }
    } catch (e) {}
})();

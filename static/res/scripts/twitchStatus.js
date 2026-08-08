const twitch_status = document.getElementById("twitch-status");
const twitch_pre = document.querySelector(".twitch-pre");
const twitch_post = document.querySelector(".twitch-post");

function setTwitchLiveStatus(live) {
    twitch_status.classList.toggle("is-live", live);
    twitch_pre.textContent = live ? "em " : "não estou em ";
    twitch_post.textContent = live ? " nesse exato momento" : " agora";
}

setTwitchLiveStatus(false);

const twitch_embed = new Twitch.Embed("twitch_embed", {
    channel: "neraid_live",
    parent: ["neraid.live", "www.neraid.live", "localhost", "127.0.0.1"],
    autoplay: false,
    muted: true,
    layout: "video",
    width: 560,
    height: 315,
});

twitch_embed.addEventListener(Twitch.Embed.VIDEO_READY, () => {
    const twitch_player = twitch_embed.getPlayer();
    twitch_player.addEventListener(Twitch.Player.ONLINE, () => setTwitchLiveStatus(true));
    twitch_player.addEventListener(Twitch.Player.OFFLINE, () => setTwitchLiveStatus(false));
});

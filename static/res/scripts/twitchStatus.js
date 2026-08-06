const twitch_pre = document.getElementById("twitch-pre");
const twitch_post = document.getElementById("twitch-post");

function setTwitchLiveStatus(live) {
    twitch_pre.textContent = live ? "em " : "não estou em ";
    twitch_post.textContent = live ? " nesse exato momento" : " agora";
}

setTwitchLiveStatus(false);

const twitch_player = new Twitch.Player("twitch_embed", {
    channel: "neraid_live",
    parent: ["neraid.live", "localhost"],
    autoplay: false,
    muted: true,
    width: 560,
    height: 315,
});

twitch_player.addEventListener(Twitch.Player.ONLINE, () => setTwitchLiveStatus(true));
twitch_player.addEventListener(Twitch.Player.OFFLINE, () => setTwitchLiveStatus(false));

package main

import "core:log"
import "core:os"
import mustache "./vendor/odin-mustache"

Data :: struct {
    social: []struct {
        title: string,
        icon_url: string,
        url: string,
    }
}

main :: proc() {
    data := Data{
        social = {
            {
                title = "YouTube",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraid",
            },
            {
                title = "YouTube (VODS)",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraid_live",
            },
            {
                title = "Twitch",
                icon_url = "res/icons/twitch.png",
                url = "https://twitch.tv/neraid_live",
            },
            {
                title = "Codeberg",
                icon_url = "res/icons/github.png",
                url = "https://codeberg.org/neraid",
            },
            {
                title = "Instagram",
                icon_url = "res/icons/instagram.png",
                url = "https://instagram.com/neraid.live",
            },
            {
                title = "TikTok",
                icon_url = "res/icons/tiktok.png",
                url = "https://tiktok.com/@neraid.live",
            },
            {
                title = "Twitter",
                icon_url = "res/icons/x.png",
                url = "https://x.com/neraid_live",
            },
            {
                title = "Threads",
                icon_url = "res/icons/instagram.png",
                url = "https://www.threads.com/@neraid.live",
            },
        }
    }

    os.copy_directory_all("deploy/", "static/")

    s, err := mustache.render_from_filename("templates/index.html", data)

    if err != nil {
        log.error(err)
        os.exit(1)
    }

    write_err := os.write_entire_file("deploy/index.html", transmute([]u8)s)

    if write_err != nil {
        log.error(write_err)
        os.exit(1)
    }
}

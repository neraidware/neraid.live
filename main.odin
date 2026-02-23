package main

import "core:fmt"
import "core:log"
import "core:os"
import mustache "./vendor/odin-mustache"

Data :: struct {
    social: []struct {
        title: string,
        icon_url: string,
        url: string,
        middle_finger: bool,
    }
}

main :: proc() {
    data := Data{
        social = {
            {
                title = "my projects on github",
                icon_url = "res/icons/github.png",
                url = "https://github.com/neraid-live/",
            },
            {
                title = "streaming on twitch",
                icon_url = "res/icons/twitch.png",
                url = "https://twitch.tv/neraid_live",
            },
            {
                title = "i post on youtube!!",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraid",
            },
            {
                title = "practice charity :)",
                icon_url = "res/icons/patreon.png",
                url = "https://patreon.com/neraid_live",
            },
            {
                title = "toXic",
                icon_url = "res/icons/x.png",
                url = "https://x.com/neraid_live",
                middle_finger = true,
            },
            {
                title = "a peek into my life",
                icon_url = "res/icons/instagram.png",
                url = "https://instagram.com/neraid.live",
            },
            {
                title = "short attention span tok",
                icon_url = "res/icons/tiktok.png",
                url = "https://tiktok.com/@neraid.live",
            },
        }
    }

    os.copy_directory_all("deploy/", "static/")

    s, err := mustache.render_from_filename("templates/index.html", data)

    if err != nil {
        log.error(err)
        return
    }

    write_err := os.write_entire_file("deploy/index.html", transmute([]u8)s)

    if write_err != nil {
        fmt.println(err)
    }
}

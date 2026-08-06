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
                title = "@neraid",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraid",
            },
            {
                title = "@neraidware",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraidware",
            },
            {
                title = "neraid_live",
                icon_url = "res/icons/twitch.png",
                url = "https://twitch.tv/neraid_live",
            },
            {
                title = "@neraidware",
                icon_url = "res/icons/github.png",
                url = "https://github.com/neraidware",
            },
            {
                title = "@neraid",
                icon_url = "res/icons/github.png",
                url = "https://codeberg.org/neraid",
            },
            {
                title = "@neraid.live",
                icon_url = "res/icons/instagram.png",
                url = "https://instagram.com/neraid.live",
            },
            {
                title = "@neraid.live",
                icon_url = "res/icons/tiktok.png",
                url = "https://tiktok.com/@neraid.live",
            },
            {
                title = "@neraid_live",
                icon_url = "res/icons/x.png",
                url = "https://x.com/neraid_live",
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

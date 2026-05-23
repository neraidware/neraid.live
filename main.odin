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
    }
}

main :: proc() {
    data := Data{
        social = {
            {
                title = "meus projetos open source",
                icon_url = "res/icons/github.png",
                url = "https://codeberg.org/neraid",
            },
            {
                title = "lives na twitch",
                icon_url = "res/icons/twitch.png",
                url = "https://twitch.tv/neraid_live",
            },
            {
                title = "meu canal no youtube",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraid",
            },
            {
                title = "o instagram",
                icon_url = "res/icons/instagram.png",
                url = "https://instagram.com/neraid.live",
            },
            {
                title = "meu tuktuk",
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

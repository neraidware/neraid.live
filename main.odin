package main

import "core:fmt"
import "core:log"
import "core:os"
import "core:sort"
import "core:strings"
import mustache "./vendor/odin-mustache"

Data :: struct {
    social: []struct {
        title: string,
        icon_url: string,
        url: string,
        hand: string,
    }
}

ArticlePage_Data :: struct {
    title: string,
    content: string,
}

Article :: struct {
    date: string,
    slug: string,
    url: string,
    title: string,
    content: string,
}

Blog_Data :: struct {
    entries: []Article,
}

main :: proc() {
    data := Data{
        social = {
            {
                title = "@neraid",
                icon_url = "res/icons/youtube.png",
                url = "https://youtube.com/@neraid",
                hand = "res/icons/pointing_hand.png",
            },
            {
                title = "neraid_live",
                icon_url = "res/icons/twitch.png",
                url = "https://twitch.tv/neraid_live",
                hand = "res/icons/pointing_hand.png",
            },
            {
                title = "@neraid.live",
                icon_url = "res/icons/instagram.png",
                url = "https://instagram.com/neraid.live",
                hand = "res/icons/pointing_hand.png",
            },
            {
                title = "@neraid.live",
                icon_url = "res/icons/tiktok.png",
                url = "https://tiktok.com/@neraid.live",
                hand = "res/icons/pointing_hand.png",
            },
            {
                title = "@neraid_live",
                icon_url = "res/icons/x.png",
                url = "https://x.com/neraid_live",
                hand = "res/icons/middle_finger.png",
            },
            {
                title = "contato@neraid.live",
                icon_url = "res/icons/email.png",
                url = "mailto:contato@neraid.live",
                hand = "res/icons/pointing_hand.png",
            },
        }
    }

    os.copy_directory_all("deploy/", "static/")
    _ = os.remove_all("deploy/blog")

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

    generate_blog()
}

// ------------------------------------------------------------------
// blog
// ------------------------------------------------------------------

generate_blog :: proc() {
    files := make([dynamic]string)
    defer delete(files)
    find_norg_files("static/blog", &files)

    articles := make([dynamic]Article)
    defer delete(articles)

    for f in files {
        data, err := os.read_entire_file(f, context.allocator)
        if err != nil {
            continue
        }

        html, title := render_norg(string(data))
        date, slug, kind := parse_blog_path(f)
        if slug == "" {
            continue
        }
        if title == "" {
            title = slug
        }

        out_dir := fmt.tprintf("deploy/blog/%s/%s", date, slug)
        os.make_directory_all(out_dir)

        body, rerr := mustache.render_from_filename("templates/article.html", ArticlePage_Data{title = title, content = html})
        if rerr != nil {
            log.error(rerr)
            os.exit(1)
        }
        if werr := os.write_entire_file(fmt.tprintf("%s/index.html", out_dir), transmute([]u8)body); werr != nil {
            log.error(werr)
            os.exit(1)
        }

        append(&articles, Article{
            date = date,
            slug = slug,
            url = fmt.tprintf("/blog/%s/%s/", date, slug),
            title = title,
        })
    }

    sort.quick_sort_proc(articles[:], proc(a, b: Article) -> int {
        if a.date == b.date {
            return strings.compare(b.slug, a.slug)
        }
        return strings.compare(b.date, a.date)
    })

    index, ierr := mustache.render_from_filename("templates/blog.html", Blog_Data{entries = articles[:]})
    if ierr != nil {
        log.error(ierr)
        os.exit(1)
    }
    os.make_directory_all("deploy/blog")
    if werr := os.write_entire_file("deploy/blog/index.html", transmute([]u8)index); werr != nil {
        log.error(werr)
        os.exit(1)
    }
}

find_norg_files :: proc(dir: string, acc: ^[dynamic]string) {
    entries, err := os.read_all_directory_by_path(dir, context.allocator)
    if err != nil {
        return
    }
    defer delete(entries)

    for e in entries {
        if e.type == .Directory {
            find_norg_files(e.fullpath, acc)
        } else if strings.has_suffix(e.name, ".norg") {
            append(acc, e.fullpath)
        }
    }
}

parse_blog_path :: proc(path: string) -> (date, slug, kind: string) {
    parts := strings.split(path, "/")
    defer delete(parts)

    n := len(parts)
    if n < 7 {
        return "", "", ""
    }

    date = fmt.tprintf("%s/%s/%s", parts[n - 5], parts[n - 4], parts[n - 3])
    slug = parts[n - 2]
    kind = parts[n - 1]
    return
}

// ------------------------------------------------------------------
// norg subset renderer
// block: *..******* headings, - unordered, ~ ordered, ___ hr,
//        @code..@end verbatim blocks, paragraphs
// inline: *bold*, /italic/, _underline_, -strike-, ^super^, `code`,
//         {url}[text] and [text]{url} links, \ escapes
// ------------------------------------------------------------------

INDENT := "            "
LI_INDENT := "                "

render_norg :: proc(content: string) -> (html, title: string) {
    b := strings.builder_make()
    pb := strings.builder_make()
    defer strings.builder_destroy(&b)
    defer strings.builder_destroy(&pb)

    in_code, in_ul, in_ol, in_p := false, false, false, false
    in_meta := false
    first_h1 := true
    code_lang := ""

    lines := strings.split_lines(content, context.allocator)
    defer delete(lines)

    for line in lines {
        trimmed := strings.trim_space(line)

        if trimmed == "@document.meta" {
            close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
            in_meta = true
            continue
        }

        if in_meta {
            if trimmed == "@end" {
                in_meta = false
                continue
            }
            if idx := strings.index_byte(trimmed, ':'); idx != -1 {
                key := strings.trim_space(trimmed[:idx])
                if key == "title" && title == "" {
                    title = strings.trim_space(trimmed[idx + 1:])
                }
            }
            continue
        }

        if strings.has_prefix(trimmed, "@code") {
            close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
            lang := strings.trim_space(trimmed[5:])
            strings.write_string(&b, INDENT)
            strings.write_string(&b, "<div class=\"codeblock\">\n")
            if len(lang) > 0 {
                strings.write_string(&b, LI_INDENT)
                strings.write_string(&b, "<div class=\"code-lang\">")
                escape_into(&b, lang)
                strings.write_string(&b, "</div>\n")
            }
            strings.write_string(&b, INDENT)
            strings.write_string(&b, "<div class=\"code-text\">\n")
            in_code = true
            code_lang = lang
            continue
        }

        if trimmed == "@end" {
            strings.write_string(&b, "</div>\n")
            strings.write_string(&b, "</div>\n")
            in_code = false
            continue
        }

        if in_code {
            highlight_line(&b, line, code_lang)
            strings.write_byte(&b, '\n')
            continue
        }

        if len(trimmed) == 0 {
            close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
            continue
        }

        if is_hr(trimmed) {
            close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
            strings.write_string(&b, INDENT)
            strings.write_string(&b, "<hr>\n")
            continue
        }

        if level, ok := heading_level(trimmed); ok {
            close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
            inner := strings.trim_left(trimmed[level:], " ")
            if level == 1 && first_h1 {
                first_h1 = false
                if title == "" {
                    title = inner
                    continue
                }
            }
            level += 1
            if level > 6 {
                level = 6
            }
            strings.write_string(&b, INDENT)
            fmt.sbprintf(&b, "<h%d>", level)
            render_inline(&b, inner)
            fmt.sbprintf(&b, "</h%d>\n", level)
            continue
        }

        if strings.has_prefix(trimmed, "- ") {
            if !in_ul {
                close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
                strings.write_string(&b, INDENT)
                strings.write_string(&b, "<ul>\n")
                in_ul = true
            }
            strings.write_string(&b, LI_INDENT)
            strings.write_string(&b, "<li>")
            render_inline(&b, trimmed[2:])
            strings.write_string(&b, "</li>\n")
            continue
        }

        if strings.has_prefix(trimmed, "~ ") {
            if !in_ol {
                close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
                strings.write_string(&b, INDENT)
                strings.write_string(&b, "<ol>\n")
                in_ol = true
            }
            strings.write_string(&b, LI_INDENT)
            strings.write_string(&b, "<li>")
            render_inline(&b, trimmed[2:])
            strings.write_string(&b, "</li>\n")
            continue
        }

        if !in_p {
            in_p = true
        }
        if len(pb.buf) > 0 {
            strings.write_byte(&pb, ' ')
        }
        render_inline(&pb, trimmed)
    }

    close_blocks(&b, &pb, &in_code, &in_ul, &in_ol, &in_p)
    return strings.clone(strings.to_string(b)), title
}

close_blocks :: proc(b, pb: ^strings.Builder, in_code, in_ul, in_ol, in_p: ^bool) {
    if in_code^ {
        strings.write_string(b, "</div>\n")
        strings.write_string(b, "</div>\n")
        in_code^ = false
    }
    if in_ul^ {
        strings.write_string(b, INDENT)
        strings.write_string(b, "</ul>\n")
        in_ul^ = false
    }
    if in_ol^ {
        strings.write_string(b, INDENT)
        strings.write_string(b, "</ol>\n")
        in_ol^ = false
    }
    if in_p^ {
        strings.write_string(b, INDENT)
        strings.write_string(b, "<p>")
        strings.write_string(b, strings.to_string(pb^))
        strings.write_string(b, "</p>\n")
        strings.builder_reset(pb)
        in_p^ = false
    }
}

heading_level :: proc(s: string) -> (level: int, ok: bool) {
    n := 0
    for n < len(s) && s[n] == '*' {
        n += 1
    }
    if n == 0 || (n < len(s) && s[n] != ' ') {
        return 0, false
    }
    return n, true
}

is_hr :: proc(s: string) -> bool {
    if len(s) < 3 {
        return false
    }
    for c in s {
        if c != '_' {
            return false
        }
    }
    return true
}

render_inline :: proc(b: ^strings.Builder, s: string) {
    i := 0
    for i < len(s) {
        c := s[i]
        switch c {
        case '\\':
            if i + 1 < len(s) {
                strings.write_byte(b, s[i + 1])
                i += 2
                continue
            }
            strings.write_byte(b, c)
        case '{':
            end := strings.index_byte(s[i:], '}')
            if end != -1 {
                loc := s[i + 1:i + end]
                j := i + end + 1
                desc := ""
                if j < len(s) && s[j] == '[' {
                    if dend := strings.index_byte(s[j:], ']'); dend != -1 {
                        desc = s[j + 1:j + dend]
                        j += dend + 1
                    }
                }
                if strings.has_prefix(loc, "*") {
                    render_inline(b, strings.trim_left(loc[1:], " "))
                } else if desc == "" {
                    fmt.sbprintf(b, "<a href=\"%s\">", loc)
                    escape_into(b, loc)
                    strings.write_string(b, "</a>")
                } else {
                    strings.write_string(b, "<a href=\"")
                    escape_into(b, loc)
                    strings.write_string(b, "\">")
                    render_inline(b, desc)
                    strings.write_string(b, "</a>")
                }
                i = j
                continue
            }
            strings.write_byte(b, c)
        case '[':
            close := strings.index(s[i:], "]{")
            if close != -1 {
                end := strings.index_byte(s[i + close + 2:], '}')
                if end != -1 {
                    desc := s[i + 1:i + close]
                    loc := s[i + close + 2:i + close + 2 + end]
                    strings.write_string(b, "<a href=\"")
                    escape_into(b, loc)
                    strings.write_string(b, "\">")
                    render_inline(b, desc)
                    strings.write_string(b, "</a>")
                    i += close + 2 + end + 1
                    continue
                }
            }
            strings.write_byte(b, c)
        case '`':
            if end := strings.index_byte(s[i + 1:], '`'); end != -1 {
                strings.write_string(b, "<code>")
                escape_into(b, s[i + 1:i + 1 + end])
                strings.write_string(b, "</code>")
                i += end + 2
                continue
            }
            strings.write_byte(b, c)
        case '*':
            if end := strings.index_byte(s[i + 1:], '*'); end != -1 {
                strings.write_string(b, "<strong>")
                render_inline(b, s[i + 1:i + 1 + end])
                strings.write_string(b, "</strong>")
                i += end + 2
                continue
            }
            strings.write_byte(b, c)
        case '/':
            if end := strings.index_byte(s[i + 1:], '/'); end != -1 {
                strings.write_string(b, "<em>")
                render_inline(b, s[i + 1:i + 1 + end])
                strings.write_string(b, "</em>")
                i += end + 2
                continue
            }
            strings.write_byte(b, c)
        case '_':
            if end := strings.index_byte(s[i + 1:], '_'); end != -1 {
                strings.write_string(b, "<span class=\"ul\">")
                render_inline(b, s[i + 1:i + 1 + end])
                strings.write_string(b, "</span>")
                i += end + 2
                continue
            }
            strings.write_byte(b, c)
        case '-':
            if end := strings.index_byte(s[i + 1:], '-'); end != -1 {
                strings.write_string(b, "<s>")
                render_inline(b, s[i + 1:i + 1 + end])
                strings.write_string(b, "</s>")
                i += end + 2
                continue
            }
            strings.write_byte(b, c)
        case '^':
            if end := strings.index_byte(s[i + 1:], '^'); end != -1 {
                strings.write_string(b, "<sup>")
                render_inline(b, s[i + 1:i + 1 + end])
                strings.write_string(b, "</sup>")
                i += end + 2
                continue
            }
            strings.write_byte(b, c)
        case '&':
            strings.write_string(b, "&amp;")
        case '<':
            strings.write_string(b, "&lt;")
        case '>':
            strings.write_string(b, "&gt;")
        case:
            strings.write_byte(b, c)
        }
        i += 1
    }
}

escape_into :: proc(b: ^strings.Builder, s: string) {
    for i in 0 ..< len(s) {
        c := s[i]
        switch c {
        case '&':
            strings.write_string(b, "&amp;")
        case '<':
            strings.write_string(b, "&lt;")
        case '>':
            strings.write_string(b, "&gt;")
        case '"':
            strings.write_string(b, "&quot;")
        case:
            strings.write_byte(b, c)
        }
    }
}

// ------------------------------------------------------------------
// code highlighting
// ------------------------------------------------------------------

ODIN_KEYWORDS := "and,or,not,import,package,proc,struct,enum,union,distinct,if,else,for,in,switch,case,break,continue,defer,return,fallthrough,when,where,using,do,typeid,matrix,vector,bit_set,map,bit_field"
ODIN_TYPES := "int,int8,int16,int32,int64,uint,uint8,uint16,uint32,uint64,uintptr,f32,f64,string,cstring,bool,byte,rune,any,rawptr,complex64,complex128,error,size_t,ptrdiff_t"

highlight_line :: proc(b: ^strings.Builder, line: string, lang: string) {
    i := 0
    n := len(line)

    for i < n {
        c := line[i]

        if lang == "odin" && c == '/' && i + 1 < n && line[i + 1] == '/' {
            strings.write_string(b, "<span class=\"tok-cmt\">")
            escape_into(b, line[i:])
            strings.write_string(b, "</span>")
            return
        }

        if lang == "odin" && c == '/' && i + 1 < n && line[i + 1] == '*' {
            end := n
            if j := strings.index(line[i:], "*/"); j != -1 {
                end = i + j + 2
            }
            strings.write_string(b, "<span class=\"tok-cmt\">")
            escape_into(b, line[i:end])
            strings.write_string(b, "</span>")
            i = end
            continue
        }

        if c == '"' || c == '`' || (lang == "odin" && c == '\'') {
            end := n
            j := i + 1
            for j < n {
                if line[j] == '\\' && j + 1 < n {
                    j += 2
                    continue
                }
                if line[j] == c {
                    end = j + 1
                    break
                }
                j += 1
            }
            strings.write_string(b, "<span class=\"tok-str\">")
            escape_into(b, line[i:end])
            strings.write_string(b, "</span>")
            i = end
            continue
        }

        if c >= '0' && c <= '9' {
            j := i
            for j < n && is_num_cont(line[j]) {
                j += 1
            }
            strings.write_string(b, "<span class=\"tok-num\">")
            escape_into(b, line[i:j])
            strings.write_string(b, "</span>")
            i = j
            continue
        }

        if is_ident_start(c) {
            j := i
            for j < n && is_ident_cont(line[j]) {
                j += 1
            }
            word := line[i:j]
            if lang == "odin" {
                if in_word_list(word, ODIN_KEYWORDS) {
                    strings.write_string(b, "<span class=\"tok-kw\">")
                    escape_into(b, word)
                    strings.write_string(b, "</span>")
                } else if in_word_list(word, ODIN_TYPES) {
                    strings.write_string(b, "<span class=\"tok-type\">")
                    escape_into(b, word)
                    strings.write_string(b, "</span>")
                } else {
                    escape_into(b, word)
                }
            } else {
                escape_into(b, word)
            }
            i = j
            continue
        }

        escape_into(b, line[i:i + 1])
        i += 1
    }
}

is_ident_start :: proc(c: byte) -> bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

in_word_list :: proc(word, list: string) -> bool {
    start := 0
    for {
        end := strings.index_byte(list[start:], ',')
        token := list[start:] if end == -1 else list[start:start + end]
        if token == word {
            return true
        }
        if end == -1 {
            return false
        }
        start += end + 1
    }
}

is_ident_cont :: proc(c: byte) -> bool {
    return is_ident_start(c) || (c >= '0' && c <= '9')
}

is_num_cont :: proc(c: byte) -> bool {
    return (c >= '0' && c <= '9') ||
        (c >= 'a' && c <= 'f') ||
        (c >= 'A' && c <= 'F') ||
        c == '_' || c == 'x' || c == 'X' || c == '.' ||
        c == 'e' || c == 'E'
}

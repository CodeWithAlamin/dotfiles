hl.config({
general = {
        layout = "scrolling",
        no_focus_fallback = true,
    },
    scrolling = {
        wrap_swapcol = false,
        wrap_focus = false,
        explicit_column_widths = "0.333, 0.5, 0.667",
        fullscreen_on_one_column = true,
        follow_focus = true,
        follow_min_visible = 0.009,
    },
    
    binds = {
        movefocus_cycles_fullscreen = true,
    },
    
    dwindle = {
        preserve_split = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
    misc = {
        col = {
            splash = CACHYLGREEN,
        },
        middle_click_paste = false,
        enable_swallow = true,
        swallow_regex = "(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)",
        vrr = 3,
    },
    render = {
        direct_scanout = 2,
        -- Use the option below if you find games constantly black screening for a couple seconds whenever direct scanout enables/disables
        -- non_shader_cm = 0,
    },
    xwayland = {
        force_zero_scaling = true
    },
})

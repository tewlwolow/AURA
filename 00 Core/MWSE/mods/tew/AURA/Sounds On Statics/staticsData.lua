local this = {}

this.shelterStatics = {
    "tent",
    "shed",
    "overhang",
    "awning",
}
this.blockedShelterStatics = {
    "crushed",
    "houseshed",
    "setsky_x_shed", -- Tamriel_Data house addon
}

this.modules = {
    ["rainOnStatics"] = {
        ["ids"] = {
            "flag",
            "tent",
            "drs_tnt",
            "a1_dat_srt_ext", -- Sea Rover's Tent
            "skin",
            "shed",           -- sheds are generally made out of wood, but so are some awnings
            "fabric",
            "awning",
            "banner",
            "_ban_",       -- also banner
            "overhang",
            "marketstand", -- relevant Tamriel_Data and OAAB_Data assets
            "gather",
        },
        ["blocked"] = {
            "bannerpost",
            "_at_banner",        -- On the move bannerpost
            "hanger",
            "ex_ashl_banner",    -- vanilla bannerpost
            "flagpole",
            "flagon",            -- OAAB_Data
            "aaa_refernce_flag", -- ?
            "crushed",
            "houseshed",
            "setsky_x_shed", -- Tamriel_Data house addon
        },
        ["ignore"] = {
            "signpost",
            "signpole",
            "_pole",
            "railing",
            "hanger",
            "banner",
            "_ban_",
            "flag",
            "hv_de_setveloth_beam_01", -- wood log used as a flag hanger in Heart of the Velothi - Gnisis
            "ex_t_brace_01",           -- used as a banner hanger
        },
    },
    ["shelterRain"] = {
        ["ids"] = this.shelterStatics,
        ["blocked"] = this.blockedShelterStatics,
        ["ignore"] = {},
    },
    ["shelterWind"] = {
        ["ids"] = {
            "tent",
        },
        ["blocked"] = {},
        ["ignore"] = {},
    },
    ["shelterWeather"] = {
        ["ids"] = this.shelterStatics,
        ["blocked"] = this.blockedShelterStatics,
        ["ignore"] = {},
    },
    ["ropeBridge"] = {
        ["ids"] = {
            "ropebridge",
        },
        ["blocked"] = {
            "ropebridge_stake",
            "ropebridgestake",
        },
        ["ignore"] = {},
    },
    ["photodragons"] = {
        ["ids"] = {
            "photodragons",
        },
        ["blocked"] = {},
        ["ignore"] = {},
    },
    ["bannerFlap"] = {
        ["ids"] = {
            "banner",
            "_ban_",
            "flag",
        },
        ["blocked"] = {
            "bannerpost",
            "_at_banner",
            "hanger",
            "ex_ashl_banner",
            "flagpole",
            "flagon",
            "aaa_refernce_flag",
        },
        ["ignore"] = {},
    },
}

return this

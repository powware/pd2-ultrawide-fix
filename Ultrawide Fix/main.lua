UltrawideFix = UltrawideFix or {}
UltrawideFix.default_settings = {
    base_res_scale = 1,
    saferect_border_scale_x = 3.2,
    saferect_border_scale_y = 3.2
}

UltrawideFix._mod_path = ModPath
UltrawideFix._options_menu_file = UltrawideFix._mod_path .. "menu/options.json"
UltrawideFix._save_path = SavePath
UltrawideFix._save_file = UltrawideFix._save_path .. "ultrawide_fix.json"

HSAS = HSAS or {}

local function deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deep_copy(orig_key)] = deep_copy(orig_value)
        end
        setmetatable(copy, deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function UltrawideFix:Setup()
    if not self.settings then
        self:Load()
    end

    self.SetupHooks()
end

function UltrawideFix:Load()
    self.settings = deep_copy(self.default_settings)
    local file = io.open(self._save_file, "r")
    if file then
        local data = file:read("*a")
        if data then
            local decoded_data = json.decode(data)

            if decoded_data then
                for key, value in pairs(self.settings) do
                    if decoded_data[key] ~= nil then
                        self.settings[key] = decoded_data[key]
                    end
                end
            end
        end
        file:close()
    end
end

function UltrawideFix:Save()
    local file = io.open(self._save_file, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

function UltrawideFix.SetupHooks()
    if RequiredScript == "core/lib/managers/viewport/coreviewportmanager" then
        local settings = UltrawideFix.settings

        core:module("CoreViewportManager")

        function ViewportManager:get_safe_rect()
            return {
                x = settings.saferect_border_scale_x * 0.01,
                y = settings.saferect_border_scale_y * 0.01,
                width = 1 - settings.saferect_border_scale_x * 0.01 * 2,
                height = 1 - settings.saferect_border_scale_y * 0.01 * 2
            }
        end
    elseif RequiredScript == "core/lib/managers/coreguidatamanager" then
        local settings = UltrawideFix.settings

        if core then
            core:module("CoreGuiDataManager")
        end

        function GuiDataManager:get_base_res()
            return self._base_res.x, self._base_res.y
        end

        function GuiDataManager:scaled_size()
            local w = math.round(self:_get_safe_rect().width * self._base_res.x)
            local h = math.round(self:_get_safe_rect().height * self._base_res.y)

            return {
                x = 0,
                y = 0,
                width = w,
                height = h
            }
        end

        function GuiDataManager:_setup_workspace_data()
            local res = self._static_resolution or RenderSettings.resolution
            local aspect = res.x / res.y
            self._base_res = {
                x = 720 * aspect * settings.base_res_scale,
                y = 720 * settings.base_res_scale
            }

            self._saferect_data = {}
            self._corner_saferect_data = {}
            self._fullrect_data = {}
            local safe_rect = self:_get_safe_rect_pixels()
            local scaled_size = self:scaled_size()
            local res = self._static_resolution or RenderSettings.resolution
            local w = scaled_size.width
            local h = scaled_size.height
            local sh = math.min(safe_rect.height, safe_rect.width / (w / h))
            local sw = math.min(safe_rect.width, safe_rect.height * w / h)
            local x = res.x / 2 - sh * w / h / 2
            local y = res.y / 2 - sw / (w / h) / 2
            self._safe_x = x
            self._safe_y = y
            self._saferect_data.w = w
            self._saferect_data.h = h
            self._saferect_data.width = self._saferect_data.w
            self._saferect_data.height = self._saferect_data.h
            self._saferect_data.x = x
            self._saferect_data.y = y
            self._saferect_data.on_screen_width = sw
            local h_c = w / (safe_rect.width / safe_rect.height)
            h = math.max(h, h_c)
            local w_c = h_c / h
            w = math.max(w, w / w_c)
            self._corner_saferect_data.w = w
            self._corner_saferect_data.h = h
            self._corner_saferect_data.width = self._corner_saferect_data.w
            self._corner_saferect_data.height = self._corner_saferect_data.h
            self._corner_saferect_data.x = safe_rect.x
            self._corner_saferect_data.y = safe_rect.y
            self._corner_saferect_data.on_screen_width = safe_rect.width
            sh = self._base_res.x / self:_aspect_ratio()
            h = math.max(self._base_res.y, sh)
            sw = sh / h
            w = math.max(self._base_res.x, self._base_res.x / sw)
            self._fullrect_data.w = w
            self._fullrect_data.h = h
            self._fullrect_data.width = self._fullrect_data.w
            self._fullrect_data.height = self._fullrect_data.h
            self._fullrect_data.x = 0
            self._fullrect_data.y = 0
            self._fullrect_data.on_screen_width = res.x
            self._fullrect_data.convert_x = math.floor((w - scaled_size.width) / 2)
            self._fullrect_data.convert_y = math.floor((h - scaled_size.height) / 2)
            self._fullrect_data.corner_convert_x =
                math.floor((self._fullrect_data.width - self._corner_saferect_data.width) / 2)
            self._fullrect_data.corner_convert_y =
                math.floor((self._fullrect_data.height - self._corner_saferect_data.height) / 2)

            self._fullrect_16_9_data = self._fullrect_data
            self._fullrect_1280_data = self._fullrect_data
            self._corner_saferect_1280_data = self._corner_saferect_data
        end

        Hooks:PreHook(
            GuiDataManager,
            "resolution_changed",
            "UltrawideFix_GuiDataManager_resolution_changed",
            function(self)
                self._base_res = {
                    x = 720 * self:_aspect_ratio() * settings.base_res_scale,
                    y = 720 * settings.base_res_scale
                }
            end
        )
    elseif RequiredScript == "lib/managers/mousepointermanager" then
        MousePointerManager.convert_1280_mouse_pos = MousePointerManager.convert_fullscreen_mouse_pos
        MousePointerManager.convert_fullscreen_16_9_mouse_pos = MousePointerManager.convert_fullscreen_mouse_pos
    end

    Hooks:Add(
        "LocalizationManagerPostInit",
        "UltrawideFix_LocalizationManagerPostInit",
        function(loc)
            loc:load_localization_file(UltrawideFix._mod_path .. "loc/english.txt")
        end
    )

    Hooks:Add(
        "MenuManagerInitialize",
        "UltrawideFix_MenuManagerInitialize",
        function(menu_manager)
            function MenuCallbackHandler:ultrawide_fix_base_res_scale_callback(item)
                UltrawideFix.settings.base_res_scale = math.round_with_precision(item:value(), 2)
            end

            function MenuCallbackHandler:ultrawide_fix_saferect_border_scale_x_callback(item)
                UltrawideFix.settings.saferect_border_scale_x = math.round_with_precision(item:value(), 2)
            end

            function MenuCallbackHandler:ultrawide_fix_saferect_border_scale_y_callback(item)
                UltrawideFix.settings.saferect_border_scale_y = math.round_with_precision(item:value(), 2)
            end

            function MenuCallbackHandler:ultrawide_fix_back_callback(item)
                UltrawideFix:Save()
                managers.viewport:resolution_changed()
            end

            function MenuCallbackHandler:ultrawide_fix_default_callback(item)
                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["ultrawide_fix_base_res_scale"] = true},
                    UltrawideFix.default_settings.base_res_scale
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["ultrawide_fix_saferect_border_scale_x"] = true},
                    UltrawideFix.default_settings.saferect_border_scale_x
                )

                MenuHelper:ResetItemsToDefaultValue(
                    item,
                    {["ultrawide_fix_saferect_border_scale_y"] = true},
                    UltrawideFix.default_settings.saferect_border_scale_y
                )

                UltrawideFix:Save()
                managers.viewport:resolution_changed()
            end

            MenuHelper:LoadFromJsonFile(UltrawideFix._options_menu_file, UltrawideFix, UltrawideFix.settings)
        end
    )
end

UltrawideFix:Setup()

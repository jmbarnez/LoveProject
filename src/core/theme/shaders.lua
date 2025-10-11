local Shaders = {}

function Shaders.setup(Theme)
  Theme.shaders = {}

  function Theme.init()
    Theme.shaders.ui_blur = love.graphics.newShader[[
        extern number blur_amount;
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
            vec4 sum = vec4(0.0);
            float blur = blur_amount / love_ScreenSize.x;
            sum += Texel(tex, vec2(texture_coords.x - 4.0 * blur, texture_coords.y)) * 0.05;
            sum += Texel(tex, vec2(texture_coords.x - 3.0 * blur, texture_coords.y)) * 0.09;
            sum += Texel(tex, vec2(texture_coords.x - 2.0 * blur, texture_coords.y)) * 0.12;
            sum += Texel(tex, vec2(texture_coords.x - 1.0 * blur, texture_coords.y)) * 0.15;
            sum += Texel(tex, vec2(texture_coords.x, texture_coords.y)) * 0.16;
            sum += Texel(tex, vec2(texture_coords.x + 1.0 * blur, texture_coords.y)) * 0.15;
            sum += Texel(tex, vec2(texture_coords.x + 2.0 * blur, texture_coords.y)) * 0.12;
            sum += Texel(tex, vec2(texture_coords.x + 3.0 * blur, texture_coords.y)) * 0.09;
            sum += Texel(tex, vec2(texture_coords.x + 4.0 * blur, texture_coords.y)) * 0.05;
            return sum;
        }
    ]]
    Theme.shaders.ui_blur:send("blur_amount", 2.0)
  end
end

return Shaders
